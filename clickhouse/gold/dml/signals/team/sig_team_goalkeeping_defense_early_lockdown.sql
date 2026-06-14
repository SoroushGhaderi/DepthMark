INSERT INTO gold.sig_team_goalkeeping_defense_early_lockdown (
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
    trigger_window_minutes,
    trigger_threshold_max_opponent_shots_first_20,
    match_first_20_total_shots,
    triggered_team_first_20_total_shots,
    opponent_first_20_total_shots,
    first_20_shots_delta,
    match_first_20_total_shots_on_target,
    triggered_team_first_20_shots_on_target,
    opponent_first_20_shots_on_target,
    first_20_shots_on_target_delta,
    match_first_20_first_shot_minute,
    triggered_team_first_20_first_shot_minute,
    opponent_first_20_first_shot_minute,
    triggered_team_total_shots_faced,
    opponent_total_shots_faced,
    total_shots_faced_delta,
    triggered_team_shots_on_target_faced,
    opponent_shots_on_target_faced,
    shots_on_target_faced_delta,
    triggered_team_expected_goals_faced,
    opponent_expected_goals_faced,
    expected_goals_faced_delta,
    triggered_team_keeper_saves,
    opponent_keeper_saves,
    keeper_saves_delta,
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
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_clean_sheet_flag
)
-- Signal: sig_team_goalkeeping_defense_early_lockdown
-- Intent: detect teams that suppress all opposition shots in the opening 20 minutes, then
--         preserve bilateral first-window, defending, control, and result context.
-- Trigger: team allows 0 opposition shots in minutes 1-20 (`silver.shot.minute <= 20`).

WITH first_20_shot_context AS (
    SELECT
        m.match_id AS match_id,
        toInt32(countIf(s.team_id = m.home_team_id)) AS home_first_20_total_shots,
        toInt32(countIf(s.team_id = m.away_team_id)) AS away_first_20_total_shots,
        toInt32(countIf(coalesce(s.is_on_target, 0) = 1 AND s.team_id = m.home_team_id))
            AS home_first_20_shots_on_target,
        toInt32(countIf(coalesce(s.is_on_target, 0) = 1 AND s.team_id = m.away_team_id))
            AS away_first_20_shots_on_target,
        nullIf(
            minIf(
                toInt32(coalesce(s.minute, 0)),
                s.team_id = m.home_team_id
                AND s.minute IS NOT NULL
            ),
            0
        ) AS home_first_20_first_shot_minute,
        nullIf(
            minIf(
                toInt32(coalesce(s.minute, 0)),
                s.team_id = m.away_team_id
                AND s.minute IS NOT NULL
            ),
            0
        ) AS away_first_20_first_shot_minute,
        nullIf(
            minIf(
                toInt32(coalesce(s.minute, 0)),
                s.minute IS NOT NULL
            ),
            0
        ) AS match_first_20_first_shot_minute
    FROM silver.match AS m
    LEFT JOIN silver.shot AS s
        ON s.match_id = m.match_id
       AND s.minute IS NOT NULL
       AND s.minute <= 20
    GROUP BY
        m.match_id,
        m.home_team_id,
        m.away_team_id
),
base_stats AS (
    SELECT
        m.match_id AS match_id,
        m.match_date AS match_date,
        m.home_team_id AS home_team_id,
        m.home_team_name AS home_team_name,
        m.away_team_id AS away_team_id,
        m.away_team_name AS away_team_name,
        m.home_score AS home_score,
        m.away_score AS away_score,
        toInt32(coalesce(ps.total_shots_home, 0)) AS total_shots_home,
        toInt32(coalesce(ps.total_shots_away, 0)) AS total_shots_away,
        toInt32(coalesce(ps.shots_on_target_home, 0)) AS shots_on_target_home,
        toInt32(coalesce(ps.shots_on_target_away, 0)) AS shots_on_target_away,
        toFloat32(coalesce(ps.expected_goals_home, 0)) AS expected_goals_home,
        toFloat32(coalesce(ps.expected_goals_away, 0)) AS expected_goals_away,
        toInt32(coalesce(ps.keeper_saves_home, 0)) AS keeper_saves_home,
        toInt32(coalesce(ps.keeper_saves_away, 0)) AS keeper_saves_away,
        toInt32(coalesce(ps.shot_blocks_home, 0)) AS shot_blocks_home,
        toInt32(coalesce(ps.shot_blocks_away, 0)) AS shot_blocks_away,
        toInt32(coalesce(ps.clearances_home, 0)) AS clearances_home,
        toInt32(coalesce(ps.clearances_away, 0)) AS clearances_away,
        toInt32(coalesce(ps.interceptions_home, 0)) AS interceptions_home,
        toInt32(coalesce(ps.interceptions_away, 0)) AS interceptions_away,
        toFloat32(coalesce(ps.ball_possession_home, 0)) AS ball_possession_home,
        toFloat32(coalesce(ps.ball_possession_away, 0)) AS ball_possession_away,
        toInt32(coalesce(ps.pass_attempts_home, 0)) AS pass_attempts_home,
        toInt32(coalesce(ps.pass_attempts_away, 0)) AS pass_attempts_away,
        toInt32(coalesce(ps.accurate_passes_home, 0)) AS accurate_passes_home,
        toInt32(coalesce(ps.accurate_passes_away, 0)) AS accurate_passes_away,
        f.home_first_20_total_shots AS home_first_20_total_shots,
        f.away_first_20_total_shots AS away_first_20_total_shots,
        f.home_first_20_shots_on_target AS home_first_20_shots_on_target,
        f.away_first_20_shots_on_target AS away_first_20_shots_on_target,
        f.home_first_20_first_shot_minute AS home_first_20_first_shot_minute,
        f.away_first_20_first_shot_minute AS away_first_20_first_shot_minute,
        f.match_first_20_first_shot_minute AS match_first_20_first_shot_minute
    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.match_date = m.match_date
       AND ps.period = 'All'
    INNER JOIN first_20_shot_context AS f
        ON f.match_id = m.match_id
    WHERE m.match_finished = 1
      AND m.match_id > 0
)

