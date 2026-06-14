INSERT INTO gold.sig_match_shooting_goals_distance_shooting_duel (
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
    trigger_threshold_min_outside_box_goals_per_team,
    both_teams_scored_outside_box_flag,
    home_outside_box_goals,
    away_outside_box_goals,
    match_total_outside_box_goals,
    match_total_outside_box_xg,
    triggered_team_outside_box_goals,
    opponent_outside_box_goals,
    outside_box_goals_delta,
    triggered_team_outside_box_xg,
    opponent_outside_box_xg,
    outside_box_xg_delta,
    triggered_team_outside_box_shots,
    opponent_outside_box_shots,
    outside_box_shot_volume_delta,
    triggered_team_outside_box_shots_on_target,
    opponent_outside_box_shots_on_target,
    outside_box_shots_on_target_delta,
    triggered_team_outside_box_shot_accuracy_pct,
    opponent_outside_box_shot_accuracy_pct,
    outside_box_shot_accuracy_delta_pct,
    triggered_team_outside_box_goal_conversion_pct,
    opponent_outside_box_goal_conversion_pct,
    outside_box_goal_conversion_delta_pct,
    triggered_team_goals,
    opponent_goals,
    goal_gap,
    triggered_team_total_shots,
    opponent_total_shots,
    shot_volume_delta,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    shot_on_target_delta,
    triggered_team_shot_accuracy_pct,
    opponent_shot_accuracy_pct,
    shot_accuracy_delta_pct,
    triggered_team_xg,
    opponent_xg,
    xg_gap,
    triggered_team_big_chances,
    opponent_big_chances,
    big_chance_delta,
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
-- Signal: sig_match_shooting_goals_distance_shooting_duel
-- Intent: detect matches where both teams score from outside the penalty area, then emit
--         side-oriented long-range finishing and chance-quality context.
-- Trigger: home outside-box goals >= 1 AND away outside-box goals >= 1 in finished matches at period='All'.
WITH outside_box_team_stats AS (
    SELECT
        s.match_id,
        toInt32(s.team_id) AS team_id,
        toInt32(count()) AS team_outside_box_shots,
        toInt32(sum(if(coalesce(s.is_on_target, 0) = 1, 1, 0))) AS team_outside_box_shots_on_target,
        toInt32(sum(if(coalesce(s.is_goal, 0) = 1 AND coalesce(s.is_own_goal, 0) = 0, 1, 0)))
            AS team_outside_box_goals,
        toFloat32(round(sum(coalesce(s.expected_goals, 0.0)), 3)) AS team_outside_box_xg
    FROM silver.shot AS s
    WHERE coalesce(s.team_id, 0) > 0
      AND coalesce(s.is_from_inside_box, 1) = 0
      AND coalesce(s.is_own_goal, 0) = 0
    GROUP BY
        s.match_id,
        toInt32(s.team_id)
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
        coalesce(m.home_score, 0) AS home_goals,
        coalesce(m.away_score, 0) AS away_goals,
        coalesce(ps.total_shots_home, 0) AS total_shots_home,
        coalesce(ps.total_shots_away, 0) AS total_shots_away,
        coalesce(ps.shots_on_target_home, 0) AS shots_on_target_home,
        coalesce(ps.shots_on_target_away, 0) AS shots_on_target_away,
        toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS expected_goals_home,
        toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS expected_goals_away,
        coalesce(ps.big_chances_home, 0) AS big_chances_home,
        coalesce(ps.big_chances_away, 0) AS big_chances_away,
        coalesce(ps.touches_opp_box_home, 0) AS touches_opposition_box_home,
        coalesce(ps.touches_opp_box_away, 0) AS touches_opposition_box_away,
        toFloat32(coalesce(ps.ball_possession_home, 0)) AS possession_home_pct,
        toFloat32(coalesce(ps.ball_possession_away, 0)) AS possession_away_pct,
        coalesce(ps.accurate_passes_home, 0) AS accurate_passes_home,
        coalesce(ps.accurate_passes_away, 0) AS accurate_passes_away,
        coalesce(ps.pass_attempts_home, 0) AS pass_attempts_home,
        coalesce(ps.pass_attempts_away, 0) AS pass_attempts_away,
        coalesce(home_ob.team_outside_box_goals, 0) AS home_outside_box_goals,
        coalesce(away_ob.team_outside_box_goals, 0) AS away_outside_box_goals,
        coalesce(home_ob.team_outside_box_shots, 0) AS home_outside_box_shots,
        coalesce(away_ob.team_outside_box_shots, 0) AS away_outside_box_shots,
        coalesce(home_ob.team_outside_box_shots_on_target, 0) AS home_outside_box_shots_on_target,
        coalesce(away_ob.team_outside_box_shots_on_target, 0) AS away_outside_box_shots_on_target,
        toFloat32(coalesce(home_ob.team_outside_box_xg, 0.0)) AS home_outside_box_xg,
        toFloat32(coalesce(away_ob.team_outside_box_xg, 0.0)) AS away_outside_box_xg,
        toFloat32(round(
            coalesce(home_ob.team_outside_box_xg, 0.0) + coalesce(away_ob.team_outside_box_xg, 0.0),
            3
        )) AS match_total_outside_box_xg,
        coalesce(home_ob.team_outside_box_goals, 0) + coalesce(away_ob.team_outside_box_goals, 0)
            AS match_total_outside_box_goals
    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.match_date = m.match_date
       AND ps.period = 'All'
    LEFT JOIN outside_box_team_stats AS home_ob
        ON home_ob.match_id = m.match_id
       AND home_ob.team_id = m.home_team_id
    LEFT JOIN outside_box_team_stats AS away_ob
        ON away_ob.match_id = m.match_id
       AND away_ob.team_id = m.away_team_id
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND coalesce(home_ob.team_outside_box_goals, 0) >= 1
      AND coalesce(away_ob.team_outside_box_goals, 0) >= 1
)

-- Home-side row.
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
    toInt32(1) AS trigger_threshold_min_outside_box_goals_per_team,
    toInt8(1) AS both_teams_scored_outside_box_flag,
    b.home_outside_box_goals,
    b.away_outside_box_goals,
    b.match_total_outside_box_goals,
    b.match_total_outside_box_xg,
    b.home_outside_box_goals AS triggered_team_outside_box_goals,
    b.away_outside_box_goals AS opponent_outside_box_goals,
    b.home_outside_box_goals - b.away_outside_box_goals AS outside_box_goals_delta,
    b.home_outside_box_xg AS triggered_team_outside_box_xg,
    b.away_outside_box_xg AS opponent_outside_box_xg,
    toFloat32(round(b.home_outside_box_xg - b.away_outside_box_xg, 3)) AS outside_box_xg_delta,
    b.home_outside_box_shots AS triggered_team_outside_box_shots,
    b.away_outside_box_shots AS opponent_outside_box_shots,
    b.home_outside_box_shots - b.away_outside_box_shots AS outside_box_shot_volume_delta,
    b.home_outside_box_shots_on_target AS triggered_team_outside_box_shots_on_target,
    b.away_outside_box_shots_on_target AS opponent_outside_box_shots_on_target,
    b.home_outside_box_shots_on_target - b.away_outside_box_shots_on_target
        AS outside_box_shots_on_target_delta,
    toFloat32(coalesce(round(
        100.0 * b.home_outside_box_shots_on_target / nullIf(toFloat64(b.home_outside_box_shots), 0),
        1
    ), 0.0)) AS triggered_team_outside_box_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.away_outside_box_shots_on_target / nullIf(toFloat64(b.away_outside_box_shots), 0),
        1
    ), 0.0)) AS opponent_outside_box_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.home_outside_box_shots_on_target / nullIf(toFloat64(b.home_outside_box_shots), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * b.away_outside_box_shots_on_target / nullIf(toFloat64(b.away_outside_box_shots), 0),
            1
        ), 0.0),
        1
    )) AS outside_box_shot_accuracy_delta_pct,
    toFloat32(coalesce(round(
        100.0 * b.home_outside_box_goals / nullIf(toFloat64(b.home_outside_box_shots), 0),
        1
    ), 0.0)) AS triggered_team_outside_box_goal_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * b.away_outside_box_goals / nullIf(toFloat64(b.away_outside_box_shots), 0),
        1
    ), 0.0)) AS opponent_outside_box_goal_conversion_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.home_outside_box_goals / nullIf(toFloat64(b.home_outside_box_shots), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * b.away_outside_box_goals / nullIf(toFloat64(b.away_outside_box_shots), 0),
            1
        ), 0.0),
        1
    )) AS outside_box_goal_conversion_delta_pct,
    b.home_goals AS triggered_team_goals,
    b.away_goals AS opponent_goals,
    b.home_goals - b.away_goals AS goal_gap,
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
    b.expected_goals_home AS triggered_team_xg,
    b.expected_goals_away AS opponent_xg,
    toFloat32(round(b.expected_goals_home - b.expected_goals_away, 3)) AS xg_gap,
    b.big_chances_home AS triggered_team_big_chances,
    b.big_chances_away AS opponent_big_chances,
    b.big_chances_home - b.big_chances_away AS big_chance_delta,
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

