INSERT INTO gold.sig_team_possession_passing_one_sided_passing (
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
    trigger_threshold_pass_multiplier,
    triggered_team_accurate_passes,
    opponent_accurate_passes,
    triggered_to_opponent_accurate_passes_ratio,
    accurate_passes_delta,
    triggered_team_accurate_pass_share_pct,
    opponent_accurate_pass_share_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_opposition_half_passes,
    opponent_opposition_half_passes,
    opposition_half_passes_delta,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    triggered_team_xg,
    opponent_xg,
    xg_delta
)
-- Signal: sig_team_possession_passing_one_sided_passing
-- Trigger: triggered team accurate passes > 3.0x opponent accurate passes.
-- Intent: identify matches where one side monopolizes completed passing volume and quantify how that imbalance maps to possession, territory, and chance creation.

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

    toFloat32(3.0) AS trigger_threshold_pass_multiplier,
    coalesce(ps.accurate_passes_home, 0) AS triggered_team_accurate_passes,
    coalesce(ps.accurate_passes_away, 0) AS opponent_accurate_passes,
    toFloat32(if(
        coalesce(ps.accurate_passes_away, 0) = 0,
        NULL,
        round(
            toFloat64(coalesce(ps.accurate_passes_home, 0))
            / toFloat64(coalesce(ps.accurate_passes_away, 0)),
            2
        )
    )) AS triggered_to_opponent_accurate_passes_ratio,
    coalesce(ps.accurate_passes_home, 0) - coalesce(ps.accurate_passes_away, 0) AS accurate_passes_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0)
        / nullIf(
            coalesce(ps.accurate_passes_home, 0) + coalesce(ps.accurate_passes_away, 0),
            0
        ),
        1
    ), 0.0)) AS triggered_team_accurate_pass_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0)
        / nullIf(
            coalesce(ps.accurate_passes_home, 0) + coalesce(ps.accurate_passes_away, 0),
            0
        ),
        1
    ), 0.0)) AS opponent_accurate_pass_share_pct,

    coalesce(ps.pass_attempts_home, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_away, 0) AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0)
        / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0)
        / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
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

    toFloat32(coalesce(ps.ball_possession_home, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS opponent_possession_pct,
    toFloat32(round(
        coalesce(ps.ball_possession_home, 0) - coalesce(ps.ball_possession_away, 0),
        1
    )) AS possession_delta_pct,

    coalesce(ps.opposition_half_passes_home, 0) AS triggered_team_opposition_half_passes,
    coalesce(ps.opposition_half_passes_away, 0) AS opponent_opposition_half_passes,
    coalesce(ps.opposition_half_passes_home, 0) - coalesce(ps.opposition_half_passes_away, 0) AS opposition_half_passes_delta,

    coalesce(ps.touches_opp_box_home, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_away, 0) AS opponent_touches_opposition_box,

    toFloat32(coalesce(ps.expected_goals_home, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0)) AS opponent_xg,
    toFloat32(round(
        coalesce(ps.expected_goals_home, 0) - coalesce(ps.expected_goals_away, 0),
        3
    )) AS xg_delta

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ps.accurate_passes_home, 0) > (3.0 * coalesce(ps.accurate_passes_away, 0))

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

    toFloat32(3.0) AS trigger_threshold_pass_multiplier,
    coalesce(ps.accurate_passes_away, 0) AS triggered_team_accurate_passes,
    coalesce(ps.accurate_passes_home, 0) AS opponent_accurate_passes,
    toFloat32(if(
        coalesce(ps.accurate_passes_home, 0) = 0,
        NULL,
        round(
            toFloat64(coalesce(ps.accurate_passes_away, 0))
            / toFloat64(coalesce(ps.accurate_passes_home, 0)),
            2
        )
    )) AS triggered_to_opponent_accurate_passes_ratio,
    coalesce(ps.accurate_passes_away, 0) - coalesce(ps.accurate_passes_home, 0) AS accurate_passes_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0)
        / nullIf(
            coalesce(ps.accurate_passes_home, 0) + coalesce(ps.accurate_passes_away, 0),
            0
        ),
        1
    ), 0.0)) AS triggered_team_accurate_pass_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0)
        / nullIf(
            coalesce(ps.accurate_passes_home, 0) + coalesce(ps.accurate_passes_away, 0),
            0
        ),
        1
    ), 0.0)) AS opponent_accurate_pass_share_pct,

    coalesce(ps.pass_attempts_away, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_home, 0) AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0)
        / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0)
        / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
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

    toFloat32(coalesce(ps.ball_possession_away, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS opponent_possession_pct,
    toFloat32(round(
        coalesce(ps.ball_possession_away, 0) - coalesce(ps.ball_possession_home, 0),
        1
    )) AS possession_delta_pct,

    coalesce(ps.opposition_half_passes_away, 0) AS triggered_team_opposition_half_passes,
    coalesce(ps.opposition_half_passes_home, 0) AS opponent_opposition_half_passes,
    coalesce(ps.opposition_half_passes_away, 0) - coalesce(ps.opposition_half_passes_home, 0) AS opposition_half_passes_delta,

    coalesce(ps.touches_opp_box_away, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_home, 0) AS opponent_touches_opposition_box,

    toFloat32(coalesce(ps.expected_goals_away, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0)) AS opponent_xg,
    toFloat32(round(
        coalesce(ps.expected_goals_away, 0) - coalesce(ps.expected_goals_home, 0),
        3
    )) AS xg_delta

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ps.accurate_passes_away, 0) > (3.0 * coalesce(ps.accurate_passes_home, 0))

ORDER BY
    ifNull(triggered_to_opponent_accurate_passes_ratio, 999.0) DESC,
    accurate_passes_delta DESC,
    match_date DESC,
    match_id DESC,
    triggered_side;
