INSERT INTO gold.sig_match_goalkeeping_defense_keeper_masterclass_duel (
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
    trigger_threshold_min_goalkeeper_goals_prevented,
    trigger_condition_both_goalkeepers_required,
    home_goalkeeper_goals_prevented,
    away_goalkeeper_goals_prevented,
    match_combined_goalkeeper_goals_prevented,
    match_goalkeeper_goals_prevented_balance_abs,
    home_goalkeeper_goals_prevented_above_threshold,
    away_goalkeeper_goals_prevented_above_threshold,
    triggered_team_goalkeeper_goals_prevented,
    opponent_goalkeeper_goals_prevented,
    goalkeeper_goals_prevented_delta,
    triggered_team_expected_goals_on_target_faced,
    opponent_expected_goals_on_target_faced,
    expected_goals_on_target_faced_delta,
    triggered_team_goals_conceded,
    opponent_goals_conceded,
    goals_conceded_delta,
    triggered_team_keeper_saves,
    opponent_keeper_saves,
    keeper_saves_delta,
    triggered_team_shots_on_target_faced,
    opponent_shots_on_target_faced,
    shots_on_target_faced_delta,
    triggered_team_save_rate_pct,
    opponent_save_rate_pct,
    save_rate_delta_pct,
    triggered_team_total_shots_faced,
    opponent_total_shots_faced,
    total_shots_faced_delta,
    triggered_team_shot_blocks,
    opponent_shot_blocks,
    shot_blocks_delta,
    triggered_team_clearances,
    opponent_clearances,
    clearances_delta,
    triggered_team_interceptions,
    opponent_interceptions,
    interceptions_delta,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    pass_attempt_delta,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_clean_sheet_flag
)
-- Signal: sig_match_goalkeeping_defense_keeper_masterclass_duel
-- Intent: detect finished matches where both goalkeepers overperform by preventing more than one
--         expected on-target goal, with bilateral side-oriented defensive workload context.
-- Trigger: both keepers have (expected goals on target faced - goals conceded) > 1.0.
WITH base_stats AS (
    SELECT
        m.match_id AS match_id,
        m.match_date AS match_date,
        m.home_team_id AS home_team_id,
        m.home_team_name AS home_team_name,
        m.away_team_id AS away_team_id,
        m.away_team_name AS away_team_name,
        m.home_score AS home_score,
        m.away_score AS away_score,
        coalesce(m.home_score, 0) AS home_goals,
        coalesce(m.away_score, 0) AS away_goals,
        coalesce(ps.expected_goals_on_target_home, 0) AS expected_goals_on_target_home,
        coalesce(ps.expected_goals_on_target_away, 0) AS expected_goals_on_target_away,
        coalesce(ps.keeper_saves_home, 0) AS keeper_saves_home,
        coalesce(ps.keeper_saves_away, 0) AS keeper_saves_away,
        coalesce(ps.shots_on_target_home, 0) AS shots_on_target_home,
        coalesce(ps.shots_on_target_away, 0) AS shots_on_target_away,
        coalesce(ps.total_shots_home, 0) AS total_shots_home,
        coalesce(ps.total_shots_away, 0) AS total_shots_away,
        coalesce(ps.shot_blocks_home, 0) AS shot_blocks_home,
        coalesce(ps.shot_blocks_away, 0) AS shot_blocks_away,
        coalesce(ps.clearances_home, 0) AS clearances_home,
        coalesce(ps.clearances_away, 0) AS clearances_away,
        coalesce(ps.interceptions_home, 0) AS interceptions_home,
        coalesce(ps.interceptions_away, 0) AS interceptions_away,
        toFloat32(coalesce(ps.ball_possession_home, 0)) AS possession_home_pct,
        toFloat32(coalesce(ps.ball_possession_away, 0)) AS possession_away_pct,
        coalesce(ps.pass_attempts_home, 0) AS pass_attempts_home,
        coalesce(ps.pass_attempts_away, 0) AS pass_attempts_away,
        coalesce(ps.accurate_passes_home, 0) AS accurate_passes_home,
        coalesce(ps.accurate_passes_away, 0) AS accurate_passes_away,
        toFloat32(round(
            coalesce(ps.expected_goals_on_target_away, 0) - toFloat64(coalesce(m.away_score, 0)),
            3
        )) AS home_goalkeeper_goals_prevented,
        toFloat32(round(
            coalesce(ps.expected_goals_on_target_home, 0) - toFloat64(coalesce(m.home_score, 0)),
            3
        )) AS away_goalkeeper_goals_prevented
    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.match_date = m.match_date
       AND ps.period = 'All'
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND (coalesce(ps.expected_goals_on_target_away, 0) - toFloat64(coalesce(m.away_score, 0))) > 1.0
      AND (coalesce(ps.expected_goals_on_target_home, 0) - toFloat64(coalesce(m.home_score, 0))) > 1.0
)

