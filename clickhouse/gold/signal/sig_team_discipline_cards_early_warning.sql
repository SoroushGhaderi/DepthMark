INSERT INTO gold.sig_team_discipline_cards_early_warning (
    match_id,
    match_date,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,
    triggered_side,
    triggered_team_id,
    triggered_team_name,
    opponent_team_id,
    opponent_team_name,
    trigger_threshold_min_distinct_booked_players_early,
    trigger_threshold_booking_minute_exclusive,
    triggered_team_distinct_booked_players_early,
    opponent_distinct_booked_players_early,
    distinct_booked_players_early_delta,
    triggered_team_early_bookings_total,
    opponent_early_bookings_total,
    early_bookings_total_delta,
    triggered_team_first_booking_minute_early,
    opponent_first_booking_minute_early,
    triggered_team_third_distinct_booking_minute_early,
    opponent_third_distinct_booking_minute_early,
    triggered_team_early_booked_player_share_pct,
    opponent_early_booked_player_share_pct,
    triggered_team_yellow_cards,
    opponent_yellow_cards,
    triggered_team_red_cards,
    opponent_red_cards,
    triggered_team_total_cards,
    opponent_total_cards,
    card_count_delta,
    triggered_team_fouls_committed,
    opponent_fouls_committed,
    fouls_committed_delta,
    triggered_team_duels_won,
    opponent_duels_won,
    triggered_team_tackles_won,
    opponent_tackles_won,
    triggered_team_interceptions,
    opponent_interceptions,
    triggered_team_clearances,
    opponent_clearances,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct
)
-- Signal: sig_team_discipline_cards_early_warning
-- Trigger: team has 3 distinct booked players before the 30th minute.
-- Intent: detect early team-level discipline stress from distributed cautions across multiple players.
WITH booking_events AS (
    SELECT
        c.match_id,
        lowerUTF8(coalesce(c.team_side, '')) AS card_team_side,
        toInt32(assumeNotNull(c.player_id)) AS player_id,
        toInt32OrZero(c.card_minute) AS card_minute
    FROM silver.card AS c
    WHERE c.match_id > 0
      AND c.player_id IS NOT NULL
      AND lowerUTF8(coalesce(c.team_side, '')) IN ('home', 'away')
      AND toInt32OrZero(c.card_minute) BETWEEN 1 AND 29
      AND (
            positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'yellow') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'yellow') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'booked') > 0
      )
),
first_booking_per_player AS (
    SELECT
        be.match_id,
        be.card_team_side AS triggered_side,
        be.player_id,
        min(be.card_minute) AS first_booking_minute
    FROM booking_events AS be
    GROUP BY
        be.match_id,
        triggered_side,
        be.player_id
),
early_booking_counts AS (
    SELECT
        be.match_id,
        be.card_team_side AS triggered_side,
        count() AS early_bookings_total
    FROM booking_events AS be
    GROUP BY
        be.match_id,
        triggered_side
),
team_booking_rollup AS (
    SELECT
        fb.match_id,
        fb.triggered_side,
        count() AS distinct_booked_players_early,
        min(fb.first_booking_minute) AS first_booking_minute_early,
        toNullable(if(
            count() >= 3,
            arrayElement(arraySort(groupArray(fb.first_booking_minute)), 3),
            NULL
        )) AS third_distinct_booking_minute_early
    FROM first_booking_per_player AS fb
    GROUP BY
        fb.match_id,
        fb.triggered_side
)
SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    tbr.triggered_side,
    if(tbr.triggered_side = 'home', m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(tbr.triggered_side = 'home', m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(tbr.triggered_side = 'home', m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(tbr.triggered_side = 'home', m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(3) AS trigger_threshold_min_distinct_booked_players_early,
    toInt32(30) AS trigger_threshold_booking_minute_exclusive,
    toInt32(tbr.distinct_booked_players_early) AS triggered_team_distinct_booked_players_early,
    toInt32(coalesce(obr.distinct_booked_players_early, 0)) AS opponent_distinct_booked_players_early,
    toInt32(tbr.distinct_booked_players_early - coalesce(obr.distinct_booked_players_early, 0)) AS distinct_booked_players_early_delta,
    toInt32(coalesce(tebc.early_bookings_total, 0)) AS triggered_team_early_bookings_total,
    toInt32(coalesce(oebc.early_bookings_total, 0)) AS opponent_early_bookings_total,
    toInt32(coalesce(tebc.early_bookings_total, 0) - coalesce(oebc.early_bookings_total, 0)) AS early_bookings_total_delta,
    toInt32(tbr.first_booking_minute_early) AS triggered_team_first_booking_minute_early,
    toNullable(toInt32(obr.first_booking_minute_early)) AS opponent_first_booking_minute_early,
    toInt32(tbr.third_distinct_booking_minute_early) AS triggered_team_third_distinct_booking_minute_early,
    toNullable(toInt32(obr.third_distinct_booking_minute_early)) AS opponent_third_distinct_booking_minute_early,
    toFloat32(round(
        100.0 * tbr.distinct_booked_players_early
        / nullIf(tbr.distinct_booked_players_early + coalesce(obr.distinct_booked_players_early, 0), 0),
        1
    )) AS triggered_team_early_booked_player_share_pct,
    toFloat32(round(
        100.0 * coalesce(obr.distinct_booked_players_early, 0)
        / nullIf(tbr.distinct_booked_players_early + coalesce(obr.distinct_booked_players_early, 0), 0),
        1
    )) AS opponent_early_booked_player_share_pct,

    toInt32(multiIf(
        tbr.triggered_side = 'home', coalesce(ps.yellow_cards_home, 0),
        tbr.triggered_side = 'away', coalesce(ps.yellow_cards_away, 0),
        0
    )) AS triggered_team_yellow_cards,
    toInt32(multiIf(
        tbr.triggered_side = 'home', coalesce(ps.yellow_cards_away, 0),
        tbr.triggered_side = 'away', coalesce(ps.yellow_cards_home, 0),
        0
    )) AS opponent_yellow_cards,
    toInt32(multiIf(
        tbr.triggered_side = 'home', coalesce(ps.red_cards_home, 0),
        tbr.triggered_side = 'away', coalesce(ps.red_cards_away, 0),
        0
    )) AS triggered_team_red_cards,
    toInt32(multiIf(
        tbr.triggered_side = 'home', coalesce(ps.red_cards_away, 0),
        tbr.triggered_side = 'away', coalesce(ps.red_cards_home, 0),
        0
    )) AS opponent_red_cards,
    toInt32(multiIf(
        tbr.triggered_side = 'home',
            coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        tbr.triggered_side = 'away',
            coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        0
    )) AS triggered_team_total_cards,
    toInt32(multiIf(
        tbr.triggered_side = 'home',
            coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        tbr.triggered_side = 'away',
            coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        0
    )) AS opponent_total_cards,
    toInt32(
        multiIf(
            tbr.triggered_side = 'home',
                coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
            tbr.triggered_side = 'away',
                coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
            0
        ) - multiIf(
            tbr.triggered_side = 'home',
                coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
            tbr.triggered_side = 'away',
                coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
            0
        )
    ) AS card_count_delta,
    toInt32(multiIf(
        tbr.triggered_side = 'home', coalesce(ps.fouls_home, 0),
        tbr.triggered_side = 'away', coalesce(ps.fouls_away, 0),
        0
    )) AS triggered_team_fouls_committed,
    toInt32(multiIf(
        tbr.triggered_side = 'home', coalesce(ps.fouls_away, 0),
        tbr.triggered_side = 'away', coalesce(ps.fouls_home, 0),
        0
    )) AS opponent_fouls_committed,
    toInt32(
        multiIf(
            tbr.triggered_side = 'home', coalesce(ps.fouls_home, 0),
            tbr.triggered_side = 'away', coalesce(ps.fouls_away, 0),
            0
        ) - multiIf(
            tbr.triggered_side = 'home', coalesce(ps.fouls_away, 0),
            tbr.triggered_side = 'away', coalesce(ps.fouls_home, 0),
            0
        )
    ) AS fouls_committed_delta,
    toInt32(multiIf(
        tbr.triggered_side = 'home', coalesce(ps.duels_won_home, 0),
        tbr.triggered_side = 'away', coalesce(ps.duels_won_away, 0),
        0
    )) AS triggered_team_duels_won,
    toInt32(multiIf(
        tbr.triggered_side = 'home', coalesce(ps.duels_won_away, 0),
        tbr.triggered_side = 'away', coalesce(ps.duels_won_home, 0),
        0
    )) AS opponent_duels_won,
    toInt32(multiIf(
        tbr.triggered_side = 'home', coalesce(ps.tackles_succeeded_home, 0),
        tbr.triggered_side = 'away', coalesce(ps.tackles_succeeded_away, 0),
        0
    )) AS triggered_team_tackles_won,
    toInt32(multiIf(
        tbr.triggered_side = 'home', coalesce(ps.tackles_succeeded_away, 0),
        tbr.triggered_side = 'away', coalesce(ps.tackles_succeeded_home, 0),
        0
    )) AS opponent_tackles_won,
    toInt32(multiIf(
        tbr.triggered_side = 'home', coalesce(ps.interceptions_home, 0),
        tbr.triggered_side = 'away', coalesce(ps.interceptions_away, 0),
        0
    )) AS triggered_team_interceptions,
    toInt32(multiIf(
        tbr.triggered_side = 'home', coalesce(ps.interceptions_away, 0),
        tbr.triggered_side = 'away', coalesce(ps.interceptions_home, 0),
        0
    )) AS opponent_interceptions,
    toInt32(multiIf(
        tbr.triggered_side = 'home', coalesce(ps.clearances_home, 0),
        tbr.triggered_side = 'away', coalesce(ps.clearances_away, 0),
        0
    )) AS triggered_team_clearances,
    toInt32(multiIf(
        tbr.triggered_side = 'home', coalesce(ps.clearances_away, 0),
        tbr.triggered_side = 'away', coalesce(ps.clearances_home, 0),
        0
    )) AS opponent_clearances,
    toFloat32(multiIf(
        tbr.triggered_side = 'home', coalesce(ps.ball_possession_home, 0),
        tbr.triggered_side = 'away', coalesce(ps.ball_possession_away, 0),
        0
    )) AS triggered_team_possession_pct,
    toFloat32(multiIf(
        tbr.triggered_side = 'home', coalesce(ps.ball_possession_away, 0),
        tbr.triggered_side = 'away', coalesce(ps.ball_possession_home, 0),
        0
    )) AS opponent_possession_pct,
    toFloat32(round(
        multiIf(
            tbr.triggered_side = 'home', coalesce(ps.ball_possession_home, 0),
            tbr.triggered_side = 'away', coalesce(ps.ball_possession_away, 0),
            0
        ) - multiIf(
            tbr.triggered_side = 'home', coalesce(ps.ball_possession_away, 0),
            tbr.triggered_side = 'away', coalesce(ps.ball_possession_home, 0),
            0
        ),
        1
    )) AS possession_delta_pct

FROM team_booking_rollup AS tbr
INNER JOIN silver.match AS m
    ON m.match_id = tbr.match_id
LEFT JOIN team_booking_rollup AS obr
    ON obr.match_id = tbr.match_id
   AND obr.triggered_side = if(tbr.triggered_side = 'home', 'away', 'home')
LEFT JOIN early_booking_counts AS tebc
    ON tebc.match_id = tbr.match_id
   AND tebc.triggered_side = tbr.triggered_side
LEFT JOIN early_booking_counts AS oebc
    ON oebc.match_id = tbr.match_id
   AND oebc.triggered_side = if(tbr.triggered_side = 'home', 'away', 'home')
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = tbr.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND tbr.distinct_booked_players_early >= 3

ORDER BY
    triggered_team_distinct_booked_players_early DESC,
    triggered_team_third_distinct_booking_minute_early ASC,
    early_bookings_total_delta DESC,
    m.match_date DESC,
    m.match_id DESC;
