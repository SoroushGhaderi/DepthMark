INSERT INTO gold.sig_player_goalkeeping_defense_interception_marathon (
    match_id,
    match_date,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,
    triggered_side,
    triggered_player_id,
    triggered_player_name,
    triggered_team_id,
    triggered_team_name,
    opponent_team_id,
    opponent_team_name,
    triggered_player_role_group,
    triggered_player_position_id,
    triggered_player_usual_playing_position_id,
    has_first_half_period_row_flag,
    trigger_threshold_min_first_half_interceptions_proxy,
    trigger_threshold_interception_period,
    triggered_player_interceptions_full_match,
    triggered_team_interceptions_first_half,
    opponent_interceptions_first_half,
    first_half_interceptions_delta,
    triggered_player_first_half_interceptions_proxy,
    triggered_player_first_half_interceptions_above_threshold_proxy,
    triggered_player_first_half_interception_share_of_team_proxy_pct,
    triggered_player_tackles_won,
    triggered_player_tackle_attempts,
    triggered_player_tackle_success_pct,
    triggered_player_clearances,
    triggered_player_defensive_actions,
    triggered_player_recoveries,
    triggered_player_duels_won,
    triggered_player_duels_lost,
    triggered_player_fouls_committed,
    triggered_player_minutes_played,
    triggered_player_touches,
    triggered_player_total_passes,
    triggered_player_accurate_passes,
    triggered_player_pass_accuracy_pct,
    triggered_team_interceptions,
    opponent_interceptions,
    interception_delta_vs_opponent_team,
    triggered_team_tackles_won,
    opponent_tackles_won,
    triggered_team_clearances,
    opponent_clearances,
    triggered_team_shot_blocks,
    opponent_shot_blocks,
    triggered_team_duels_won,
    opponent_duels_won,
    triggered_team_fouls,
    opponent_fouls,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct
)
WITH player_positions AS (
    SELECT
        mp.match_id,
        toInt32(mp.person_id) AS person_id,
        argMax(mp.position_id, if(mp.role = 'starter', 2, 1)) AS position_id,
        argMax(mp.usual_playing_position_id, if(mp.role = 'starter', 2, 1))
            AS usual_playing_position_id
    FROM silver.match_personnel AS mp
    WHERE mp.role IN ('starter', 'substitute')
    GROUP BY
        mp.match_id,
        person_id
),
period_stats AS (
    SELECT
        ps.match_id,
        maxIf(coalesce(ps.interceptions_home, 0), ps.period = 'All') AS interceptions_home_all,
        maxIf(coalesce(ps.interceptions_away, 0), ps.period = 'All') AS interceptions_away_all,
        maxIf(coalesce(ps.interceptions_home, 0), ps.period = 'FirstHalf')
            AS interceptions_home_first_half,
        maxIf(coalesce(ps.interceptions_away, 0), ps.period = 'FirstHalf')
            AS interceptions_away_first_half,
        maxIf(coalesce(ps.tackles_succeeded_home, 0), ps.period = 'All') AS tackles_won_home_all,
        maxIf(coalesce(ps.tackles_succeeded_away, 0), ps.period = 'All') AS tackles_won_away_all,
        maxIf(coalesce(ps.clearances_home, 0), ps.period = 'All') AS clearances_home_all,
        maxIf(coalesce(ps.clearances_away, 0), ps.period = 'All') AS clearances_away_all,
        maxIf(coalesce(ps.shot_blocks_home, 0), ps.period = 'All') AS shot_blocks_home_all,
        maxIf(coalesce(ps.shot_blocks_away, 0), ps.period = 'All') AS shot_blocks_away_all,
        maxIf(coalesce(ps.duels_won_home, 0), ps.period = 'All') AS duels_won_home_all,
        maxIf(coalesce(ps.duels_won_away, 0), ps.period = 'All') AS duels_won_away_all,
        maxIf(coalesce(ps.fouls_home, 0), ps.period = 'All') AS fouls_home_all,
        maxIf(coalesce(ps.fouls_away, 0), ps.period = 'All') AS fouls_away_all,
        maxIf(coalesce(ps.ball_possession_home, 0), ps.period = 'All') AS possession_home_all_pct,
        maxIf(coalesce(ps.ball_possession_away, 0), ps.period = 'All') AS possession_away_all_pct,
        maxIf(coalesce(ps.accurate_passes_home, 0), ps.period = 'All') AS accurate_passes_home_all,
        maxIf(coalesce(ps.accurate_passes_away, 0), ps.period = 'All') AS accurate_passes_away_all,
        maxIf(coalesce(ps.pass_attempts_home, 0), ps.period = 'All') AS pass_attempts_home_all,
        maxIf(coalesce(ps.pass_attempts_away, 0), ps.period = 'All') AS pass_attempts_away_all,
        toInt8(maxIf(1, ps.period = 'FirstHalf')) AS has_first_half_period_row_flag
    FROM silver.period_stat AS ps
    WHERE ps.period IN ('All', 'FirstHalf')
    GROUP BY
        ps.match_id
),
enriched AS (
    SELECT
        m.match_id AS match_id,
        m.match_date AS match_date,
        m.home_team_id AS home_team_id,
        m.home_team_name AS home_team_name,
        m.away_team_id AS away_team_id,
        m.away_team_name AS away_team_name,
        m.home_score AS home_score,
        m.away_score AS away_score,
        if(p.team_id = m.home_team_id, 'home', 'away') AS triggered_side,
        toInt32(p.player_id) AS triggered_player_id,
        coalesce(p.player_name, 'Unknown') AS triggered_player_name,
        if(p.team_id = m.home_team_id, m.home_team_id, m.away_team_id) AS triggered_team_id,
        if(p.team_id = m.home_team_id, m.home_team_name, m.away_team_name) AS triggered_team_name,
        if(p.team_id = m.home_team_id, m.away_team_id, m.home_team_id) AS opponent_team_id,
        if(p.team_id = m.home_team_id, m.away_team_name, m.home_team_name) AS opponent_team_name,
        'defender' AS triggered_player_role_group,
        toInt32(coalesce(pp.position_id, 0)) AS triggered_player_position_id,
        toInt32(coalesce(pp.usual_playing_position_id, 0))
            AS triggered_player_usual_playing_position_id,
        toInt8(ps.has_first_half_period_row_flag) AS has_first_half_period_row_flag,
        toInt32(5) AS trigger_threshold_min_first_half_interceptions_proxy,
        'FirstHalf' AS trigger_threshold_interception_period,
        toInt32(coalesce(p.interceptions, 0)) AS triggered_player_interceptions_full_match,
        toInt32(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.interceptions_home_first_half, 0),
            p.team_id = m.away_team_id, coalesce(ps.interceptions_away_first_half, 0),
            0
        )) AS triggered_team_interceptions_first_half,
        toInt32(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.interceptions_away_first_half, 0),
            p.team_id = m.away_team_id, coalesce(ps.interceptions_home_first_half, 0),
            0
        )) AS opponent_interceptions_first_half,
        toInt32(least(
            coalesce(p.interceptions, 0),
            multiIf(
                p.team_id = m.home_team_id, coalesce(ps.interceptions_home_first_half, 0),
                p.team_id = m.away_team_id, coalesce(ps.interceptions_away_first_half, 0),
                0
            )
        )) AS triggered_player_first_half_interceptions_proxy,
        toInt32(least(
            coalesce(p.interceptions, 0),
            multiIf(
                p.team_id = m.home_team_id, coalesce(ps.interceptions_home_first_half, 0),
                p.team_id = m.away_team_id, coalesce(ps.interceptions_away_first_half, 0),
                0
            )
        ) - 5) AS triggered_player_first_half_interceptions_above_threshold_proxy,
        toFloat32(coalesce(round(
            100.0 * least(
                coalesce(p.interceptions, 0),
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.interceptions_home_first_half, 0),
                    p.team_id = m.away_team_id, coalesce(ps.interceptions_away_first_half, 0),
                    0
                )
            ) / nullIf(toFloat64(multiIf(
                p.team_id = m.home_team_id, coalesce(ps.interceptions_home_first_half, 0),
                p.team_id = m.away_team_id, coalesce(ps.interceptions_away_first_half, 0),
                0
            )), 0.0),
            1
        ), 0.0)) AS triggered_player_first_half_interception_share_of_team_proxy_pct,
        toInt32(coalesce(p.tackles_won, 0)) AS triggered_player_tackles_won,
        toInt32(coalesce(p.tackle_attempts, 0)) AS triggered_player_tackle_attempts,
        toFloat32(coalesce(
            p.tackle_success_rate,
            round(
                100.0 * coalesce(p.tackles_won, 0)
                / nullIf(coalesce(p.tackle_attempts, 0), 0),
                1
            ),
            0.0
        )) AS triggered_player_tackle_success_pct,
        toInt32(coalesce(p.clearances, 0)) AS triggered_player_clearances,
        toInt32(coalesce(p.defensive_actions, 0)) AS triggered_player_defensive_actions,
        toInt32(coalesce(p.recoveries, 0)) AS triggered_player_recoveries,
        toInt32(coalesce(p.duels_won, 0)) AS triggered_player_duels_won,
        toInt32(coalesce(p.duels_lost, 0)) AS triggered_player_duels_lost,
        toInt32(coalesce(p.fouls_committed, 0)) AS triggered_player_fouls_committed,
        toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,
        toInt32(coalesce(p.touches, 0)) AS triggered_player_touches,
        toInt32(coalesce(p.total_passes, 0)) AS triggered_player_total_passes,
        toInt32(coalesce(p.accurate_passes, 0)) AS triggered_player_accurate_passes,
        toFloat32(coalesce(
            p.pass_accuracy,
            round(
                100.0 * coalesce(p.accurate_passes, 0)
                / nullIf(coalesce(p.total_passes, 0), 0),
                1
            ),
            0.0
        )) AS triggered_player_pass_accuracy_pct,
        toInt32(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.interceptions_home_all, 0),
            p.team_id = m.away_team_id, coalesce(ps.interceptions_away_all, 0),
            0
        )) AS triggered_team_interceptions,
        toInt32(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.interceptions_away_all, 0),
            p.team_id = m.away_team_id, coalesce(ps.interceptions_home_all, 0),
            0
        )) AS opponent_interceptions,
        toInt32(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.interceptions_home_all, 0),
            p.team_id = m.away_team_id, coalesce(ps.interceptions_away_all, 0),
            0
        ) - multiIf(
            p.team_id = m.home_team_id, coalesce(ps.interceptions_away_all, 0),
            p.team_id = m.away_team_id, coalesce(ps.interceptions_home_all, 0),
            0
        )) AS interception_delta_vs_opponent_team,
        toInt32(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.interceptions_home_first_half, 0),
            p.team_id = m.away_team_id, coalesce(ps.interceptions_away_first_half, 0),
            0
        ) - multiIf(
            p.team_id = m.home_team_id, coalesce(ps.interceptions_away_first_half, 0),
            p.team_id = m.away_team_id, coalesce(ps.interceptions_home_first_half, 0),
            0
        )) AS first_half_interceptions_delta,
        toInt32(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.tackles_won_home_all, 0),
            p.team_id = m.away_team_id, coalesce(ps.tackles_won_away_all, 0),
            0
        )) AS triggered_team_tackles_won,
        toInt32(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.tackles_won_away_all, 0),
            p.team_id = m.away_team_id, coalesce(ps.tackles_won_home_all, 0),
            0
        )) AS opponent_tackles_won,
        toInt32(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.clearances_home_all, 0),
            p.team_id = m.away_team_id, coalesce(ps.clearances_away_all, 0),
            0
        )) AS triggered_team_clearances,
        toInt32(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.clearances_away_all, 0),
            p.team_id = m.away_team_id, coalesce(ps.clearances_home_all, 0),
            0
        )) AS opponent_clearances,
        toInt32(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.shot_blocks_home_all, 0),
            p.team_id = m.away_team_id, coalesce(ps.shot_blocks_away_all, 0),
            0
        )) AS triggered_team_shot_blocks,
        toInt32(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.shot_blocks_away_all, 0),
            p.team_id = m.away_team_id, coalesce(ps.shot_blocks_home_all, 0),
            0
        )) AS opponent_shot_blocks,
        toInt32(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.duels_won_home_all, 0),
            p.team_id = m.away_team_id, coalesce(ps.duels_won_away_all, 0),
            0
        )) AS triggered_team_duels_won,
        toInt32(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.duels_won_away_all, 0),
            p.team_id = m.away_team_id, coalesce(ps.duels_won_home_all, 0),
            0
        )) AS opponent_duels_won,
        toInt32(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.fouls_home_all, 0),
            p.team_id = m.away_team_id, coalesce(ps.fouls_away_all, 0),
            0
        )) AS triggered_team_fouls,
        toInt32(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.fouls_away_all, 0),
            p.team_id = m.away_team_id, coalesce(ps.fouls_home_all, 0),
            0
        )) AS opponent_fouls,
        toFloat32(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.possession_home_all_pct, 0),
            p.team_id = m.away_team_id, coalesce(ps.possession_away_all_pct, 0),
            0
        )) AS triggered_team_possession_pct,
        toFloat32(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.possession_away_all_pct, 0),
            p.team_id = m.away_team_id, coalesce(ps.possession_home_all_pct, 0),
            0
        )) AS opponent_possession_pct,
        toFloat32(coalesce(round(
            100.0 * multiIf(
                p.team_id = m.home_team_id, coalesce(ps.accurate_passes_home_all, 0),
                p.team_id = m.away_team_id, coalesce(ps.accurate_passes_away_all, 0),
                0
            ) / nullIf(toFloat64(multiIf(
                p.team_id = m.home_team_id, coalesce(ps.pass_attempts_home_all, 0),
                p.team_id = m.away_team_id, coalesce(ps.pass_attempts_away_all, 0),
                0
            )), 0.0),
            1
        ), 0.0)) AS triggered_team_pass_accuracy_pct,
        toFloat32(coalesce(round(
            100.0 * multiIf(
                p.team_id = m.home_team_id, coalesce(ps.accurate_passes_away_all, 0),
                p.team_id = m.away_team_id, coalesce(ps.accurate_passes_home_all, 0),
                0
            ) / nullIf(toFloat64(multiIf(
                p.team_id = m.home_team_id, coalesce(ps.pass_attempts_away_all, 0),
                p.team_id = m.away_team_id, coalesce(ps.pass_attempts_home_all, 0),
                0
            )), 0.0),
            1
        ), 0.0)) AS opponent_pass_accuracy_pct
    FROM silver.player_match_stat AS p
    INNER JOIN silver.match AS m
        ON m.match_id = p.match_id
    INNER JOIN player_positions AS pp
        ON pp.match_id = p.match_id
       AND pp.person_id = p.player_id
    INNER JOIN period_stats AS ps
        ON ps.match_id = p.match_id
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)
      AND p.is_goalkeeper = 0
      AND coalesce(pp.usual_playing_position_id, 0) = 1
      AND ps.has_first_half_period_row_flag = 1
)
-- Signal: sig_player_goalkeeping_defense_interception_marathon
-- Intent: detect defender matches with very high first-half interception intensity using
--         an explicit available-data proxy and preserve bilateral defensive context.
-- Trigger: defender first-half interception proxy >= 5 in a finished match.
SELECT
    match_id,
    match_date,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,
    triggered_side,
    triggered_player_id,
    triggered_player_name,
    triggered_team_id,
    triggered_team_name,
    opponent_team_id,
    opponent_team_name,
    triggered_player_role_group,
    triggered_player_position_id,
    triggered_player_usual_playing_position_id,
    has_first_half_period_row_flag,
    trigger_threshold_min_first_half_interceptions_proxy,
    trigger_threshold_interception_period,
    triggered_player_interceptions_full_match,
    triggered_team_interceptions_first_half,
    opponent_interceptions_first_half,
    first_half_interceptions_delta,
    triggered_player_first_half_interceptions_proxy,
    triggered_player_first_half_interceptions_above_threshold_proxy,
    triggered_player_first_half_interception_share_of_team_proxy_pct,
    triggered_player_tackles_won,
    triggered_player_tackle_attempts,
    triggered_player_tackle_success_pct,
    triggered_player_clearances,
    triggered_player_defensive_actions,
    triggered_player_recoveries,
    triggered_player_duels_won,
    triggered_player_duels_lost,
    triggered_player_fouls_committed,
    triggered_player_minutes_played,
    triggered_player_touches,
    triggered_player_total_passes,
    triggered_player_accurate_passes,
    triggered_player_pass_accuracy_pct,
    triggered_team_interceptions,
    opponent_interceptions,
    interception_delta_vs_opponent_team,
    triggered_team_tackles_won,
    opponent_tackles_won,
    triggered_team_clearances,
    opponent_clearances,
    triggered_team_shot_blocks,
    opponent_shot_blocks,
    triggered_team_duels_won,
    opponent_duels_won,
    triggered_team_fouls,
    opponent_fouls,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct
FROM enriched
WHERE triggered_player_first_half_interceptions_proxy >= 5
ORDER BY
    triggered_player_first_half_interceptions_proxy DESC,
    triggered_player_interceptions_full_match DESC,
    triggered_player_defensive_actions DESC,
    match_date DESC,
    match_id DESC,
    triggered_player_id ASC;
