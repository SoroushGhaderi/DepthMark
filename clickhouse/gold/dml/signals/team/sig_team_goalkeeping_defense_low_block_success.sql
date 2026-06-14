INSERT INTO gold.sig_team_goalkeeping_defense_low_block_success (
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
    trigger_threshold_min_interceptions_in_own_defensive_third_proxy,
    triggered_team_interceptions_in_own_defensive_third_proxy,
    opponent_interceptions_in_own_defensive_third_proxy,
    interceptions_in_own_defensive_third_proxy_delta,
    triggered_team_interceptions_proxy_above_threshold,
    triggered_team_interceptions,
    opponent_interceptions,
    interceptions_delta,
    triggered_team_clearances,
    opponent_clearances,
    clearances_delta,
    triggered_team_tackles_won,
    opponent_tackles_won,
    tackles_won_delta,
    triggered_team_shot_blocks,
    opponent_shot_blocks,
    shot_blocks_delta,
    triggered_team_duels_won,
    opponent_duels_won,
    duels_won_delta,
    triggered_team_total_shots_faced,
    opponent_total_shots_faced,
    total_shots_faced_delta,
    triggered_team_shots_on_target_faced,
    opponent_shots_on_target_faced,
    shots_on_target_faced_delta,
    triggered_team_keeper_saves,
    opponent_keeper_saves,
    keeper_saves_delta,
    triggered_team_expected_goals_faced,
    opponent_expected_goals_faced,
    expected_goals_faced_delta,
    triggered_team_expected_goals_on_target_faced,
    opponent_expected_goals_on_target_faced,
    expected_goals_on_target_faced_delta,
    triggered_team_fouls,
    opponent_fouls,
    fouls_delta,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_clean_sheet_flag
)
-- Signal: sig_team_goalkeeping_defense_low_block_success
-- Intent: detect low-block defensive outputs via high interception pressure in deep territory proxy.
-- Trigger: team records at least 20 interceptions in own defensive third proxy in a finished match.

