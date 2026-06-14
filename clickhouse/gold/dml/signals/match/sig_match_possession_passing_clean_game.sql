INSERT INTO gold.sig_match_possession_passing_clean_game (
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
    trigger_threshold_turnovers,
    match_total_turnovers,
    match_total_pass_attempts,
    match_turnovers_per_100_pass_attempts,
    triggered_team_turnovers,
    opponent_turnovers,
    triggered_team_turnover_share_pct,
    triggered_team_failed_passes,
    opponent_failed_passes,
    triggered_team_failed_dribbles,
    opponent_failed_dribbles,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_dribble_success_pct,
    opponent_dribble_success_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    triggered_team_xg,
    opponent_xg,
    xg_gap
)
-- ============================================================
-- Signal: sig_match_possession_passing_clean_game
-- Intent: Detect low-turnover matches where both teams keep possession
--         securely, then emit symmetric side-oriented rows.
-- Trigger: Total match turnovers < 50 at period='All', where turnovers
--          are estimated as failed passes + failed dribbles.
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
        coalesce(ps.accurate_passes_home, 0) AS accurate_passes_home,
        coalesce(ps.accurate_passes_away, 0) AS accurate_passes_away,
        coalesce(ps.dribble_attempts_home, 0) AS dribble_attempts_home,
        coalesce(ps.dribble_attempts_away, 0) AS dribble_attempts_away,
        coalesce(ps.dribbles_succeeded_home, 0) AS successful_dribbles_home,
        coalesce(ps.dribbles_succeeded_away, 0) AS successful_dribbles_away,
        toFloat32(coalesce(ps.ball_possession_home, 0)) AS ball_possession_home,
        toFloat32(coalesce(ps.ball_possession_away, 0)) AS ball_possession_away,
        coalesce(ps.total_shots_home, 0) AS total_shots_home,
        coalesce(ps.total_shots_away, 0) AS total_shots_away,
        coalesce(ps.touches_opp_box_home, 0) AS touches_opposition_box_home,
        coalesce(ps.touches_opp_box_away, 0) AS touches_opposition_box_away,
        toFloat32(coalesce(ps.expected_goals_home, 0)) AS expected_goals_home,
        toFloat32(coalesce(ps.expected_goals_away, 0)) AS expected_goals_away,
        greatest(coalesce(ps.pass_attempts_home, 0) - coalesce(ps.accurate_passes_home, 0), 0) AS failed_passes_home,
        greatest(coalesce(ps.pass_attempts_away, 0) - coalesce(ps.accurate_passes_away, 0), 0) AS failed_passes_away,
        greatest(coalesce(ps.dribble_attempts_home, 0) - coalesce(ps.dribbles_succeeded_home, 0), 0) AS failed_dribbles_home,
        greatest(coalesce(ps.dribble_attempts_away, 0) - coalesce(ps.dribbles_succeeded_away, 0), 0) AS failed_dribbles_away
    FROM silver.match AS m FINAL
    INNER JOIN silver.period_stat AS ps FINAL
        ON ps.match_id = m.match_id
       AND ps.period = 'All'
    WHERE m.match_finished = 1
      AND m.match_id > 0
),
triggered_matches AS (
    SELECT
        b.*,
        b.pass_attempts_home + b.pass_attempts_away AS match_total_pass_attempts,
        (b.failed_passes_home + b.failed_dribbles_home) AS turnovers_home,
        (b.failed_passes_away + b.failed_dribbles_away) AS turnovers_away,
        (b.failed_passes_home + b.failed_dribbles_home + b.failed_passes_away + b.failed_dribbles_away) AS match_total_turnovers
    FROM base_stats AS b
    WHERE (b.failed_passes_home + b.failed_dribbles_home + b.failed_passes_away + b.failed_dribbles_away) < 50
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
    50 AS trigger_threshold_turnovers,
    b.match_total_turnovers,
    b.match_total_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * b.match_total_turnovers / nullIf(toFloat64(b.match_total_pass_attempts), 0),
        2
    ), 0.0)) AS match_turnovers_per_100_pass_attempts,
    b.turnovers_home AS triggered_team_turnovers,
    b.turnovers_away AS opponent_turnovers,
    toFloat32(coalesce(round(
        100.0 * b.turnovers_home / nullIf(toFloat64(b.match_total_turnovers), 0),
        1
    ), 0.0)) AS triggered_team_turnover_share_pct,
    b.failed_passes_home AS triggered_team_failed_passes,
    b.failed_passes_away AS opponent_failed_passes,
    b.failed_dribbles_home AS triggered_team_failed_dribbles,
    b.failed_dribbles_away AS opponent_failed_dribbles,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.successful_dribbles_home / nullIf(toFloat64(b.dribble_attempts_home), 0),
        1
    ), 0.0)) AS triggered_team_dribble_success_pct,
    toFloat32(coalesce(round(
        100.0 * b.successful_dribbles_away / nullIf(toFloat64(b.dribble_attempts_away), 0),
        1
    ), 0.0)) AS opponent_dribble_success_pct,
    b.ball_possession_home AS triggered_team_possession_pct,
    b.ball_possession_away AS opponent_possession_pct,
    b.total_shots_home AS triggered_team_total_shots,
    b.total_shots_away AS opponent_total_shots,
    b.touches_opposition_box_home AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_away AS opponent_touches_opposition_box,
    b.expected_goals_home AS triggered_team_xg,
    b.expected_goals_away AS opponent_xg,
    toFloat32(round(b.expected_goals_home - b.expected_goals_away, 3)) AS xg_gap
FROM triggered_matches AS b

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
    50 AS trigger_threshold_turnovers,
    b.match_total_turnovers,
    b.match_total_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * b.match_total_turnovers / nullIf(toFloat64(b.match_total_pass_attempts), 0),
        2
    ), 0.0)) AS match_turnovers_per_100_pass_attempts,
    b.turnovers_away AS triggered_team_turnovers,
    b.turnovers_home AS opponent_turnovers,
    toFloat32(coalesce(round(
        100.0 * b.turnovers_away / nullIf(toFloat64(b.match_total_turnovers), 0),
        1
    ), 0.0)) AS triggered_team_turnover_share_pct,
    b.failed_passes_away AS triggered_team_failed_passes,
    b.failed_passes_home AS opponent_failed_passes,
    b.failed_dribbles_away AS triggered_team_failed_dribbles,
    b.failed_dribbles_home AS opponent_failed_dribbles,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.successful_dribbles_away / nullIf(toFloat64(b.dribble_attempts_away), 0),
        1
    ), 0.0)) AS triggered_team_dribble_success_pct,
    toFloat32(coalesce(round(
        100.0 * b.successful_dribbles_home / nullIf(toFloat64(b.dribble_attempts_home), 0),
        1
    ), 0.0)) AS opponent_dribble_success_pct,
    b.ball_possession_away AS triggered_team_possession_pct,
    b.ball_possession_home AS opponent_possession_pct,
    b.total_shots_away AS triggered_team_total_shots,
    b.total_shots_home AS opponent_total_shots,
    b.touches_opposition_box_away AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_home AS opponent_touches_opposition_box,
    b.expected_goals_away AS triggered_team_xg,
    b.expected_goals_home AS opponent_xg,
    toFloat32(round(b.expected_goals_away - b.expected_goals_home, 3)) AS xg_gap
FROM triggered_matches AS b

ORDER BY match_id, triggered_side;
