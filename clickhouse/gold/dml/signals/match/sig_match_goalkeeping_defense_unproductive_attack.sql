INSERT INTO gold.sig_match_goalkeeping_defense_unproductive_attack (
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
    trigger_threshold_min_opponent_total_shots,
    trigger_threshold_min_triggered_team_shot_blocks,
    trigger_condition_triggered_team_win_required,
    triggered_team_shot_blocks,
    opponent_shot_blocks,
    shot_blocks_delta,
    triggered_team_shot_blocks_above_threshold,
    triggered_team_total_shots_faced,
    opponent_total_shots_faced,
    total_shots_faced_delta,
    triggered_team_shots_on_target_faced,
    opponent_shots_on_target_faced,
    shots_on_target_faced_delta,
    triggered_team_shot_block_rate_pct,
    opponent_shot_block_rate_pct,
    shot_block_rate_delta_pct,
    triggered_team_keeper_saves,
    opponent_keeper_saves,
    keeper_saves_delta,
    triggered_team_save_rate_pct,
    opponent_save_rate_pct,
    save_rate_delta_pct,
    triggered_team_interceptions,
    opponent_interceptions,
    interceptions_delta,
    triggered_team_clearances,
    opponent_clearances,
    clearances_delta,
    triggered_team_tackles_won,
    opponent_tackles_won,
    tackles_won_delta,
    triggered_team_duels_won,
    opponent_duels_won,
    duels_won_delta,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_clean_sheet_flag,
    opponent_shot_accuracy_pct,
    opponent_shot_conversion_pct,
    opponent_expected_goals,
    opponent_expected_goals_on_target
)
-- Signal: sig_match_goalkeeping_defense_unproductive_attack
-- Intent: detect winning defensive sides that absorb extreme shot pressure while producing
--         exceptional block volume, then preserve bilateral context for resistance diagnostics.
-- Trigger: opponent has >= 25 total shots, triggered side has >= 15 shot blocks, and triggered side wins.
WITH base_stats AS (
    SELECT
        m.match_id,
        m.match_date,
        m.home_team_id,
        m.home_team_name,
        m.away_team_id,
        m.away_team_name,
        m.home_score,
        m.away_score,
        toInt32(coalesce(m.home_score, 0)) AS home_goals,
        toInt32(coalesce(m.away_score, 0)) AS away_goals,
        toInt32(coalesce(ps.shot_blocks_home, 0)) AS shot_blocks_home,
        toInt32(coalesce(ps.shot_blocks_away, 0)) AS shot_blocks_away,
        toInt32(coalesce(ps.total_shots_home, 0)) AS total_shots_home,
        toInt32(coalesce(ps.total_shots_away, 0)) AS total_shots_away,
        toInt32(coalesce(ps.shots_on_target_home, 0)) AS shots_on_target_home,
        toInt32(coalesce(ps.shots_on_target_away, 0)) AS shots_on_target_away,
        toInt32(coalesce(ps.keeper_saves_home, 0)) AS keeper_saves_home,
        toInt32(coalesce(ps.keeper_saves_away, 0)) AS keeper_saves_away,
        toInt32(coalesce(ps.interceptions_home, 0)) AS interceptions_home,
        toInt32(coalesce(ps.interceptions_away, 0)) AS interceptions_away,
        toInt32(coalesce(ps.clearances_home, 0)) AS clearances_home,
        toInt32(coalesce(ps.clearances_away, 0)) AS clearances_away,
        toInt32(coalesce(ps.tackles_succeeded_home, 0)) AS tackles_won_home,
        toInt32(coalesce(ps.tackles_succeeded_away, 0)) AS tackles_won_away,
        toInt32(coalesce(ps.duels_won_home, 0)) AS duels_won_home,
        toInt32(coalesce(ps.duels_won_away, 0)) AS duels_won_away,
        toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS possession_home_pct,
        toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS possession_away_pct,
        toInt32(coalesce(ps.pass_attempts_home, 0)) AS pass_attempts_home,
        toInt32(coalesce(ps.pass_attempts_away, 0)) AS pass_attempts_away,
        toInt32(coalesce(ps.accurate_passes_home, 0)) AS accurate_passes_home,
        toInt32(coalesce(ps.accurate_passes_away, 0)) AS accurate_passes_away,
        toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS expected_goals_home,
        toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS expected_goals_away,
        toFloat32(coalesce(ps.expected_goals_on_target_home, 0.0)) AS expected_goals_on_target_home,
        toFloat32(coalesce(ps.expected_goals_on_target_away, 0.0)) AS expected_goals_on_target_away
    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.match_date = m.match_date
       AND ps.period = 'All'
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND (
          (
              coalesce(ps.total_shots_away, 0) >= 25
              AND coalesce(ps.shot_blocks_home, 0) >= 15
              AND coalesce(m.home_score, 0) > coalesce(m.away_score, 0)
          )
          OR (
              coalesce(ps.total_shots_home, 0) >= 25
              AND coalesce(ps.shot_blocks_away, 0) >= 15
              AND coalesce(m.away_score, 0) > coalesce(m.home_score, 0)
          )
      )
)

