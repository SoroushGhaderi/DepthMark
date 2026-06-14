INSERT INTO gold.sig_player_goalkeeping_defense_pressure_absorber (
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
    triggered_player_role_group,
    triggered_player_position_id,
    triggered_player_usual_playing_position_id,
    trigger_threshold_min_minutes_played,
    trigger_threshold_min_touches_exclusive,
    trigger_threshold_max_turnovers_proxy,
    triggered_player_minutes_played,
    triggered_player_touches,
    triggered_player_turnovers_proxy,
    triggered_player_failed_passes,
    triggered_player_failed_dribbles,
    triggered_player_total_passes,
    triggered_player_accurate_passes,
    triggered_player_pass_accuracy_pct,
    triggered_player_dribble_attempts,
    triggered_player_successful_dribbles,
    triggered_player_dribble_success_pct,
    triggered_player_tackles_won,
    triggered_player_tackle_attempts,
    triggered_player_tackle_success_pct,
    triggered_player_duels_won,
    triggered_player_duels_lost,
    triggered_player_interceptions,
    triggered_player_clearances,
    triggered_player_recoveries,
    triggered_player_defensive_actions,
    triggered_player_ground_duels_won,
    triggered_player_ground_duel_attempts,
    triggered_player_ground_duel_success_pct,
    triggered_player_aerial_duels_won,
    triggered_player_aerial_duel_attempts,
    triggered_player_aerial_duel_success_pct,
    triggered_player_fouls_committed,
    triggered_player_dribbled_past,
    triggered_team_turnovers_proxy,
    opponent_turnovers_proxy,
    turnovers_proxy_delta,
    triggered_team_failed_passes,
    opponent_failed_passes,
    triggered_team_failed_dribbles,
    opponent_failed_dribbles,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_duels_won,
    opponent_duels_won,
    triggered_team_interceptions,
    opponent_interceptions,
    triggered_team_clearances,
    opponent_clearances
)
WITH player_positions AS (
    SELECT
        mp.match_id,
        toInt32(mp.person_id) AS person_id,
        argMax(mp.position_id, if(mp.role = 'starter', 2, 1)) AS position_id,
        argMax(mp.usual_playing_position_id, if(mp.role = 'starter', 2, 1))
            AS usual_playing_position_id
    FROM silver.match_personnel AS mp
    WHERE mp.role IN ('starter', 'substitute')
    GROUP BY
        mp.match_id,
        person_id
)
-- Signal: sig_player_goalkeeping_defense_pressure_absorber
-- Intent: detect high-touch full-match defenders who retain possession cleanly under pressure.
-- Trigger: defender plays at least 90 minutes, records more than 50 touches, and has zero turnover proxy events.
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
    coalesce(p.player_name, 'Unknown') AS triggered_player_name,
    if(p.team_id = m.home_team_id, m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(p.team_id = m.home_team_id, m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(p.team_id = m.home_team_id, m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(p.team_id = m.home_team_id, m.away_team_name, m.home_team_name) AS opponent_team_name,

    'defender' AS triggered_player_role_group,
    toInt32(coalesce(pp.position_id, 0)) AS triggered_player_position_id,
    toInt32(coalesce(pp.usual_playing_position_id, 0)) AS triggered_player_usual_playing_position_id,

    toInt32(90) AS trigger_threshold_min_minutes_played,
    toInt32(50) AS trigger_threshold_min_touches_exclusive,
    toInt32(0) AS trigger_threshold_max_turnovers_proxy,

    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,
    toInt32(coalesce(p.touches, 0)) AS triggered_player_touches,
    toInt32(
        greatest(coalesce(p.total_passes, 0) - coalesce(p.accurate_passes, 0), 0)
        + greatest(coalesce(p.dribble_attempts, 0) - coalesce(p.successful_dribbles, 0), 0)
    ) AS triggered_player_turnovers_proxy,
    toInt32(greatest(coalesce(p.total_passes, 0) - coalesce(p.accurate_passes, 0), 0))
        AS triggered_player_failed_passes,
    toInt32(greatest(coalesce(p.dribble_attempts, 0) - coalesce(p.successful_dribbles, 0), 0))
        AS triggered_player_failed_dribbles,
    toInt32(coalesce(p.total_passes, 0)) AS triggered_player_total_passes,
    toInt32(coalesce(p.accurate_passes, 0)) AS triggered_player_accurate_passes,
    toFloat32(coalesce(
        p.pass_accuracy,
        round(
            100.0 * coalesce(p.accurate_passes, 0)
            / nullIf(coalesce(p.total_passes, 0), 0),
            1
        ),
        0.0
    )) AS triggered_player_pass_accuracy_pct,
    toInt32(coalesce(p.dribble_attempts, 0)) AS triggered_player_dribble_attempts,
    toInt32(coalesce(p.successful_dribbles, 0)) AS triggered_player_successful_dribbles,
    toFloat32(coalesce(
        p.dribble_success_rate,
        round(
            100.0 * coalesce(p.successful_dribbles, 0)
            / nullIf(coalesce(p.dribble_attempts, 0), 0),
            1
        ),
        0.0
    )) AS triggered_player_dribble_success_pct,
    toInt32(coalesce(p.tackles_won, 0)) AS triggered_player_tackles_won,
    toInt32(coalesce(p.tackle_attempts, 0)) AS triggered_player_tackle_attempts,
    toFloat32(coalesce(
        p.tackle_success_rate,
        round(
            100.0 * coalesce(p.tackles_won, 0)
            / nullIf(coalesce(p.tackle_attempts, 0), 0),
            1
        ),
        0.0
    )) AS triggered_player_tackle_success_pct,
    toInt32(coalesce(p.duels_won, 0)) AS triggered_player_duels_won,
    toInt32(coalesce(p.duels_lost, 0)) AS triggered_player_duels_lost,
    toInt32(coalesce(p.interceptions, 0)) AS triggered_player_interceptions,
    toInt32(coalesce(p.clearances, 0)) AS triggered_player_clearances,
    toInt32(coalesce(p.recoveries, 0)) AS triggered_player_recoveries,
    toInt32(coalesce(p.defensive_actions, 0)) AS triggered_player_defensive_actions,
    toInt32(coalesce(p.ground_duels_won, 0)) AS triggered_player_ground_duels_won,
    toInt32(coalesce(p.ground_duel_attempts, 0)) AS triggered_player_ground_duel_attempts,
    toFloat32(coalesce(
        p.ground_duel_success_rate,
        round(
            100.0 * coalesce(p.ground_duels_won, 0)
            / nullIf(coalesce(p.ground_duel_attempts, 0), 0),
            1
        ),
        0.0
    )) AS triggered_player_ground_duel_success_pct,
    toInt32(coalesce(p.aerial_duels_won, 0)) AS triggered_player_aerial_duels_won,
    toInt32(coalesce(p.aerial_duel_attempts, 0)) AS triggered_player_aerial_duel_attempts,
    toFloat32(coalesce(
        p.aerial_duel_success_rate,
        round(
            100.0 * coalesce(p.aerial_duels_won, 0)
            / nullIf(coalesce(p.aerial_duel_attempts, 0), 0),
            1
        ),
        0.0
    )) AS triggered_player_aerial_duel_success_pct,
    toInt32(coalesce(p.fouls_committed, 0)) AS triggered_player_fouls_committed,
    toInt32(coalesce(p.dribbled_past, 0)) AS triggered_player_dribbled_past,

    toInt32(
        greatest(
            multiIf(
                p.team_id = m.home_team_id, coalesce(ps.pass_attempts_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.pass_attempts_away, 0),
                0
            ) - multiIf(
                p.team_id = m.home_team_id, coalesce(ps.accurate_passes_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.accurate_passes_away, 0),
                0
            ),
            0
        ) + greatest(
            multiIf(
                p.team_id = m.home_team_id, coalesce(ps.dribble_attempts_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.dribble_attempts_away, 0),
                0
            ) - multiIf(
                p.team_id = m.home_team_id, coalesce(ps.dribbles_succeeded_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.dribbles_succeeded_away, 0),
                0
            ),
            0
        )
    ) AS triggered_team_turnovers_proxy,
    toInt32(
        greatest(
            multiIf(
                p.team_id = m.home_team_id, coalesce(ps.pass_attempts_away, 0),
                p.team_id = m.away_team_id, coalesce(ps.pass_attempts_home, 0),
                0
            ) - multiIf(
                p.team_id = m.home_team_id, coalesce(ps.accurate_passes_away, 0),
                p.team_id = m.away_team_id, coalesce(ps.accurate_passes_home, 0),
                0
            ),
            0
        ) + greatest(
            multiIf(
                p.team_id = m.home_team_id, coalesce(ps.dribble_attempts_away, 0),
                p.team_id = m.away_team_id, coalesce(ps.dribble_attempts_home, 0),
                0
            ) - multiIf(
                p.team_id = m.home_team_id, coalesce(ps.dribbles_succeeded_away, 0),
                p.team_id = m.away_team_id, coalesce(ps.dribbles_succeeded_home, 0),
                0
            ),
            0
        )
    ) AS opponent_turnovers_proxy,
    toInt32(
        (
            greatest(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.pass_attempts_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.pass_attempts_away, 0),
                    0
                ) - multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.accurate_passes_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.accurate_passes_away, 0),
                    0
                ),
                0
            ) + greatest(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.dribble_attempts_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.dribble_attempts_away, 0),
                    0
                ) - multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.dribbles_succeeded_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.dribbles_succeeded_away, 0),
                    0
                ),
                0
            )
        ) - (
            greatest(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.pass_attempts_away, 0),
                    p.team_id = m.away_team_id, coalesce(ps.pass_attempts_home, 0),
                    0
                ) - multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.accurate_passes_away, 0),
                    p.team_id = m.away_team_id, coalesce(ps.accurate_passes_home, 0),
                    0
                ),
                0
            ) + greatest(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.dribble_attempts_away, 0),
                    p.team_id = m.away_team_id, coalesce(ps.dribble_attempts_home, 0),
                    0
                ) - multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.dribbles_succeeded_away, 0),
                    p.team_id = m.away_team_id, coalesce(ps.dribbles_succeeded_home, 0),
                    0
                ),
                0
            )
        )
    ) AS turnovers_proxy_delta,

    toInt32(greatest(
        multiIf(
            p.team_id = m.home_team_id, coalesce(ps.pass_attempts_home, 0),
            p.team_id = m.away_team_id, coalesce(ps.pass_attempts_away, 0),
            0
        ) - multiIf(
            p.team_id = m.home_team_id, coalesce(ps.accurate_passes_home, 0),
            p.team_id = m.away_team_id, coalesce(ps.accurate_passes_away, 0),
            0
        ),
        0
    )) AS triggered_team_failed_passes,
    toInt32(greatest(
        multiIf(
            p.team_id = m.home_team_id, coalesce(ps.pass_attempts_away, 0),
            p.team_id = m.away_team_id, coalesce(ps.pass_attempts_home, 0),
            0
        ) - multiIf(
            p.team_id = m.home_team_id, coalesce(ps.accurate_passes_away, 0),
            p.team_id = m.away_team_id, coalesce(ps.accurate_passes_home, 0),
            0
        ),
        0
    )) AS opponent_failed_passes,
    toInt32(greatest(
        multiIf(
            p.team_id = m.home_team_id, coalesce(ps.dribble_attempts_home, 0),
            p.team_id = m.away_team_id, coalesce(ps.dribble_attempts_away, 0),
            0
        ) - multiIf(
            p.team_id = m.home_team_id, coalesce(ps.dribbles_succeeded_home, 0),
            p.team_id = m.away_team_id, coalesce(ps.dribbles_succeeded_away, 0),
            0
        ),
        0
    )) AS triggered_team_failed_dribbles,
    toInt32(greatest(
        multiIf(
            p.team_id = m.home_team_id, coalesce(ps.dribble_attempts_away, 0),
            p.team_id = m.away_team_id, coalesce(ps.dribble_attempts_home, 0),
            0
        ) - multiIf(
            p.team_id = m.home_team_id, coalesce(ps.dribbles_succeeded_away, 0),
            p.team_id = m.away_team_id, coalesce(ps.dribbles_succeeded_home, 0),
            0
        ),
        0
    )) AS opponent_failed_dribbles,
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
    toFloat32(coalesce(round(
        100.0 * multiIf(
            p.team_id = m.home_team_id, coalesce(ps.accurate_passes_home, 0),
            p.team_id = m.away_team_id, coalesce(ps.accurate_passes_away, 0),
            0
        ) / nullIf(toFloat64(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.pass_attempts_home, 0),
            p.team_id = m.away_team_id, coalesce(ps.pass_attempts_away, 0),
            0
        )), 0.0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * multiIf(
            p.team_id = m.home_team_id, coalesce(ps.accurate_passes_away, 0),
            p.team_id = m.away_team_id, coalesce(ps.accurate_passes_home, 0),
            0
        ) / nullIf(toFloat64(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.pass_attempts_away, 0),
            p.team_id = m.away_team_id, coalesce(ps.pass_attempts_home, 0),
            0
        )), 0.0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.duels_won_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.duels_won_away, 0),
        0
    )) AS triggered_team_duels_won,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.duels_won_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.duels_won_home, 0),
        0
    )) AS opponent_duels_won,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.interceptions_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.interceptions_away, 0),
        0
    )) AS triggered_team_interceptions,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.interceptions_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.interceptions_home, 0),
        0
    )) AS opponent_interceptions,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.clearances_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.clearances_away, 0),
        0
    )) AS triggered_team_clearances,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.clearances_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.clearances_home, 0),
        0
    )) AS opponent_clearances
FROM silver.player_match_stat AS p
INNER JOIN silver.match AS m
    ON m.match_id = p.match_id
INNER JOIN player_positions AS pp
    ON pp.match_id = p.match_id
   AND pp.person_id = p.player_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = p.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND p.player_id > 0
  AND p.is_goalkeeper = 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)
  AND coalesce(pp.usual_playing_position_id, 0) = 1
  AND coalesce(p.minutes_played, 0) >= 90
  AND coalesce(p.touches, 0) > 50
  AND (
      greatest(coalesce(p.total_passes, 0) - coalesce(p.accurate_passes, 0), 0)
      + greatest(coalesce(p.dribble_attempts, 0) - coalesce(p.successful_dribbles, 0), 0)
  ) = 0
ORDER BY
    triggered_player_touches DESC,
    triggered_player_minutes_played DESC,
    triggered_player_defensive_actions DESC,
    m.match_date DESC,
    m.match_id DESC,
    p.player_id ASC;
