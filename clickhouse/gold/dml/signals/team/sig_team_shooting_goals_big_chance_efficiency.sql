INSERT INTO gold.sig_team_shooting_goals_big_chance_efficiency (
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
    trigger_threshold_min_big_chances,
    trigger_threshold_required_big_chances_missed,
    trigger_threshold_big_chance_conversion_pct,
    triggered_team_big_chances,
    opponent_big_chances,
    big_chances_delta,
    triggered_team_big_chances_missed,
    opponent_big_chances_missed,
    big_chances_missed_delta,
    triggered_team_big_chances_converted,
    opponent_big_chances_converted,
    big_chances_converted_delta,
    triggered_team_big_chance_conversion_pct,
    opponent_big_chance_conversion_pct,
    big_chance_conversion_delta_pct,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    total_shots_delta,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    shots_on_target_delta,
    triggered_team_shot_accuracy_pct,
    opponent_shot_accuracy_pct,
    shot_accuracy_delta_pct,
    triggered_team_goal_conversion_pct,
    opponent_goal_conversion_pct,
    goal_conversion_delta_pct,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_goals_minus_xg,
    opponent_goals_minus_xg,
    goals_minus_xg_delta,
    triggered_team_xg_per_shot,
    opponent_xg_per_shot,
    xg_per_shot_delta,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    touches_opposition_box_delta,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_corners,
    opponent_corners
)
-- Signal: sig_team_shooting_goals_big_chance_efficiency
-- Trigger: Team converts 100% of big chances (Opta) into goals in a finished match (`period = 'All'`).
-- Intent: Detect perfect big-chance conversion at team level with bilateral chance-quality,
--         finishing, and territorial context for interpretation.

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

    toInt32(1) AS trigger_threshold_min_big_chances,
    toInt32(0) AS trigger_threshold_required_big_chances_missed,
    toFloat32(100.0) AS trigger_threshold_big_chance_conversion_pct,

    toInt32(coalesce(ps.big_chances_home, 0)) AS triggered_team_big_chances,
    toInt32(coalesce(ps.big_chances_away, 0)) AS opponent_big_chances,
    toInt32(coalesce(ps.big_chances_home, 0) - coalesce(ps.big_chances_away, 0)) AS big_chances_delta,

    toInt32(coalesce(ps.big_chances_missed_home, 0)) AS triggered_team_big_chances_missed,
    toInt32(coalesce(ps.big_chances_missed_away, 0)) AS opponent_big_chances_missed,
    toInt32(coalesce(ps.big_chances_missed_home, 0) - coalesce(ps.big_chances_missed_away, 0))
        AS big_chances_missed_delta,

    toInt32(greatest(coalesce(ps.big_chances_home, 0) - coalesce(ps.big_chances_missed_home, 0), 0))
        AS triggered_team_big_chances_converted,
    toInt32(greatest(coalesce(ps.big_chances_away, 0) - coalesce(ps.big_chances_missed_away, 0), 0))
        AS opponent_big_chances_converted,
    toInt32(
        greatest(coalesce(ps.big_chances_home, 0) - coalesce(ps.big_chances_missed_home, 0), 0)
      - greatest(coalesce(ps.big_chances_away, 0) - coalesce(ps.big_chances_missed_away, 0), 0)
    ) AS big_chances_converted_delta,

    toFloat32(coalesce(round(
        100.0 * greatest(coalesce(ps.big_chances_home, 0) - coalesce(ps.big_chances_missed_home, 0), 0)
            / nullIf(toFloat64(coalesce(ps.big_chances_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_big_chance_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * greatest(coalesce(ps.big_chances_away, 0) - coalesce(ps.big_chances_missed_away, 0), 0)
            / nullIf(toFloat64(coalesce(ps.big_chances_away, 0)), 0),
        1
    ), 0.0)) AS opponent_big_chance_conversion_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * greatest(coalesce(ps.big_chances_home, 0) - coalesce(ps.big_chances_missed_home, 0), 0)
                / nullIf(toFloat64(coalesce(ps.big_chances_home, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * greatest(coalesce(ps.big_chances_away, 0) - coalesce(ps.big_chances_missed_away, 0), 0)
                / nullIf(toFloat64(coalesce(ps.big_chances_away, 0)), 0),
            1
        ), 0.0),
        1
    )) AS big_chance_conversion_delta_pct,

    toInt32(coalesce(m.home_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.away_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.home_score, 0) - coalesce(m.away_score, 0)) AS goal_delta,

    toInt32(coalesce(ps.total_shots_home, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_away, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.total_shots_home, 0) - coalesce(ps.total_shots_away, 0)) AS total_shots_delta,

    toInt32(coalesce(ps.shots_on_target_home, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS opponent_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_home, 0) - coalesce(ps.shots_on_target_away, 0))
        AS shots_on_target_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_home, 0) / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_away, 0) / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        1
    ), 0.0)) AS opponent_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.shots_on_target_home, 0) / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.shots_on_target_away, 0) / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
            1
        ), 0.0),
        1
    )) AS shot_accuracy_delta_pct,

    toFloat32(coalesce(round(
        100.0 * coalesce(m.home_score, 0) / nullIf(toFloat64(coalesce(ps.shots_on_target_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_goal_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(m.away_score, 0) / nullIf(toFloat64(coalesce(ps.shots_on_target_away, 0)), 0),
        1
    ), 0.0)) AS opponent_goal_conversion_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(m.home_score, 0) / nullIf(toFloat64(coalesce(ps.shots_on_target_home, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(m.away_score, 0) / nullIf(toFloat64(coalesce(ps.shots_on_target_away, 0)), 0),
            1
        ), 0.0),
        1
    )) AS goal_conversion_delta_pct,

    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_home, 0.0) - coalesce(ps.expected_goals_away, 0.0), 3))
        AS xg_delta,
    toFloat32(round(coalesce(m.home_score, 0) - coalesce(ps.expected_goals_home, 0.0), 3))
        AS triggered_team_goals_minus_xg,
    toFloat32(round(coalesce(m.away_score, 0) - coalesce(ps.expected_goals_away, 0.0), 3))
        AS opponent_goals_minus_xg,
    toFloat32(round(
        (coalesce(m.home_score, 0) - coalesce(ps.expected_goals_home, 0.0))
      - (coalesce(m.away_score, 0) - coalesce(ps.expected_goals_away, 0.0)),
        3
    )) AS goals_minus_xg_delta,

    toFloat32(coalesce(round(
        coalesce(ps.expected_goals_home, 0.0) / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        3
    ), 0.0)) AS triggered_team_xg_per_shot,
    toFloat32(coalesce(round(
        coalesce(ps.expected_goals_away, 0.0) / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        3
    ), 0.0)) AS opponent_xg_per_shot,
    toFloat32(round(
        coalesce(round(
            coalesce(ps.expected_goals_home, 0.0) / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
            3
        ), 0.0)
      - coalesce(round(
            coalesce(ps.expected_goals_away, 0.0) / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
            3
        ), 0.0),
        3
    )) AS xg_per_shot_delta,

    toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_home, 0.0) - coalesce(ps.ball_possession_away, 0.0), 1))
        AS possession_delta_pct,

    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS opponent_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_home, 0) - coalesce(ps.touches_opp_box_away, 0))
        AS touches_opposition_box_delta,

    toInt32(coalesce(ps.pass_attempts_home, 0)) AS triggered_team_pass_attempts,
    toInt32(coalesce(ps.pass_attempts_away, 0)) AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
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
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ps.big_chances_home, 0) >= 1
  AND coalesce(ps.big_chances_missed_home, 0) = 0

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

    toInt32(1) AS trigger_threshold_min_big_chances,
    toInt32(0) AS trigger_threshold_required_big_chances_missed,
    toFloat32(100.0) AS trigger_threshold_big_chance_conversion_pct,

    toInt32(coalesce(ps.big_chances_away, 0)) AS triggered_team_big_chances,
    toInt32(coalesce(ps.big_chances_home, 0)) AS opponent_big_chances,
    toInt32(coalesce(ps.big_chances_away, 0) - coalesce(ps.big_chances_home, 0)) AS big_chances_delta,

    toInt32(coalesce(ps.big_chances_missed_away, 0)) AS triggered_team_big_chances_missed,
    toInt32(coalesce(ps.big_chances_missed_home, 0)) AS opponent_big_chances_missed,
    toInt32(coalesce(ps.big_chances_missed_away, 0) - coalesce(ps.big_chances_missed_home, 0))
        AS big_chances_missed_delta,

    toInt32(greatest(coalesce(ps.big_chances_away, 0) - coalesce(ps.big_chances_missed_away, 0), 0))
        AS triggered_team_big_chances_converted,
    toInt32(greatest(coalesce(ps.big_chances_home, 0) - coalesce(ps.big_chances_missed_home, 0), 0))
        AS opponent_big_chances_converted,
    toInt32(
        greatest(coalesce(ps.big_chances_away, 0) - coalesce(ps.big_chances_missed_away, 0), 0)
      - greatest(coalesce(ps.big_chances_home, 0) - coalesce(ps.big_chances_missed_home, 0), 0)
    ) AS big_chances_converted_delta,

    toFloat32(coalesce(round(
        100.0 * greatest(coalesce(ps.big_chances_away, 0) - coalesce(ps.big_chances_missed_away, 0), 0)
            / nullIf(toFloat64(coalesce(ps.big_chances_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_big_chance_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * greatest(coalesce(ps.big_chances_home, 0) - coalesce(ps.big_chances_missed_home, 0), 0)
            / nullIf(toFloat64(coalesce(ps.big_chances_home, 0)), 0),
        1
    ), 0.0)) AS opponent_big_chance_conversion_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * greatest(coalesce(ps.big_chances_away, 0) - coalesce(ps.big_chances_missed_away, 0), 0)
                / nullIf(toFloat64(coalesce(ps.big_chances_away, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * greatest(coalesce(ps.big_chances_home, 0) - coalesce(ps.big_chances_missed_home, 0), 0)
                / nullIf(toFloat64(coalesce(ps.big_chances_home, 0)), 0),
            1
        ), 0.0),
        1
    )) AS big_chance_conversion_delta_pct,

    toInt32(coalesce(m.away_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.home_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.away_score, 0) - coalesce(m.home_score, 0)) AS goal_delta,

    toInt32(coalesce(ps.total_shots_away, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_home, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.total_shots_away, 0) - coalesce(ps.total_shots_home, 0)) AS total_shots_delta,

    toInt32(coalesce(ps.shots_on_target_away, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS opponent_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_away, 0) - coalesce(ps.shots_on_target_home, 0))
        AS shots_on_target_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_away, 0) / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_home, 0) / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        1
    ), 0.0)) AS opponent_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.shots_on_target_away, 0) / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.shots_on_target_home, 0) / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
            1
        ), 0.0),
        1
    )) AS shot_accuracy_delta_pct,

    toFloat32(coalesce(round(
        100.0 * coalesce(m.away_score, 0) / nullIf(toFloat64(coalesce(ps.shots_on_target_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_goal_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(m.home_score, 0) / nullIf(toFloat64(coalesce(ps.shots_on_target_home, 0)), 0),
        1
    ), 0.0)) AS opponent_goal_conversion_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(m.away_score, 0) / nullIf(toFloat64(coalesce(ps.shots_on_target_away, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(m.home_score, 0) / nullIf(toFloat64(coalesce(ps.shots_on_target_home, 0)), 0),
            1
        ), 0.0),
        1
    )) AS goal_conversion_delta_pct,

    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_away, 0.0) - coalesce(ps.expected_goals_home, 0.0), 3))
        AS xg_delta,
    toFloat32(round(coalesce(m.away_score, 0) - coalesce(ps.expected_goals_away, 0.0), 3))
        AS triggered_team_goals_minus_xg,
    toFloat32(round(coalesce(m.home_score, 0) - coalesce(ps.expected_goals_home, 0.0), 3))
        AS opponent_goals_minus_xg,
    toFloat32(round(
        (coalesce(m.away_score, 0) - coalesce(ps.expected_goals_away, 0.0))
      - (coalesce(m.home_score, 0) - coalesce(ps.expected_goals_home, 0.0)),
        3
    )) AS goals_minus_xg_delta,

    toFloat32(coalesce(round(
        coalesce(ps.expected_goals_away, 0.0) / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        3
    ), 0.0)) AS triggered_team_xg_per_shot,
    toFloat32(coalesce(round(
        coalesce(ps.expected_goals_home, 0.0) / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        3
    ), 0.0)) AS opponent_xg_per_shot,
    toFloat32(round(
        coalesce(round(
            coalesce(ps.expected_goals_away, 0.0) / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
            3
        ), 0.0)
      - coalesce(round(
            coalesce(ps.expected_goals_home, 0.0) / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
            3
        ), 0.0),
        3
    )) AS xg_per_shot_delta,

    toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_away, 0.0) - coalesce(ps.ball_possession_home, 0.0), 1))
        AS possession_delta_pct,

    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS opponent_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_away, 0) - coalesce(ps.touches_opp_box_home, 0))
        AS touches_opposition_box_delta,

    toInt32(coalesce(ps.pass_attempts_away, 0)) AS triggered_team_pass_attempts,
    toInt32(coalesce(ps.pass_attempts_home, 0)) AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
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
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ps.big_chances_away, 0) >= 1
  AND coalesce(ps.big_chances_missed_away, 0) = 0

ORDER BY
    triggered_team_big_chances DESC,
    triggered_team_big_chance_conversion_pct DESC,
    triggered_team_goals_minus_xg DESC,
    m.match_date DESC,
    m.match_id DESC;
