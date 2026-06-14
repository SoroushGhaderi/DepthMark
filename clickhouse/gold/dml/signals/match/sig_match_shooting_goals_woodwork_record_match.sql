INSERT INTO gold.sig_match_shooting_goals_woodwork_record_match (
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
    trigger_threshold_match_total_shots_woodwork,
    match_total_shots_woodwork,
    match_total_shots_woodwork_above_threshold,
    match_total_goals,
    match_total_xg,
    triggered_team_shots_woodwork,
    opponent_shots_woodwork,
    shots_woodwork_delta,
    triggered_team_shots_woodwork_share_pct,
    opponent_shots_woodwork_share_pct,
    shots_woodwork_share_delta_pct,
    triggered_team_total_shots,
    opponent_total_shots,
    shot_volume_delta,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    shot_on_target_delta,
    triggered_team_shot_accuracy_pct,
    opponent_shot_accuracy_pct,
    shot_accuracy_delta_pct,
    triggered_team_goals,
    opponent_goals,
    goal_gap,
    triggered_team_xg,
    opponent_xg,
    xg_gap,
    triggered_team_goals_minus_xg,
    opponent_goals_minus_xg,
    goals_minus_xg_gap,
    triggered_team_big_chances,
    opponent_big_chances,
    big_chance_delta,
    triggered_team_big_chances_missed,
    opponent_big_chances_missed,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    opposition_box_touch_delta,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct
)
-- Signal: sig_match_shooting_goals_woodwork_record_match
-- Intent: detect extreme woodwork-heavy matches and emit side-oriented rows for
--         bilateral finishing, chance-quality, and territorial-control diagnostics.
-- Trigger: combined match woodwork hits >= 5 in period='All'.
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
        coalesce(ps.big_chances_home, 0) AS big_chances_home,
        coalesce(ps.big_chances_away, 0) AS big_chances_away,
        coalesce(ps.big_chances_missed_home, 0) AS big_chances_missed_home,
        coalesce(ps.big_chances_missed_away, 0) AS big_chances_missed_away,
        coalesce(ps.shots_woodwork_home, 0) AS shots_woodwork_home,
        coalesce(ps.shots_woodwork_away, 0) AS shots_woodwork_away,
        coalesce(ps.touches_opp_box_home, 0) AS touches_opposition_box_home,
        coalesce(ps.touches_opp_box_away, 0) AS touches_opposition_box_away,
        toFloat32(coalesce(ps.ball_possession_home, 0)) AS possession_home_pct,
        toFloat32(coalesce(ps.ball_possession_away, 0)) AS possession_away_pct,
        coalesce(ps.accurate_passes_home, 0) AS accurate_passes_home,
        coalesce(ps.accurate_passes_away, 0) AS accurate_passes_away,
        coalesce(ps.pass_attempts_home, 0) AS pass_attempts_home,
        coalesce(ps.pass_attempts_away, 0) AS pass_attempts_away,
        coalesce(ps.shots_woodwork_home, 0) + coalesce(ps.shots_woodwork_away, 0)
            AS match_total_shots_woodwork,
        coalesce(m.home_score, 0) + coalesce(m.away_score, 0) AS match_total_goals,
        toFloat32(round(
            coalesce(ps.expected_goals_home, 0) + coalesce(ps.expected_goals_away, 0),
            3
        )) AS match_total_xg
    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.match_date = m.match_date
       AND ps.period = 'All'
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND (coalesce(ps.shots_woodwork_home, 0) + coalesce(ps.shots_woodwork_away, 0)) >= 5
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
    toInt32(5) AS trigger_threshold_match_total_shots_woodwork,
    b.match_total_shots_woodwork,
    toInt32(b.match_total_shots_woodwork - 5) AS match_total_shots_woodwork_above_threshold,
    b.match_total_goals,
    b.match_total_xg,
    b.shots_woodwork_home AS triggered_team_shots_woodwork,
    b.shots_woodwork_away AS opponent_shots_woodwork,
    b.shots_woodwork_home - b.shots_woodwork_away AS shots_woodwork_delta,
    toFloat32(coalesce(round(
        100.0 * b.shots_woodwork_home / nullIf(toFloat64(b.match_total_shots_woodwork), 0),
        1
    ), 0.0)) AS triggered_team_shots_woodwork_share_pct,
    toFloat32(coalesce(round(
        100.0 * b.shots_woodwork_away / nullIf(toFloat64(b.match_total_shots_woodwork), 0),
        1
    ), 0.0)) AS opponent_shots_woodwork_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.shots_woodwork_home / nullIf(toFloat64(b.match_total_shots_woodwork), 0),
            1
        ), 0.0)
        - coalesce(round(
            100.0 * b.shots_woodwork_away / nullIf(toFloat64(b.match_total_shots_woodwork), 0),
            1
        ), 0.0),
        1
    )) AS shots_woodwork_share_delta_pct,
    b.total_shots_home AS triggered_team_total_shots,
    b.total_shots_away AS opponent_total_shots,
    b.total_shots_home - b.total_shots_away AS shot_volume_delta,
    b.shots_on_target_home AS triggered_team_shots_on_target,
    b.shots_on_target_away AS opponent_shots_on_target,
    b.shots_on_target_home - b.shots_on_target_away AS shot_on_target_delta,
    toFloat32(coalesce(round(
        100.0 * b.shots_on_target_home / nullIf(toFloat64(b.total_shots_home), 0),
        1
    ), 0.0)) AS triggered_team_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.shots_on_target_away / nullIf(toFloat64(b.total_shots_away), 0),
        1
    ), 0.0)) AS opponent_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.shots_on_target_home / nullIf(toFloat64(b.total_shots_home), 0), 1), 0.0)
        - coalesce(round(100.0 * b.shots_on_target_away / nullIf(toFloat64(b.total_shots_away), 0), 1), 0.0),
        1
    )) AS shot_accuracy_delta_pct,
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
    b.big_chances_home AS triggered_team_big_chances,
    b.big_chances_away AS opponent_big_chances,
    b.big_chances_home - b.big_chances_away AS big_chance_delta,
    b.big_chances_missed_home AS triggered_team_big_chances_missed,
    b.big_chances_missed_away AS opponent_big_chances_missed,
    b.touches_opposition_box_home AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_away AS opponent_touches_opposition_box,
    b.touches_opposition_box_home - b.touches_opposition_box_away AS opposition_box_touch_delta,
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
    )) AS pass_accuracy_delta_pct
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
    toInt32(5) AS trigger_threshold_match_total_shots_woodwork,
    b.match_total_shots_woodwork,
    toInt32(b.match_total_shots_woodwork - 5) AS match_total_shots_woodwork_above_threshold,
    b.match_total_goals,
    b.match_total_xg,
    b.shots_woodwork_away AS triggered_team_shots_woodwork,
    b.shots_woodwork_home AS opponent_shots_woodwork,
    b.shots_woodwork_away - b.shots_woodwork_home AS shots_woodwork_delta,
    toFloat32(coalesce(round(
        100.0 * b.shots_woodwork_away / nullIf(toFloat64(b.match_total_shots_woodwork), 0),
        1
    ), 0.0)) AS triggered_team_shots_woodwork_share_pct,
    toFloat32(coalesce(round(
        100.0 * b.shots_woodwork_home / nullIf(toFloat64(b.match_total_shots_woodwork), 0),
        1
    ), 0.0)) AS opponent_shots_woodwork_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.shots_woodwork_away / nullIf(toFloat64(b.match_total_shots_woodwork), 0),
            1
        ), 0.0)
        - coalesce(round(
            100.0 * b.shots_woodwork_home / nullIf(toFloat64(b.match_total_shots_woodwork), 0),
            1
        ), 0.0),
        1
    )) AS shots_woodwork_share_delta_pct,
    b.total_shots_away AS triggered_team_total_shots,
    b.total_shots_home AS opponent_total_shots,
    b.total_shots_away - b.total_shots_home AS shot_volume_delta,
    b.shots_on_target_away AS triggered_team_shots_on_target,
    b.shots_on_target_home AS opponent_shots_on_target,
    b.shots_on_target_away - b.shots_on_target_home AS shot_on_target_delta,
    toFloat32(coalesce(round(
        100.0 * b.shots_on_target_away / nullIf(toFloat64(b.total_shots_away), 0),
        1
    ), 0.0)) AS triggered_team_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.shots_on_target_home / nullIf(toFloat64(b.total_shots_home), 0),
        1
    ), 0.0)) AS opponent_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.shots_on_target_away / nullIf(toFloat64(b.total_shots_away), 0), 1), 0.0)
        - coalesce(round(100.0 * b.shots_on_target_home / nullIf(toFloat64(b.total_shots_home), 0), 1), 0.0),
        1
    )) AS shot_accuracy_delta_pct,
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
    b.big_chances_away AS triggered_team_big_chances,
    b.big_chances_home AS opponent_big_chances,
    b.big_chances_away - b.big_chances_home AS big_chance_delta,
    b.big_chances_missed_away AS triggered_team_big_chances_missed,
    b.big_chances_missed_home AS opponent_big_chances_missed,
    b.touches_opposition_box_away AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_home AS opponent_touches_opposition_box,
    b.touches_opposition_box_away - b.touches_opposition_box_home AS opposition_box_touch_delta,
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
    )) AS pass_accuracy_delta_pct
FROM base_stats AS b

ORDER BY
    match_total_shots_woodwork DESC,
    match_date DESC,
    match_id DESC,
    triggered_side;
