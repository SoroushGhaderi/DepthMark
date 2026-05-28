INSERT INTO gold.sig_match_shooting_goals_early_goal_late_goal (
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
    trigger_threshold_max_early_effective_minute,
    trigger_threshold_min_late_effective_minute,
    match_early_goal_count,
    match_late_goal_count,
    home_early_goal_count,
    away_early_goal_count,
    home_late_goal_count,
    away_late_goal_count,
    first_early_goal_effective_minute,
    last_late_goal_effective_minute,
    early_to_late_goal_span_minutes,
    both_sides_scored_early_flag,
    both_sides_scored_late_flag,
    triggered_team_early_goal_count,
    opponent_early_goal_count,
    early_goal_count_delta,
    triggered_team_late_goal_count,
    opponent_late_goal_count,
    late_goal_count_delta,
    triggered_team_total_goals,
    opponent_total_goals,
    goal_gap,
    triggered_team_total_shots,
    opponent_total_shots,
    shot_volume_delta,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    triggered_team_shot_accuracy_pct,
    opponent_shot_accuracy_pct,
    shot_accuracy_delta_pct,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_shot_conversion_pct,
    opponent_shot_conversion_pct,
    shot_conversion_delta_pct,
    triggered_team_big_chances,
    opponent_big_chances,
    triggered_team_big_chances_missed,
    opponent_big_chances_missed,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct
)
-- Signal: sig_match_shooting_goals_early_goal_late_goal
-- Intent: detect matches with at least one non-own goal in the opening 5 effective minutes and
--         at least one non-own goal in the final 5 regulation minutes (including stoppage-time),
--         then emit side-oriented finishing and control diagnostics.
-- Trigger: match_early_goal_count >= 1 and match_late_goal_count >= 1.
WITH goal_events AS (
    SELECT
        s.match_id,
        if(coalesce(s.is_home_goal, 0) = 1, 'home', 'away') AS goal_side,
        toInt32(coalesce(s.goal_time, s.minute, 0)) AS goal_minute,
        toInt32(coalesce(s.goal_overload_time, s.minute_added, 0)) AS goal_added_time,
        toInt32(
            coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
        ) AS goal_effective_minute
    FROM silver.shot AS s
    WHERE s.match_id > 0
      AND coalesce(s.is_goal, 0) = 1
      AND coalesce(s.is_own_goal, 0) = 0
      AND isNotNull(s.is_home_goal)
      AND toInt32(coalesce(s.goal_time, s.minute, 0)) > 0
),
match_goal_windows AS (
    SELECT
        ge.match_id,
        toInt32(countIf(ge.goal_effective_minute BETWEEN 1 AND 5)) AS match_early_goal_count,
        toInt32(countIf(ge.goal_effective_minute >= 86)) AS match_late_goal_count,
        toInt32(countIf(ge.goal_side = 'home' AND ge.goal_effective_minute BETWEEN 1 AND 5))
            AS home_early_goal_count,
        toInt32(countIf(ge.goal_side = 'away' AND ge.goal_effective_minute BETWEEN 1 AND 5))
            AS away_early_goal_count,
        toInt32(countIf(ge.goal_side = 'home' AND ge.goal_effective_minute >= 86))
            AS home_late_goal_count,
        toInt32(countIf(ge.goal_side = 'away' AND ge.goal_effective_minute >= 86))
            AS away_late_goal_count,
        toInt32(minIf(ge.goal_effective_minute, ge.goal_effective_minute BETWEEN 1 AND 5))
            AS first_early_goal_effective_minute,
        toInt32(maxIf(ge.goal_effective_minute, ge.goal_effective_minute >= 86))
            AS last_late_goal_effective_minute
    FROM goal_events AS ge
    GROUP BY ge.match_id
    HAVING match_early_goal_count >= 1
       AND match_late_goal_count >= 1
),
base_stats AS (
    SELECT
        m.match_id,
        m.match_date,
        m.home_team_id,
        m.home_team_name,
        m.away_team_id,
        m.away_team_name,
        m.home_score,
        m.away_score,
        coalesce(m.home_score, 0) AS home_goals,
        coalesce(m.away_score, 0) AS away_goals,
        mgw.match_early_goal_count,
        mgw.match_late_goal_count,
        mgw.home_early_goal_count,
        mgw.away_early_goal_count,
        mgw.home_late_goal_count,
        mgw.away_late_goal_count,
        mgw.first_early_goal_effective_minute,
        mgw.last_late_goal_effective_minute,
        coalesce(ps.total_shots_home, 0) AS total_shots_home,
        coalesce(ps.total_shots_away, 0) AS total_shots_away,
        coalesce(ps.shots_on_target_home, 0) AS shots_on_target_home,
        coalesce(ps.shots_on_target_away, 0) AS shots_on_target_away,
        toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS expected_goals_home,
        toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS expected_goals_away,
        coalesce(ps.big_chances_home, 0) AS big_chances_home,
        coalesce(ps.big_chances_away, 0) AS big_chances_away,
        coalesce(ps.big_chances_missed_home, 0) AS big_chances_missed_home,
        coalesce(ps.big_chances_missed_away, 0) AS big_chances_missed_away,
        coalesce(ps.touches_opp_box_home, 0) AS touches_opposition_box_home,
        coalesce(ps.touches_opp_box_away, 0) AS touches_opposition_box_away,
        toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS possession_home_pct,
        toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS possession_away_pct,
        coalesce(ps.accurate_passes_home, 0) AS accurate_passes_home,
        coalesce(ps.accurate_passes_away, 0) AS accurate_passes_away,
        coalesce(ps.pass_attempts_home, 0) AS pass_attempts_home,
        coalesce(ps.pass_attempts_away, 0) AS pass_attempts_away
    FROM silver.match AS m
    INNER JOIN match_goal_windows AS mgw
        ON mgw.match_id = m.match_id
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.match_date = m.match_date
       AND ps.period = 'All'
    WHERE m.match_finished = 1
      AND m.match_id > 0
)

