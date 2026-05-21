INSERT INTO gold.sig_team_shooting_goals_expected_goal_dominance (
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
    trigger_threshold_min_triggered_team_xg,
    trigger_threshold_max_opponent_xg,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_xg_above_threshold,
    opponent_xg_below_threshold,
    trigger_clearance_xg,
    triggered_team_total_shots,
    opponent_total_shots,
    total_shots_delta,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    shots_on_target_delta,
    triggered_team_on_target_ratio_pct,
    opponent_on_target_ratio_pct,
    on_target_ratio_delta_pct,
    triggered_team_xg_per_shot,
    opponent_xg_per_shot,
    xg_per_shot_delta,
    triggered_team_big_chances,
    opponent_big_chances,
    triggered_team_big_chances_missed,
    opponent_big_chances_missed,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
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
    opponent_corners,
    triggered_team_clean_sheet_flag
)
-- Signal: sig_team_shooting_goals_expected_goal_dominance
-- Trigger: Team records > 3.0 xG while opponent records < 0.3 xG in a finished match (`period = 'All'`).
-- Intent: Detect extreme bilateral chance-quality dominance where one side creates high xG and
--         suppresses opponent chance quality to a minimal level.

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

    toFloat32(3.0) AS trigger_threshold_min_triggered_team_xg,
    toFloat32(0.3) AS trigger_threshold_max_opponent_xg,

    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_home, 0.0) - coalesce(ps.expected_goals_away, 0.0), 3))
        AS xg_delta,
    toFloat32(round(coalesce(ps.expected_goals_home, 0.0) - 3.0, 3)) AS triggered_team_xg_above_threshold,
    toFloat32(round(0.3 - coalesce(ps.expected_goals_away, 0.0), 3)) AS opponent_xg_below_threshold,
    toFloat32(round(
        least(
            coalesce(ps.expected_goals_home, 0.0) - 3.0,
            0.3 - coalesce(ps.expected_goals_away, 0.0)
        ),
        3
    )) AS trigger_clearance_xg,

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
    ), 0.0)) AS triggered_team_on_target_ratio_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_away, 0) / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        1
    ), 0.0)) AS opponent_on_target_ratio_pct,
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
    )) AS on_target_ratio_delta_pct,

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

    toInt32(coalesce(ps.big_chances_home, 0)) AS triggered_team_big_chances,
    toInt32(coalesce(ps.big_chances_away, 0)) AS opponent_big_chances,
    toInt32(coalesce(ps.big_chances_missed_home, 0)) AS triggered_team_big_chances_missed,
    toInt32(coalesce(ps.big_chances_missed_away, 0)) AS opponent_big_chances_missed,

    toInt32(coalesce(m.home_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.away_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.home_score, 0) - coalesce(m.away_score, 0)) AS goal_delta,

    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS opponent_touches_opposition_box,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_home, 0) - coalesce(ps.ball_possession_away, 0), 1))
        AS possession_delta_pct,

    toInt32(coalesce(ps.pass_attempts_home, 0)) AS triggered_team_pass_attempts,
    toInt32(coalesce(ps.pass_attempts_away, 0)) AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0)
                / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0)
                / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    toInt32(coalesce(ps.corners_home, 0)) AS triggered_team_corners,
    toInt32(coalesce(ps.corners_away, 0)) AS opponent_corners,
    toInt8(if(coalesce(m.away_score, 0) = 0, 1, 0)) AS triggered_team_clean_sheet_flag

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ps.expected_goals_home, 0.0) > 3.0
  AND coalesce(ps.expected_goals_away, 0.0) < 0.3

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

    toFloat32(3.0) AS trigger_threshold_min_triggered_team_xg,
    toFloat32(0.3) AS trigger_threshold_max_opponent_xg,

    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_away, 0.0) - coalesce(ps.expected_goals_home, 0.0), 3))
        AS xg_delta,
    toFloat32(round(coalesce(ps.expected_goals_away, 0.0) - 3.0, 3)) AS triggered_team_xg_above_threshold,
    toFloat32(round(0.3 - coalesce(ps.expected_goals_home, 0.0), 3)) AS opponent_xg_below_threshold,
    toFloat32(round(
        least(
            coalesce(ps.expected_goals_away, 0.0) - 3.0,
            0.3 - coalesce(ps.expected_goals_home, 0.0)
        ),
        3
    )) AS trigger_clearance_xg,

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
    ), 0.0)) AS triggered_team_on_target_ratio_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_home, 0) / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        1
    ), 0.0)) AS opponent_on_target_ratio_pct,
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
    )) AS on_target_ratio_delta_pct,

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

    toInt32(coalesce(ps.big_chances_away, 0)) AS triggered_team_big_chances,
    toInt32(coalesce(ps.big_chances_home, 0)) AS opponent_big_chances,
    toInt32(coalesce(ps.big_chances_missed_away, 0)) AS triggered_team_big_chances_missed,
    toInt32(coalesce(ps.big_chances_missed_home, 0)) AS opponent_big_chances_missed,

    toInt32(coalesce(m.away_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.home_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.away_score, 0) - coalesce(m.home_score, 0)) AS goal_delta,

    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS opponent_touches_opposition_box,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_away, 0) - coalesce(ps.ball_possession_home, 0), 1))
        AS possession_delta_pct,

    toInt32(coalesce(ps.pass_attempts_away, 0)) AS triggered_team_pass_attempts,
    toInt32(coalesce(ps.pass_attempts_home, 0)) AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0)
                / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0)
                / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    toInt32(coalesce(ps.corners_away, 0)) AS triggered_team_corners,
    toInt32(coalesce(ps.corners_home, 0)) AS opponent_corners,
    toInt8(if(coalesce(m.home_score, 0) = 0, 1, 0)) AS triggered_team_clean_sheet_flag

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ps.expected_goals_away, 0.0) > 3.0
  AND coalesce(ps.expected_goals_home, 0.0) < 0.3;
