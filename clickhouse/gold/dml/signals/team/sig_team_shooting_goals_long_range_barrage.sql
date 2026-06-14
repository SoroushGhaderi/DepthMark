INSERT INTO gold.sig_team_shooting_goals_long_range_barrage (
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
    trigger_threshold_min_shots_outside_box,
    triggered_team_shots_outside_box,
    opponent_shots_outside_box,
    shots_outside_box_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_outside_box_shot_share_pct,
    opponent_outside_box_shot_share_pct,
    outside_box_shot_share_delta_pct,
    triggered_team_outside_box_shots_on_target,
    opponent_outside_box_shots_on_target,
    triggered_team_outside_box_shot_accuracy_pct,
    opponent_outside_box_shot_accuracy_pct,
    outside_box_shot_accuracy_delta_pct,
    triggered_team_outside_box_goals,
    opponent_outside_box_goals,
    triggered_team_outside_box_xg,
    opponent_outside_box_xg,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_big_chances,
    opponent_big_chances,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_corners,
    opponent_corners
)
-- Signal: sig_team_shooting_goals_long_range_barrage
-- Trigger: team records >= 10 outside-box shots in a finished match at period='All'.
-- Intent: capture long-range shot-volume overload and preserve bilateral execution, chance-quality, and control context.
WITH outside_box_team_stats AS (
    SELECT
        s.match_id,
        toInt32(s.team_id) AS team_id,
        toInt32(count()) AS team_shots_outside_box,
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
)

-- Home-side trigger.
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

    toInt32(10) AS trigger_threshold_min_shots_outside_box,
    toInt32(coalesce(home_ob.team_shots_outside_box, 0)) AS triggered_team_shots_outside_box,
    toInt32(coalesce(away_ob.team_shots_outside_box, 0)) AS opponent_shots_outside_box,
    toInt32(
        coalesce(home_ob.team_shots_outside_box, 0) - coalesce(away_ob.team_shots_outside_box, 0)
    ) AS shots_outside_box_delta,

    toInt32(coalesce(ps.total_shots_home, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_away, 0)) AS opponent_total_shots,

    toFloat32(coalesce(round(
        100.0 * coalesce(home_ob.team_shots_outside_box, 0)
        / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_outside_box_shot_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(away_ob.team_shots_outside_box, 0)
        / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        1
    ), 0.0)) AS opponent_outside_box_shot_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(home_ob.team_shots_outside_box, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(away_ob.team_shots_outside_box, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
            1
        ), 0.0),
        1
    )) AS outside_box_shot_share_delta_pct,

    toInt32(coalesce(home_ob.team_outside_box_shots_on_target, 0)) AS triggered_team_outside_box_shots_on_target,
    toInt32(coalesce(away_ob.team_outside_box_shots_on_target, 0)) AS opponent_outside_box_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * coalesce(home_ob.team_outside_box_shots_on_target, 0)
        / nullIf(toFloat64(coalesce(home_ob.team_shots_outside_box, 0)), 0),
        1
    ), 0.0)) AS triggered_team_outside_box_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(away_ob.team_outside_box_shots_on_target, 0)
        / nullIf(toFloat64(coalesce(away_ob.team_shots_outside_box, 0)), 0),
        1
    ), 0.0)) AS opponent_outside_box_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(home_ob.team_outside_box_shots_on_target, 0)
            / nullIf(toFloat64(coalesce(home_ob.team_shots_outside_box, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(away_ob.team_outside_box_shots_on_target, 0)
            / nullIf(toFloat64(coalesce(away_ob.team_shots_outside_box, 0)), 0),
            1
        ), 0.0),
        1
    )) AS outside_box_shot_accuracy_delta_pct,

    toInt32(coalesce(home_ob.team_outside_box_goals, 0)) AS triggered_team_outside_box_goals,
    toInt32(coalesce(away_ob.team_outside_box_goals, 0)) AS opponent_outside_box_goals,
    toFloat32(coalesce(home_ob.team_outside_box_xg, 0.0)) AS triggered_team_outside_box_xg,
    toFloat32(coalesce(away_ob.team_outside_box_xg, 0.0)) AS opponent_outside_box_xg,

    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_home, 0.0) - coalesce(ps.expected_goals_away, 0.0), 3))
        AS xg_delta,

    toInt32(coalesce(ps.big_chances_home, 0)) AS triggered_team_big_chances,
    toInt32(coalesce(ps.big_chances_away, 0)) AS opponent_big_chances,
    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS opponent_touches_opposition_box,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_home, 0) - coalesce(ps.ball_possession_away, 0), 1))
        AS possession_delta_pct,

    toInt32(coalesce(ps.pass_attempts_home, 0)) AS triggered_team_pass_attempts,
    toInt32(coalesce(ps.pass_attempts_away, 0)) AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0)
        / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0)
        / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0)
            / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0)
            / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    toInt32(coalesce(ps.corners_home, 0)) AS triggered_team_corners,
    toInt32(coalesce(ps.corners_away, 0)) AS opponent_corners

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
LEFT JOIN outside_box_team_stats AS home_ob
    ON home_ob.match_id = m.match_id
   AND home_ob.team_id = m.home_team_id
