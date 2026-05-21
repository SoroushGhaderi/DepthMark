INSERT INTO gold.sig_match_shooting_goals_box_siege_match (
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
    trigger_threshold_match_total_touches_opposition_box_exclusive,
    match_total_touches_opposition_box,
    match_total_shots,
    match_total_shots_on_target,
    match_total_shot_accuracy_pct,
    match_total_xg,
    match_total_goals,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    opposition_box_touch_delta,
    triggered_team_touches_opposition_box_share_pct,
    opponent_touches_opposition_box_share_pct,
    opposition_box_touch_share_delta_pct,
    triggered_team_total_shots,
    opponent_total_shots,
    shot_volume_delta,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    shot_on_target_delta,
    triggered_team_shot_accuracy_pct,
    opponent_shot_accuracy_pct,
    shot_accuracy_delta_pct,
    triggered_team_shot_conversion_pct,
    opponent_shot_conversion_pct,
    shot_conversion_delta_pct,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_big_chances,
    opponent_big_chances,
    big_chance_delta,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    pass_attempt_delta,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_corners,
    opponent_corners,
    corner_delta
)
-- Signal: sig_match_shooting_goals_box_siege_match
-- Intent: detect finished matches with extreme combined opposition-box touches and emit
--         side-oriented bilateral shooting and control context for box-pressure diagnostics.
-- Trigger: combined opposition-box touches > 80 in period='All'.
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
        coalesce(ps.touches_opp_box_home, 0) AS touches_opposition_box_home,
        coalesce(ps.touches_opp_box_away, 0) AS touches_opposition_box_away,
        coalesce(ps.total_shots_home, 0) AS total_shots_home,
        coalesce(ps.total_shots_away, 0) AS total_shots_away,
        coalesce(ps.shots_on_target_home, 0) AS shots_on_target_home,
        coalesce(ps.shots_on_target_away, 0) AS shots_on_target_away,
        toFloat32(coalesce(ps.expected_goals_home, 0)) AS expected_goals_home,
        toFloat32(coalesce(ps.expected_goals_away, 0)) AS expected_goals_away,
        coalesce(ps.big_chances_home, 0) AS big_chances_home,
        coalesce(ps.big_chances_away, 0) AS big_chances_away,
        toFloat32(coalesce(ps.ball_possession_home, 0)) AS possession_home_pct,
        toFloat32(coalesce(ps.ball_possession_away, 0)) AS possession_away_pct,
        coalesce(ps.pass_attempts_home, 0) AS pass_attempts_home,
        coalesce(ps.pass_attempts_away, 0) AS pass_attempts_away,
        coalesce(ps.accurate_passes_home, 0) AS accurate_passes_home,
        coalesce(ps.accurate_passes_away, 0) AS accurate_passes_away,
        coalesce(ps.corners_home, 0) AS corners_home,
        coalesce(ps.corners_away, 0) AS corners_away,
        coalesce(ps.touches_opp_box_home, 0) + coalesce(ps.touches_opp_box_away, 0)
            AS match_total_touches_opposition_box,
        coalesce(ps.total_shots_home, 0) + coalesce(ps.total_shots_away, 0) AS match_total_shots,
        coalesce(ps.shots_on_target_home, 0) + coalesce(ps.shots_on_target_away, 0)
            AS match_total_shots_on_target,
        toFloat32(round(
            coalesce(ps.expected_goals_home, 0) + coalesce(ps.expected_goals_away, 0),
            3
        )) AS match_total_xg,
        coalesce(m.home_score, 0) + coalesce(m.away_score, 0) AS match_total_goals
    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.match_date = m.match_date
       AND ps.period = 'All'
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND (coalesce(ps.touches_opp_box_home, 0) + coalesce(ps.touches_opp_box_away, 0)) > 80
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
    toInt32(80) AS trigger_threshold_match_total_touches_opposition_box_exclusive,
    b.match_total_touches_opposition_box,
    b.match_total_shots,
    b.match_total_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * b.match_total_shots_on_target / nullIf(toFloat64(b.match_total_shots), 0),
        1
    ), 0.0)) AS match_total_shot_accuracy_pct,
    b.match_total_xg,
    b.match_total_goals,
    b.touches_opposition_box_home AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_away AS opponent_touches_opposition_box,
    b.touches_opposition_box_home - b.touches_opposition_box_away AS opposition_box_touch_delta,
    toFloat32(coalesce(round(
        100.0 * b.touches_opposition_box_home
        / nullIf(toFloat64(b.match_total_touches_opposition_box), 0),
        1
    ), 0.0)) AS triggered_team_touches_opposition_box_share_pct,
    toFloat32(coalesce(round(
        100.0 * b.touches_opposition_box_away
        / nullIf(toFloat64(b.match_total_touches_opposition_box), 0),
        1
    ), 0.0)) AS opponent_touches_opposition_box_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.touches_opposition_box_home
            / nullIf(toFloat64(b.match_total_touches_opposition_box), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * b.touches_opposition_box_away
            / nullIf(toFloat64(b.match_total_touches_opposition_box), 0),
            1
        ), 0.0),
        1
    )) AS opposition_box_touch_share_delta_pct,
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
    toFloat32(coalesce(round(
        100.0 * b.home_goals / nullIf(toFloat64(b.total_shots_home), 0),
        1
    ), 0.0)) AS triggered_team_shot_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * b.away_goals / nullIf(toFloat64(b.total_shots_away), 0),
        1
    ), 0.0)) AS opponent_shot_conversion_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.home_goals / nullIf(toFloat64(b.total_shots_home), 0), 1), 0.0)
        - coalesce(round(100.0 * b.away_goals / nullIf(toFloat64(b.total_shots_away), 0), 1), 0.0),
        1
    )) AS shot_conversion_delta_pct,
    b.expected_goals_home AS triggered_team_xg,
    b.expected_goals_away AS opponent_xg,
    toFloat32(round(b.expected_goals_home - b.expected_goals_away, 3)) AS xg_delta,
    b.big_chances_home AS triggered_team_big_chances,
    b.big_chances_away AS opponent_big_chances,
    b.big_chances_home - b.big_chances_away AS big_chance_delta,
    b.possession_home_pct AS triggered_team_possession_pct,
    b.possession_away_pct AS opponent_possession_pct,
    toFloat32(round(b.possession_home_pct - b.possession_away_pct, 1)) AS possession_delta_pct,
    b.pass_attempts_home AS triggered_team_pass_attempts,
    b.pass_attempts_away AS opponent_pass_attempts,
    b.pass_attempts_home - b.pass_attempts_away AS pass_attempt_delta,
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
    )) AS pass_accuracy_delta_pct,
    b.corners_home AS triggered_team_corners,
    b.corners_away AS opponent_corners,
    b.corners_home - b.corners_away AS corner_delta
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
    toInt32(80) AS trigger_threshold_match_total_touches_opposition_box_exclusive,
    b.match_total_touches_opposition_box,
    b.match_total_shots,
    b.match_total_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * b.match_total_shots_on_target / nullIf(toFloat64(b.match_total_shots), 0),
        1
    ), 0.0)) AS match_total_shot_accuracy_pct,
    b.match_total_xg,
    b.match_total_goals,
    b.touches_opposition_box_away AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_home AS opponent_touches_opposition_box,
    b.touches_opposition_box_away - b.touches_opposition_box_home AS opposition_box_touch_delta,
    toFloat32(coalesce(round(
        100.0 * b.touches_opposition_box_away
        / nullIf(toFloat64(b.match_total_touches_opposition_box), 0),
        1
    ), 0.0)) AS triggered_team_touches_opposition_box_share_pct,
    toFloat32(coalesce(round(
        100.0 * b.touches_opposition_box_home
        / nullIf(toFloat64(b.match_total_touches_opposition_box), 0),
        1
    ), 0.0)) AS opponent_touches_opposition_box_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.touches_opposition_box_away
            / nullIf(toFloat64(b.match_total_touches_opposition_box), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * b.touches_opposition_box_home
            / nullIf(toFloat64(b.match_total_touches_opposition_box), 0),
            1
        ), 0.0),
        1
    )) AS opposition_box_touch_share_delta_pct,
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
    toFloat32(coalesce(round(
        100.0 * b.away_goals / nullIf(toFloat64(b.total_shots_away), 0),
        1
    ), 0.0)) AS triggered_team_shot_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * b.home_goals / nullIf(toFloat64(b.total_shots_home), 0),
        1
    ), 0.0)) AS opponent_shot_conversion_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.away_goals / nullIf(toFloat64(b.total_shots_away), 0), 1), 0.0)
        - coalesce(round(100.0 * b.home_goals / nullIf(toFloat64(b.total_shots_home), 0), 1), 0.0),
        1
    )) AS shot_conversion_delta_pct,
    b.expected_goals_away AS triggered_team_xg,
    b.expected_goals_home AS opponent_xg,
    toFloat32(round(b.expected_goals_away - b.expected_goals_home, 3)) AS xg_delta,
    b.big_chances_away AS triggered_team_big_chances,
    b.big_chances_home AS opponent_big_chances,
    b.big_chances_away - b.big_chances_home AS big_chance_delta,
    b.possession_away_pct AS triggered_team_possession_pct,
    b.possession_home_pct AS opponent_possession_pct,
    toFloat32(round(b.possession_away_pct - b.possession_home_pct, 1)) AS possession_delta_pct,
    b.pass_attempts_away AS triggered_team_pass_attempts,
    b.pass_attempts_home AS opponent_pass_attempts,
    b.pass_attempts_away - b.pass_attempts_home AS pass_attempt_delta,
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
    )) AS pass_accuracy_delta_pct,
    b.corners_away AS triggered_team_corners,
    b.corners_home AS opponent_corners,
    b.corners_away - b.corners_home AS corner_delta
FROM base_stats AS b;