-- Away-side row.
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
    toInt32(1) AS trigger_threshold_min_outside_box_goals_per_team,
    toInt8(1) AS both_teams_scored_outside_box_flag,
    b.home_outside_box_goals,
    b.away_outside_box_goals,
    b.match_total_outside_box_goals,
    b.match_total_outside_box_xg,
    b.away_outside_box_goals AS triggered_team_outside_box_goals,
    b.home_outside_box_goals AS opponent_outside_box_goals,
    b.away_outside_box_goals - b.home_outside_box_goals AS outside_box_goals_delta,
    b.away_outside_box_xg AS triggered_team_outside_box_xg,
    b.home_outside_box_xg AS opponent_outside_box_xg,
    toFloat32(round(b.away_outside_box_xg - b.home_outside_box_xg, 3)) AS outside_box_xg_delta,
    b.away_outside_box_shots AS triggered_team_outside_box_shots,
    b.home_outside_box_shots AS opponent_outside_box_shots,
    b.away_outside_box_shots - b.home_outside_box_shots AS outside_box_shot_volume_delta,
    b.away_outside_box_shots_on_target AS triggered_team_outside_box_shots_on_target,
    b.home_outside_box_shots_on_target AS opponent_outside_box_shots_on_target,
    b.away_outside_box_shots_on_target - b.home_outside_box_shots_on_target
        AS outside_box_shots_on_target_delta,
    toFloat32(coalesce(round(
        100.0 * b.away_outside_box_shots_on_target / nullIf(toFloat64(b.away_outside_box_shots), 0),
        1
    ), 0.0)) AS triggered_team_outside_box_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.home_outside_box_shots_on_target / nullIf(toFloat64(b.home_outside_box_shots), 0),
        1
    ), 0.0)) AS opponent_outside_box_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.away_outside_box_shots_on_target / nullIf(toFloat64(b.away_outside_box_shots), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * b.home_outside_box_shots_on_target / nullIf(toFloat64(b.home_outside_box_shots), 0),
            1
        ), 0.0),
        1
    )) AS outside_box_shot_accuracy_delta_pct,
    toFloat32(coalesce(round(
        100.0 * b.away_outside_box_goals / nullIf(toFloat64(b.away_outside_box_shots), 0),
        1
    ), 0.0)) AS triggered_team_outside_box_goal_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * b.home_outside_box_goals / nullIf(toFloat64(b.home_outside_box_shots), 0),
        1
    ), 0.0)) AS opponent_outside_box_goal_conversion_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.away_outside_box_goals / nullIf(toFloat64(b.away_outside_box_shots), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * b.home_outside_box_goals / nullIf(toFloat64(b.home_outside_box_shots), 0),
            1
        ), 0.0),
        1
    )) AS outside_box_goal_conversion_delta_pct,
    b.away_goals AS triggered_team_goals,
    b.home_goals AS opponent_goals,
    b.away_goals - b.home_goals AS goal_gap,
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
    b.expected_goals_away AS triggered_team_xg,
    b.expected_goals_home AS opponent_xg,
    toFloat32(round(b.expected_goals_away - b.expected_goals_home, 3)) AS xg_gap,
    b.big_chances_away AS triggered_team_big_chances,
    b.big_chances_home AS opponent_big_chances,
    b.big_chances_away - b.big_chances_home AS big_chance_delta,
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
    match_total_outside_box_goals DESC,
    match_total_outside_box_xg DESC,
    match_date DESC,
    match_id DESC;