LEFT JOIN outside_box_team_stats AS away_ob
    ON away_ob.match_id = m.match_id
   AND away_ob.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(home_ob.team_shots_outside_box, 0) >= 10

UNION ALL

-- Away-side trigger.
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

    toInt32(10) AS trigger_threshold_min_shots_outside_box,
    toInt32(coalesce(away_ob.team_shots_outside_box, 0)) AS triggered_team_shots_outside_box,
    toInt32(coalesce(home_ob.team_shots_outside_box, 0)) AS opponent_shots_outside_box,
    toInt32(
        coalesce(away_ob.team_shots_outside_box, 0) - coalesce(home_ob.team_shots_outside_box, 0)
    ) AS shots_outside_box_delta,

    toInt32(coalesce(ps.total_shots_away, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_home, 0)) AS opponent_total_shots,

    toFloat32(coalesce(round(
        100.0 * coalesce(away_ob.team_shots_outside_box, 0)
        / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_outside_box_shot_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(home_ob.team_shots_outside_box, 0)
        / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        1
    ), 0.0)) AS opponent_outside_box_shot_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(away_ob.team_shots_outside_box, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(home_ob.team_shots_outside_box, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
            1
        ), 0.0),
        1
    )) AS outside_box_shot_share_delta_pct,

    toInt32(coalesce(away_ob.team_outside_box_shots_on_target, 0)) AS triggered_team_outside_box_shots_on_target,
    toInt32(coalesce(home_ob.team_outside_box_shots_on_target, 0)) AS opponent_outside_box_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * coalesce(away_ob.team_outside_box_shots_on_target, 0)
        / nullIf(toFloat64(coalesce(away_ob.team_shots_outside_box, 0)), 0),
        1
    ), 0.0)) AS triggered_team_outside_box_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(home_ob.team_outside_box_shots_on_target, 0)
        / nullIf(toFloat64(coalesce(home_ob.team_shots_outside_box, 0)), 0),
        1
    ), 0.0)) AS opponent_outside_box_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(away_ob.team_outside_box_shots_on_target, 0)
            / nullIf(toFloat64(coalesce(away_ob.team_shots_outside_box, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(home_ob.team_outside_box_shots_on_target, 0)
            / nullIf(toFloat64(coalesce(home_ob.team_shots_outside_box, 0)), 0),
            1
        ), 0.0),
        1
    )) AS outside_box_shot_accuracy_delta_pct,

    toInt32(coalesce(away_ob.team_outside_box_goals, 0)) AS triggered_team_outside_box_goals,
    toInt32(coalesce(home_ob.team_outside_box_goals, 0)) AS opponent_outside_box_goals,
    toFloat32(coalesce(away_ob.team_outside_box_xg, 0.0)) AS triggered_team_outside_box_xg,
    toFloat32(coalesce(home_ob.team_outside_box_xg, 0.0)) AS opponent_outside_box_xg,

    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_away, 0.0) - coalesce(ps.expected_goals_home, 0.0), 3))
        AS xg_delta,

    toInt32(coalesce(ps.big_chances_away, 0)) AS triggered_team_big_chances,
    toInt32(coalesce(ps.big_chances_home, 0)) AS opponent_big_chances,
    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS opponent_touches_opposition_box,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_away, 0) - coalesce(ps.ball_possession_home, 0), 1))
        AS possession_delta_pct,

    toInt32(coalesce(ps.pass_attempts_away, 0)) AS triggered_team_pass_attempts,
    toInt32(coalesce(ps.pass_attempts_home, 0)) AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0)
        / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0)
        / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0)
            / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0)
            / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    toInt32(coalesce(ps.corners_away, 0)) AS triggered_team_corners,
    toInt32(coalesce(ps.corners_home, 0)) AS opponent_corners

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
LEFT JOIN outside_box_team_stats AS home_ob
    ON home_ob.match_id = m.match_id
   AND home_ob.team_id = m.home_team_id
LEFT JOIN outside_box_team_stats AS away_ob
    ON away_ob.match_id = m.match_id
   AND away_ob.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(away_ob.team_shots_outside_box, 0) >= 10

ORDER BY
    triggered_team_shots_outside_box DESC,
    outside_box_shot_share_delta_pct DESC,
    m.match_date DESC,
    m.match_id DESC;
