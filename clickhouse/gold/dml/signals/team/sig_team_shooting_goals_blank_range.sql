INSERT INTO gold.sig_team_shooting_goals_blank_range (
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
    trigger_threshold_min_xg,
    trigger_required_goals,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_goals_minus_xg,
    opponent_goals_minus_xg,
    goals_minus_xg_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    total_shots_delta,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    triggered_team_on_target_ratio_pct,
    opponent_on_target_ratio_pct,
    on_target_ratio_delta_pct,
    triggered_team_big_chances,
    opponent_big_chances,
    triggered_team_big_chances_missed,
    opponent_big_chances_missed,
    triggered_team_xg_per_shot,
    opponent_xg_per_shot,
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
-- Signal: sig_team_shooting_goals_blank_range
-- Trigger: Team fails to score despite total match xG > 2.5 (`period = 'All'`).
-- Intent: Detect severe team-level finishing underperformance and preserve bilateral context for diagnostics.

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

    toFloat32(2.5) AS trigger_threshold_min_xg,
    toInt32(0) AS trigger_required_goals,
    coalesce(m.home_score, 0) AS triggered_team_goals,
    coalesce(m.away_score, 0) AS opponent_goals,
    coalesce(m.home_score, 0) - coalesce(m.away_score, 0) AS goal_delta,

    toFloat32(coalesce(ps.expected_goals_home, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_home, 0) - coalesce(ps.expected_goals_away, 0), 3)) AS xg_delta,
    toFloat32(round(coalesce(m.home_score, 0) - coalesce(ps.expected_goals_home, 0), 3))
        AS triggered_team_goals_minus_xg,
    toFloat32(round(coalesce(m.away_score, 0) - coalesce(ps.expected_goals_away, 0), 3))
        AS opponent_goals_minus_xg,
    toFloat32(round(
        (coalesce(m.home_score, 0) - coalesce(ps.expected_goals_home, 0))
      - (coalesce(m.away_score, 0) - coalesce(ps.expected_goals_away, 0)),
        3
    )) AS goals_minus_xg_delta,

    coalesce(ps.total_shots_home, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_away, 0) AS opponent_total_shots,
    coalesce(ps.total_shots_home, 0) - coalesce(ps.total_shots_away, 0) AS total_shots_delta,
    coalesce(ps.shots_on_target_home, 0) AS triggered_team_shots_on_target,
    coalesce(ps.shots_on_target_away, 0) AS opponent_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_home, 0)
            / nullIf(coalesce(ps.total_shots_home, 0), 0),
        1
    ), 0.0)) AS triggered_team_on_target_ratio_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_away, 0)
            / nullIf(coalesce(ps.total_shots_away, 0), 0),
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

    coalesce(ps.big_chances_home, 0) AS triggered_team_big_chances,
    coalesce(ps.big_chances_away, 0) AS opponent_big_chances,
    coalesce(ps.big_chances_missed_home, 0) AS triggered_team_big_chances_missed,
    coalesce(ps.big_chances_missed_away, 0) AS opponent_big_chances_missed,
    toFloat32(coalesce(round(
        coalesce(ps.expected_goals_home, 0) / nullIf(toFloat32(coalesce(ps.total_shots_home, 0)), 0.0),
        3
    ), 0.0)) AS triggered_team_xg_per_shot,
    toFloat32(coalesce(round(
        coalesce(ps.expected_goals_away, 0) / nullIf(toFloat32(coalesce(ps.total_shots_away, 0)), 0.0),
        3
    ), 0.0)) AS opponent_xg_per_shot,

    coalesce(ps.touches_opp_box_home, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_away, 0) AS opponent_touches_opposition_box,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_home, 0) - coalesce(ps.ball_possession_away, 0), 1))
        AS possession_delta_pct,
    coalesce(ps.pass_attempts_home, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_away, 0) AS opponent_pass_attempts,
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
    coalesce(ps.corners_home, 0) AS triggered_team_corners,
    coalesce(ps.corners_away, 0) AS opponent_corners

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(m.home_score, 0) = 0
  AND coalesce(ps.expected_goals_home, 0) > 2.5

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

    toFloat32(2.5) AS trigger_threshold_min_xg,
    toInt32(0) AS trigger_required_goals,
    coalesce(m.away_score, 0) AS triggered_team_goals,
    coalesce(m.home_score, 0) AS opponent_goals,
    coalesce(m.away_score, 0) - coalesce(m.home_score, 0) AS goal_delta,

    toFloat32(coalesce(ps.expected_goals_away, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_away, 0) - coalesce(ps.expected_goals_home, 0), 3)) AS xg_delta,
    toFloat32(round(coalesce(m.away_score, 0) - coalesce(ps.expected_goals_away, 0), 3))
        AS triggered_team_goals_minus_xg,
    toFloat32(round(coalesce(m.home_score, 0) - coalesce(ps.expected_goals_home, 0), 3))
        AS opponent_goals_minus_xg,
    toFloat32(round(
        (coalesce(m.away_score, 0) - coalesce(ps.expected_goals_away, 0))
      - (coalesce(m.home_score, 0) - coalesce(ps.expected_goals_home, 0)),
        3
    )) AS goals_minus_xg_delta,

    coalesce(ps.total_shots_away, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_home, 0) AS opponent_total_shots,
    coalesce(ps.total_shots_away, 0) - coalesce(ps.total_shots_home, 0) AS total_shots_delta,
    coalesce(ps.shots_on_target_away, 0) AS triggered_team_shots_on_target,
    coalesce(ps.shots_on_target_home, 0) AS opponent_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_away, 0)
            / nullIf(coalesce(ps.total_shots_away, 0), 0),
        1
    ), 0.0)) AS triggered_team_on_target_ratio_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_home, 0)
            / nullIf(coalesce(ps.total_shots_home, 0), 0),
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

    coalesce(ps.big_chances_away, 0) AS triggered_team_big_chances,
    coalesce(ps.big_chances_home, 0) AS opponent_big_chances,
    coalesce(ps.big_chances_missed_away, 0) AS triggered_team_big_chances_missed,
    coalesce(ps.big_chances_missed_home, 0) AS opponent_big_chances_missed,
    toFloat32(coalesce(round(
        coalesce(ps.expected_goals_away, 0) / nullIf(toFloat32(coalesce(ps.total_shots_away, 0)), 0.0),
        3
    ), 0.0)) AS triggered_team_xg_per_shot,
    toFloat32(coalesce(round(
        coalesce(ps.expected_goals_home, 0) / nullIf(toFloat32(coalesce(ps.total_shots_home, 0)), 0.0),
        3
    ), 0.0)) AS opponent_xg_per_shot,

    coalesce(ps.touches_opp_box_away, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_home, 0) AS opponent_touches_opposition_box,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_away, 0) - coalesce(ps.ball_possession_home, 0), 1))
        AS possession_delta_pct,
    coalesce(ps.pass_attempts_away, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_home, 0) AS opponent_pass_attempts,
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
    coalesce(ps.corners_away, 0) AS triggered_team_corners,
    coalesce(ps.corners_home, 0) AS opponent_corners

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(m.away_score, 0) = 0
  AND coalesce(ps.expected_goals_away, 0) > 2.5

ORDER BY
    triggered_team_xg DESC,
    m.match_date DESC,
    m.match_id DESC;
