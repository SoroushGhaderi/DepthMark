INSERT INTO gold.sig_team_shooting_goals_shot_accuracy_collapse (
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
    trigger_threshold_min_total_shots,
    trigger_threshold_max_shot_accuracy_pct,
    triggered_team_total_shots,
    opponent_total_shots,
    total_shots_delta,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    shots_on_target_delta,
    triggered_team_shot_accuracy_pct,
    opponent_shot_accuracy_pct,
    shot_accuracy_delta_pct,
    triggered_team_shots_off_target,
    opponent_shots_off_target,
    shots_off_target_delta,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_shot_conversion_pct,
    opponent_shot_conversion_pct,
    shot_conversion_delta_pct,
    triggered_team_expected_goals,
    opponent_expected_goals,
    expected_goals_delta,
    triggered_team_expected_goals_per_shot,
    opponent_expected_goals_per_shot,
    expected_goals_per_shot_delta,
    triggered_team_big_chances,
    opponent_big_chances,
    triggered_team_big_chances_missed,
    opponent_big_chances_missed,
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
-- Signal: sig_team_shooting_goals_shot_accuracy_collapse
-- Trigger: team has >= 15 total shots with shot accuracy <= 10% in a finished match.
-- Intent: isolate high-volume but low-precision shooting collapses and preserve bilateral match context.

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

    toInt32(15) AS trigger_threshold_min_total_shots,
    toFloat32(10.0) AS trigger_threshold_max_shot_accuracy_pct,

    toInt32(coalesce(ps.total_shots_home, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_away, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.total_shots_home, 0) - coalesce(ps.total_shots_away, 0)) AS total_shots_delta,

    toInt32(coalesce(ps.shots_on_target_home, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS opponent_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_home, 0) - coalesce(ps.shots_on_target_away, 0))
        AS shots_on_target_delta,

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

    toInt32(greatest(
        coalesce(ps.total_shots_home, 0) - coalesce(ps.shots_on_target_home, 0),
        0
    )) AS triggered_team_shots_off_target,
    toInt32(greatest(
        coalesce(ps.total_shots_away, 0) - coalesce(ps.shots_on_target_away, 0),
        0
    )) AS opponent_shots_off_target,
    toInt32(
        greatest(coalesce(ps.total_shots_home, 0) - coalesce(ps.shots_on_target_home, 0), 0)
        - greatest(coalesce(ps.total_shots_away, 0) - coalesce(ps.shots_on_target_away, 0), 0)
    ) AS shots_off_target_delta,

    toInt32(coalesce(m.home_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.away_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.home_score, 0) - coalesce(m.away_score, 0)) AS goal_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(m.home_score, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_shot_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(m.away_score, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        1
    ), 0.0)) AS opponent_shot_conversion_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(m.home_score, 0)
                / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(m.away_score, 0)
                / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
            1
        ), 0.0),
        1
    )) AS shot_conversion_delta_pct,

    toFloat32(coalesce(ps.expected_goals_home, 0)) AS triggered_team_expected_goals,
    toFloat32(coalesce(ps.expected_goals_away, 0)) AS opponent_expected_goals,
    toFloat32(round(
        coalesce(ps.expected_goals_home, 0) - coalesce(ps.expected_goals_away, 0),
        3
    )) AS expected_goals_delta,

    toFloat32(coalesce(round(
        coalesce(ps.expected_goals_home, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        3
    ), 0.0)) AS triggered_team_expected_goals_per_shot,
    toFloat32(coalesce(round(
        coalesce(ps.expected_goals_away, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        3
    ), 0.0)) AS opponent_expected_goals_per_shot,
    toFloat32(round(
        coalesce(round(
            coalesce(ps.expected_goals_home, 0)
                / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
            3
        ), 0.0)
      - coalesce(round(
            coalesce(ps.expected_goals_away, 0)
                / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
            3
        ), 0.0),
        3
    )) AS expected_goals_per_shot_delta,

    toInt32(coalesce(ps.big_chances_home, 0)) AS triggered_team_big_chances,
    toInt32(coalesce(ps.big_chances_away, 0)) AS opponent_big_chances,
    toInt32(coalesce(ps.big_chances_missed_home, 0)) AS triggered_team_big_chances_missed,
    toInt32(coalesce(ps.big_chances_missed_away, 0)) AS opponent_big_chances_missed,

    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS opponent_touches_opposition_box,

    toFloat32(coalesce(ps.ball_possession_home, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS opponent_possession_pct,
    toFloat32(round(
        coalesce(ps.ball_possession_home, 0) - coalesce(ps.ball_possession_away, 0),
        1
    )) AS possession_delta_pct,

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
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ps.total_shots_home, 0) >= 15
  AND coalesce(
        100.0 * coalesce(ps.shots_on_target_home, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        0.0
      ) <= 10.0

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

    toInt32(15) AS trigger_threshold_min_total_shots,
    toFloat32(10.0) AS trigger_threshold_max_shot_accuracy_pct,

    toInt32(coalesce(ps.total_shots_away, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_home, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.total_shots_away, 0) - coalesce(ps.total_shots_home, 0)) AS total_shots_delta,

    toInt32(coalesce(ps.shots_on_target_away, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS opponent_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_away, 0) - coalesce(ps.shots_on_target_home, 0))
        AS shots_on_target_delta,

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

    toInt32(greatest(
        coalesce(ps.total_shots_away, 0) - coalesce(ps.shots_on_target_away, 0),
        0
    )) AS triggered_team_shots_off_target,
    toInt32(greatest(
        coalesce(ps.total_shots_home, 0) - coalesce(ps.shots_on_target_home, 0),
        0
    )) AS opponent_shots_off_target,
    toInt32(
        greatest(coalesce(ps.total_shots_away, 0) - coalesce(ps.shots_on_target_away, 0), 0)
        - greatest(coalesce(ps.total_shots_home, 0) - coalesce(ps.shots_on_target_home, 0), 0)
    ) AS shots_off_target_delta,

    toInt32(coalesce(m.away_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.home_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.away_score, 0) - coalesce(m.home_score, 0)) AS goal_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(m.away_score, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_shot_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(m.home_score, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        1
    ), 0.0)) AS opponent_shot_conversion_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(m.away_score, 0)
                / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(m.home_score, 0)
                / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
            1
        ), 0.0),
        1
    )) AS shot_conversion_delta_pct,

    toFloat32(coalesce(ps.expected_goals_away, 0)) AS triggered_team_expected_goals,
    toFloat32(coalesce(ps.expected_goals_home, 0)) AS opponent_expected_goals,
    toFloat32(round(
        coalesce(ps.expected_goals_away, 0) - coalesce(ps.expected_goals_home, 0),
        3
    )) AS expected_goals_delta,

    toFloat32(coalesce(round(
        coalesce(ps.expected_goals_away, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        3
    ), 0.0)) AS triggered_team_expected_goals_per_shot,
    toFloat32(coalesce(round(
        coalesce(ps.expected_goals_home, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        3
    ), 0.0)) AS opponent_expected_goals_per_shot,
    toFloat32(round(
        coalesce(round(
            coalesce(ps.expected_goals_away, 0)
                / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
            3
        ), 0.0)
      - coalesce(round(
            coalesce(ps.expected_goals_home, 0)
                / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
            3
        ), 0.0),
        3
    )) AS expected_goals_per_shot_delta,

    toInt32(coalesce(ps.big_chances_away, 0)) AS triggered_team_big_chances,
    toInt32(coalesce(ps.big_chances_home, 0)) AS opponent_big_chances,
    toInt32(coalesce(ps.big_chances_missed_away, 0)) AS triggered_team_big_chances_missed,
    toInt32(coalesce(ps.big_chances_missed_home, 0)) AS opponent_big_chances_missed,

    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS opponent_touches_opposition_box,

    toFloat32(coalesce(ps.ball_possession_away, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS opponent_possession_pct,
    toFloat32(round(
        coalesce(ps.ball_possession_away, 0) - coalesce(ps.ball_possession_home, 0),
        1
    )) AS possession_delta_pct,

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
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ps.total_shots_away, 0) >= 15
  AND coalesce(
        100.0 * coalesce(ps.shots_on_target_away, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        0.0
      ) <= 10.0

ORDER BY
    triggered_team_total_shots DESC,
    triggered_team_shot_accuracy_pct ASC,
    m.match_date DESC,
    m.match_id DESC;
