INSERT INTO gold.sig_team_possession_passing_cross_spam (
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
    trigger_threshold_cross_attempts,
    triggered_team_cross_attempts,
    opponent_cross_attempts,
    cross_attempts_delta,
    triggered_team_accurate_crosses,
    opponent_accurate_crosses,
    triggered_team_cross_accuracy_pct,
    opponent_cross_accuracy_pct,
    cross_accuracy_delta_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_cross_share_of_passes_pct,
    opponent_cross_share_of_passes_pct,
    cross_share_of_passes_delta_pct,
    triggered_team_opposition_half_passes,
    opponent_opposition_half_passes,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_crosses_per_shot,
    opponent_crosses_per_shot,
    triggered_team_corners,
    opponent_corners,
    triggered_team_xg,
    opponent_xg,
    xg_delta
)
-- Signal: sig_team_possession_passing_cross_spam
-- Trigger: Team attempts >= 35 crosses in a single match.
-- Intent: identify side-oriented crossing spam behavior and quantify whether volume translated into territorial and chance-quality advantage.

-- Home-side triggers.
SELECT
    -- Match identifiers.
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    -- Triggered team and opponent identifiers.
    'home' AS triggered_side,
    m.home_team_id AS triggered_team_id,
    m.home_team_name AS triggered_team_name,
    m.away_team_id AS opponent_team_id,
    m.away_team_name AS opponent_team_name,

    -- Trigger constants and core crossing values.
    35 AS trigger_threshold_cross_attempts,
    coalesce(ps.cross_attempts_home, 0) AS triggered_team_cross_attempts,
    coalesce(ps.cross_attempts_away, 0) AS opponent_cross_attempts,
    coalesce(ps.cross_attempts_home, 0) - coalesce(ps.cross_attempts_away, 0) AS cross_attempts_delta,
    coalesce(ps.accurate_crosses_home, 0) AS triggered_team_accurate_crosses,
    coalesce(ps.accurate_crosses_away, 0) AS opponent_accurate_crosses,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_crosses_home, 0) / nullIf(toFloat64(coalesce(ps.cross_attempts_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_cross_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_crosses_away, 0) / nullIf(toFloat64(coalesce(ps.cross_attempts_away, 0)), 0),
        1
    ), 0.0)) AS opponent_cross_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_crosses_home, 0) / nullIf(toFloat64(coalesce(ps.cross_attempts_home, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_crosses_away, 0) / nullIf(toFloat64(coalesce(ps.cross_attempts_away, 0)), 0),
            1
        ), 0.0),
        1
    )) AS cross_accuracy_delta_pct,

    -- Passing denominator and passing-quality context.
    coalesce(ps.pass_attempts_home, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_away, 0) AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.cross_attempts_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_cross_share_of_passes_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.cross_attempts_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
        1
    ), 0.0)) AS opponent_cross_share_of_passes_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.cross_attempts_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.cross_attempts_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
            1
        ), 0.0),
        1
    )) AS cross_share_of_passes_delta_pct,

    -- Territorial and attacking output context.
    coalesce(ps.opposition_half_passes_home, 0) AS triggered_team_opposition_half_passes,
    coalesce(ps.opposition_half_passes_away, 0) AS opponent_opposition_half_passes,
    coalesce(ps.touches_opp_box_home, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_away, 0) AS opponent_touches_opposition_box,
    coalesce(ps.total_shots_home, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_away, 0) AS opponent_total_shots,
    toFloat32(coalesce(round(
        coalesce(ps.cross_attempts_home, 0) / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        2
    ), 0.0)) AS triggered_team_crosses_per_shot,
    toFloat32(coalesce(round(
        coalesce(ps.cross_attempts_away, 0) / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        2
    ), 0.0)) AS opponent_crosses_per_shot,
    coalesce(ps.corners_home, 0) AS triggered_team_corners,
    coalesce(ps.corners_away, 0) AS opponent_corners,
    toFloat32(coalesce(ps.expected_goals_home, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_home, 0) - coalesce(ps.expected_goals_away, 0), 3)) AS xg_delta

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ps.cross_attempts_home, 0) >= 35

UNION ALL

-- Away-side triggers.
SELECT
    -- Match identifiers.
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    -- Triggered team and opponent identifiers.
    'away' AS triggered_side,
    m.away_team_id AS triggered_team_id,
    m.away_team_name AS triggered_team_name,
    m.home_team_id AS opponent_team_id,
    m.home_team_name AS opponent_team_name,

    -- Trigger constants and core crossing values.
    35 AS trigger_threshold_cross_attempts,
    coalesce(ps.cross_attempts_away, 0) AS triggered_team_cross_attempts,
    coalesce(ps.cross_attempts_home, 0) AS opponent_cross_attempts,
    coalesce(ps.cross_attempts_away, 0) - coalesce(ps.cross_attempts_home, 0) AS cross_attempts_delta,
    coalesce(ps.accurate_crosses_away, 0) AS triggered_team_accurate_crosses,
    coalesce(ps.accurate_crosses_home, 0) AS opponent_accurate_crosses,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_crosses_away, 0) / nullIf(toFloat64(coalesce(ps.cross_attempts_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_cross_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_crosses_home, 0) / nullIf(toFloat64(coalesce(ps.cross_attempts_home, 0)), 0),
        1
    ), 0.0)) AS opponent_cross_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_crosses_away, 0) / nullIf(toFloat64(coalesce(ps.cross_attempts_away, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_crosses_home, 0) / nullIf(toFloat64(coalesce(ps.cross_attempts_home, 0)), 0),
            1
        ), 0.0),
        1
    )) AS cross_accuracy_delta_pct,

    -- Passing denominator and passing-quality context.
    coalesce(ps.pass_attempts_away, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_home, 0) AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.cross_attempts_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_cross_share_of_passes_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.cross_attempts_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
        1
    ), 0.0)) AS opponent_cross_share_of_passes_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.cross_attempts_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.cross_attempts_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
            1
        ), 0.0),
        1
    )) AS cross_share_of_passes_delta_pct,

    -- Territorial and attacking output context.
    coalesce(ps.opposition_half_passes_away, 0) AS triggered_team_opposition_half_passes,
    coalesce(ps.opposition_half_passes_home, 0) AS opponent_opposition_half_passes,
    coalesce(ps.touches_opp_box_away, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_home, 0) AS opponent_touches_opposition_box,
    coalesce(ps.total_shots_away, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_home, 0) AS opponent_total_shots,
    toFloat32(coalesce(round(
        coalesce(ps.cross_attempts_away, 0) / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        2
    ), 0.0)) AS triggered_team_crosses_per_shot,
    toFloat32(coalesce(round(
        coalesce(ps.cross_attempts_home, 0) / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        2
    ), 0.0)) AS opponent_crosses_per_shot,
    coalesce(ps.corners_away, 0) AS triggered_team_corners,
    coalesce(ps.corners_home, 0) AS opponent_corners,
    toFloat32(coalesce(ps.expected_goals_away, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_away, 0) - coalesce(ps.expected_goals_home, 0), 3)) AS xg_delta

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ps.cross_attempts_away, 0) >= 35

ORDER BY
    assumeNotNull(triggered_team_cross_attempts) DESC,
    m.match_date DESC,
    m.match_id DESC;
