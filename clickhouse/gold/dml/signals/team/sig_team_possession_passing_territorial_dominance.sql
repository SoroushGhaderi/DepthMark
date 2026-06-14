INSERT INTO gold.sig_team_possession_passing_territorial_dominance (
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
    trigger_threshold_opposition_box_touches,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    opposition_box_touches_delta,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_opposition_half_passes,
    opponent_opposition_half_passes,
    opposition_half_passes_delta,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    pass_attempts_delta,
    triggered_team_accurate_passes,
    opponent_accurate_passes,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_total_shots,
    opponent_total_shots,
    shot_volume_delta,
    triggered_team_shots_inside_box,
    opponent_shots_inside_box,
    shots_inside_box_delta,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_big_chances,
    opponent_big_chances,
    triggered_team_corners,
    opponent_corners,
    triggered_team_xg_per_opposition_box_touch,
    opponent_xg_per_opposition_box_touch,
    xg_per_opposition_box_touch_delta
)
-- Signal: sig_team_possession_passing_territorial_dominance
-- Intent: identify teams that sustain high opposition-box touch volume as a territorial-control pattern,
-- then contextualize whether that dominance produced superior progression, shot profile, and chance quality.
-- Trigger: Team records >= 40 touches in the opposition box.

-- Home-side triggers.
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

    40 AS trigger_threshold_opposition_box_touches,
    coalesce(ps.touches_opp_box_home, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_away, 0) AS opponent_touches_opposition_box,
    coalesce(ps.touches_opp_box_home, 0) - coalesce(ps.touches_opp_box_away, 0) AS opposition_box_touches_delta,

    toFloat32(assumeNotNull(ps.ball_possession_home)) AS triggered_team_possession_pct,
    toFloat32(assumeNotNull(ps.ball_possession_away)) AS opponent_possession_pct,
    toFloat32(round(assumeNotNull(ps.ball_possession_home) - assumeNotNull(ps.ball_possession_away), 1)) AS possession_delta_pct,

    coalesce(ps.opposition_half_passes_home, 0) AS triggered_team_opposition_half_passes,
    coalesce(ps.opposition_half_passes_away, 0) AS opponent_opposition_half_passes,
    coalesce(ps.opposition_half_passes_home, 0) - coalesce(ps.opposition_half_passes_away, 0) AS opposition_half_passes_delta,

    coalesce(ps.pass_attempts_home, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_away, 0) AS opponent_pass_attempts,
    coalesce(ps.pass_attempts_home, 0) - coalesce(ps.pass_attempts_away, 0) AS pass_attempts_delta,

    coalesce(ps.accurate_passes_home, 0) AS triggered_team_accurate_passes,
    coalesce(ps.accurate_passes_away, 0) AS opponent_accurate_passes,
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
            100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    coalesce(ps.total_shots_home, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_away, 0) AS opponent_total_shots,
    coalesce(ps.total_shots_home, 0) - coalesce(ps.total_shots_away, 0) AS shot_volume_delta,
    coalesce(ps.shots_inside_box_home, 0) AS triggered_team_shots_inside_box,
    coalesce(ps.shots_inside_box_away, 0) AS opponent_shots_inside_box,
    coalesce(ps.shots_inside_box_home, 0) - coalesce(ps.shots_inside_box_away, 0) AS shots_inside_box_delta,
    coalesce(ps.shots_on_target_home, 0) AS triggered_team_shots_on_target,
    coalesce(ps.shots_on_target_away, 0) AS opponent_shots_on_target,

    toFloat32(coalesce(ps.expected_goals_home, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_home, 0) - coalesce(ps.expected_goals_away, 0), 3)) AS xg_delta,

    coalesce(ps.big_chances_home, 0) AS triggered_team_big_chances,
    coalesce(ps.big_chances_away, 0) AS opponent_big_chances,
    coalesce(ps.corners_home, 0) AS triggered_team_corners,
    coalesce(ps.corners_away, 0) AS opponent_corners,

    toFloat32(coalesce(round(
        coalesce(ps.expected_goals_home, 0) / nullIf(toFloat64(coalesce(ps.touches_opp_box_home, 0)), 0),
        4
    ), 0.0)) AS triggered_team_xg_per_opposition_box_touch,
    toFloat32(coalesce(round(
        coalesce(ps.expected_goals_away, 0) / nullIf(toFloat64(coalesce(ps.touches_opp_box_away, 0)), 0),
        4
    ), 0.0)) AS opponent_xg_per_opposition_box_touch,
    toFloat32(round(
        coalesce(round(
            coalesce(ps.expected_goals_home, 0) / nullIf(toFloat64(coalesce(ps.touches_opp_box_home, 0)), 0),
            4
        ), 0.0)
      - coalesce(round(
            coalesce(ps.expected_goals_away, 0) / nullIf(toFloat64(coalesce(ps.touches_opp_box_away, 0)), 0),
            4
        ), 0.0),
        4
    )) AS xg_per_opposition_box_touch_delta

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ps.touches_opp_box_home, 0) >= 40