SELECT
    b.match_id,
    b.match_date,
    b.home_team_id,
    b.home_team_name,
    b.away_team_id,
    b.away_team_name,
    b.home_score,
    b.away_score,
    'home' AS triggered_side,
    b.home_team_id AS triggered_team_id,
    b.home_team_name AS triggered_team_name,
    b.away_team_id AS opponent_team_id,
    b.away_team_name AS opponent_team_name,
    toFloat32(1.0) AS trigger_threshold_min_goalkeeper_goals_prevented,
    toInt8(1) AS trigger_condition_both_goalkeepers_required,
    b.home_goalkeeper_goals_prevented,
    b.away_goalkeeper_goals_prevented,
    toFloat32(round(
        b.home_goalkeeper_goals_prevented + b.away_goalkeeper_goals_prevented,
        3
    )) AS match_combined_goalkeeper_goals_prevented,
    toFloat32(round(
        abs(b.home_goalkeeper_goals_prevented - b.away_goalkeeper_goals_prevented),
        3
    )) AS match_goalkeeper_goals_prevented_balance_abs,
    toFloat32(round(b.home_goalkeeper_goals_prevented - 1.0, 3)) AS home_goalkeeper_goals_prevented_above_threshold,
    toFloat32(round(b.away_goalkeeper_goals_prevented - 1.0, 3)) AS away_goalkeeper_goals_prevented_above_threshold,
    b.home_goalkeeper_goals_prevented AS triggered_team_goalkeeper_goals_prevented,
    b.away_goalkeeper_goals_prevented AS opponent_goalkeeper_goals_prevented,
    toFloat32(round(
        b.home_goalkeeper_goals_prevented - b.away_goalkeeper_goals_prevented,
        3
    )) AS goalkeeper_goals_prevented_delta,
    toFloat32(b.expected_goals_on_target_away) AS triggered_team_expected_goals_on_target_faced,
    toFloat32(b.expected_goals_on_target_home) AS opponent_expected_goals_on_target_faced,
    toFloat32(round(
        b.expected_goals_on_target_away - b.expected_goals_on_target_home,
        3
    )) AS expected_goals_on_target_faced_delta,
    b.away_goals AS triggered_team_goals_conceded,
    b.home_goals AS opponent_goals_conceded,
    b.away_goals - b.home_goals AS goals_conceded_delta,
    b.keeper_saves_home AS triggered_team_keeper_saves,
    b.keeper_saves_away AS opponent_keeper_saves,
    b.keeper_saves_home - b.keeper_saves_away AS keeper_saves_delta,
    b.shots_on_target_away AS triggered_team_shots_on_target_faced,
    b.shots_on_target_home AS opponent_shots_on_target_faced,
    b.shots_on_target_away - b.shots_on_target_home AS shots_on_target_faced_delta,
    toFloat32(coalesce(round(
        100.0 * b.keeper_saves_home / nullIf(toFloat64(b.shots_on_target_away), 0),
        1
    ), 0.0)) AS triggered_team_save_rate_pct,
    toFloat32(coalesce(round(
        100.0 * b.keeper_saves_away / nullIf(toFloat64(b.shots_on_target_home), 0),
        1
    ), 0.0)) AS opponent_save_rate_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.keeper_saves_home / nullIf(toFloat64(b.shots_on_target_away), 0), 1), 0.0)
      - coalesce(round(100.0 * b.keeper_saves_away / nullIf(toFloat64(b.shots_on_target_home), 0), 1), 0.0),
        1
    )) AS save_rate_delta_pct,
    b.total_shots_away AS triggered_team_total_shots_faced,
    b.total_shots_home AS opponent_total_shots_faced,
    b.total_shots_away - b.total_shots_home AS total_shots_faced_delta,
    b.shot_blocks_home AS triggered_team_shot_blocks,
    b.shot_blocks_away AS opponent_shot_blocks,
    b.shot_blocks_home - b.shot_blocks_away AS shot_blocks_delta,
    b.clearances_home AS triggered_team_clearances,
    b.clearances_away AS opponent_clearances,
    b.clearances_home - b.clearances_away AS clearances_delta,
    b.interceptions_home AS triggered_team_interceptions,
    b.interceptions_away AS opponent_interceptions,
    b.interceptions_home - b.interceptions_away AS interceptions_delta,
    b.possession_home_pct AS triggered_team_possession_pct,
    b.possession_away_pct AS opponent_possession_pct,
    toFloat32(round(b.possession_home_pct - b.possession_away_pct, 1)) AS possession_delta_pct,
    b.pass_attempts_home AS triggered_team_pass_attempts,
    b.pass_attempts_away AS opponent_pass_attempts,
    b.pass_attempts_home - b.pass_attempts_away AS pass_attempt_delta,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0), 1), 0.0)
      - coalesce(round(100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct,
    b.home_goals AS triggered_team_goals,
    b.away_goals AS opponent_goals,
    b.home_goals - b.away_goals AS goal_delta,
    toUInt8(if(b.away_goals = 0, 1, 0)) AS triggered_team_clean_sheet_flag
FROM base_stats AS b

UNION ALL

SELECT
    b.match_id,
    b.match_date,
    b.home_team_id,
    b.home_team_name,
    b.away_team_id,
    b.away_team_name,
    b.home_score,
    b.away_score,
    'away' AS triggered_side,
    b.away_team_id AS triggered_team_id,
    b.away_team_name AS triggered_team_name,
    b.home_team_id AS opponent_team_id,
    b.home_team_name AS opponent_team_name,
    toFloat32(1.0) AS trigger_threshold_min_goalkeeper_goals_prevented,
    toInt8(1) AS trigger_condition_both_goalkeepers_required,
    b.home_goalkeeper_goals_prevented,
    b.away_goalkeeper_goals_prevented,
    toFloat32(round(
        b.home_goalkeeper_goals_prevented + b.away_goalkeeper_goals_prevented,
        3
    )) AS match_combined_goalkeeper_goals_prevented,
    toFloat32(round(
        abs(b.home_goalkeeper_goals_prevented - b.away_goalkeeper_goals_prevented),
        3
    )) AS match_goalkeeper_goals_prevented_balance_abs,
    toFloat32(round(b.home_goalkeeper_goals_prevented - 1.0, 3)) AS home_goalkeeper_goals_prevented_above_threshold,
    toFloat32(round(b.away_goalkeeper_goals_prevented - 1.0, 3)) AS away_goalkeeper_goals_prevented_above_threshold,
    b.away_goalkeeper_goals_prevented AS triggered_team_goalkeeper_goals_prevented,
    b.home_goalkeeper_goals_prevented AS opponent_goalkeeper_goals_prevented,
    toFloat32(round(
        b.away_goalkeeper_goals_prevented - b.home_goalkeeper_goals_prevented,
        3
    )) AS goalkeeper_goals_prevented_delta,
    toFloat32(b.expected_goals_on_target_home) AS triggered_team_expected_goals_on_target_faced,
    toFloat32(b.expected_goals_on_target_away) AS opponent_expected_goals_on_target_faced,
    toFloat32(round(
        b.expected_goals_on_target_home - b.expected_goals_on_target_away,
        3
    )) AS expected_goals_on_target_faced_delta,
    b.home_goals AS triggered_team_goals_conceded,
    b.away_goals AS opponent_goals_conceded,
    b.home_goals - b.away_goals AS goals_conceded_delta,
    b.keeper_saves_away AS triggered_team_keeper_saves,
    b.keeper_saves_home AS opponent_keeper_saves,
    b.keeper_saves_away - b.keeper_saves_home AS keeper_saves_delta,
    b.shots_on_target_home AS triggered_team_shots_on_target_faced,
    b.shots_on_target_away AS opponent_shots_on_target_faced,
    b.shots_on_target_home - b.shots_on_target_away AS shots_on_target_faced_delta,
    toFloat32(coalesce(round(
        100.0 * b.keeper_saves_away / nullIf(toFloat64(b.shots_on_target_home), 0),
        1
    ), 0.0)) AS triggered_team_save_rate_pct,
    toFloat32(coalesce(round(
        100.0 * b.keeper_saves_home / nullIf(toFloat64(b.shots_on_target_away), 0),
        1
    ), 0.0)) AS opponent_save_rate_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.keeper_saves_away / nullIf(toFloat64(b.shots_on_target_home), 0), 1), 0.0)
      - coalesce(round(100.0 * b.keeper_saves_home / nullIf(toFloat64(b.shots_on_target_away), 0), 1), 0.0),
        1
    )) AS save_rate_delta_pct,
    b.total_shots_home AS triggered_team_total_shots_faced,
    b.total_shots_away AS opponent_total_shots_faced,
    b.total_shots_home - b.total_shots_away AS total_shots_faced_delta,
    b.shot_blocks_away AS triggered_team_shot_blocks,
    b.shot_blocks_home AS opponent_shot_blocks,
    b.shot_blocks_away - b.shot_blocks_home AS shot_blocks_delta,
    b.clearances_away AS triggered_team_clearances,
    b.clearances_home AS opponent_clearances,
    b.clearances_away - b.clearances_home AS clearances_delta,
    b.interceptions_away AS triggered_team_interceptions,
    b.interceptions_home AS opponent_interceptions,
    b.interceptions_away - b.interceptions_home AS interceptions_delta,
    b.possession_away_pct AS triggered_team_possession_pct,
    b.possession_home_pct AS opponent_possession_pct,
    toFloat32(round(b.possession_away_pct - b.possession_home_pct, 1)) AS possession_delta_pct,
    b.pass_attempts_away AS triggered_team_pass_attempts,
    b.pass_attempts_home AS opponent_pass_attempts,
    b.pass_attempts_away - b.pass_attempts_home AS pass_attempt_delta,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0), 1), 0.0)
      - coalesce(round(100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct,
    b.away_goals AS triggered_team_goals,
    b.home_goals AS opponent_goals,
    b.away_goals - b.home_goals AS goal_delta,
    toUInt8(if(b.home_goals = 0, 1, 0)) AS triggered_team_clean_sheet_flag
FROM base_stats AS b
ORDER BY
    match_combined_goalkeeper_goals_prevented DESC,
    match_goalkeeper_goals_prevented_balance_abs ASC,
    match_date DESC,
    match_id DESC;
