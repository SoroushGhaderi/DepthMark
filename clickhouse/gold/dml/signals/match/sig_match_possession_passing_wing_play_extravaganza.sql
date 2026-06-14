INSERT INTO gold.sig_match_possession_passing_wing_play_extravaganza (
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
    match_total_cross_attempts,
    match_total_accurate_crosses,
    match_cross_accuracy_pct,
    triggered_team_cross_attempts,
    opponent_cross_attempts,
    triggered_team_accurate_crosses,
    opponent_accurate_crosses,
    triggered_team_cross_share_pct,
    opponent_cross_share_pct,
    triggered_team_cross_accuracy_pct,
    opponent_cross_accuracy_pct,
    triggered_team_crosses_per_shot,
    opponent_crosses_per_shot,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_xg,
    opponent_xg,
    xg_gap
)
-- ============================================================
-- Signal: sig_match_possession_passing_wing_play_extravaganza
-- Intent: Detect matches with exceptionally high combined crossing volume
--         and expose bilateral side-oriented context for wing-led game states.
-- Trigger: Combined total crosses in a match > 60 at period='All'.
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
        coalesce(ps.cross_attempts_home, 0) AS cross_attempts_home,
        coalesce(ps.cross_attempts_away, 0) AS cross_attempts_away,
        coalesce(ps.accurate_crosses_home, 0) AS accurate_crosses_home,
        coalesce(ps.accurate_crosses_away, 0) AS accurate_crosses_away,
        coalesce(ps.pass_attempts_home, 0) AS pass_attempts_home,
        coalesce(ps.pass_attempts_away, 0) AS pass_attempts_away,
        toFloat32(coalesce(ps.ball_possession_home, 0)) AS ball_possession_home,
        toFloat32(coalesce(ps.ball_possession_away, 0)) AS ball_possession_away,
        coalesce(ps.total_shots_home, 0) AS total_shots_home,
        coalesce(ps.total_shots_away, 0) AS total_shots_away,
        toFloat32(coalesce(ps.expected_goals_home, 0)) AS expected_goals_home,
        toFloat32(coalesce(ps.expected_goals_away, 0)) AS expected_goals_away,
        coalesce(ps.cross_attempts_home, 0) + coalesce(ps.cross_attempts_away, 0) AS match_total_cross_attempts,
        coalesce(ps.accurate_crosses_home, 0) + coalesce(ps.accurate_crosses_away, 0) AS match_total_accurate_crosses,
        toFloat32(round(
            100.0 * (
                coalesce(ps.accurate_crosses_home, 0) + coalesce(ps.accurate_crosses_away, 0)
            ) / nullIf(
                toFloat64(coalesce(ps.cross_attempts_home, 0) + coalesce(ps.cross_attempts_away, 0)),
                0
            ),
            1
        )) AS match_cross_accuracy_pct
    FROM silver.match AS m FINAL
    INNER JOIN silver.period_stat AS ps FINAL
        ON  ps.match_id = m.match_id
        AND ps.period = 'All'
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND (coalesce(ps.cross_attempts_home, 0) + coalesce(ps.cross_attempts_away, 0)) > 60
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
    b.match_total_cross_attempts,
    b.match_total_accurate_crosses,
    b.match_cross_accuracy_pct,
    b.cross_attempts_home AS triggered_team_cross_attempts,
    b.cross_attempts_away AS opponent_cross_attempts,
    b.accurate_crosses_home AS triggered_team_accurate_crosses,
    b.accurate_crosses_away AS opponent_accurate_crosses,
    toFloat32(round(
        100.0 * b.cross_attempts_home / nullIf(toFloat64(b.match_total_cross_attempts), 0),
        1
    )) AS triggered_team_cross_share_pct,
    toFloat32(round(
        100.0 * b.cross_attempts_away / nullIf(toFloat64(b.match_total_cross_attempts), 0),
        1
    )) AS opponent_cross_share_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_crosses_home / nullIf(toFloat64(b.cross_attempts_home), 0),
        1
    ), 0.0)) AS triggered_team_cross_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_crosses_away / nullIf(toFloat64(b.cross_attempts_away), 0),
        1
    ), 0.0)) AS opponent_cross_accuracy_pct,
    toFloat32(round(
        b.cross_attempts_home / nullIf(toFloat64(b.total_shots_home), 0),
        2
    )) AS triggered_team_crosses_per_shot,
    toFloat32(round(
        b.cross_attempts_away / nullIf(toFloat64(b.total_shots_away), 0),
        2
    )) AS opponent_crosses_per_shot,
    b.pass_attempts_home AS triggered_team_pass_attempts,
    b.pass_attempts_away AS opponent_pass_attempts,
    b.ball_possession_home AS triggered_team_possession_pct,
    b.ball_possession_away AS opponent_possession_pct,
    b.total_shots_home AS triggered_team_total_shots,
    b.total_shots_away AS opponent_total_shots,
    b.expected_goals_home AS triggered_team_xg,
    b.expected_goals_away AS opponent_xg,
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
    b.match_total_cross_attempts,
    b.match_total_accurate_crosses,
    b.match_cross_accuracy_pct,
    b.cross_attempts_away AS triggered_team_cross_attempts,
    b.cross_attempts_home AS opponent_cross_attempts,
    b.accurate_crosses_away AS triggered_team_accurate_crosses,
    b.accurate_crosses_home AS opponent_accurate_crosses,
    toFloat32(round(
        100.0 * b.cross_attempts_away / nullIf(toFloat64(b.match_total_cross_attempts), 0),
        1
    )) AS triggered_team_cross_share_pct,
    toFloat32(round(
        100.0 * b.cross_attempts_home / nullIf(toFloat64(b.match_total_cross_attempts), 0),
        1
    )) AS opponent_cross_share_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_crosses_away / nullIf(toFloat64(b.cross_attempts_away), 0),
        1
    ), 0.0)) AS triggered_team_cross_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_crosses_home / nullIf(toFloat64(b.cross_attempts_home), 0),
        1
    ), 0.0)) AS opponent_cross_accuracy_pct,
    toFloat32(round(
        b.cross_attempts_away / nullIf(toFloat64(b.total_shots_away), 0),
        2
    )) AS triggered_team_crosses_per_shot,
    toFloat32(round(
        b.cross_attempts_home / nullIf(toFloat64(b.total_shots_home), 0),
        2
    )) AS opponent_crosses_per_shot,
    b.pass_attempts_away AS triggered_team_pass_attempts,
    b.pass_attempts_home AS opponent_pass_attempts,
    b.ball_possession_away AS triggered_team_possession_pct,
    b.ball_possession_home AS opponent_possession_pct,
    b.total_shots_away AS triggered_team_total_shots,
    b.total_shots_home AS opponent_total_shots,
    b.expected_goals_away AS triggered_team_xg,
    b.expected_goals_home AS opponent_xg,
    toFloat32(round(b.expected_goals_away - b.expected_goals_home, 3)) AS xg_gap
FROM base_stats AS b

ORDER BY match_id, triggered_side;
