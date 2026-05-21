WITH half_shot_stats AS (
    SELECT
        ps.match_id,
        maxIf(coalesce(ps.total_shots_home, 0), ps.period = 'FirstHalf') AS home_shots_first_half,
        maxIf(coalesce(ps.total_shots_home, 0), ps.period = 'SecondHalf') AS home_shots_second_half,
        maxIf(coalesce(ps.total_shots_away, 0), ps.period = 'FirstHalf') AS away_shots_first_half,
        maxIf(coalesce(ps.total_shots_away, 0), ps.period = 'SecondHalf') AS away_shots_second_half,
        toInt8(maxIf(1, ps.period = 'FirstHalf')) AS has_first_half_period_row_flag,
        toInt8(maxIf(1, ps.period = 'SecondHalf')) AS has_second_half_period_row_flag
    FROM silver.period_stat AS ps
    WHERE ps.period IN ('FirstHalf', 'SecondHalf')
    GROUP BY ps.match_id
)
INSERT INTO gold.sig_team_shooting_goals_zero_shot_half (
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
    trigger_threshold_max_shots_per_half,
    trigger_threshold_required_half_minutes,
    triggered_half_without_shot,
    has_first_half_period_row_flag,
    has_second_half_period_row_flag,
    triggered_team_shots_first_half,
    triggered_team_shots_second_half,
    opponent_shots_first_half,
    opponent_shots_second_half,
    triggered_team_zero_shot_first_half_flag,
    triggered_team_zero_shot_second_half_flag,
    opponent_zero_shot_first_half_flag,
    opponent_zero_shot_second_half_flag,
    half_shot_gap_first_half,
    half_shot_gap_second_half,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    total_shots_delta,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    shots_on_target_delta,
    triggered_team_on_target_ratio_pct,
    opponent_on_target_ratio_pct,
    on_target_ratio_delta_pct,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
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
-- Signal: sig_team_shooting_goals_zero_shot_half
-- Trigger: team records 0 total shots in a full 45-minute half (FirstHalf or SecondHalf).
-- Intent: detect severe half-level attacking droughts with explicit full-half period-coverage
-- validation and bilateral full-match context.

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

    toInt32(0) AS trigger_threshold_max_shots_per_half,
    toInt32(45) AS trigger_threshold_required_half_minutes,
    if(
        coalesce(hss.home_shots_first_half, 0) = 0 AND coalesce(hss.home_shots_second_half, 0) = 0,
        'BothHalves',
        if(coalesce(hss.home_shots_first_half, 0) = 0, 'FirstHalf', 'SecondHalf')
    ) AS triggered_half_without_shot,
    hss.has_first_half_period_row_flag,
    hss.has_second_half_period_row_flag,

    toInt32(coalesce(hss.home_shots_first_half, 0)) AS triggered_team_shots_first_half,
    toInt32(coalesce(hss.home_shots_second_half, 0)) AS triggered_team_shots_second_half,
    toInt32(coalesce(hss.away_shots_first_half, 0)) AS opponent_shots_first_half,
    toInt32(coalesce(hss.away_shots_second_half, 0)) AS opponent_shots_second_half,

    toInt8(if(coalesce(hss.home_shots_first_half, 0) = 0, 1, 0))
        AS triggered_team_zero_shot_first_half_flag,
    toInt8(if(coalesce(hss.home_shots_second_half, 0) = 0, 1, 0))
        AS triggered_team_zero_shot_second_half_flag,
    toInt8(if(coalesce(hss.away_shots_first_half, 0) = 0, 1, 0))
        AS opponent_zero_shot_first_half_flag,
    toInt8(if(coalesce(hss.away_shots_second_half, 0) = 0, 1, 0))
        AS opponent_zero_shot_second_half_flag,

    toInt32(coalesce(hss.home_shots_first_half, 0) - coalesce(hss.away_shots_first_half, 0))
        AS half_shot_gap_first_half,
    toInt32(coalesce(hss.home_shots_second_half, 0) - coalesce(hss.away_shots_second_half, 0))
        AS half_shot_gap_second_half,

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
        100.0 * coalesce(ps.shots_on_target_home, 0) / nullIf(coalesce(ps.total_shots_home, 0), 0),
        1
    ), 0.0)) AS triggered_team_on_target_ratio_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_away, 0) / nullIf(coalesce(ps.total_shots_away, 0), 0),
        1
    ), 0.0)) AS opponent_on_target_ratio_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.shots_on_target_home, 0) / nullIf(coalesce(ps.total_shots_home, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.shots_on_target_away, 0) / nullIf(coalesce(ps.total_shots_away, 0), 0),
            1
        ), 0.0),
        1
    )) AS on_target_ratio_delta_pct,

    toFloat32(coalesce(ps.expected_goals_home, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_home, 0) - coalesce(ps.expected_goals_away, 0), 3))
        AS xg_delta,

    toInt32(coalesce(ps.big_chances_home, 0)) AS triggered_team_big_chances,
    toInt32(coalesce(ps.big_chances_away, 0)) AS opponent_big_chances,
    toInt32(coalesce(ps.big_chances_missed_home, 0)) AS triggered_team_big_chances_missed,
    toInt32(coalesce(ps.big_chances_missed_away, 0)) AS opponent_big_chances_missed,

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
            100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
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
INNER JOIN half_shot_stats AS hss
    ON hss.match_id = m.match_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND hss.has_first_half_period_row_flag = 1
  AND hss.has_second_half_period_row_flag = 1
  AND (
      coalesce(hss.home_shots_first_half, 0) = 0
      OR coalesce(hss.home_shots_second_half, 0) = 0
  )

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

    toInt32(0) AS trigger_threshold_max_shots_per_half,
    toInt32(45) AS trigger_threshold_required_half_minutes,
    if(
        coalesce(hss.away_shots_first_half, 0) = 0 AND coalesce(hss.away_shots_second_half, 0) = 0,
        'BothHalves',
        if(coalesce(hss.away_shots_first_half, 0) = 0, 'FirstHalf', 'SecondHalf')
    ) AS triggered_half_without_shot,
    hss.has_first_half_period_row_flag,
    hss.has_second_half_period_row_flag,

    toInt32(coalesce(hss.away_shots_first_half, 0)) AS triggered_team_shots_first_half,
    toInt32(coalesce(hss.away_shots_second_half, 0)) AS triggered_team_shots_second_half,
    toInt32(coalesce(hss.home_shots_first_half, 0)) AS opponent_shots_first_half,
    toInt32(coalesce(hss.home_shots_second_half, 0)) AS opponent_shots_second_half,

    toInt8(if(coalesce(hss.away_shots_first_half, 0) = 0, 1, 0))
        AS triggered_team_zero_shot_first_half_flag,
    toInt8(if(coalesce(hss.away_shots_second_half, 0) = 0, 1, 0))
        AS triggered_team_zero_shot_second_half_flag,
    toInt8(if(coalesce(hss.home_shots_first_half, 0) = 0, 1, 0))
        AS opponent_zero_shot_first_half_flag,
    toInt8(if(coalesce(hss.home_shots_second_half, 0) = 0, 1, 0))
        AS opponent_zero_shot_second_half_flag,

    toInt32(coalesce(hss.away_shots_first_half, 0) - coalesce(hss.home_shots_first_half, 0))
        AS half_shot_gap_first_half,
    toInt32(coalesce(hss.away_shots_second_half, 0) - coalesce(hss.home_shots_second_half, 0))
        AS half_shot_gap_second_half,

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
        100.0 * coalesce(ps.shots_on_target_away, 0) / nullIf(coalesce(ps.total_shots_away, 0), 0),
        1
    ), 0.0)) AS triggered_team_on_target_ratio_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_home, 0) / nullIf(coalesce(ps.total_shots_home, 0), 0),
        1
    ), 0.0)) AS opponent_on_target_ratio_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.shots_on_target_away, 0) / nullIf(coalesce(ps.total_shots_away, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.shots_on_target_home, 0) / nullIf(coalesce(ps.total_shots_home, 0), 0),
            1
        ), 0.0),
        1
    )) AS on_target_ratio_delta_pct,

    toFloat32(coalesce(ps.expected_goals_away, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_away, 0) - coalesce(ps.expected_goals_home, 0), 3))
        AS xg_delta,

    toInt32(coalesce(ps.big_chances_away, 0)) AS triggered_team_big_chances,
    toInt32(coalesce(ps.big_chances_home, 0)) AS opponent_big_chances,
    toInt32(coalesce(ps.big_chances_missed_away, 0)) AS triggered_team_big_chances_missed,
    toInt32(coalesce(ps.big_chances_missed_home, 0)) AS opponent_big_chances_missed,

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
            100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
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
INNER JOIN half_shot_stats AS hss
    ON hss.match_id = m.match_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND hss.has_first_half_period_row_flag = 1
  AND hss.has_second_half_period_row_flag = 1
  AND (
      coalesce(hss.away_shots_first_half, 0) = 0
      OR coalesce(hss.away_shots_second_half, 0) = 0
  );