-- Home-side trigger: home wins while away produces high shot volume and home blocks heavily.
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
    toInt32(25) AS trigger_threshold_min_opponent_total_shots,
    toInt32(15) AS trigger_threshold_min_triggered_team_shot_blocks,
    toInt8(1) AS trigger_condition_triggered_team_win_required,
    b.shot_blocks_home AS triggered_team_shot_blocks,
    b.shot_blocks_away AS opponent_shot_blocks,
    toInt32(b.shot_blocks_home - b.shot_blocks_away) AS shot_blocks_delta,
    toInt32(b.shot_blocks_home - 15) AS triggered_team_shot_blocks_above_threshold,
    b.total_shots_away AS triggered_team_total_shots_faced,
    b.total_shots_home AS opponent_total_shots_faced,
    toInt32(b.total_shots_away - b.total_shots_home) AS total_shots_faced_delta,
    b.shots_on_target_away AS triggered_team_shots_on_target_faced,
    b.shots_on_target_home AS opponent_shots_on_target_faced,
    toInt32(b.shots_on_target_away - b.shots_on_target_home) AS shots_on_target_faced_delta,
    toFloat32(coalesce(round(
        100.0 * b.shot_blocks_home / nullIf(toFloat64(b.total_shots_away), 0),
        1
    ), 0.0)) AS triggered_team_shot_block_rate_pct,
    toFloat32(coalesce(round(
        100.0 * b.shot_blocks_away / nullIf(toFloat64(b.total_shots_home), 0),
        1
    ), 0.0)) AS opponent_shot_block_rate_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.shot_blocks_home / nullIf(toFloat64(b.total_shots_away), 0), 1), 0.0)
      - coalesce(round(100.0 * b.shot_blocks_away / nullIf(toFloat64(b.total_shots_home), 0), 1), 0.0),
        1
    )) AS shot_block_rate_delta_pct,
    b.keeper_saves_home AS triggered_team_keeper_saves,
    b.keeper_saves_away AS opponent_keeper_saves,
    toInt32(b.keeper_saves_home - b.keeper_saves_away) AS keeper_saves_delta,
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
    b.interceptions_home AS triggered_team_interceptions,
    b.interceptions_away AS opponent_interceptions,
    toInt32(b.interceptions_home - b.interceptions_away) AS interceptions_delta,
    b.clearances_home AS triggered_team_clearances,
    b.clearances_away AS opponent_clearances,
    toInt32(b.clearances_home - b.clearances_away) AS clearances_delta,
    b.tackles_won_home AS triggered_team_tackles_won,
    b.tackles_won_away AS opponent_tackles_won,
    toInt32(b.tackles_won_home - b.tackles_won_away) AS tackles_won_delta,
    b.duels_won_home AS triggered_team_duels_won,
    b.duels_won_away AS opponent_duels_won,
    toInt32(b.duels_won_home - b.duels_won_away) AS duels_won_delta,
    b.possession_home_pct AS triggered_team_possession_pct,
    b.possession_away_pct AS opponent_possession_pct,
    toFloat32(round(b.possession_home_pct - b.possession_away_pct, 1)) AS possession_delta_pct,
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
    toInt32(b.home_goals - b.away_goals) AS goal_delta,
    toInt8(if(b.away_goals = 0, 1, 0)) AS triggered_team_clean_sheet_flag,
    toFloat32(coalesce(round(
        100.0 * b.shots_on_target_away / nullIf(toFloat64(b.total_shots_away), 0),
        1
    ), 0.0)) AS opponent_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.away_goals / nullIf(toFloat64(b.total_shots_away), 0),
        1
    ), 0.0)) AS opponent_shot_conversion_pct,
    b.expected_goals_away AS opponent_expected_goals,
    b.expected_goals_on_target_away AS opponent_expected_goals_on_target
