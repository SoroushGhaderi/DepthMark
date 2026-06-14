INSERT INTO gold.sig_team_possession_passing_dribble_heavy_attack (
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
    trigger_threshold_dribble_attempts,
    both_sides_triggered,
    triggered_team_dribble_attempts,
    opponent_dribble_attempts,
    dribble_attempts_delta,
    triggered_team_successful_dribbles,
    opponent_successful_dribbles,
    triggered_team_dribble_success_pct,
    opponent_dribble_success_pct,
    dribble_success_delta_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_xg,
    opponent_xg,
    xg_delta
)
-- ============================================================
-- Signal: sig_team_possession_passing_dribble_heavy_attack
-- Intent: Detect team-level attack phases where one side repeatedly
--         carries the ball and attempts many dribbles.
-- Trigger: Team dribble attempts >= 25 at period='All'.
-- ============================================================

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
        coalesce(ps.dribble_attempts_home, 0) AS dribble_attempts_home,
        coalesce(ps.dribble_attempts_away, 0) AS dribble_attempts_away,
        coalesce(ps.dribbles_succeeded_home, 0) AS successful_dribbles_home,
        coalesce(ps.dribbles_succeeded_away, 0) AS successful_dribbles_away,
        coalesce(ps.pass_attempts_home, 0) AS pass_attempts_home,
        coalesce(ps.pass_attempts_away, 0) AS pass_attempts_away,
        coalesce(ps.accurate_passes_home, 0) AS accurate_passes_home,
        coalesce(ps.accurate_passes_away, 0) AS accurate_passes_away,
        toFloat32(coalesce(ps.ball_possession_home, 0)) AS ball_possession_home,
        toFloat32(coalesce(ps.ball_possession_away, 0)) AS ball_possession_away,
        coalesce(ps.touches_opp_box_home, 0) AS touches_opposition_box_home,
        coalesce(ps.touches_opp_box_away, 0) AS touches_opposition_box_away,
        coalesce(ps.total_shots_home, 0) AS total_shots_home,
        coalesce(ps.total_shots_away, 0) AS total_shots_away,
        toFloat32(coalesce(ps.expected_goals_home, 0)) AS expected_goals_home,
        toFloat32(coalesce(ps.expected_goals_away, 0)) AS expected_goals_away
    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.period = 'All'
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND (
          coalesce(ps.dribble_attempts_home, 0) >= 25
          OR coalesce(ps.dribble_attempts_away, 0) >= 25
      )
),
triggered_rows AS (
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
        25 AS trigger_threshold_dribble_attempts,
        toUInt8(b.dribble_attempts_home >= 25 AND b.dribble_attempts_away >= 25) AS both_sides_triggered,
        b.dribble_attempts_home AS triggered_team_dribble_attempts,
        b.dribble_attempts_away AS opponent_dribble_attempts,
        b.successful_dribbles_home AS triggered_team_successful_dribbles,
        b.successful_dribbles_away AS opponent_successful_dribbles,
        b.pass_attempts_home AS triggered_team_pass_attempts,
        b.pass_attempts_away AS opponent_pass_attempts,
        b.accurate_passes_home AS triggered_team_accurate_passes,
        b.accurate_passes_away AS opponent_accurate_passes,
        b.ball_possession_home AS triggered_team_possession_pct,
        b.ball_possession_away AS opponent_possession_pct,
        b.touches_opposition_box_home AS triggered_team_touches_opposition_box,
        b.touches_opposition_box_away AS opponent_touches_opposition_box,
        b.total_shots_home AS triggered_team_total_shots,
        b.total_shots_away AS opponent_total_shots,
        b.expected_goals_home AS triggered_team_xg,
        b.expected_goals_away AS opponent_xg
    FROM base_stats AS b
    WHERE b.dribble_attempts_home >= 25

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
        25 AS trigger_threshold_dribble_attempts,
        toUInt8(b.dribble_attempts_home >= 25 AND b.dribble_attempts_away >= 25) AS both_sides_triggered,
        b.dribble_attempts_away AS triggered_team_dribble_attempts,
        b.dribble_attempts_home AS opponent_dribble_attempts,
        b.successful_dribbles_away AS triggered_team_successful_dribbles,
        b.successful_dribbles_home AS opponent_successful_dribbles,
        b.pass_attempts_away AS triggered_team_pass_attempts,
        b.pass_attempts_home AS opponent_pass_attempts,
        b.accurate_passes_away AS triggered_team_accurate_passes,
        b.accurate_passes_home AS opponent_accurate_passes,
        b.ball_possession_away AS triggered_team_possession_pct,
        b.ball_possession_home AS opponent_possession_pct,
        b.touches_opposition_box_away AS triggered_team_touches_opposition_box,
        b.touches_opposition_box_home AS opponent_touches_opposition_box,
        b.total_shots_away AS triggered_team_total_shots,
        b.total_shots_home AS opponent_total_shots,
        b.expected_goals_away AS triggered_team_xg,
        b.expected_goals_home AS opponent_xg
    FROM base_stats AS b
    WHERE b.dribble_attempts_away >= 25
)

