INSERT INTO gold.sig_team_discipline_cards_midfield_enforcement (
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
    trigger_threshold_min_central_midfielder_fouls_committed,
    triggered_team_central_midfielders,
    opponent_central_midfielders,
    central_midfielders_delta,
    triggered_team_central_midfielders_with_fouls,
    opponent_central_midfielders_with_fouls,
    central_midfielders_with_fouls_delta,
    triggered_team_central_midfielder_fouls_committed,
    opponent_central_midfielder_fouls_committed,
    central_midfielder_fouls_committed_delta,
    triggered_team_central_midfielder_fouls_above_threshold,
    triggered_team_central_midfielder_fouls_share_of_team_fouls_pct,
    opponent_central_midfielder_fouls_share_of_team_fouls_pct,
    central_midfielder_fouls_share_of_team_fouls_delta_pct,
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
WITH central_midfielders AS (
    SELECT
        mp.match_id,
        lowerUTF8(coalesce(mp.team_side, '')) AS triggered_side,
        toInt32(mp.person_id) AS triggered_player_id
    FROM silver.match_personnel AS mp
    WHERE mp.match_id > 0
      AND mp.person_id > 0
      AND lowerUTF8(coalesce(mp.team_side, '')) IN ('home', 'away')
      AND coalesce(mp.usual_playing_position_id, 0) = 2
    GROUP BY
        mp.match_id,
        triggered_side,
        triggered_player_id
),
midfielder_fouls AS (
    SELECT
        pms.match_id,
        lowerUTF8(coalesce(mp.team_side, '')) AS triggered_side,
        toInt32(pms.player_id) AS triggered_player_id,
        sum(coalesce(pms.fouls_committed, 0)) AS triggered_player_fouls_committed
    FROM silver.player_match_stat AS pms
    INNER JOIN silver.match_personnel AS mp
        ON mp.match_id = pms.match_id
       AND toInt32(mp.person_id) = pms.player_id
    WHERE pms.match_id > 0
      AND pms.player_id > 0
      AND lowerUTF8(coalesce(mp.team_side, '')) IN ('home', 'away')
      AND coalesce(mp.usual_playing_position_id, 0) = 2
    GROUP BY
        pms.match_id,
        triggered_side,
        triggered_player_id
),
team_midfield_foul_rollup AS (
    SELECT
        cm.match_id AS match_id,
        cm.triggered_side AS triggered_side,
        count() AS rollup_central_midfielders,
        countIf(coalesce(mf.triggered_player_fouls_committed, 0) > 0) AS rollup_central_midfielders_with_fouls,
        sum(coalesce(mf.triggered_player_fouls_committed, 0)) AS rollup_central_midfielder_fouls_committed
    FROM central_midfielders AS cm
    LEFT JOIN midfielder_fouls AS mf
        ON mf.match_id = cm.match_id
       AND mf.triggered_side = cm.triggered_side
       AND mf.triggered_player_id = cm.triggered_player_id
    GROUP BY
        cm.match_id,
        cm.triggered_side
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

    toInt32(10) AS trigger_threshold_min_central_midfielder_fouls_committed,
    toInt32(tmr.rollup_central_midfielders) AS triggered_team_central_midfielders,
    toInt32(coalesce(omr.rollup_central_midfielders, 0)) AS opponent_central_midfielders,
    toInt32(tmr.rollup_central_midfielders - coalesce(omr.rollup_central_midfielders, 0)) AS central_midfielders_delta,
    toInt32(tmr.rollup_central_midfielders_with_fouls) AS triggered_team_central_midfielders_with_fouls,
    toInt32(coalesce(omr.rollup_central_midfielders_with_fouls, 0)) AS opponent_central_midfielders_with_fouls,
    toInt32(
        tmr.rollup_central_midfielders_with_fouls
        - coalesce(omr.rollup_central_midfielders_with_fouls, 0)
    ) AS central_midfielders_with_fouls_delta,
    toInt32(tmr.rollup_central_midfielder_fouls_committed) AS triggered_team_central_midfielder_fouls_committed,
    toInt32(coalesce(omr.rollup_central_midfielder_fouls_committed, 0)) AS opponent_central_midfielder_fouls_committed,
    toInt32(
        tmr.rollup_central_midfielder_fouls_committed
        - coalesce(omr.rollup_central_midfielder_fouls_committed, 0)
    ) AS central_midfielder_fouls_committed_delta,
    toInt32(tmr.rollup_central_midfielder_fouls_committed - 10) AS triggered_team_central_midfielder_fouls_above_threshold,
    toFloat32(round(
        100.0 * tmr.rollup_central_midfielder_fouls_committed
        / nullIf(multiIf(
            tmr.triggered_side = 'home', coalesce(ps.fouls_home, 0),
            tmr.triggered_side = 'away', coalesce(ps.fouls_away, 0),
            0
        ), 0),
        1
    )) AS triggered_team_central_midfielder_fouls_share_of_team_fouls_pct,
    toNullable(toFloat32(round(
        100.0 * coalesce(omr.rollup_central_midfielder_fouls_committed, 0)
        / nullIf(multiIf(
            tmr.triggered_side = 'home', coalesce(ps.fouls_away, 0),
            tmr.triggered_side = 'away', coalesce(ps.fouls_home, 0),
            0
        ), 0),
        1
    ))) AS opponent_central_midfielder_fouls_share_of_team_fouls_pct,
    toFloat32(round(
        (
            100.0 * tmr.rollup_central_midfielder_fouls_committed
            / nullIf(multiIf(
                tmr.triggered_side = 'home', coalesce(ps.fouls_home, 0),
                tmr.triggered_side = 'away', coalesce(ps.fouls_away, 0),
                0
            ), 0)
        ) - coalesce(
            (
                100.0 * coalesce(omr.rollup_central_midfielder_fouls_committed, 0)
                / nullIf(multiIf(
                    tmr.triggered_side = 'home', coalesce(ps.fouls_away, 0),
                    tmr.triggered_side = 'away', coalesce(ps.fouls_home, 0),
                    0
                ), 0)
            ),
            0.0
        ),
        1
    )) AS central_midfielder_fouls_share_of_team_fouls_delta_pct,

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
        tmr.triggered_side = 'home', coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        tmr.triggered_side = 'away', coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        0
    )) AS triggered_team_total_cards,
    toInt32(multiIf(
        tmr.triggered_side = 'home', coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        tmr.triggered_side = 'away', coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        0
    )) AS opponent_total_cards,
    toInt32(
        multiIf(
            tmr.triggered_side = 'home', coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
            tmr.triggered_side = 'away', coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
            0
        ) - multiIf(
            tmr.triggered_side = 'home', coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
            tmr.triggered_side = 'away', coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
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
    toFloat32(round(multiIf(
        tmr.triggered_side = 'home', coalesce(ps.ball_possession_home, 0),
        tmr.triggered_side = 'away', coalesce(ps.ball_possession_away, 0),
        0
    ), 1)) AS triggered_team_possession_pct,
    toFloat32(round(multiIf(
        tmr.triggered_side = 'home', coalesce(ps.ball_possession_away, 0),
        tmr.triggered_side = 'away', coalesce(ps.ball_possession_home, 0),
        0
    ), 1)) AS opponent_possession_pct,
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
FROM team_midfield_foul_rollup AS tmr
INNER JOIN silver.match AS m
    ON m.match_id = tmr.match_id
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
LEFT JOIN team_midfield_foul_rollup AS omr
    ON omr.match_id = tmr.match_id
   AND omr.triggered_side = if(tmr.triggered_side = 'home', 'away', 'home')
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND tmr.rollup_central_midfielder_fouls_committed >= 10
ORDER BY
    triggered_team_central_midfielder_fouls_committed DESC,
    triggered_team_central_midfielder_fouls_share_of_team_fouls_pct DESC,
    central_midfielder_fouls_committed_delta DESC,
    m.match_date DESC,
    m.match_id DESC;
