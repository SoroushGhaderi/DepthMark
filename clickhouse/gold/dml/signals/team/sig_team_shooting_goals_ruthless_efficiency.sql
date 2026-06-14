INSERT INTO gold.sig_team_shooting_goals_ruthless_efficiency (
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
    trigger_threshold_min_goals,
    trigger_threshold_max_shots_on_target,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    shots_on_target_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_shot_accuracy_pct,
    opponent_shot_accuracy_pct,
    shot_accuracy_delta_pct,
    triggered_team_goals_per_shot_on_target,
    opponent_goals_per_shot_on_target,
    goals_per_shot_on_target_delta,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_goals_minus_xg,
    opponent_goals_minus_xg,
    goals_minus_xg_delta,
    triggered_team_big_chances,
    opponent_big_chances,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box
)
-- Signal: sig_team_shooting_goals_ruthless_efficiency
-- Trigger: team scores >= 3 goals from <= 5 shots on target in a finished match at period='All'.
-- Intent: identify extreme team-level conversion efficiency with bilateral shot quality and control context.

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

    toInt32(3) AS trigger_threshold_min_goals,
    toInt32(5) AS trigger_threshold_max_shots_on_target,

    toInt32(coalesce(m.home_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.away_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.home_score, 0) - coalesce(m.away_score, 0)) AS goal_delta,

    toInt32(coalesce(ps.shots_on_target_home, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS opponent_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_home, 0) - coalesce(ps.shots_on_target_away, 0)) AS shots_on_target_delta,

    toInt32(coalesce(ps.total_shots_home, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_away, 0)) AS opponent_total_shots,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_home, 0)
        / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_away, 0)
        / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        1
    ), 0.0)) AS opponent_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.shots_on_target_home, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.shots_on_target_away, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
            1
        ), 0.0),
        1
    )) AS shot_accuracy_delta_pct,

    toFloat32(coalesce(round(
        coalesce(m.home_score, 0)
        / nullIf(toFloat64(coalesce(ps.shots_on_target_home, 0)), 0),
        3
    ), 0.0)) AS triggered_team_goals_per_shot_on_target,
    toFloat32(coalesce(round(
        coalesce(m.away_score, 0)
        / nullIf(toFloat64(coalesce(ps.shots_on_target_away, 0)), 0),
        3
    ), 0.0)) AS opponent_goals_per_shot_on_target,
    toFloat32(round(
        coalesce(round(
            coalesce(m.home_score, 0)
            / nullIf(toFloat64(coalesce(ps.shots_on_target_home, 0)), 0),
            3
        ), 0.0)
      - coalesce(round(
            coalesce(m.away_score, 0)
            / nullIf(toFloat64(coalesce(ps.shots_on_target_away, 0)), 0),
            3
        ), 0.0),
        3
    )) AS goals_per_shot_on_target_delta,

    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_home, 0.0) - coalesce(ps.expected_goals_away, 0.0), 3)) AS xg_delta,
    toFloat32(round(coalesce(m.home_score, 0) - coalesce(ps.expected_goals_home, 0.0), 3)) AS triggered_team_goals_minus_xg,
    toFloat32(round(coalesce(m.away_score, 0) - coalesce(ps.expected_goals_away, 0.0), 3)) AS opponent_goals_minus_xg,
    toFloat32(round(
        (coalesce(m.home_score, 0) - coalesce(ps.expected_goals_home, 0.0))
      - (coalesce(m.away_score, 0) - coalesce(ps.expected_goals_away, 0.0)),
        3
    )) AS goals_minus_xg_delta,

    toInt32(coalesce(ps.big_chances_home, 0)) AS triggered_team_big_chances,
    toInt32(coalesce(ps.big_chances_away, 0)) AS opponent_big_chances,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS opponent_possession_pct,
    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS opponent_touches_opposition_box

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(m.home_score, 0) >= 3
  AND coalesce(ps.shots_on_target_home, 0) <= 5

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

    toInt32(3) AS trigger_threshold_min_goals,
    toInt32(5) AS trigger_threshold_max_shots_on_target,

    toInt32(coalesce(m.away_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.home_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.away_score, 0) - coalesce(m.home_score, 0)) AS goal_delta,

    toInt32(coalesce(ps.shots_on_target_away, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS opponent_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_away, 0) - coalesce(ps.shots_on_target_home, 0)) AS shots_on_target_delta,

    toInt32(coalesce(ps.total_shots_away, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_home, 0)) AS opponent_total_shots,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_away, 0)
        / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_home, 0)
        / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        1
    ), 0.0)) AS opponent_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.shots_on_target_away, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.shots_on_target_home, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
            1
        ), 0.0),
        1
    )) AS shot_accuracy_delta_pct,

    toFloat32(coalesce(round(
        coalesce(m.away_score, 0)
        / nullIf(toFloat64(coalesce(ps.shots_on_target_away, 0)), 0),
        3
    ), 0.0)) AS triggered_team_goals_per_shot_on_target,
    toFloat32(coalesce(round(
        coalesce(m.home_score, 0)
        / nullIf(toFloat64(coalesce(ps.shots_on_target_home, 0)), 0),
        3
    ), 0.0)) AS opponent_goals_per_shot_on_target,
    toFloat32(round(
        coalesce(round(
            coalesce(m.away_score, 0)
            / nullIf(toFloat64(coalesce(ps.shots_on_target_away, 0)), 0),
            3
        ), 0.0)
      - coalesce(round(
            coalesce(m.home_score, 0)
            / nullIf(toFloat64(coalesce(ps.shots_on_target_home, 0)), 0),
            3
        ), 0.0),
        3
    )) AS goals_per_shot_on_target_delta,

    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_away, 0.0) - coalesce(ps.expected_goals_home, 0.0), 3)) AS xg_delta,
    toFloat32(round(coalesce(m.away_score, 0) - coalesce(ps.expected_goals_away, 0.0), 3)) AS triggered_team_goals_minus_xg,
    toFloat32(round(coalesce(m.home_score, 0) - coalesce(ps.expected_goals_home, 0.0), 3)) AS opponent_goals_minus_xg,
    toFloat32(round(
        (coalesce(m.away_score, 0) - coalesce(ps.expected_goals_away, 0.0))
      - (coalesce(m.home_score, 0) - coalesce(ps.expected_goals_home, 0.0)),
        3
    )) AS goals_minus_xg_delta,

    toInt32(coalesce(ps.big_chances_away, 0)) AS triggered_team_big_chances,
    toInt32(coalesce(ps.big_chances_home, 0)) AS opponent_big_chances,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS opponent_possession_pct,
    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS opponent_touches_opposition_box

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(m.away_score, 0) >= 3
  AND coalesce(ps.shots_on_target_away, 0) <= 5

ORDER BY
    triggered_team_goals_per_shot_on_target DESC,
    triggered_team_goals_minus_xg DESC,
    m.match_date DESC,
    m.match_id DESC;
