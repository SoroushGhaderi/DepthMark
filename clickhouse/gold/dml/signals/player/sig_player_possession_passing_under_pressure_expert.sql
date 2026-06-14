INSERT INTO gold.sig_player_possession_passing_under_pressure_expert (
    match_id,
    match_date,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,
    triggered_side,
    triggered_player_id,
    triggered_player_name,
    triggered_team_id,
    triggered_team_name,
    opponent_team_id,
    opponent_team_name,
    triggered_player_accurate_passes,
    triggered_player_total_passes,
    triggered_player_pass_accuracy_pct,
    triggered_player_pass_accuracy_above_threshold_pct,
    triggered_player_passes_final_third,
    triggered_player_minutes_played,
    triggered_player_touches,
    triggered_player_was_fouled,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_accurate_passes,
    opponent_accurate_passes,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_player_vs_team_pass_accuracy_delta_pct,
    triggered_team_own_half_passes,
    opponent_own_half_passes,
    triggered_team_own_half_pass_share_pct,
    opponent_own_half_pass_share_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_interceptions,
    opponent_interceptions,
    triggered_team_tackles_won,
    opponent_tackles_won,
    triggered_team_fouls,
    opponent_fouls,
    triggered_team_press_actions,
    opponent_press_actions,
    opponent_press_actions_per_100_triggered_passes,
    press_actions_delta,
    player_share_of_team_passes_pct
)
-- Signal: sig_player_possession_passing_under_pressure_expert
-- Trigger: Player maintains >90% pass accuracy while under high defensive pressure.
-- Intent: identify players who retain elite passing efficiency despite strong opponent pressure intensity, with bilateral team passing and pressure context.

SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    if(p.team_id = m.home_team_id, 'home', 'away') AS triggered_side,

    p.player_id AS triggered_player_id,
    p.player_name AS triggered_player_name,

    if(p.team_id = m.home_team_id, m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(p.team_id = m.home_team_id, m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(p.team_id = m.home_team_id, m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(p.team_id = m.home_team_id, m.away_team_name, m.home_team_name) AS opponent_team_name,

    coalesce(p.accurate_passes, 0) AS triggered_player_accurate_passes,
    coalesce(p.total_passes, 0) AS triggered_player_total_passes,
    coalesce(
        p.pass_accuracy,
        round(
            100.0 * coalesce(p.accurate_passes, 0)
            / nullIf(coalesce(p.total_passes, 0), 0),
            1
        ),
        0.0
    ) AS triggered_player_pass_accuracy_pct,
    round(
        coalesce(
            p.pass_accuracy,
            round(
                100.0 * coalesce(p.accurate_passes, 0)
                / nullIf(coalesce(p.total_passes, 0), 0),
                1
            ),
            0.0
        ) - 90.0,
        1
    ) AS triggered_player_pass_accuracy_above_threshold_pct,
    coalesce(p.passes_final_third, 0) AS triggered_player_passes_final_third,
    coalesce(p.minutes_played, 0) AS triggered_player_minutes_played,
    coalesce(p.touches, 0) AS triggered_player_touches,
    coalesce(p.was_fouled, 0) AS triggered_player_was_fouled,

    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.pass_attempts_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.pass_attempts_away, 0),
        0
    ) AS triggered_team_pass_attempts,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.pass_attempts_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.pass_attempts_home, 0),
        0
    ) AS opponent_pass_attempts,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.accurate_passes_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.accurate_passes_away, 0),
        0
    ) AS triggered_team_accurate_passes,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.accurate_passes_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.accurate_passes_home, 0),
        0
    ) AS opponent_accurate_passes,
    coalesce(
        round(
            100.0 * multiIf(
                p.team_id = m.home_team_id, coalesce(ps.accurate_passes_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.accurate_passes_away, 0),
                0
            ) / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.pass_attempts_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.pass_attempts_away, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    ) AS triggered_team_pass_accuracy_pct,
    coalesce(
        round(
            100.0 * multiIf(
                p.team_id = m.home_team_id, coalesce(ps.accurate_passes_away, 0),
                p.team_id = m.away_team_id, coalesce(ps.accurate_passes_home, 0),
                0
            ) / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.pass_attempts_away, 0),
                    p.team_id = m.away_team_id, coalesce(ps.pass_attempts_home, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    ) AS opponent_pass_accuracy_pct,
    round(
        coalesce(
            p.pass_accuracy,
            round(
                100.0 * coalesce(p.accurate_passes, 0)
                / nullIf(coalesce(p.total_passes, 0), 0),
                1
            ),
            0.0
        ) - coalesce(
            round(
                100.0 * multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.accurate_passes_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.accurate_passes_away, 0),
                    0
                ) / nullIf(
                    multiIf(
                        p.team_id = m.home_team_id, coalesce(ps.pass_attempts_home, 0),
                        p.team_id = m.away_team_id, coalesce(ps.pass_attempts_away, 0),
                        0
                    ),
                    0
                ),
                1
            ),
            0.0
        ),
        1
    ) AS triggered_player_vs_team_pass_accuracy_delta_pct,

    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.own_half_passes_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.own_half_passes_away, 0),
        0
    ) AS triggered_team_own_half_passes,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.own_half_passes_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.own_half_passes_home, 0),
        0
    ) AS opponent_own_half_passes,
    coalesce(
        round(
            100.0 * multiIf(
                p.team_id = m.home_team_id, coalesce(ps.own_half_passes_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.own_half_passes_away, 0),
                0
            ) / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.pass_attempts_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.pass_attempts_away, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    ) AS triggered_team_own_half_pass_share_pct,
    coalesce(
        round(
            100.0 * multiIf(
                p.team_id = m.home_team_id, coalesce(ps.own_half_passes_away, 0),
                p.team_id = m.away_team_id, coalesce(ps.own_half_passes_home, 0),
                0
            ) / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.pass_attempts_away, 0),
                    p.team_id = m.away_team_id, coalesce(ps.pass_attempts_home, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    ) AS opponent_own_half_pass_share_pct,

    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.ball_possession_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.ball_possession_away, 0),
        0
    )) AS triggered_team_possession_pct,
    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.ball_possession_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.ball_possession_home, 0),
        0
    )) AS opponent_possession_pct,

    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.interceptions_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.interceptions_away, 0),
        0
    ) AS triggered_team_interceptions,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.interceptions_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.interceptions_home, 0),
        0
    ) AS opponent_interceptions,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.tackles_succeeded_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.tackles_succeeded_away, 0),
        0
    ) AS triggered_team_tackles_won,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.tackles_succeeded_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.tackles_succeeded_home, 0),
        0
    ) AS opponent_tackles_won,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.fouls_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.fouls_away, 0),
        0
    ) AS triggered_team_fouls,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.fouls_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.fouls_home, 0),
        0
    ) AS opponent_fouls,

    (
        multiIf(
            p.team_id = m.home_team_id, coalesce(ps.interceptions_home, 0),
            p.team_id = m.away_team_id, coalesce(ps.interceptions_away, 0),
            0
        )
        + multiIf(
            p.team_id = m.home_team_id, coalesce(ps.tackles_succeeded_home, 0),
            p.team_id = m.away_team_id, coalesce(ps.tackles_succeeded_away, 0),
            0
        )
        + multiIf(
            p.team_id = m.home_team_id, coalesce(ps.fouls_home, 0),
            p.team_id = m.away_team_id, coalesce(ps.fouls_away, 0),
            0
        )
    ) AS triggered_team_press_actions,
    (
        multiIf(
            p.team_id = m.home_team_id, coalesce(ps.interceptions_away, 0),
            p.team_id = m.away_team_id, coalesce(ps.interceptions_home, 0),
            0
        )
        + multiIf(
            p.team_id = m.home_team_id, coalesce(ps.tackles_succeeded_away, 0),
            p.team_id = m.away_team_id, coalesce(ps.tackles_succeeded_home, 0),
            0
        )
        + multiIf(
            p.team_id = m.home_team_id, coalesce(ps.fouls_away, 0),
            p.team_id = m.away_team_id, coalesce(ps.fouls_home, 0),
            0
        )
    ) AS opponent_press_actions,
    coalesce(
        round(
            100.0 * (
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.interceptions_away, 0),
                    p.team_id = m.away_team_id, coalesce(ps.interceptions_home, 0),
                    0
                )
                + multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.tackles_succeeded_away, 0),
                    p.team_id = m.away_team_id, coalesce(ps.tackles_succeeded_home, 0),
                    0
                )
                + multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.fouls_away, 0),
                    p.team_id = m.away_team_id, coalesce(ps.fouls_home, 0),
                    0
                )
            ) / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.pass_attempts_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.pass_attempts_away, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    ) AS opponent_press_actions_per_100_triggered_passes,
    (
        (
            multiIf(
                p.team_id = m.home_team_id, coalesce(ps.interceptions_away, 0),
                p.team_id = m.away_team_id, coalesce(ps.interceptions_home, 0),
                0
            )
            + multiIf(
                p.team_id = m.home_team_id, coalesce(ps.tackles_succeeded_away, 0),
                p.team_id = m.away_team_id, coalesce(ps.tackles_succeeded_home, 0),
                0
            )
            + multiIf(
                p.team_id = m.home_team_id, coalesce(ps.fouls_away, 0),
                p.team_id = m.away_team_id, coalesce(ps.fouls_home, 0),
                0
            )
        )
        -
        (
            multiIf(
                p.team_id = m.home_team_id, coalesce(ps.interceptions_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.interceptions_away, 0),
                0
            )
            + multiIf(
                p.team_id = m.home_team_id, coalesce(ps.tackles_succeeded_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.tackles_succeeded_away, 0),
                0
            )
            + multiIf(
                p.team_id = m.home_team_id, coalesce(ps.fouls_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.fouls_away, 0),
                0
            )
        )
    ) AS press_actions_delta,

    coalesce(
        round(
            100.0 * coalesce(p.total_passes, 0)
            / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.pass_attempts_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.pass_attempts_away, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    ) AS player_share_of_team_passes_pct

FROM silver.player_match_stat AS p
INNER JOIN silver.match AS m
    ON m.match_id = p.match_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = p.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)
  AND coalesce(p.total_passes, 0) >= 30
  AND coalesce(
        p.pass_accuracy,
        round(
            100.0 * coalesce(p.accurate_passes, 0)
            / nullIf(coalesce(p.total_passes, 0), 0),
            1
        ),
        0.0
    ) > 90
  AND (
        multiIf(
            p.team_id = m.home_team_id, coalesce(ps.interceptions_away, 0),
            p.team_id = m.away_team_id, coalesce(ps.interceptions_home, 0),
            0
        )
        + multiIf(
            p.team_id = m.home_team_id, coalesce(ps.tackles_succeeded_away, 0),
            p.team_id = m.away_team_id, coalesce(ps.tackles_succeeded_home, 0),
            0
        )
        + multiIf(
            p.team_id = m.home_team_id, coalesce(ps.fouls_away, 0),
            p.team_id = m.away_team_id, coalesce(ps.fouls_home, 0),
            0
        )
      ) >= 35
  AND coalesce(
        round(
            100.0 * (
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.interceptions_away, 0),
                    p.team_id = m.away_team_id, coalesce(ps.interceptions_home, 0),
                    0
                )
                + multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.tackles_succeeded_away, 0),
                    p.team_id = m.away_team_id, coalesce(ps.tackles_succeeded_home, 0),
                    0
                )
                + multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.fouls_away, 0),
                    p.team_id = m.away_team_id, coalesce(ps.fouls_home, 0),
                    0
                )
            ) / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.pass_attempts_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.pass_attempts_away, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
      ) >= 10.0

ORDER BY
    opponent_press_actions_per_100_triggered_passes DESC,
    triggered_player_pass_accuracy_pct DESC,
    triggered_player_total_passes DESC,
    m.match_date DESC,
    m.match_id DESC;
