INSERT INTO gold.sig_match_possession_passing_unproductive_game (
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
    match_total_pass_attempts,
    match_total_shots,
    match_passes_per_shot,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_pass_share_pct,
    triggered_team_shot_share_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_opposition_half_passes,
    opponent_opposition_half_passes,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    triggered_team_xg,
    opponent_xg,
    match_total_xg,
    xg_gap
)
-- ============================================================
-- Signal: sig_match_possession_passing_unproductive_game
-- Intent: Detect matches with very high circulation but very low shot output,
--         then orient each row to one side for symmetric team-context analysis.
-- Trigger: Total match pass attempts > 1000 and total match shots < 10 at period='All'.
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
        coalesce(ps.pass_attempts_home, 0) AS pass_attempts_home,
        coalesce(ps.pass_attempts_away, 0) AS pass_attempts_away,
        coalesce(ps.total_shots_home, 0) AS total_shots_home,
        coalesce(ps.total_shots_away, 0) AS total_shots_away,
        coalesce(ps.accurate_passes_home, 0) AS accurate_passes_home,
        coalesce(ps.accurate_passes_away, 0) AS accurate_passes_away,
        toFloat32(coalesce(ps.ball_possession_home, 0)) AS ball_possession_home,
        toFloat32(coalesce(ps.ball_possession_away, 0)) AS ball_possession_away,
        coalesce(ps.opposition_half_passes_home, 0) AS opposition_half_passes_home,
        coalesce(ps.opposition_half_passes_away, 0) AS opposition_half_passes_away,
        coalesce(ps.touches_opp_box_home, 0) AS touches_opposition_box_home,
        coalesce(ps.touches_opp_box_away, 0) AS touches_opposition_box_away,
        toFloat32(coalesce(ps.expected_goals_home, 0)) AS expected_goals_home,
        toFloat32(coalesce(ps.expected_goals_away, 0)) AS expected_goals_away,
        coalesce(ps.pass_attempts_home, 0) + coalesce(ps.pass_attempts_away, 0) AS match_total_pass_attempts,
        coalesce(ps.total_shots_home, 0) + coalesce(ps.total_shots_away, 0) AS match_total_shots
    FROM silver.match AS m FINAL
    INNER JOIN silver.period_stat AS ps FINAL
        ON ps.match_id = m.match_id
       AND ps.period = 'All'
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND (coalesce(ps.pass_attempts_home, 0) + coalesce(ps.pass_attempts_away, 0)) > 1000
      AND (coalesce(ps.total_shots_home, 0) + coalesce(ps.total_shots_away, 0)) < 10
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
    b.match_total_pass_attempts,
    b.match_total_shots,
    toFloat32(round(b.match_total_pass_attempts / nullIf(toFloat64(b.match_total_shots), 0), 2)) AS match_passes_per_shot,
    b.pass_attempts_home AS triggered_team_pass_attempts,
    b.pass_attempts_away AS opponent_pass_attempts,
    b.total_shots_home AS triggered_team_total_shots,
    b.total_shots_away AS opponent_total_shots,
    toFloat32(round(b.pass_attempts_home * 100.0 / nullIf(toFloat64(b.match_total_pass_attempts), 0), 1)) AS triggered_team_pass_share_pct,
    toFloat32(round(b.total_shots_home * 100.0 / nullIf(toFloat64(b.match_total_shots), 0), 1)) AS triggered_team_shot_share_pct,
    toFloat32(round(b.accurate_passes_home * 100.0 / nullIf(toFloat64(b.pass_attempts_home), 0), 1)) AS triggered_team_pass_accuracy_pct,
    toFloat32(round(b.accurate_passes_away * 100.0 / nullIf(toFloat64(b.pass_attempts_away), 0), 1)) AS opponent_pass_accuracy_pct,
    b.ball_possession_home AS triggered_team_possession_pct,
    b.ball_possession_away AS opponent_possession_pct,
    b.opposition_half_passes_home AS triggered_team_opposition_half_passes,
    b.opposition_half_passes_away AS opponent_opposition_half_passes,
    b.touches_opposition_box_home AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_away AS opponent_touches_opposition_box,
    b.expected_goals_home AS triggered_team_xg,
    b.expected_goals_away AS opponent_xg,
    toFloat32(round(b.expected_goals_home + b.expected_goals_away, 3)) AS match_total_xg,
    toFloat32(round(b.expected_goals_home - b.expected_goals_away, 3)) AS xg_gap
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
    b.match_total_pass_attempts,
    b.match_total_shots,
    toFloat32(round(b.match_total_pass_attempts / nullIf(toFloat64(b.match_total_shots), 0), 2)) AS match_passes_per_shot,
    b.pass_attempts_away AS triggered_team_pass_attempts,
    b.pass_attempts_home AS opponent_pass_attempts,
    b.total_shots_away AS triggered_team_total_shots,
    b.total_shots_home AS opponent_total_shots,
    toFloat32(round(b.pass_attempts_away * 100.0 / nullIf(toFloat64(b.match_total_pass_attempts), 0), 1)) AS triggered_team_pass_share_pct,
    toFloat32(round(b.total_shots_away * 100.0 / nullIf(toFloat64(b.match_total_shots), 0), 1)) AS triggered_team_shot_share_pct,
    toFloat32(round(b.accurate_passes_away * 100.0 / nullIf(toFloat64(b.pass_attempts_away), 0), 1)) AS triggered_team_pass_accuracy_pct,
    toFloat32(round(b.accurate_passes_home * 100.0 / nullIf(toFloat64(b.pass_attempts_home), 0), 1)) AS opponent_pass_accuracy_pct,
    b.ball_possession_away AS triggered_team_possession_pct,
    b.ball_possession_home AS opponent_possession_pct,
    b.opposition_half_passes_away AS triggered_team_opposition_half_passes,
    b.opposition_half_passes_home AS opponent_opposition_half_passes,
    b.touches_opposition_box_away AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_home AS opponent_touches_opposition_box,
    b.expected_goals_away AS triggered_team_xg,
    b.expected_goals_home AS opponent_xg,
    toFloat32(round(b.expected_goals_home + b.expected_goals_away, 3)) AS match_total_xg,
    toFloat32(round(b.expected_goals_away - b.expected_goals_home, 3)) AS xg_gap
FROM base_stats AS b

ORDER BY match_id, triggered_side;
