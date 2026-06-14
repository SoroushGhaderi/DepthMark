INSERT INTO gold.sig_team_discipline_cards_the_triple_booking (
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
    trigger_threshold_min_distinct_yellow_carded_players,
    trigger_threshold_rolling_window_minutes,
    triggered_team_booking_window_start_minute,
    triggered_team_booking_window_end_minute,
    triggered_team_third_distinct_yellow_card_minute,
    triggered_team_distinct_yellow_carded_players_in_window,
    opponent_max_distinct_yellow_carded_players_in_window,
    distinct_yellow_carded_players_in_window_delta,
    triggered_team_yellow_card_events_in_window,
    opponent_max_yellow_card_events_in_window,
    yellow_card_events_in_window_delta,
    triggered_team_match_yellow_card_events,
    opponent_match_yellow_card_events,
    match_yellow_card_events_delta,
    triggered_team_yellow_cards,
    opponent_yellow_cards,
    yellow_cards_delta,
    triggered_team_red_cards,
    opponent_red_cards,
    red_cards_delta,
    triggered_team_total_cards,
    opponent_total_cards,
    card_count_delta,
    triggered_team_fouls_committed,
    opponent_fouls_committed,
    fouls_committed_delta,
    triggered_team_cards_per_foul_pct,
    opponent_cards_per_foul_pct,
    cards_per_foul_delta_pct,
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
-- Signal: sig_team_discipline_cards_the_triple_booking
-- Trigger: 3 different players on the same team receive yellow cards inside one rolling 5-minute window.
-- Intent: detect compact team-wide booking clusters that indicate a sudden discipline flashpoint rather than broad full-match caution volume.
WITH yellow_card_events AS (
    SELECT
        c.match_id,
        lowerUTF8(coalesce(c.team_side, '')) AS triggered_side,
        toInt32(assumeNotNull(c.player_id)) AS triggered_player_id,
        coalesce(c.player_name, 'Unknown') AS triggered_player_name,
        toInt32(c.card_minute) AS card_minute,
        c.event_id
    FROM silver.card AS c
    WHERE c.match_id > 0
      AND c.player_id IS NOT NULL
      AND lowerUTF8(coalesce(c.team_side, '')) IN ('home', 'away')
      AND c.card_minute > 0
      AND (
            positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'yellow') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'yellow') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'booked') > 0
      )
),
window_starts AS (
    SELECT
        yce.match_id,
        yce.triggered_side,
        yce.card_minute AS window_start_minute
    FROM yellow_card_events AS yce
    GROUP BY
        yce.match_id,
        yce.triggered_side,
        window_start_minute
),
window_player_bookings AS (
    SELECT
        ws.match_id,
        ws.triggered_side,
        ws.window_start_minute,
        yce.triggered_player_id,
        min(yce.card_minute) AS player_first_yellow_card_minute_in_window,
        max(yce.card_minute) AS player_last_yellow_card_minute_in_window,
        count() AS player_yellow_card_events_in_window
    FROM window_starts AS ws
    INNER JOIN yellow_card_events AS yce
        ON yce.match_id = ws.match_id
       AND yce.triggered_side = ws.triggered_side
    WHERE yce.card_minute >= ws.window_start_minute
      AND yce.card_minute <= ws.window_start_minute + 5
    GROUP BY
        ws.match_id,
        ws.triggered_side,
        ws.window_start_minute,
        yce.triggered_player_id
),
window_rollup AS (
    SELECT
        wpb.match_id,
        wpb.triggered_side,
        wpb.window_start_minute,
        max(wpb.player_last_yellow_card_minute_in_window) AS window_end_minute,
        count() AS distinct_yellow_carded_players_in_window,
        sum(wpb.player_yellow_card_events_in_window) AS yellow_card_events_in_window,
        arrayElement(
            arraySort(groupArray(wpb.player_first_yellow_card_minute_in_window)),
            3
        ) AS third_distinct_yellow_card_minute
    FROM window_player_bookings AS wpb
    GROUP BY
        wpb.match_id,
        wpb.triggered_side,
        wpb.window_start_minute
),
ranked_qualifying_windows AS (
    SELECT
        wr.match_id,
        wr.triggered_side,
        wr.window_start_minute,
        wr.window_end_minute,
        wr.third_distinct_yellow_card_minute,
        wr.distinct_yellow_carded_players_in_window,
        wr.yellow_card_events_in_window,
        row_number() OVER (
            PARTITION BY wr.match_id, wr.triggered_side
            ORDER BY
                wr.window_start_minute ASC,
                wr.third_distinct_yellow_card_minute ASC,
                wr.window_end_minute ASC,
                wr.yellow_card_events_in_window DESC
        ) AS rn
    FROM window_rollup AS wr
    WHERE wr.distinct_yellow_carded_players_in_window >= 3
),
best_team_window AS (
    SELECT
        rqw.match_id,
        rqw.triggered_side,
        rqw.window_start_minute,
        rqw.window_end_minute,
        rqw.third_distinct_yellow_card_minute,
        rqw.distinct_yellow_carded_players_in_window,
        rqw.yellow_card_events_in_window
    FROM ranked_qualifying_windows AS rqw
    WHERE rqw.rn = 1
),
team_window_max AS (
    SELECT
        wr.match_id,
        wr.triggered_side,
        max(wr.distinct_yellow_carded_players_in_window) AS max_distinct_yellow_carded_players_in_window,
        max(wr.yellow_card_events_in_window) AS max_yellow_card_events_in_window
    FROM window_rollup AS wr
    GROUP BY
        wr.match_id,
        wr.triggered_side
),
match_yellow_event_counts AS (
    SELECT
        yce.match_id,
        yce.triggered_side,
        count() AS match_yellow_card_events
    FROM yellow_card_events AS yce
    GROUP BY
        yce.match_id,
        yce.triggered_side
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

    btw.triggered_side,
    if(btw.triggered_side = 'home', m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(btw.triggered_side = 'home', m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(btw.triggered_side = 'home', m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(btw.triggered_side = 'home', m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(3) AS trigger_threshold_min_distinct_yellow_carded_players,
    toInt32(5) AS trigger_threshold_rolling_window_minutes,
    toInt32(btw.window_start_minute) AS triggered_team_booking_window_start_minute,
    toInt32(btw.window_end_minute) AS triggered_team_booking_window_end_minute,
    toInt32(btw.third_distinct_yellow_card_minute) AS triggered_team_third_distinct_yellow_card_minute,
    toInt32(btw.distinct_yellow_carded_players_in_window) AS triggered_team_distinct_yellow_carded_players_in_window,
    toInt32(coalesce(otwm.max_distinct_yellow_carded_players_in_window, 0)) AS opponent_max_distinct_yellow_carded_players_in_window,
    toInt32(
        btw.distinct_yellow_carded_players_in_window
        - coalesce(otwm.max_distinct_yellow_carded_players_in_window, 0)
    ) AS distinct_yellow_carded_players_in_window_delta,
    toInt32(btw.yellow_card_events_in_window) AS triggered_team_yellow_card_events_in_window,
    toInt32(coalesce(otwm.max_yellow_card_events_in_window, 0)) AS opponent_max_yellow_card_events_in_window,
    toInt32(
        btw.yellow_card_events_in_window
        - coalesce(otwm.max_yellow_card_events_in_window, 0)
    ) AS yellow_card_events_in_window_delta,
    toInt32(coalesce(tmyc.match_yellow_card_events, 0)) AS triggered_team_match_yellow_card_events,
    toInt32(coalesce(omyc.match_yellow_card_events, 0)) AS opponent_match_yellow_card_events,
    toInt32(
        coalesce(tmyc.match_yellow_card_events, 0)
        - coalesce(omyc.match_yellow_card_events, 0)
    ) AS match_yellow_card_events_delta,

    toInt32(multiIf(
        btw.triggered_side = 'home', coalesce(ps.yellow_cards_home, 0),
        btw.triggered_side = 'away', coalesce(ps.yellow_cards_away, 0),
        0
    )) AS triggered_team_yellow_cards,
    toInt32(multiIf(
        btw.triggered_side = 'home', coalesce(ps.yellow_cards_away, 0),
        btw.triggered_side = 'away', coalesce(ps.yellow_cards_home, 0),
        0
    )) AS opponent_yellow_cards,
    toInt32(
        multiIf(
            btw.triggered_side = 'home', coalesce(ps.yellow_cards_home, 0),
            btw.triggered_side = 'away', coalesce(ps.yellow_cards_away, 0),
            0
        ) - multiIf(
            btw.triggered_side = 'home', coalesce(ps.yellow_cards_away, 0),
            btw.triggered_side = 'away', coalesce(ps.yellow_cards_home, 0),
            0
        )
    ) AS yellow_cards_delta,
    toInt32(multiIf(
        btw.triggered_side = 'home', coalesce(ps.red_cards_home, 0),
        btw.triggered_side = 'away', coalesce(ps.red_cards_away, 0),
        0
    )) AS triggered_team_red_cards,
    toInt32(multiIf(
        btw.triggered_side = 'home', coalesce(ps.red_cards_away, 0),
        btw.triggered_side = 'away', coalesce(ps.red_cards_home, 0),
        0
    )) AS opponent_red_cards,
    toInt32(
        multiIf(
            btw.triggered_side = 'home', coalesce(ps.red_cards_home, 0),
            btw.triggered_side = 'away', coalesce(ps.red_cards_away, 0),
            0
        ) - multiIf(
            btw.triggered_side = 'home', coalesce(ps.red_cards_away, 0),
            btw.triggered_side = 'away', coalesce(ps.red_cards_home, 0),
            0
        )
    ) AS red_cards_delta,
    toInt32(multiIf(
        btw.triggered_side = 'home',
            coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        btw.triggered_side = 'away',
            coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        0
    )) AS triggered_team_total_cards,
    toInt32(multiIf(
        btw.triggered_side = 'home',
            coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        btw.triggered_side = 'away',
            coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        0
    )) AS opponent_total_cards,
    toInt32(
        multiIf(
            btw.triggered_side = 'home',
                coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
            btw.triggered_side = 'away',
                coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
            0
        ) - multiIf(
            btw.triggered_side = 'home',
                coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
            btw.triggered_side = 'away',
                coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
            0
        )
    ) AS card_count_delta,
    toInt32(multiIf(
        btw.triggered_side = 'home', coalesce(ps.fouls_home, 0),
        btw.triggered_side = 'away', coalesce(ps.fouls_away, 0),
        0
    )) AS triggered_team_fouls_committed,
    toInt32(multiIf(
        btw.triggered_side = 'home', coalesce(ps.fouls_away, 0),
        btw.triggered_side = 'away', coalesce(ps.fouls_home, 0),
        0
    )) AS opponent_fouls_committed,
    toInt32(
        multiIf(
            btw.triggered_side = 'home', coalesce(ps.fouls_home, 0),
            btw.triggered_side = 'away', coalesce(ps.fouls_away, 0),
            0
        ) - multiIf(
            btw.triggered_side = 'home', coalesce(ps.fouls_away, 0),
            btw.triggered_side = 'away', coalesce(ps.fouls_home, 0),
            0
        )
    ) AS fouls_committed_delta,
    toNullable(toFloat32(round(
        100.0 * multiIf(
            btw.triggered_side = 'home',
                coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
            btw.triggered_side = 'away',
                coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
            0
        ) / nullIf(toFloat64(multiIf(
            btw.triggered_side = 'home', coalesce(ps.fouls_home, 0),
            btw.triggered_side = 'away', coalesce(ps.fouls_away, 0),
            0
        )), 0),
        1
    ))) AS triggered_team_cards_per_foul_pct,
    toNullable(toFloat32(round(
        100.0 * multiIf(
            btw.triggered_side = 'home',
                coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
            btw.triggered_side = 'away',
                coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
            0
        ) / nullIf(toFloat64(multiIf(
            btw.triggered_side = 'home', coalesce(ps.fouls_away, 0),
            btw.triggered_side = 'away', coalesce(ps.fouls_home, 0),
            0
        )), 0),
        1
    ))) AS opponent_cards_per_foul_pct,
    toNullable(toFloat32(round(
        (
            100.0 * multiIf(
                btw.triggered_side = 'home',
                    coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
                btw.triggered_side = 'away',
                    coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
                0
            ) / nullIf(toFloat64(multiIf(
                btw.triggered_side = 'home', coalesce(ps.fouls_home, 0),
                btw.triggered_side = 'away', coalesce(ps.fouls_away, 0),
                0
            )), 0)
        ) - (
            100.0 * multiIf(
                btw.triggered_side = 'home',
                    coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
                btw.triggered_side = 'away',
                    coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
                0
            ) / nullIf(toFloat64(multiIf(
                btw.triggered_side = 'home', coalesce(ps.fouls_away, 0),
                btw.triggered_side = 'away', coalesce(ps.fouls_home, 0),
                0
            )), 0)
        ),
        1
    ))) AS cards_per_foul_delta_pct,
    toInt32(multiIf(
        btw.triggered_side = 'home', coalesce(ps.duels_won_home, 0),
        btw.triggered_side = 'away', coalesce(ps.duels_won_away, 0),
        0
    )) AS triggered_team_duels_won,
    toInt32(multiIf(
        btw.triggered_side = 'home', coalesce(ps.duels_won_away, 0),
        btw.triggered_side = 'away', coalesce(ps.duels_won_home, 0),
        0
    )) AS opponent_duels_won,
    toInt32(multiIf(
        btw.triggered_side = 'home', coalesce(ps.tackles_succeeded_home, 0),
        btw.triggered_side = 'away', coalesce(ps.tackles_succeeded_away, 0),
        0
    )) AS triggered_team_tackles_won,
    toInt32(multiIf(
        btw.triggered_side = 'home', coalesce(ps.tackles_succeeded_away, 0),
        btw.triggered_side = 'away', coalesce(ps.tackles_succeeded_home, 0),
        0
    )) AS opponent_tackles_won,
    toInt32(multiIf(
        btw.triggered_side = 'home', coalesce(ps.interceptions_home, 0),
        btw.triggered_side = 'away', coalesce(ps.interceptions_away, 0),
        0
    )) AS triggered_team_interceptions,
    toInt32(multiIf(
        btw.triggered_side = 'home', coalesce(ps.interceptions_away, 0),
        btw.triggered_side = 'away', coalesce(ps.interceptions_home, 0),
        0
    )) AS opponent_interceptions,
    toInt32(multiIf(
        btw.triggered_side = 'home', coalesce(ps.clearances_home, 0),
        btw.triggered_side = 'away', coalesce(ps.clearances_away, 0),
        0
    )) AS triggered_team_clearances,
    toInt32(multiIf(
        btw.triggered_side = 'home', coalesce(ps.clearances_away, 0),
        btw.triggered_side = 'away', coalesce(ps.clearances_home, 0),
        0
    )) AS opponent_clearances,
    toFloat32(multiIf(
        btw.triggered_side = 'home', coalesce(ps.ball_possession_home, 0),
        btw.triggered_side = 'away', coalesce(ps.ball_possession_away, 0),
        0
    )) AS triggered_team_possession_pct,
    toFloat32(multiIf(
        btw.triggered_side = 'home', coalesce(ps.ball_possession_away, 0),
        btw.triggered_side = 'away', coalesce(ps.ball_possession_home, 0),
        0
    )) AS opponent_possession_pct,
    toFloat32(round(
        multiIf(
            btw.triggered_side = 'home', coalesce(ps.ball_possession_home, 0),
            btw.triggered_side = 'away', coalesce(ps.ball_possession_away, 0),
            0
        ) - multiIf(
            btw.triggered_side = 'home', coalesce(ps.ball_possession_away, 0),
            btw.triggered_side = 'away', coalesce(ps.ball_possession_home, 0),
            0
        ),
        1
    )) AS possession_delta_pct

FROM best_team_window AS btw
INNER JOIN silver.match AS m
    ON m.match_id = btw.match_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = btw.match_id
   AND ps.period = 'All'
LEFT JOIN team_window_max AS otwm
    ON otwm.match_id = btw.match_id
   AND otwm.triggered_side = if(btw.triggered_side = 'home', 'away', 'home')
LEFT JOIN match_yellow_event_counts AS tmyc
    ON tmyc.match_id = btw.match_id
   AND tmyc.triggered_side = btw.triggered_side
LEFT JOIN match_yellow_event_counts AS omyc
    ON omyc.match_id = btw.match_id
   AND omyc.triggered_side = if(btw.triggered_side = 'home', 'away', 'home')
WHERE m.match_finished = 1
  AND m.match_id > 0

ORDER BY
    triggered_team_third_distinct_yellow_card_minute ASC,
    triggered_team_distinct_yellow_carded_players_in_window DESC,
    yellow_card_events_in_window_delta DESC,
    m.match_date DESC,
    m.match_id DESC;