UNION ALL

-- Away-side triggers.
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

    40 AS trigger_threshold_opposition_box_touches,
    coalesce(ps.touches_opp_box_away, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_home, 0) AS opponent_touches_opposition_box,
    coalesce(ps.touches_opp_box_away, 0) - coalesce(ps.touches_opp_box_home, 0) AS opposition_box_touches_delta,

    toFloat32(assumeNotNull(ps.ball_possession_away)) AS triggered_team_possession_pct,
    toFloat32(assumeNotNull(ps.ball_possession_home)) AS opponent_possession_pct,
    toFloat32(round(assumeNotNull(ps.ball_possession_away) - assumeNotNull(ps.ball_possession_home), 1)) AS possession_delta_pct,

    coalesce(ps.opposition_half_passes_away, 0) AS triggered_team_opposition_half_passes,
    coalesce(ps.opposition_half_passes_home, 0) AS opponent_opposition_half_passes,
    coalesce(ps.opposition_half_passes_away, 0) - coalesce(ps.opposition_half_passes_home, 0) AS opposition_half_passes_delta,

    coalesce(ps.pass_attempts_away, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_home, 0) AS opponent_pass_attempts,
    coalesce(ps.pass_attempts_away, 0) - coalesce(ps.pass_attempts_home, 0) AS pass_attempts_delta,

    coalesce(ps.accurate_passes_away, 0) AS triggered_team_accurate_passes,
    coalesce(ps.accurate_passes_home, 0) AS opponent_accurate_passes,
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
            100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    coalesce(ps.total_shots_away, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_home, 0) AS opponent_total_shots,
    coalesce(ps.total_shots_away, 0) - coalesce(ps.total_shots_home, 0) AS shot_volume_delta,
    coalesce(ps.shots_inside_box_away, 0) AS triggered_team_shots_inside_box,
    coalesce(ps.shots_inside_box_home, 0) AS opponent_shots_inside_box,
    coalesce(ps.shots_inside_box_away, 0) - coalesce(ps.shots_inside_box_home, 0) AS shots_inside_box_delta,
    coalesce(ps.shots_on_target_away, 0) AS triggered_team_shots_on_target,
    coalesce(ps.shots_on_target_home, 0) AS opponent_shots_on_target,

    toFloat32(coalesce(ps.expected_goals_away, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_away, 0) - coalesce(ps.expected_goals_home, 0), 3)) AS xg_delta,

    coalesce(ps.big_chances_away, 0) AS triggered_team_big_chances,
    coalesce(ps.big_chances_home, 0) AS opponent_big_chances,
    coalesce(ps.corners_away, 0) AS triggered_team_corners,
    coalesce(ps.corners_home, 0) AS opponent_corners,

    toFloat32(coalesce(round(
        coalesce(ps.expected_goals_away, 0) / nullIf(toFloat64(coalesce(ps.touches_opp_box_away, 0)), 0),
        4
    ), 0.0)) AS triggered_team_xg_per_opposition_box_touch,
    toFloat32(coalesce(round(
        coalesce(ps.expected_goals_home, 0) / nullIf(toFloat64(coalesce(ps.touches_opp_box_home, 0)), 0),
        4
    ), 0.0)) AS opponent_xg_per_opposition_box_touch,
    toFloat32(round(
        coalesce(round(
            coalesce(ps.expected_goals_away, 0) / nullIf(toFloat64(coalesce(ps.touches_opp_box_away, 0)), 0),
            4
        ), 0.0)
      - coalesce(round(
            coalesce(ps.expected_goals_home, 0) / nullIf(toFloat64(coalesce(ps.touches_opp_box_home, 0)), 0),
            4
        ), 0.0),
        4
    )) AS xg_per_opposition_box_touch_delta

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ps.touches_opp_box_away, 0) >= 40

ORDER BY
    assumeNotNull(triggered_team_touches_opposition_box) DESC,
    m.match_date DESC,
    m.match_id DESC;