SELECT
    match_id,
    match_date,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,
    'home' AS triggered_side,
    home_team_id AS triggered_team_id,
    home_team_name AS triggered_team_name,
    away_team_id AS opponent_team_id,
    away_team_name AS opponent_team_name,
    toInt32(5) AS trigger_threshold_max_early_effective_minute,
    toInt32(86) AS trigger_threshold_min_late_effective_minute,
    match_early_goal_count,
    match_late_goal_count,
    home_early_goal_count,
    away_early_goal_count,
    home_late_goal_count,
    away_late_goal_count,
    first_early_goal_effective_minute,
    last_late_goal_effective_minute,
    toInt32(last_late_goal_effective_minute - first_early_goal_effective_minute)
        AS early_to_late_goal_span_minutes,
    toUInt8(home_early_goal_count > 0 AND away_early_goal_count > 0) AS both_sides_scored_early_flag,
    toUInt8(home_late_goal_count > 0 AND away_late_goal_count > 0) AS both_sides_scored_late_flag,
    home_early_goal_count AS triggered_team_early_goal_count,
    away_early_goal_count AS opponent_early_goal_count,
    home_early_goal_count - away_early_goal_count AS early_goal_count_delta,
    home_late_goal_count AS triggered_team_late_goal_count,
    away_late_goal_count AS opponent_late_goal_count,
    home_late_goal_count - away_late_goal_count AS late_goal_count_delta,
    home_goals AS triggered_team_total_goals,
    away_goals AS opponent_total_goals,
    home_goals - away_goals AS goal_gap,
    total_shots_home AS triggered_team_total_shots,
    total_shots_away AS opponent_total_shots,
    total_shots_home - total_shots_away AS shot_volume_delta,
    shots_on_target_home AS triggered_team_shots_on_target,
    shots_on_target_away AS opponent_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * shots_on_target_home / nullIf(toFloat64(total_shots_home), 0),
        1
    ), 0.0)) AS triggered_team_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * shots_on_target_away / nullIf(toFloat64(total_shots_away), 0),
        1
    ), 0.0)) AS opponent_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * shots_on_target_home / nullIf(toFloat64(total_shots_home), 0), 1), 0.0)
      - coalesce(round(100.0 * shots_on_target_away / nullIf(toFloat64(total_shots_away), 0), 1), 0.0),
        1
    )) AS shot_accuracy_delta_pct,
    expected_goals_home AS triggered_team_xg,
    expected_goals_away AS opponent_xg,
    toFloat32(round(expected_goals_home - expected_goals_away, 3)) AS xg_delta,
    toFloat32(coalesce(round(
        100.0 * home_goals / nullIf(toFloat64(total_shots_home), 0),
        1
    ), 0.0)) AS triggered_team_shot_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * away_goals / nullIf(toFloat64(total_shots_away), 0),
        1
    ), 0.0)) AS opponent_shot_conversion_pct,
    toFloat32(round(
        coalesce(round(100.0 * home_goals / nullIf(toFloat64(total_shots_home), 0), 1), 0.0)
      - coalesce(round(100.0 * away_goals / nullIf(toFloat64(total_shots_away), 0), 1), 0.0),
        1
    )) AS shot_conversion_delta_pct,
    big_chances_home AS triggered_team_big_chances,
    big_chances_away AS opponent_big_chances,
    big_chances_missed_home AS triggered_team_big_chances_missed,
    big_chances_missed_away AS opponent_big_chances_missed,
    touches_opposition_box_home AS triggered_team_touches_opposition_box,
    touches_opposition_box_away AS opponent_touches_opposition_box,
    possession_home_pct AS triggered_team_possession_pct,
    possession_away_pct AS opponent_possession_pct,
    toFloat32(round(possession_home_pct - possession_away_pct, 1)) AS possession_delta_pct,
    toFloat32(coalesce(round(
        100.0 * accurate_passes_home / nullIf(toFloat64(pass_attempts_home), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * accurate_passes_away / nullIf(toFloat64(pass_attempts_away), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * accurate_passes_home / nullIf(toFloat64(pass_attempts_home), 0), 1), 0.0)
      - coalesce(round(100.0 * accurate_passes_away / nullIf(toFloat64(pass_attempts_away), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct
FROM base_stats AS bs

UNION ALL

SELECT
    match_id,
    match_date,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,
    'away' AS triggered_side,
    away_team_id AS triggered_team_id,
    away_team_name AS triggered_team_name,
    home_team_id AS opponent_team_id,
    home_team_name AS opponent_team_name,
    toInt32(5) AS trigger_threshold_max_early_effective_minute,
    toInt32(86) AS trigger_threshold_min_late_effective_minute,
    match_early_goal_count,
    match_late_goal_count,
    home_early_goal_count,
    away_early_goal_count,
    home_late_goal_count,
    away_late_goal_count,
    first_early_goal_effective_minute,
    last_late_goal_effective_minute,
    toInt32(last_late_goal_effective_minute - first_early_goal_effective_minute)
        AS early_to_late_goal_span_minutes,
    toUInt8(home_early_goal_count > 0 AND away_early_goal_count > 0) AS both_sides_scored_early_flag,
    toUInt8(home_late_goal_count > 0 AND away_late_goal_count > 0) AS both_sides_scored_late_flag,
    away_early_goal_count AS triggered_team_early_goal_count,
    home_early_goal_count AS opponent_early_goal_count,
    away_early_goal_count - home_early_goal_count AS early_goal_count_delta,
    away_late_goal_count AS triggered_team_late_goal_count,
    home_late_goal_count AS opponent_late_goal_count,
    away_late_goal_count - home_late_goal_count AS late_goal_count_delta,
    away_goals AS triggered_team_total_goals,
    home_goals AS opponent_total_goals,
    away_goals - home_goals AS goal_gap,
    total_shots_away AS triggered_team_total_shots,
    total_shots_home AS opponent_total_shots,
    total_shots_away - total_shots_home AS shot_volume_delta,
    shots_on_target_away AS triggered_team_shots_on_target,
    shots_on_target_home AS opponent_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * shots_on_target_away / nullIf(toFloat64(total_shots_away), 0),
        1
    ), 0.0)) AS triggered_team_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * shots_on_target_home / nullIf(toFloat64(total_shots_home), 0),
        1
    ), 0.0)) AS opponent_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * shots_on_target_away / nullIf(toFloat64(total_shots_away), 0), 1), 0.0)
      - coalesce(round(100.0 * shots_on_target_home / nullIf(toFloat64(total_shots_home), 0), 1), 0.0),
        1
    )) AS shot_accuracy_delta_pct,
    expected_goals_away AS triggered_team_xg,
    expected_goals_home AS opponent_xg,
    toFloat32(round(expected_goals_away - expected_goals_home, 3)) AS xg_delta,
    toFloat32(coalesce(round(
        100.0 * away_goals / nullIf(toFloat64(total_shots_away), 0),
        1
    ), 0.0)) AS triggered_team_shot_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * home_goals / nullIf(toFloat64(total_shots_home), 0),
        1
    ), 0.0)) AS opponent_shot_conversion_pct,
    toFloat32(round(
        coalesce(round(100.0 * away_goals / nullIf(toFloat64(total_shots_away), 0), 1), 0.0)
      - coalesce(round(100.0 * home_goals / nullIf(toFloat64(total_shots_home), 0), 1), 0.0),
        1
    )) AS shot_conversion_delta_pct,
    big_chances_away AS triggered_team_big_chances,
    big_chances_home AS opponent_big_chances,
    big_chances_missed_away AS triggered_team_big_chances_missed,
    big_chances_missed_home AS opponent_big_chances_missed,
    touches_opposition_box_away AS triggered_team_touches_opposition_box,
    touches_opposition_box_home AS opponent_touches_opposition_box,
    possession_away_pct AS triggered_team_possession_pct,
    possession_home_pct AS opponent_possession_pct,
    toFloat32(round(possession_away_pct - possession_home_pct, 1)) AS possession_delta_pct,
    toFloat32(coalesce(round(
        100.0 * accurate_passes_away / nullIf(toFloat64(pass_attempts_away), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * accurate_passes_home / nullIf(toFloat64(pass_attempts_home), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * accurate_passes_away / nullIf(toFloat64(pass_attempts_away), 0), 1), 0.0)
      - coalesce(round(100.0 * accurate_passes_home / nullIf(toFloat64(pass_attempts_home), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct
FROM base_stats AS bs
SETTINGS allow_experimental_analyzer = 0;