FROM base_stats AS b
WHERE b.total_shots_away >= 25
  AND b.shot_blocks_home >= 15
  AND b.home_goals > b.away_goals

UNION ALL

-- Away-side trigger: away wins while home produces high shot volume and away blocks heavily.
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
    toInt32(25) AS trigger_threshold_min_opponent_total_shots,
    toInt32(15) AS trigger_threshold_min_triggered_team_shot_blocks,
    toInt8(1) AS trigger_condition_triggered_team_win_required,
    b.shot_blocks_away AS triggered_team_shot_blocks,
    b.shot_blocks_home AS opponent_shot_blocks,
    toInt32(b.shot_blocks_away - b.shot_blocks_home) AS shot_blocks_delta,
    toInt32(b.shot_blocks_away - 15) AS triggered_team_shot_blocks_above_threshold,
    b.total_shots_home AS triggered_team_total_shots_faced,
    b.total_shots_away AS opponent_total_shots_faced,
    toInt32(b.total_shots_home - b.total_shots_away) AS total_shots_faced_delta,
    b.shots_on_target_home AS triggered_team_shots_on_target_faced,
    b.shots_on_target_away AS opponent_shots_on_target_faced,
    toInt32(b.shots_on_target_home - b.shots_on_target_away) AS shots_on_target_faced_delta,
    toFloat32(coalesce(round(
        100.0 * b.shot_blocks_away / nullIf(toFloat64(b.total_shots_home), 0),
        1
    ), 0.0)) AS triggered_team_shot_block_rate_pct,
    toFloat32(coalesce(round(
        100.0 * b.shot_blocks_home / nullIf(toFloat64(b.total_shots_away), 0),
        1
    ), 0.0)) AS opponent_shot_block_rate_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.shot_blocks_away / nullIf(toFloat64(b.total_shots_home), 0), 1), 0.0)
      - coalesce(round(100.0 * b.shot_blocks_home / nullIf(toFloat64(b.total_shots_away), 0), 1), 0.0),
        1
    )) AS shot_block_rate_delta_pct,
    b.keeper_saves_away AS triggered_team_keeper_saves,
    b.keeper_saves_home AS opponent_keeper_saves,
    toInt32(b.keeper_saves_away - b.keeper_saves_home) AS keeper_saves_delta,
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
    b.interceptions_away AS triggered_team_interceptions,
    b.interceptions_home AS opponent_interceptions,
    toInt32(b.interceptions_away - b.interceptions_home) AS interceptions_delta,
    b.clearances_away AS triggered_team_clearances,
    b.clearances_home AS opponent_clearances,
    toInt32(b.clearances_away - b.clearances_home) AS clearances_delta,
    b.tackles_won_away AS triggered_team_tackles_won,
    b.tackles_won_home AS opponent_tackles_won,
    toInt32(b.tackles_won_away - b.tackles_won_home) AS tackles_won_delta,
    b.duels_won_away AS triggered_team_duels_won,
    b.duels_won_home AS opponent_duels_won,
    toInt32(b.duels_won_away - b.duels_won_home) AS duels_won_delta,
    b.possession_away_pct AS triggered_team_possession_pct,
    b.possession_home_pct AS opponent_possession_pct,
    toFloat32(round(b.possession_away_pct - b.possession_home_pct, 1)) AS possession_delta_pct,
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
    toInt32(b.away_goals - b.home_goals) AS goal_delta,
    toInt8(if(b.home_goals = 0, 1, 0)) AS triggered_team_clean_sheet_flag,
    toFloat32(coalesce(round(
        100.0 * b.shots_on_target_home / nullIf(toFloat64(b.total_shots_home), 0),
        1
    ), 0.0)) AS opponent_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.home_goals / nullIf(toFloat64(b.total_shots_home), 0),
        1
    ), 0.0)) AS opponent_shot_conversion_pct,
    b.expected_goals_home AS opponent_expected_goals,
    b.expected_goals_on_target_home AS opponent_expected_goals_on_target
FROM base_stats AS b
WHERE b.total_shots_home >= 25
  AND b.shot_blocks_away >= 15
  AND b.away_goals > b.home_goals;
