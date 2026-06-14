INSERT INTO gold.sig_match_possession_passing_possession_stalemate (
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
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_gap_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_final_third_passes,
    opponent_final_third_passes,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_xg,
    opponent_xg,
    xg_gap
)
-- ============================================================
-- Signal: sig_match_possession_passing_possession_stalemate
-- Intent: Detect matches where full-time possession is perfectly balanced.
-- Trigger: Home possession = 50 and away possession = 50 at period='All'.
-- ============================================================

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

    toFloat32(assumeNotNull(ps.ball_possession_home)) AS triggered_team_possession_pct,
    toFloat32(assumeNotNull(ps.ball_possession_away)) AS opponent_possession_pct,
    toFloat32(abs(assumeNotNull(ps.ball_possession_home) - assumeNotNull(ps.ball_possession_away))) AS possession_gap_pct,

    coalesce(ps.pass_attempts_home, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_away, 0) AS opponent_pass_attempts,
    if(coalesce(ps.pass_attempts_home, 0) > 0,
       round(coalesce(ps.accurate_passes_home, 0) / ps.pass_attempts_home * 100, 1),
       NULL) AS triggered_team_pass_accuracy_pct,
    if(coalesce(ps.pass_attempts_away, 0) > 0,
       round(coalesce(ps.accurate_passes_away, 0) / ps.pass_attempts_away * 100, 1),
       NULL) AS opponent_pass_accuracy_pct,

    coalesce(ps.opposition_half_passes_home, 0) AS triggered_team_final_third_passes,
    coalesce(ps.opposition_half_passes_away, 0) AS opponent_final_third_passes,
    coalesce(ps.touches_opp_box_home, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_away, 0) AS opponent_touches_opposition_box,
    coalesce(ps.total_shots_home, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_away, 0) AS opponent_total_shots,
    toFloat32(coalesce(ps.expected_goals_home, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_home, 0) - coalesce(ps.expected_goals_away, 0), 3)) AS xg_gap
FROM silver.match AS m FINAL
INNER JOIN silver.period_stat AS ps FINAL
    ON  ps.match_id = m.match_id
    AND ps.period   = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND assumeNotNull(ps.ball_possession_home) = 50
  AND assumeNotNull(ps.ball_possession_away) = 50

UNION ALL

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

    toFloat32(assumeNotNull(ps.ball_possession_away)) AS triggered_team_possession_pct,
    toFloat32(assumeNotNull(ps.ball_possession_home)) AS opponent_possession_pct,
    toFloat32(abs(assumeNotNull(ps.ball_possession_away) - assumeNotNull(ps.ball_possession_home))) AS possession_gap_pct,

    coalesce(ps.pass_attempts_away, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_home, 0) AS opponent_pass_attempts,
    if(coalesce(ps.pass_attempts_away, 0) > 0,
       round(coalesce(ps.accurate_passes_away, 0) / ps.pass_attempts_away * 100, 1),
       NULL) AS triggered_team_pass_accuracy_pct,
    if(coalesce(ps.pass_attempts_home, 0) > 0,
       round(coalesce(ps.accurate_passes_home, 0) / ps.pass_attempts_home * 100, 1),
       NULL) AS opponent_pass_accuracy_pct,

    coalesce(ps.opposition_half_passes_away, 0) AS triggered_team_final_third_passes,
    coalesce(ps.opposition_half_passes_home, 0) AS opponent_final_third_passes,
    coalesce(ps.touches_opp_box_away, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_home, 0) AS opponent_touches_opposition_box,
    coalesce(ps.total_shots_away, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_home, 0) AS opponent_total_shots,
    toFloat32(coalesce(ps.expected_goals_away, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_away, 0) - coalesce(ps.expected_goals_home, 0), 3)) AS xg_gap
FROM silver.match AS m FINAL
INNER JOIN silver.period_stat AS ps FINAL
    ON  ps.match_id = m.match_id
    AND ps.period   = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND assumeNotNull(ps.ball_possession_home) = 50
  AND assumeNotNull(ps.ball_possession_away) = 50
ORDER BY match_id, triggered_side;
