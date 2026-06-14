INSERT INTO gold.sig_team_possession_passing_short_pass_philosophy (
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
    trigger_threshold_long_ball_share_pct,
    triggered_team_long_ball_attempts,
    opponent_long_ball_attempts,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_long_ball_share_pct,
    opponent_long_ball_share_pct,
    long_ball_share_delta_pct,
    triggered_team_accurate_passes,
    opponent_accurate_passes,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_own_half_passes,
    opponent_own_half_passes,
    triggered_team_opposition_half_passes,
    opponent_opposition_half_passes,
    triggered_team_own_half_pass_share_pct,
    opponent_own_half_pass_share_pct,
    triggered_team_opposition_half_pass_share_pct,
    opponent_opposition_half_pass_share_pct,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_xg,
    opponent_xg,
    xg_delta
)
-- Signal: sig_team_possession_passing_short_pass_philosophy
-- Trigger: team long-ball attempts are <= 5% of total pass attempts.
-- Intent: identify teams whose full-match passing profile is strongly short-passing oriented.

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

    -- Trigger guardrail.
    toFloat32(5.0) AS trigger_threshold_long_ball_share_pct,

    -- Long-ball and passing volume (core trigger pair).
    coalesce(ps.long_ball_attempts_home, 0) AS triggered_team_long_ball_attempts,
    coalesce(ps.long_ball_attempts_away, 0) AS opponent_long_ball_attempts,
    coalesce(ps.pass_attempts_home, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_away, 0) AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.long_ball_attempts_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS triggered_team_long_ball_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.long_ball_attempts_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS opponent_long_ball_share_pct,
    toFloat32(round(
        coalesce(round(100.0 * coalesce(ps.long_ball_attempts_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0)
      - coalesce(round(100.0 * coalesce(ps.long_ball_attempts_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0),
        1
    )) AS long_ball_share_delta_pct,

    -- Passing quality and possession context.
    coalesce(ps.accurate_passes_home, 0) AS triggered_team_accurate_passes,
    coalesce(ps.accurate_passes_away, 0) AS opponent_accurate_passes,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0)
      - coalesce(round(100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_home, 0) - coalesce(ps.ball_possession_away, 0), 1)) AS possession_delta_pct,

    -- Territorial distribution of short passing.
    coalesce(ps.own_half_passes_home, 0) AS triggered_team_own_half_passes,
    coalesce(ps.own_half_passes_away, 0) AS opponent_own_half_passes,
    coalesce(ps.opposition_half_passes_home, 0) AS triggered_team_opposition_half_passes,
    coalesce(ps.opposition_half_passes_away, 0) AS opponent_opposition_half_passes,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.own_half_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS triggered_team_own_half_pass_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.own_half_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS opponent_own_half_pass_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.opposition_half_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS triggered_team_opposition_half_pass_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.opposition_half_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS opponent_opposition_half_pass_share_pct,

    -- Attacking output context.
    coalesce(ps.touches_opp_box_home, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_away, 0) AS opponent_touches_opposition_box,
    coalesce(ps.total_shots_home, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_away, 0) AS opponent_total_shots,
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
  AND coalesce(ps.pass_attempts_home, 0) > 0
  AND coalesce(round(100.0 * coalesce(ps.long_ball_attempts_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0) <= 5

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

    -- Trigger guardrail.
    toFloat32(5.0) AS trigger_threshold_long_ball_share_pct,

    -- Long-ball and passing volume (core trigger pair).
    coalesce(ps.long_ball_attempts_away, 0) AS triggered_team_long_ball_attempts,
    coalesce(ps.long_ball_attempts_home, 0) AS opponent_long_ball_attempts,
    coalesce(ps.pass_attempts_away, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_home, 0) AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.long_ball_attempts_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS triggered_team_long_ball_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.long_ball_attempts_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS opponent_long_ball_share_pct,
    toFloat32(round(
        coalesce(round(100.0 * coalesce(ps.long_ball_attempts_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0)
      - coalesce(round(100.0 * coalesce(ps.long_ball_attempts_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0),
        1
    )) AS long_ball_share_delta_pct,

    -- Passing quality and possession context.
    coalesce(ps.accurate_passes_away, 0) AS triggered_team_accurate_passes,
    coalesce(ps.accurate_passes_home, 0) AS opponent_accurate_passes,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0)
      - coalesce(round(100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_away, 0) - coalesce(ps.ball_possession_home, 0), 1)) AS possession_delta_pct,

    -- Territorial distribution of short passing.
    coalesce(ps.own_half_passes_away, 0) AS triggered_team_own_half_passes,
    coalesce(ps.own_half_passes_home, 0) AS opponent_own_half_passes,
    coalesce(ps.opposition_half_passes_away, 0) AS triggered_team_opposition_half_passes,
    coalesce(ps.opposition_half_passes_home, 0) AS opponent_opposition_half_passes,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.own_half_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS triggered_team_own_half_pass_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.own_half_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS opponent_own_half_pass_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.opposition_half_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS triggered_team_opposition_half_pass_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.opposition_half_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS opponent_opposition_half_pass_share_pct,

    -- Attacking output context.
    coalesce(ps.touches_opp_box_away, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_home, 0) AS opponent_touches_opposition_box,
    coalesce(ps.total_shots_away, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_home, 0) AS opponent_total_shots,
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
  AND coalesce(ps.pass_attempts_away, 0) > 0
  AND coalesce(round(100.0 * coalesce(ps.long_ball_attempts_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0) <= 5

ORDER BY
    assumeNotNull(triggered_team_long_ball_share_pct) ASC,
    m.match_date DESC,
    m.match_id DESC;