-- Home-side trigger.
SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    'home' AS triggered_side,
    m.home_team_id AS triggered_team_id,
    m.home_team_name AS triggered_team_name,
    m.away_team_id AS opponent_team_id,
    m.away_team_name AS opponent_team_name,

    toInt32(20) AS trigger_threshold_min_interceptions_in_own_defensive_third_proxy,
    toInt32(coalesce(ps.interceptions_home, 0))
        AS triggered_team_interceptions_in_own_defensive_third_proxy,
    toInt32(coalesce(ps.interceptions_away, 0))
        AS opponent_interceptions_in_own_defensive_third_proxy,
    toInt32(coalesce(ps.interceptions_home, 0) - coalesce(ps.interceptions_away, 0))
        AS interceptions_in_own_defensive_third_proxy_delta,
    toInt32(coalesce(ps.interceptions_home, 0) - 20) AS triggered_team_interceptions_proxy_above_threshold,
    toInt32(coalesce(ps.interceptions_home, 0)) AS triggered_team_interceptions,
    toInt32(coalesce(ps.interceptions_away, 0)) AS opponent_interceptions,
    toInt32(coalesce(ps.interceptions_home, 0) - coalesce(ps.interceptions_away, 0))
        AS interceptions_delta,

    toInt32(coalesce(ps.clearances_home, 0)) AS triggered_team_clearances,
    toInt32(coalesce(ps.clearances_away, 0)) AS opponent_clearances,
    toInt32(coalesce(ps.clearances_home, 0) - coalesce(ps.clearances_away, 0)) AS clearances_delta,

    toInt32(coalesce(ps.tackles_succeeded_home, 0)) AS triggered_team_tackles_won,
    toInt32(coalesce(ps.tackles_succeeded_away, 0)) AS opponent_tackles_won,
    toInt32(
        coalesce(ps.tackles_succeeded_home, 0) - coalesce(ps.tackles_succeeded_away, 0)
    ) AS tackles_won_delta,

    toInt32(coalesce(ps.shot_blocks_home, 0)) AS triggered_team_shot_blocks,
    toInt32(coalesce(ps.shot_blocks_away, 0)) AS opponent_shot_blocks,
    toInt32(coalesce(ps.shot_blocks_home, 0) - coalesce(ps.shot_blocks_away, 0)) AS shot_blocks_delta,

    toInt32(coalesce(ps.duels_won_home, 0)) AS triggered_team_duels_won,
    toInt32(coalesce(ps.duels_won_away, 0)) AS opponent_duels_won,
    toInt32(coalesce(ps.duels_won_home, 0) - coalesce(ps.duels_won_away, 0)) AS duels_won_delta,

    toInt32(coalesce(ps.total_shots_away, 0)) AS triggered_team_total_shots_faced,
    toInt32(coalesce(ps.total_shots_home, 0)) AS opponent_total_shots_faced,
    toInt32(coalesce(ps.total_shots_away, 0) - coalesce(ps.total_shots_home, 0))
        AS total_shots_faced_delta,

    toInt32(coalesce(ps.shots_on_target_away, 0)) AS triggered_team_shots_on_target_faced,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS opponent_shots_on_target_faced,
    toInt32(coalesce(ps.shots_on_target_away, 0) - coalesce(ps.shots_on_target_home, 0))
        AS shots_on_target_faced_delta,

    toInt32(coalesce(ps.keeper_saves_home, 0)) AS triggered_team_keeper_saves,
    toInt32(coalesce(ps.keeper_saves_away, 0)) AS opponent_keeper_saves,
    toInt32(coalesce(ps.keeper_saves_home, 0) - coalesce(ps.keeper_saves_away, 0)) AS keeper_saves_delta,

    toFloat32(coalesce(ps.expected_goals_away, 0)) AS triggered_team_expected_goals_faced,
    toFloat32(coalesce(ps.expected_goals_home, 0)) AS opponent_expected_goals_faced,
    toFloat32(round(
        coalesce(ps.expected_goals_away, 0) - coalesce(ps.expected_goals_home, 0),
        3
    )) AS expected_goals_faced_delta,

    toFloat32(coalesce(ps.expected_goals_on_target_away, 0)) AS triggered_team_expected_goals_on_target_faced,
    toFloat32(coalesce(ps.expected_goals_on_target_home, 0)) AS opponent_expected_goals_on_target_faced,
    toFloat32(round(
        coalesce(ps.expected_goals_on_target_away, 0) - coalesce(ps.expected_goals_on_target_home, 0),
        3
    )) AS expected_goals_on_target_faced_delta,

    toInt32(coalesce(ps.fouls_home, 0)) AS triggered_team_fouls,
    toInt32(coalesce(ps.fouls_away, 0)) AS opponent_fouls,
    toInt32(coalesce(ps.fouls_home, 0) - coalesce(ps.fouls_away, 0)) AS fouls_delta,

    toFloat32(coalesce(ps.ball_possession_home, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS opponent_possession_pct,
    toFloat32(round(
        coalesce(ps.ball_possession_home, 0) - coalesce(ps.ball_possession_away, 0),
        1
    )) AS possession_delta_pct,

    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    toInt32(coalesce(m.home_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.away_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.home_score, 0) - coalesce(m.away_score, 0)) AS goal_delta,
    toInt8(if(coalesce(m.away_score, 0) = 0, 1, 0)) AS triggered_team_clean_sheet_flag

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ps.interceptions_home, 0) >= 20

UNION ALL

-- Away-side trigger.
SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    'away' AS triggered_side,
    m.away_team_id AS triggered_team_id,
    m.away_team_name AS triggered_team_name,
    m.home_team_id AS opponent_team_id,
    m.home_team_name AS opponent_team_name,

    toInt32(20) AS trigger_threshold_min_interceptions_in_own_defensive_third_proxy,
    toInt32(coalesce(ps.interceptions_away, 0))
        AS triggered_team_interceptions_in_own_defensive_third_proxy,
    toInt32(coalesce(ps.interceptions_home, 0))
        AS opponent_interceptions_in_own_defensive_third_proxy,
    toInt32(coalesce(ps.interceptions_away, 0) - coalesce(ps.interceptions_home, 0))
        AS interceptions_in_own_defensive_third_proxy_delta,
    toInt32(coalesce(ps.interceptions_away, 0) - 20) AS triggered_team_interceptions_proxy_above_threshold,
    toInt32(coalesce(ps.interceptions_away, 0)) AS triggered_team_interceptions,
    toInt32(coalesce(ps.interceptions_home, 0)) AS opponent_interceptions,
    toInt32(coalesce(ps.interceptions_away, 0) - coalesce(ps.interceptions_home, 0))
        AS interceptions_delta,

    toInt32(coalesce(ps.clearances_away, 0)) AS triggered_team_clearances,
    toInt32(coalesce(ps.clearances_home, 0)) AS opponent_clearances,
    toInt32(coalesce(ps.clearances_away, 0) - coalesce(ps.clearances_home, 0)) AS clearances_delta,

    toInt32(coalesce(ps.tackles_succeeded_away, 0)) AS triggered_team_tackles_won,
    toInt32(coalesce(ps.tackles_succeeded_home, 0)) AS opponent_tackles_won,
    toInt32(
        coalesce(ps.tackles_succeeded_away, 0) - coalesce(ps.tackles_succeeded_home, 0)
    ) AS tackles_won_delta,

    toInt32(coalesce(ps.shot_blocks_away, 0)) AS triggered_team_shot_blocks,
    toInt32(coalesce(ps.shot_blocks_home, 0)) AS opponent_shot_blocks,
    toInt32(coalesce(ps.shot_blocks_away, 0) - coalesce(ps.shot_blocks_home, 0)) AS shot_blocks_delta,

    toInt32(coalesce(ps.duels_won_away, 0)) AS triggered_team_duels_won,
    toInt32(coalesce(ps.duels_won_home, 0)) AS opponent_duels_won,
    toInt32(coalesce(ps.duels_won_away, 0) - coalesce(ps.duels_won_home, 0)) AS duels_won_delta,

    toInt32(coalesce(ps.total_shots_home, 0)) AS triggered_team_total_shots_faced,
    toInt32(coalesce(ps.total_shots_away, 0)) AS opponent_total_shots_faced,
    toInt32(coalesce(ps.total_shots_home, 0) - coalesce(ps.total_shots_away, 0))
        AS total_shots_faced_delta,

    toInt32(coalesce(ps.shots_on_target_home, 0)) AS triggered_team_shots_on_target_faced,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS opponent_shots_on_target_faced,
    toInt32(coalesce(ps.shots_on_target_home, 0) - coalesce(ps.shots_on_target_away, 0))
        AS shots_on_target_faced_delta,

    toInt32(coalesce(ps.keeper_saves_away, 0)) AS triggered_team_keeper_saves,
    toInt32(coalesce(ps.keeper_saves_home, 0)) AS opponent_keeper_saves,
    toInt32(coalesce(ps.keeper_saves_away, 0) - coalesce(ps.keeper_saves_home, 0)) AS keeper_saves_delta,

    toFloat32(coalesce(ps.expected_goals_home, 0)) AS triggered_team_expected_goals_faced,
    toFloat32(coalesce(ps.expected_goals_away, 0)) AS opponent_expected_goals_faced,
    toFloat32(round(
        coalesce(ps.expected_goals_home, 0) - coalesce(ps.expected_goals_away, 0),
        3
    )) AS expected_goals_faced_delta,

    toFloat32(coalesce(ps.expected_goals_on_target_home, 0)) AS triggered_team_expected_goals_on_target_faced,
    toFloat32(coalesce(ps.expected_goals_on_target_away, 0)) AS opponent_expected_goals_on_target_faced,
    toFloat32(round(
        coalesce(ps.expected_goals_on_target_home, 0) - coalesce(ps.expected_goals_on_target_away, 0),
        3
    )) AS expected_goals_on_target_faced_delta,

    toInt32(coalesce(ps.fouls_away, 0)) AS triggered_team_fouls,
    toInt32(coalesce(ps.fouls_home, 0)) AS opponent_fouls,
    toInt32(coalesce(ps.fouls_away, 0) - coalesce(ps.fouls_home, 0)) AS fouls_delta,

    toFloat32(coalesce(ps.ball_possession_away, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS opponent_possession_pct,
    toFloat32(round(
        coalesce(ps.ball_possession_away, 0) - coalesce(ps.ball_possession_home, 0),
        1
    )) AS possession_delta_pct,

    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    toInt32(coalesce(m.away_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.home_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.away_score, 0) - coalesce(m.home_score, 0)) AS goal_delta,
    toInt8(if(coalesce(m.home_score, 0) = 0, 1, 0)) AS triggered_team_clean_sheet_flag

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ps.interceptions_away, 0) >= 20

ORDER BY
    triggered_team_interceptions_proxy_above_threshold DESC,
    triggered_team_total_shots_faced DESC,
    triggered_team_expected_goals_faced DESC,
    m.match_date DESC,
    m.match_id DESC;
