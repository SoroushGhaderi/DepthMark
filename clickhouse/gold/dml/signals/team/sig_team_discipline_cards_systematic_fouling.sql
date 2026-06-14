INSERT INTO gold.sig_team_discipline_cards_systematic_fouling (
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
    trigger_threshold_min_starting_midfielders,
    trigger_threshold_min_yellow_cards_per_starting_midfielder,
    triggered_team_starting_midfielders,
    opponent_starting_midfielders,
    starting_midfielders_delta,
    triggered_team_starting_midfielders_booked,
    opponent_starting_midfielders_booked,
    starting_midfielders_booked_delta,
    triggered_team_starting_midfielders_booked_share_pct,
    opponent_starting_midfielders_booked_share_pct,
    triggered_team_yellow_cards_on_starting_midfielders,
    opponent_yellow_cards_on_starting_midfielders,
    yellow_cards_on_starting_midfielders_delta,
    triggered_team_first_starting_midfielder_yellow_card_minute,
    opponent_first_starting_midfielder_yellow_card_minute,
    triggered_team_last_starting_midfielder_yellow_card_minute,
    opponent_last_starting_midfielder_yellow_card_minute,
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
-- Signal: sig_team_discipline_cards_systematic_fouling
-- Trigger: every starter midfielder on one side receives at least one yellow card.
-- Intent: detect distributed midfield caution pressure across the full starting midfield unit, with bilateral discipline and game-state context.
WITH starting_midfielders AS (
    SELECT
        mp.match_id,
        lowerUTF8(coalesce(mp.team_side, '')) AS triggered_side,
        toInt32(mp.person_id) AS triggered_player_id
    FROM silver.match_personnel AS mp
    WHERE mp.match_id > 0
      AND mp.person_id > 0
      AND lowerUTF8(coalesce(mp.team_side, '')) IN ('home', 'away')
      AND lowerUTF8(coalesce(mp.role, '')) = 'starter'
      AND coalesce(mp.usual_playing_position_id, 0) = 2
    GROUP BY
        mp.match_id,
        triggered_side,
        triggered_player_id
),
yellow_card_events AS (
    SELECT
        c.match_id,
        lowerUTF8(coalesce(c.team_side, '')) AS triggered_side,
        toInt32(assumeNotNull(c.player_id)) AS triggered_player_id,
        toInt32(coalesce(c.card_minute, 0)) AS card_minute
    FROM silver.card AS c
    WHERE c.match_id > 0
      AND c.player_id IS NOT NULL
      AND lowerUTF8(coalesce(c.team_side, '')) IN ('home', 'away')
      AND (
            positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'yellow') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'yellow') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'booked') > 0
      )
),
midfielder_yellow_rollup AS (
    SELECT
        sm.match_id,
        sm.triggered_side,
        sm.triggered_player_id,
        countIf(yce.card_minute > 0) AS triggered_player_yellow_cards,
        toNullable(minIf(yce.card_minute, yce.card_minute > 0)) AS triggered_player_first_yellow_card_minute,
        toNullable(maxIf(yce.card_minute, yce.card_minute > 0)) AS triggered_player_last_yellow_card_minute
    FROM starting_midfielders AS sm
    LEFT JOIN yellow_card_events AS yce
        ON yce.match_id = sm.match_id
       AND yce.triggered_side = sm.triggered_side
       AND yce.triggered_player_id = sm.triggered_player_id
    GROUP BY
        sm.match_id,
        sm.triggered_side,
        sm.triggered_player_id
),
team_midfield_rollup AS (
    SELECT
        sm.match_id,
        sm.triggered_side,
        count() AS triggered_team_starting_midfielders,
        countIf(coalesce(myr.triggered_player_yellow_cards, 0) > 0) AS triggered_team_starting_midfielders_booked,
        sum(coalesce(myr.triggered_player_yellow_cards, 0)) AS triggered_team_yellow_cards_on_starting_midfielders,
        if(
            countIf(coalesce(myr.triggered_player_yellow_cards, 0) > 0) > 0,
            minIf(
                toInt32(assumeNotNull(myr.triggered_player_first_yellow_card_minute)),
                coalesce(myr.triggered_player_yellow_cards, 0) > 0
            ),
            NULL
        ) AS triggered_team_first_starting_midfielder_yellow_card_minute,
        if(
            countIf(coalesce(myr.triggered_player_yellow_cards, 0) > 0) > 0,
            maxIf(
                toInt32(assumeNotNull(myr.triggered_player_last_yellow_card_minute)),
                coalesce(myr.triggered_player_yellow_cards, 0) > 0
            ),
            NULL
        ) AS triggered_team_last_starting_midfielder_yellow_card_minute
    FROM starting_midfielders AS sm
    LEFT JOIN midfielder_yellow_rollup AS myr
        ON myr.match_id = sm.match_id
       AND myr.triggered_side = sm.triggered_side
       AND myr.triggered_player_id = sm.triggered_player_id
    GROUP BY
        sm.match_id,
        sm.triggered_side
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

    tmr.triggered_side,
    if(tmr.triggered_side = 'home', m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(tmr.triggered_side = 'home', m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(tmr.triggered_side = 'home', m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(tmr.triggered_side = 'home', m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(1) AS trigger_threshold_min_starting_midfielders,
    toInt32(1) AS trigger_threshold_min_yellow_cards_per_starting_midfielder,
    toInt32(tmr.triggered_team_starting_midfielders) AS triggered_team_starting_midfielders,
    toInt32(coalesce(omr.triggered_team_starting_midfielders, 0)) AS opponent_starting_midfielders,
    toInt32(tmr.triggered_team_starting_midfielders - coalesce(omr.triggered_team_starting_midfielders, 0)) AS starting_midfielders_delta,
    toInt32(tmr.triggered_team_starting_midfielders_booked) AS triggered_team_starting_midfielders_booked,
    toInt32(coalesce(omr.triggered_team_starting_midfielders_booked, 0)) AS opponent_starting_midfielders_booked,
    toInt32(
        tmr.triggered_team_starting_midfielders_booked
        - coalesce(omr.triggered_team_starting_midfielders_booked, 0)
    ) AS starting_midfielders_booked_delta,
    toFloat32(round(
        100.0 * tmr.triggered_team_starting_midfielders_booked
        / nullIf(tmr.triggered_team_starting_midfielders, 0),
        1
    )) AS triggered_team_starting_midfielders_booked_share_pct,
    toNullable(toFloat32(round(
        100.0 * coalesce(omr.triggered_team_starting_midfielders_booked, 0)
        / nullIf(coalesce(omr.triggered_team_starting_midfielders, 0), 0),
        1
    ))) AS opponent_starting_midfielders_booked_share_pct,
    toInt32(tmr.triggered_team_yellow_cards_on_starting_midfielders) AS triggered_team_yellow_cards_on_starting_midfielders,
    toInt32(coalesce(omr.triggered_team_yellow_cards_on_starting_midfielders, 0)) AS opponent_yellow_cards_on_starting_midfielders,
    toInt32(
        tmr.triggered_team_yellow_cards_on_starting_midfielders
        - coalesce(omr.triggered_team_yellow_cards_on_starting_midfielders, 0)
    ) AS yellow_cards_on_starting_midfielders_delta,
    toNullable(toInt32(tmr.triggered_team_first_starting_midfielder_yellow_card_minute)) AS triggered_team_first_starting_midfielder_yellow_card_minute,
    toNullable(toInt32(omr.triggered_team_first_starting_midfielder_yellow_card_minute)) AS opponent_first_starting_midfielder_yellow_card_minute,
    toNullable(toInt32(tmr.triggered_team_last_starting_midfielder_yellow_card_minute)) AS triggered_team_last_starting_midfielder_yellow_card_minute,
    toNullable(toInt32(omr.triggered_team_last_starting_midfielder_yellow_card_minute)) AS opponent_last_starting_midfielder_yellow_card_minute,

    toInt32(multiIf(
        tmr.triggered_side = 'home', coalesce(ps.yellow_cards_home, 0),
        tmr.triggered_side = 'away', coalesce(ps.yellow_cards_away, 0),
        0
    )) AS triggered_team_yellow_cards,
    toInt32(multiIf(
        tmr.triggered_side = 'home', coalesce(ps.yellow_cards_away, 0),
        tmr.triggered_side = 'away', coalesce(ps.yellow_cards_home, 0),
        0
    )) AS opponent_yellow_cards,
    toInt32(multiIf(
        tmr.triggered_side = 'home', coalesce(ps.red_cards_home, 0),
        tmr.triggered_side = 'away', coalesce(ps.red_cards_away, 0),
        0
    )) AS triggered_team_red_cards,
    toInt32(multiIf(
        tmr.triggered_side = 'home', coalesce(ps.red_cards_away, 0),
        tmr.triggered_side = 'away', coalesce(ps.red_cards_home, 0),
        0
    )) AS opponent_red_cards,
    toInt32(multiIf(
        tmr.triggered_side = 'home',
            coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        tmr.triggered_side = 'away',
            coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        0
    )) AS triggered_team_total_cards,
    toInt32(multiIf(
        tmr.triggered_side = 'home',
            coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        tmr.triggered_side = 'away',
            coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        0
    )) AS opponent_total_cards,
    toInt32(
        multiIf(
            tmr.triggered_side = 'home',
                coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
            tmr.triggered_side = 'away',
                coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
            0
        ) - multiIf(
            tmr.triggered_side = 'home',
                coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
            tmr.triggered_side = 'away',
                coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
            0
        )
    ) AS card_count_delta,
    toInt32(multiIf(
        tmr.triggered_side = 'home', coalesce(ps.fouls_home, 0),
        tmr.triggered_side = 'away', coalesce(ps.fouls_away, 0),
        0
    )) AS triggered_team_fouls_committed,
    toInt32(multiIf(
        tmr.triggered_side = 'home', coalesce(ps.fouls_away, 0),
        tmr.triggered_side = 'away', coalesce(ps.fouls_home, 0),
        0
    )) AS opponent_fouls_committed,
    toInt32(
        multiIf(
            tmr.triggered_side = 'home', coalesce(ps.fouls_home, 0),
            tmr.triggered_side = 'away', coalesce(ps.fouls_away, 0),
            0
        ) - multiIf(
            tmr.triggered_side = 'home', coalesce(ps.fouls_away, 0),
            tmr.triggered_side = 'away', coalesce(ps.fouls_home, 0),
            0
        )
    ) AS fouls_committed_delta,
    toInt32(multiIf(
        tmr.triggered_side = 'home', coalesce(ps.duels_won_home, 0),
        tmr.triggered_side = 'away', coalesce(ps.duels_won_away, 0),
        0
    )) AS triggered_team_duels_won,
    toInt32(multiIf(
        tmr.triggered_side = 'home', coalesce(ps.duels_won_away, 0),
        tmr.triggered_side = 'away', coalesce(ps.duels_won_home, 0),
        0
    )) AS opponent_duels_won,
    toInt32(multiIf(
        tmr.triggered_side = 'home', coalesce(ps.tackles_succeeded_home, 0),
        tmr.triggered_side = 'away', coalesce(ps.tackles_succeeded_away, 0),
        0
    )) AS triggered_team_tackles_won,
    toInt32(multiIf(
        tmr.triggered_side = 'home', coalesce(ps.tackles_succeeded_away, 0),
        tmr.triggered_side = 'away', coalesce(ps.tackles_succeeded_home, 0),
        0
    )) AS opponent_tackles_won,
    toInt32(multiIf(
        tmr.triggered_side = 'home', coalesce(ps.interceptions_home, 0),
        tmr.triggered_side = 'away', coalesce(ps.interceptions_away, 0),
        0
    )) AS triggered_team_interceptions,
    toInt32(multiIf(
        tmr.triggered_side = 'home', coalesce(ps.interceptions_away, 0),
        tmr.triggered_side = 'away', coalesce(ps.interceptions_home, 0),
        0
    )) AS opponent_interceptions,
    toInt32(multiIf(
        tmr.triggered_side = 'home', coalesce(ps.clearances_home, 0),
        tmr.triggered_side = 'away', coalesce(ps.clearances_away, 0),
        0
    )) AS triggered_team_clearances,
    toInt32(multiIf(
        tmr.triggered_side = 'home', coalesce(ps.clearances_away, 0),
        tmr.triggered_side = 'away', coalesce(ps.clearances_home, 0),
        0
    )) AS opponent_clearances,
    toFloat32(multiIf(
        tmr.triggered_side = 'home', coalesce(ps.ball_possession_home, 0),
        tmr.triggered_side = 'away', coalesce(ps.ball_possession_away, 0),
        0
    )) AS triggered_team_possession_pct,
    toFloat32(multiIf(
        tmr.triggered_side = 'home', coalesce(ps.ball_possession_away, 0),
        tmr.triggered_side = 'away', coalesce(ps.ball_possession_home, 0),
        0
    )) AS opponent_possession_pct,
    toFloat32(round(
        multiIf(
            tmr.triggered_side = 'home', coalesce(ps.ball_possession_home, 0),
            tmr.triggered_side = 'away', coalesce(ps.ball_possession_away, 0),
            0
        ) - multiIf(
            tmr.triggered_side = 'home', coalesce(ps.ball_possession_away, 0),
            tmr.triggered_side = 'away', coalesce(ps.ball_possession_home, 0),
            0
        ),
        1
    )) AS possession_delta_pct

FROM team_midfield_rollup AS tmr
INNER JOIN silver.match AS m
    ON m.match_id = tmr.match_id
LEFT JOIN team_midfield_rollup AS omr
    ON omr.match_id = tmr.match_id
   AND omr.triggered_side = if(tmr.triggered_side = 'home', 'away', 'home')
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = tmr.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND tmr.triggered_team_starting_midfielders >= 1
  AND tmr.triggered_team_starting_midfielders_booked = tmr.triggered_team_starting_midfielders

ORDER BY
    triggered_team_starting_midfielders DESC,
    triggered_team_yellow_cards_on_starting_midfielders DESC,
    yellow_cards_on_starting_midfielders_delta DESC,
    m.match_date DESC,
    m.match_id DESC;