-- Home-side trigger.
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
    toInt32(20) AS trigger_window_minutes,
    toInt32(0) AS trigger_threshold_max_opponent_shots_first_20,
    toInt32(b.home_first_20_total_shots + b.away_first_20_total_shots) AS match_first_20_total_shots,
    b.home_first_20_total_shots AS triggered_team_first_20_total_shots,
    b.away_first_20_total_shots AS opponent_first_20_total_shots,
    toInt32(b.home_first_20_total_shots - b.away_first_20_total_shots) AS first_20_shots_delta,
    toInt32(b.home_first_20_shots_on_target + b.away_first_20_shots_on_target)
        AS match_first_20_total_shots_on_target,
    b.home_first_20_shots_on_target AS triggered_team_first_20_shots_on_target,
    b.away_first_20_shots_on_target AS opponent_first_20_shots_on_target,
    toInt32(b.home_first_20_shots_on_target - b.away_first_20_shots_on_target)
        AS first_20_shots_on_target_delta,
    b.match_first_20_first_shot_minute,
    b.home_first_20_first_shot_minute AS triggered_team_first_20_first_shot_minute,
    b.away_first_20_first_shot_minute AS opponent_first_20_first_shot_minute,
    b.total_shots_away AS triggered_team_total_shots_faced,
    b.total_shots_home AS opponent_total_shots_faced,
    toInt32(b.total_shots_away - b.total_shots_home) AS total_shots_faced_delta,
    b.shots_on_target_away AS triggered_team_shots_on_target_faced,
    b.shots_on_target_home AS opponent_shots_on_target_faced,
    toInt32(b.shots_on_target_away - b.shots_on_target_home) AS shots_on_target_faced_delta,
    b.expected_goals_away AS triggered_team_expected_goals_faced,
    b.expected_goals_home AS opponent_expected_goals_faced,
    toFloat32(round(b.expected_goals_away - b.expected_goals_home, 3)) AS expected_goals_faced_delta,
    b.keeper_saves_home AS triggered_team_keeper_saves,
    b.keeper_saves_away AS opponent_keeper_saves,
    toInt32(b.keeper_saves_home - b.keeper_saves_away) AS keeper_saves_delta,
    b.shot_blocks_home AS triggered_team_shot_blocks,
    b.shot_blocks_away AS opponent_shot_blocks,
    toInt32(b.shot_blocks_home - b.shot_blocks_away) AS shot_blocks_delta,
    b.clearances_home AS triggered_team_clearances,
    b.clearances_away AS opponent_clearances,
    toInt32(b.clearances_home - b.clearances_away) AS clearances_delta,
    b.interceptions_home AS triggered_team_interceptions,
    b.interceptions_away AS opponent_interceptions,
    toInt32(b.interceptions_home - b.interceptions_away) AS interceptions_delta,
    b.ball_possession_home AS triggered_team_possession_pct,
    b.ball_possession_away AS opponent_possession_pct,
    toFloat32(round(b.ball_possession_home - b.ball_possession_away, 1)) AS possession_delta_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,
    toInt32(coalesce(b.home_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(b.away_score, 0)) AS opponent_goals,
    toInt32(coalesce(b.home_score, 0) - coalesce(b.away_score, 0)) AS goal_delta,
    toInt8(if(coalesce(b.away_score, 0) = 0, 1, 0)) AS triggered_team_clean_sheet_flag
FROM base_stats AS b
WHERE b.away_first_20_total_shots = 0

UNION ALL

-- Away-side trigger.
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
    toInt32(20) AS trigger_window_minutes,
    toInt32(0) AS trigger_threshold_max_opponent_shots_first_20,
    toInt32(b.home_first_20_total_shots + b.away_first_20_total_shots) AS match_first_20_total_shots,
    b.away_first_20_total_shots AS triggered_team_first_20_total_shots,
    b.home_first_20_total_shots AS opponent_first_20_total_shots,
    toInt32(b.away_first_20_total_shots - b.home_first_20_total_shots) AS first_20_shots_delta,
    toInt32(b.home_first_20_shots_on_target + b.away_first_20_shots_on_target)
        AS match_first_20_total_shots_on_target,
    b.away_first_20_shots_on_target AS triggered_team_first_20_shots_on_target,
    b.home_first_20_shots_on_target AS opponent_first_20_shots_on_target,
    toInt32(b.away_first_20_shots_on_target - b.home_first_20_shots_on_target)
        AS first_20_shots_on_target_delta,
    b.match_first_20_first_shot_minute,
    b.away_first_20_first_shot_minute AS triggered_team_first_20_first_shot_minute,
    b.home_first_20_first_shot_minute AS opponent_first_20_first_shot_minute,
    b.total_shots_home AS triggered_team_total_shots_faced,
    b.total_shots_away AS opponent_total_shots_faced,
    toInt32(b.total_shots_home - b.total_shots_away) AS total_shots_faced_delta,
    b.shots_on_target_home AS triggered_team_shots_on_target_faced,
    b.shots_on_target_away AS opponent_shots_on_target_faced,
    toInt32(b.shots_on_target_home - b.shots_on_target_away) AS shots_on_target_faced_delta,
    b.expected_goals_home AS triggered_team_expected_goals_faced,
    b.expected_goals_away AS opponent_expected_goals_faced,
    toFloat32(round(b.expected_goals_home - b.expected_goals_away, 3)) AS expected_goals_faced_delta,
    b.keeper_saves_away AS triggered_team_keeper_saves,
    b.keeper_saves_home AS opponent_keeper_saves,
    toInt32(b.keeper_saves_away - b.keeper_saves_home) AS keeper_saves_delta,
    b.shot_blocks_away AS triggered_team_shot_blocks,
    b.shot_blocks_home AS opponent_shot_blocks,
    toInt32(b.shot_blocks_away - b.shot_blocks_home) AS shot_blocks_delta,
    b.clearances_away AS triggered_team_clearances,
    b.clearances_home AS opponent_clearances,
    toInt32(b.clearances_away - b.clearances_home) AS clearances_delta,
    b.interceptions_away AS triggered_team_interceptions,
    b.interceptions_home AS opponent_interceptions,
    toInt32(b.interceptions_away - b.interceptions_home) AS interceptions_delta,
    b.ball_possession_away AS triggered_team_possession_pct,
    b.ball_possession_home AS opponent_possession_pct,
    toFloat32(round(b.ball_possession_away - b.ball_possession_home, 1)) AS possession_delta_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,
    toInt32(coalesce(b.away_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(b.home_score, 0)) AS opponent_goals,
    toInt32(coalesce(b.away_score, 0) - coalesce(b.home_score, 0)) AS goal_delta,
    toInt8(if(coalesce(b.home_score, 0) = 0, 1, 0)) AS triggered_team_clean_sheet_flag
FROM base_stats AS b
WHERE b.home_first_20_total_shots = 0

ORDER BY
    first_20_shots_delta DESC,
    total_shots_faced_delta ASC,
    match_date DESC,
    match_id DESC;
