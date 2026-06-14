INSERT INTO gold.sig_match_possession_passing_early_tactical_lock (
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
    match_first_30_total_shots_on_target,
    triggered_team_first_30_shots_on_target,
    opponent_first_30_shots_on_target,
    match_first_30_total_shots,
    triggered_team_first_30_total_shots,
    opponent_first_30_total_shots,
    match_first_30_first_shot_minute,
    triggered_team_first_30_first_shot_minute,
    opponent_first_30_first_shot_minute,
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
    opponent_touches_opposition_box,
    triggered_team_xg,
    opponent_xg,
    xg_gap
)
-- ============================================================
-- Signal: sig_match_possession_passing_early_tactical_lock
-- Intent: Detect matches where both teams are kept off-target in the
--         opening tactical phase, then emit symmetric side-oriented rows.
-- Trigger: No shots on target for either team in the first 30 minutes
--          of play (`silver.shot.minute <= 30`).
-- ============================================================

WITH first_30_shot_context AS (
    SELECT
        m.match_id AS match_id,
        toInt32(countIf(
            coalesce(s.is_on_target, 0) = 1
            AND s.team_id = m.home_team_id
        )) AS home_first_30_shots_on_target,
        toInt32(countIf(
            coalesce(s.is_on_target, 0) = 1
            AND s.team_id = m.away_team_id
        )) AS away_first_30_shots_on_target,
        toInt32(countIf(s.team_id = m.home_team_id)) AS home_first_30_total_shots,
        toInt32(countIf(s.team_id = m.away_team_id)) AS away_first_30_total_shots,
        nullIf(
            minIf(
                toInt32(coalesce(s.minute, 0)),
                s.team_id = m.home_team_id
                AND s.minute IS NOT NULL
            ),
            0
        ) AS home_first_30_first_shot_minute,
        nullIf(
            minIf(
                toInt32(coalesce(s.minute, 0)),
                s.team_id = m.away_team_id
                AND s.minute IS NOT NULL
            ),
            0
        ) AS away_first_30_first_shot_minute,
        nullIf(
            minIf(
                toInt32(coalesce(s.minute, 0)),
                s.minute IS NOT NULL
            ),
            0
        ) AS match_first_30_first_shot_minute
    FROM silver.match AS m FINAL
    LEFT JOIN silver.shot AS s FINAL
        ON s.match_id = m.match_id
       AND s.minute IS NOT NULL
       AND s.minute <= 30
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
        toFloat32(coalesce(ps.expected_goals_home, 0)) AS expected_goals_home,
        toFloat32(coalesce(ps.expected_goals_away, 0)) AS expected_goals_away,
        f.home_first_30_shots_on_target AS home_first_30_shots_on_target,
        f.away_first_30_shots_on_target AS away_first_30_shots_on_target,
        f.home_first_30_total_shots AS home_first_30_total_shots,
        f.away_first_30_total_shots AS away_first_30_total_shots,
        f.home_first_30_first_shot_minute AS home_first_30_first_shot_minute,
        f.away_first_30_first_shot_minute AS away_first_30_first_shot_minute,
        f.match_first_30_first_shot_minute AS match_first_30_first_shot_minute
    FROM silver.match AS m FINAL
    INNER JOIN silver.period_stat AS ps FINAL
        ON ps.match_id = m.match_id
       AND ps.period = 'All'
    INNER JOIN first_30_shot_context AS f
        ON f.match_id = m.match_id
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND f.home_first_30_shots_on_target = 0
      AND f.away_first_30_shots_on_target = 0
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
    30 AS trigger_window_minutes,
    (b.home_first_30_shots_on_target + b.away_first_30_shots_on_target) AS match_first_30_total_shots_on_target,
    b.home_first_30_shots_on_target AS triggered_team_first_30_shots_on_target,
    b.away_first_30_shots_on_target AS opponent_first_30_shots_on_target,
    (b.home_first_30_total_shots + b.away_first_30_total_shots) AS match_first_30_total_shots,
    b.home_first_30_total_shots AS triggered_team_first_30_total_shots,
    b.away_first_30_total_shots AS opponent_first_30_total_shots,
    b.match_first_30_first_shot_minute AS match_first_30_first_shot_minute,
    b.home_first_30_first_shot_minute AS triggered_team_first_30_first_shot_minute,
    b.away_first_30_first_shot_minute AS opponent_first_30_first_shot_minute,
    b.total_shots_home AS triggered_team_total_shots,
    b.total_shots_away AS opponent_total_shots,
    b.shots_on_target_home AS triggered_team_shots_on_target,
    b.shots_on_target_away AS opponent_shots_on_target,
    b.pass_attempts_home AS triggered_team_pass_attempts,
    b.pass_attempts_away AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    b.ball_possession_home AS triggered_team_possession_pct,
    b.ball_possession_away AS opponent_possession_pct,
    b.opposition_half_passes_home AS triggered_team_opposition_half_passes,
    b.opposition_half_passes_away AS opponent_opposition_half_passes,
    b.touches_opposition_box_home AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_away AS opponent_touches_opposition_box,
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
    30 AS trigger_window_minutes,
    (b.home_first_30_shots_on_target + b.away_first_30_shots_on_target) AS match_first_30_total_shots_on_target,
    b.away_first_30_shots_on_target AS triggered_team_first_30_shots_on_target,
    b.home_first_30_shots_on_target AS opponent_first_30_shots_on_target,
    (b.home_first_30_total_shots + b.away_first_30_total_shots) AS match_first_30_total_shots,
    b.away_first_30_total_shots AS triggered_team_first_30_total_shots,
    b.home_first_30_total_shots AS opponent_first_30_total_shots,
    b.match_first_30_first_shot_minute AS match_first_30_first_shot_minute,
    b.away_first_30_first_shot_minute AS triggered_team_first_30_first_shot_minute,
    b.home_first_30_first_shot_minute AS opponent_first_30_first_shot_minute,
    b.total_shots_away AS triggered_team_total_shots,
    b.total_shots_home AS opponent_total_shots,
    b.shots_on_target_away AS triggered_team_shots_on_target,
    b.shots_on_target_home AS opponent_shots_on_target,
    b.pass_attempts_away AS triggered_team_pass_attempts,
    b.pass_attempts_home AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    b.ball_possession_away AS triggered_team_possession_pct,
    b.ball_possession_home AS opponent_possession_pct,
    b.opposition_half_passes_away AS triggered_team_opposition_half_passes,
    b.opposition_half_passes_home AS opponent_opposition_half_passes,
    b.touches_opposition_box_away AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_home AS opponent_touches_opposition_box,
    b.expected_goals_away AS triggered_team_xg,
    b.expected_goals_home AS opponent_xg,
    toFloat32(round(b.expected_goals_away - b.expected_goals_home, 3)) AS xg_gap
FROM base_stats AS b

ORDER BY match_id, triggered_side;
