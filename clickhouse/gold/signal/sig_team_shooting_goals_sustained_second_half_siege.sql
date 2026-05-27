INSERT INTO gold.sig_team_shooting_goals_sustained_second_half_siege (
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
    trigger_threshold_min_second_half_shots,
    trigger_threshold_required_half_minutes,
    has_first_half_period_row_flag,
    has_second_half_period_row_flag,
    triggered_team_shots_first_half,
    triggered_team_shots_second_half,
    opponent_shots_first_half,
    opponent_shots_second_half,
    first_half_shots_delta,
    second_half_shots_delta,
    triggered_team_second_half_shot_share_pct,
    opponent_second_half_shot_share_pct,
    second_half_shot_share_delta_pct,
    triggered_team_shots_on_target_second_half,
    opponent_shots_on_target_second_half,
    shots_on_target_second_half_delta,
    triggered_team_on_target_ratio_second_half_pct,
    opponent_on_target_ratio_second_half_pct,
    on_target_ratio_second_half_delta_pct,
    triggered_team_xg_second_half,
    opponent_xg_second_half,
    xg_second_half_delta,
    triggered_team_xg_per_shot_second_half,
    opponent_xg_per_shot_second_half,
    xg_per_shot_second_half_delta,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    total_shots_delta,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
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
WITH half_shot_stats AS (
    SELECT
        ps.match_id,
        maxIf(coalesce(ps.total_shots_home, 0), ps.period = 'FirstHalf') AS home_shots_first_half,
        maxIf(coalesce(ps.total_shots_home, 0), ps.period = 'SecondHalf') AS home_shots_second_half,
        maxIf(coalesce(ps.total_shots_away, 0), ps.period = 'FirstHalf') AS away_shots_first_half,
        maxIf(coalesce(ps.total_shots_away, 0), ps.period = 'SecondHalf') AS away_shots_second_half,
        maxIf(coalesce(ps.shots_on_target_home, 0), ps.period = 'SecondHalf')
            AS home_shots_on_target_second_half,
        maxIf(coalesce(ps.shots_on_target_away, 0), ps.period = 'SecondHalf')
            AS away_shots_on_target_second_half,
        maxIf(coalesce(ps.expected_goals_home, 0), ps.period = 'SecondHalf') AS home_xg_second_half,
        maxIf(coalesce(ps.expected_goals_away, 0), ps.period = 'SecondHalf') AS away_xg_second_half,
        toInt8(maxIf(1, ps.period = 'FirstHalf')) AS has_first_half_period_row_flag,
        toInt8(maxIf(1, ps.period = 'SecondHalf')) AS has_second_half_period_row_flag
    FROM silver.period_stat AS ps
    WHERE ps.period IN ('FirstHalf', 'SecondHalf')
    GROUP BY ps.match_id
)
-- Signal: sig_team_shooting_goals_sustained_second_half_siege
-- Trigger: team records >= 15 total shots in SecondHalf.
-- Intent: detect sustained post-halftime attacking sieges and preserve bilateral half-level
--         and full-match context to evaluate pressure translation and execution quality.

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

    toInt32(15) AS trigger_threshold_min_second_half_shots,
    toInt32(45) AS trigger_threshold_required_half_minutes,
    hss.has_first_half_period_row_flag,
    hss.has_second_half_period_row_flag,

    toInt32(coalesce(hss.home_shots_first_half, 0)) AS triggered_team_shots_first_half,
    toInt32(coalesce(hss.home_shots_second_half, 0)) AS triggered_team_shots_second_half,
    toInt32(coalesce(hss.away_shots_first_half, 0)) AS opponent_shots_first_half,
    toInt32(coalesce(hss.away_shots_second_half, 0)) AS opponent_shots_second_half,

    toInt32(coalesce(hss.home_shots_first_half, 0) - coalesce(hss.away_shots_first_half, 0))
        AS first_half_shots_delta,
    toInt32(coalesce(hss.home_shots_second_half, 0) - coalesce(hss.away_shots_second_half, 0))
        AS second_half_shots_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(hss.home_shots_second_half, 0) / nullIf(coalesce(ps.total_shots_home, 0), 0),
        1
    ), 0.0)) AS triggered_team_second_half_shot_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(hss.away_shots_second_half, 0) / nullIf(coalesce(ps.total_shots_away, 0), 0),
        1
    ), 0.0)) AS opponent_second_half_shot_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(hss.home_shots_second_half, 0)
                / nullIf(coalesce(ps.total_shots_home, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(hss.away_shots_second_half, 0)
                / nullIf(coalesce(ps.total_shots_away, 0), 0),
            1
        ), 0.0),
        1
    )) AS second_half_shot_share_delta_pct,

    toInt32(coalesce(hss.home_shots_on_target_second_half, 0)) AS triggered_team_shots_on_target_second_half,
    toInt32(coalesce(hss.away_shots_on_target_second_half, 0)) AS opponent_shots_on_target_second_half,
    toInt32(
        coalesce(hss.home_shots_on_target_second_half, 0)
      - coalesce(hss.away_shots_on_target_second_half, 0)
    ) AS shots_on_target_second_half_delta,
    toFloat32(coalesce(round(
        100.0 * coalesce(hss.home_shots_on_target_second_half, 0)
            / nullIf(coalesce(hss.home_shots_second_half, 0), 0),
        1
    ), 0.0)) AS triggered_team_on_target_ratio_second_half_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(hss.away_shots_on_target_second_half, 0)
            / nullIf(coalesce(hss.away_shots_second_half, 0), 0),
        1
    ), 0.0)) AS opponent_on_target_ratio_second_half_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(hss.home_shots_on_target_second_half, 0)
                / nullIf(coalesce(hss.home_shots_second_half, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(hss.away_shots_on_target_second_half, 0)
                / nullIf(coalesce(hss.away_shots_second_half, 0), 0),
            1
        ), 0.0),
        1
    )) AS on_target_ratio_second_half_delta_pct,

    toFloat32(coalesce(hss.home_xg_second_half, 0)) AS triggered_team_xg_second_half,
    toFloat32(coalesce(hss.away_xg_second_half, 0)) AS opponent_xg_second_half,
    toFloat32(round(coalesce(hss.home_xg_second_half, 0) - coalesce(hss.away_xg_second_half, 0), 3))
        AS xg_second_half_delta,
    toFloat32(coalesce(round(
        coalesce(hss.home_xg_second_half, 0) / nullIf(toFloat32(coalesce(hss.home_shots_second_half, 0)), 0.0),
        3
    ), 0.0)) AS triggered_team_xg_per_shot_second_half,
    toFloat32(coalesce(round(
        coalesce(hss.away_xg_second_half, 0) / nullIf(toFloat32(coalesce(hss.away_shots_second_half, 0)), 0.0),
        3
    ), 0.0)) AS opponent_xg_per_shot_second_half,
    toFloat32(round(
        coalesce(round(
            coalesce(hss.home_xg_second_half, 0)
                / nullIf(toFloat32(coalesce(hss.home_shots_second_half, 0)), 0.0),
            3
        ), 0.0)
      - coalesce(round(
            coalesce(hss.away_xg_second_half, 0)
                / nullIf(toFloat32(coalesce(hss.away_shots_second_half, 0)), 0.0),
            3
        ), 0.0),
        3
    )) AS xg_per_shot_second_half_delta,

    toInt32(coalesce(m.home_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.away_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.home_score, 0) - coalesce(m.away_score, 0)) AS goal_delta,

    toInt32(coalesce(ps.total_shots_home, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_away, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.total_shots_home, 0) - coalesce(ps.total_shots_away, 0)) AS total_shots_delta,

    toInt32(coalesce(ps.shots_on_target_home, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS opponent_shots_on_target,
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
            100.0 * coalesce(ps.shots_on_target_home, 0)
                / nullIf(coalesce(ps.total_shots_home, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.shots_on_target_away, 0)
                / nullIf(coalesce(ps.total_shots_away, 0), 0),
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
  AND coalesce(hss.home_shots_second_half, 0) >= 15

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

    toInt32(15) AS trigger_threshold_min_second_half_shots,
    toInt32(45) AS trigger_threshold_required_half_minutes,
    hss.has_first_half_period_row_flag,
    hss.has_second_half_period_row_flag,

    toInt32(coalesce(hss.away_shots_first_half, 0)) AS triggered_team_shots_first_half,
    toInt32(coalesce(hss.away_shots_second_half, 0)) AS triggered_team_shots_second_half,
    toInt32(coalesce(hss.home_shots_first_half, 0)) AS opponent_shots_first_half,
    toInt32(coalesce(hss.home_shots_second_half, 0)) AS opponent_shots_second_half,

    toInt32(coalesce(hss.away_shots_first_half, 0) - coalesce(hss.home_shots_first_half, 0))
        AS first_half_shots_delta,
    toInt32(coalesce(hss.away_shots_second_half, 0) - coalesce(hss.home_shots_second_half, 0))
        AS second_half_shots_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(hss.away_shots_second_half, 0) / nullIf(coalesce(ps.total_shots_away, 0), 0),
        1
    ), 0.0)) AS triggered_team_second_half_shot_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(hss.home_shots_second_half, 0) / nullIf(coalesce(ps.total_shots_home, 0), 0),
        1
    ), 0.0)) AS opponent_second_half_shot_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(hss.away_shots_second_half, 0)
                / nullIf(coalesce(ps.total_shots_away, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(hss.home_shots_second_half, 0)
                / nullIf(coalesce(ps.total_shots_home, 0), 0),
            1
        ), 0.0),
        1
    )) AS second_half_shot_share_delta_pct,

    toInt32(coalesce(hss.away_shots_on_target_second_half, 0)) AS triggered_team_shots_on_target_second_half,
    toInt32(coalesce(hss.home_shots_on_target_second_half, 0)) AS opponent_shots_on_target_second_half,
    toInt32(
        coalesce(hss.away_shots_on_target_second_half, 0)
      - coalesce(hss.home_shots_on_target_second_half, 0)
    ) AS shots_on_target_second_half_delta,
    toFloat32(coalesce(round(
        100.0 * coalesce(hss.away_shots_on_target_second_half, 0)
            / nullIf(coalesce(hss.away_shots_second_half, 0), 0),
        1
    ), 0.0)) AS triggered_team_on_target_ratio_second_half_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(hss.home_shots_on_target_second_half, 0)
            / nullIf(coalesce(hss.home_shots_second_half, 0), 0),
        1
    ), 0.0)) AS opponent_on_target_ratio_second_half_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(hss.away_shots_on_target_second_half, 0)
                / nullIf(coalesce(hss.away_shots_second_half, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(hss.home_shots_on_target_second_half, 0)
                / nullIf(coalesce(hss.home_shots_second_half, 0), 0),
            1
        ), 0.0),
        1
    )) AS on_target_ratio_second_half_delta_pct,

    toFloat32(coalesce(hss.away_xg_second_half, 0)) AS triggered_team_xg_second_half,
    toFloat32(coalesce(hss.home_xg_second_half, 0)) AS opponent_xg_second_half,
    toFloat32(round(coalesce(hss.away_xg_second_half, 0) - coalesce(hss.home_xg_second_half, 0), 3))
        AS xg_second_half_delta,
    toFloat32(coalesce(round(
        coalesce(hss.away_xg_second_half, 0) / nullIf(toFloat32(coalesce(hss.away_shots_second_half, 0)), 0.0),
        3
    ), 0.0)) AS triggered_team_xg_per_shot_second_half,
    toFloat32(coalesce(round(
        coalesce(hss.home_xg_second_half, 0) / nullIf(toFloat32(coalesce(hss.home_shots_second_half, 0)), 0.0),
        3
    ), 0.0)) AS opponent_xg_per_shot_second_half,
    toFloat32(round(
        coalesce(round(
            coalesce(hss.away_xg_second_half, 0)
                / nullIf(toFloat32(coalesce(hss.away_shots_second_half, 0)), 0.0),
            3
        ), 0.0)
      - coalesce(round(
            coalesce(hss.home_xg_second_half, 0)
                / nullIf(toFloat32(coalesce(hss.home_shots_second_half, 0)), 0.0),
            3
        ), 0.0),
        3
    )) AS xg_per_shot_second_half_delta,

    toInt32(coalesce(m.away_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.home_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.away_score, 0) - coalesce(m.home_score, 0)) AS goal_delta,

    toInt32(coalesce(ps.total_shots_away, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_home, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.total_shots_away, 0) - coalesce(ps.total_shots_home, 0)) AS total_shots_delta,

    toInt32(coalesce(ps.shots_on_target_away, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS opponent_shots_on_target,
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
            100.0 * coalesce(ps.shots_on_target_away, 0)
                / nullIf(coalesce(ps.total_shots_away, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.shots_on_target_home, 0)
                / nullIf(coalesce(ps.total_shots_home, 0), 0),
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
  AND coalesce(hss.away_shots_second_half, 0) >= 15

ORDER BY
    triggered_team_shots_second_half DESC,
    second_half_shots_delta DESC,
    m.match_date DESC,
    m.match_id DESC;