SELECT
    t.match_id,
    t.match_date,
    t.home_team_id,
    t.home_team_name,
    t.away_team_id,
    t.away_team_name,
    t.home_score,
    t.away_score,
    t.triggered_side,
    t.triggered_team_id,
    t.triggered_team_name,
    t.opponent_team_id,
    t.opponent_team_name,
    t.trigger_threshold_dribble_attempts,
    t.both_sides_triggered,
    t.triggered_team_dribble_attempts,
    t.opponent_dribble_attempts,
    t.triggered_team_dribble_attempts - t.opponent_dribble_attempts AS dribble_attempts_delta,
    t.triggered_team_successful_dribbles,
    t.opponent_successful_dribbles,
    toFloat32(coalesce(round(
        100.0 * t.triggered_team_successful_dribbles / nullIf(toFloat64(t.triggered_team_dribble_attempts), 0),
        1
    ), 0.0)) AS triggered_team_dribble_success_pct,
    toFloat32(coalesce(round(
        100.0 * t.opponent_successful_dribbles / nullIf(toFloat64(t.opponent_dribble_attempts), 0),
        1
    ), 0.0)) AS opponent_dribble_success_pct,
    toFloat32(round(
        coalesce(
            100.0 * t.triggered_team_successful_dribbles / nullIf(toFloat64(t.triggered_team_dribble_attempts), 0),
            0.0
        )
        -
        coalesce(
            100.0 * t.opponent_successful_dribbles / nullIf(toFloat64(t.opponent_dribble_attempts), 0),
            0.0
        ),
        1
    )) AS dribble_success_delta_pct,
    t.triggered_team_pass_attempts,
    t.opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * t.triggered_team_accurate_passes / nullIf(toFloat64(t.triggered_team_pass_attempts), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * t.opponent_accurate_passes / nullIf(toFloat64(t.opponent_pass_attempts), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(
            100.0 * t.triggered_team_accurate_passes / nullIf(toFloat64(t.triggered_team_pass_attempts), 0),
            0.0
        )
        -
        coalesce(
            100.0 * t.opponent_accurate_passes / nullIf(toFloat64(t.opponent_pass_attempts), 0),
            0.0
        ),
        1
    )) AS pass_accuracy_delta_pct,
    t.triggered_team_possession_pct,
    t.opponent_possession_pct,
    toFloat32(round(t.triggered_team_possession_pct - t.opponent_possession_pct, 1)) AS possession_delta_pct,
    t.triggered_team_touches_opposition_box,
    t.opponent_touches_opposition_box,
    t.triggered_team_total_shots,
    t.opponent_total_shots,
    t.triggered_team_xg,
    t.opponent_xg,
    toFloat32(round(t.triggered_team_xg - t.opponent_xg, 3)) AS xg_delta
FROM triggered_rows AS t
ORDER BY t.match_id, t.triggered_side;
