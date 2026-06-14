INSERT INTO gold.sig_match_possession_passing_clinical_match (
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
    trigger_threshold_match_total_goals,
    trigger_threshold_match_total_xg,
    match_total_goals,
    match_total_xg,
    match_goal_minus_xg,
    triggered_team_goals,
    opponent_goals,
    goal_gap,
    triggered_team_xg,
    opponent_xg,
    xg_gap,
    triggered_team_goals_minus_xg,
    opponent_goals_minus_xg,
    goals_minus_xg_gap,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_opposition_half_passes,
    opponent_opposition_half_passes,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box
)
-- ============================================================
-- Signal: sig_match_possession_passing_clinical_match
-- Intent: Detect matches where finishing runs far ahead of chance
--         quality despite modest expected-goals volume.
-- Trigger: combined match goals >= 5 and combined match xG <= 2.5
--          in period='All'.
-- ============================================================

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
        toFloat32(coalesce(ps.expected_goals_home, 0)) AS expected_goals_home,
        toFloat32(coalesce(ps.expected_goals_away, 0)) AS expected_goals_away,
        coalesce(ps.total_shots_home, 0) AS total_shots_home,
        coalesce(ps.total_shots_away, 0) AS total_shots_away,
        coalesce(ps.shots_on_target_home, 0) AS shots_on_target_home,
        coalesce(ps.shots_on_target_away, 0) AS shots_on_target_away,
        coalesce(ps.pass_attempts_home, 0) AS pass_attempts_home,
        coalesce(ps.pass_attempts_away, 0) AS pass_attempts_away,
        coalesce(ps.accurate_passes_home, 0) AS accurate_passes_home,
        coalesce(ps.accurate_passes_away, 0) AS accurate_passes_away,
        toFloat32(coalesce(ps.ball_possession_home, 0)) AS ball_possession_home,
        toFloat32(coalesce(ps.ball_possession_away, 0)) AS ball_possession_away,
        coalesce(ps.opposition_half_passes_home, 0) AS opposition_half_passes_home,
        coalesce(ps.opposition_half_passes_away, 0) AS opposition_half_passes_away,
        coalesce(ps.touches_opp_box_home, 0) AS touches_opposition_box_home,
        coalesce(ps.touches_opp_box_away, 0) AS touches_opposition_box_away,
        coalesce(m.home_score, 0) + coalesce(m.away_score, 0) AS match_total_goals,
        toFloat32(round(
            coalesce(ps.expected_goals_home, 0) + coalesce(ps.expected_goals_away, 0),
            3
        )) AS match_total_xg
    FROM silver.match AS m FINAL
    INNER JOIN silver.period_stat AS ps FINAL
        ON ps.match_id = m.match_id
       AND ps.period = 'All'
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND (coalesce(m.home_score, 0) + coalesce(m.away_score, 0)) >= 5
      AND (coalesce(ps.expected_goals_home, 0) + coalesce(ps.expected_goals_away, 0)) <= 2.5
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
    5 AS trigger_threshold_match_total_goals,
    toFloat32(2.5) AS trigger_threshold_match_total_xg,
    b.match_total_goals,
    b.match_total_xg,
    toFloat32(round(b.match_total_goals - b.match_total_xg, 3)) AS match_goal_minus_xg,
    b.home_goals AS triggered_team_goals,
    b.away_goals AS opponent_goals,
    b.home_goals - b.away_goals AS goal_gap,
    b.expected_goals_home AS triggered_team_xg,
    b.expected_goals_away AS opponent_xg,
    toFloat32(round(b.expected_goals_home - b.expected_goals_away, 3)) AS xg_gap,
    toFloat32(round(b.home_goals - b.expected_goals_home, 3)) AS triggered_team_goals_minus_xg,
    toFloat32(round(b.away_goals - b.expected_goals_away, 3)) AS opponent_goals_minus_xg,
    toFloat32(round(
        (b.home_goals - b.expected_goals_home) - (b.away_goals - b.expected_goals_away),
        3
    )) AS goals_minus_xg_gap,
    b.total_shots_home AS triggered_team_total_shots,
    b.total_shots_away AS opponent_total_shots,
    b.shots_on_target_home AS triggered_team_shots_on_target,
    b.shots_on_target_away AS opponent_shots_on_target,
    b.pass_attempts_home AS triggered_team_pass_attempts,
    b.pass_attempts_away AS opponent_pass_attempts,
    toFloat32(round(
        100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    )) AS triggered_team_pass_accuracy_pct,
    toFloat32(round(
        100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    )) AS opponent_pass_accuracy_pct,
    b.ball_possession_home AS triggered_team_possession_pct,
    b.ball_possession_away AS opponent_possession_pct,
    b.opposition_half_passes_home AS triggered_team_opposition_half_passes,
    b.opposition_half_passes_away AS opponent_opposition_half_passes,
    b.touches_opposition_box_home AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_away AS opponent_touches_opposition_box
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
    5 AS trigger_threshold_match_total_goals,
    toFloat32(2.5) AS trigger_threshold_match_total_xg,
    b.match_total_goals,
    b.match_total_xg,
    toFloat32(round(b.match_total_goals - b.match_total_xg, 3)) AS match_goal_minus_xg,
    b.away_goals AS triggered_team_goals,
    b.home_goals AS opponent_goals,
    b.away_goals - b.home_goals AS goal_gap,
    b.expected_goals_away AS triggered_team_xg,
    b.expected_goals_home AS opponent_xg,
    toFloat32(round(b.expected_goals_away - b.expected_goals_home, 3)) AS xg_gap,
    toFloat32(round(b.away_goals - b.expected_goals_away, 3)) AS triggered_team_goals_minus_xg,
    toFloat32(round(b.home_goals - b.expected_goals_home, 3)) AS opponent_goals_minus_xg,
    toFloat32(round(
        (b.away_goals - b.expected_goals_away) - (b.home_goals - b.expected_goals_home),
        3
    )) AS goals_minus_xg_gap,
    b.total_shots_away AS triggered_team_total_shots,
    b.total_shots_home AS opponent_total_shots,
    b.shots_on_target_away AS triggered_team_shots_on_target,
    b.shots_on_target_home AS opponent_shots_on_target,
    b.pass_attempts_away AS triggered_team_pass_attempts,
    b.pass_attempts_home AS opponent_pass_attempts,
    toFloat32(round(
        100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    )) AS triggered_team_pass_accuracy_pct,
    toFloat32(round(
        100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    )) AS opponent_pass_accuracy_pct,
    b.ball_possession_away AS triggered_team_possession_pct,
    b.ball_possession_home AS opponent_possession_pct,
    b.opposition_half_passes_away AS triggered_team_opposition_half_passes,
    b.opposition_half_passes_home AS opponent_opposition_half_passes,
    b.touches_opposition_box_away AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_home AS opponent_touches_opposition_box
FROM base_stats AS b

ORDER BY match_id, triggered_side;
