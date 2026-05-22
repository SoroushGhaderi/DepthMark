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
INSERT INTO gold.sig_player_goalkeeping_defense_defensive_double_double (
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
    trigger_threshold_min_tackles_won,
    trigger_threshold_min_interceptions,
    triggered_player_tackles_won,
    triggered_player_tackle_attempts,
    triggered_player_tackle_success_pct,
    triggered_player_interceptions,
    triggered_player_tackles_won_above_threshold,
    triggered_player_interceptions_above_threshold,
    triggered_player_defensive_actions,
    triggered_player_recoveries,
    triggered_player_clearances,
    triggered_player_shot_blocks,
    triggered_player_duels_won,
    triggered_player_duels_lost,
    triggered_player_fouls_committed,
    triggered_player_dribbled_past,
    triggered_player_minutes_played,
    triggered_player_touches,
    triggered_player_total_passes,
    triggered_player_accurate_passes,
    triggered_player_pass_accuracy_pct,
    triggered_team_tackles_won,
    opponent_tackles_won,
    tackles_won_delta,
    triggered_team_interceptions,
    opponent_interceptions,
    interceptions_delta,
    triggered_team_clearances,
    opponent_clearances,
    clearances_delta,
    triggered_team_duels_won,
    opponent_duels_won,
    duels_won_delta,
    triggered_team_fouls,
    opponent_fouls,
    fouls_delta,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    player_share_of_team_tackles_won_pct,
    player_share_of_team_interceptions_pct
)
-- Signal: sig_player_goalkeeping_defense_defensive_double_double
-- Intent: detect players who post a dual defensive volume peak in both tackling and interceptions.
-- Trigger: player records at least 5 tackles won and at least 5 interceptions in a finished match.
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

    multiIf(
        coalesce(pp.usual_playing_position_id, 0) = 1, 'defender',
        coalesce(pp.usual_playing_position_id, 0) = 2, 'midfielder',
        coalesce(pp.usual_playing_position_id, 0) = 3, 'forward',
        'other'
    ) AS triggered_player_role_group,
    toInt32(coalesce(pp.position_id, 0)) AS triggered_player_position_id,
    toInt32(coalesce(pp.usual_playing_position_id, 0)) AS triggered_player_usual_playing_position_id,

    toInt32(5) AS trigger_threshold_min_tackles_won,
    toInt32(5) AS trigger_threshold_min_interceptions,

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
    toInt32(coalesce(p.interceptions, 0)) AS triggered_player_interceptions,
    toInt32(coalesce(p.tackles_won, 0) - 5) AS triggered_player_tackles_won_above_threshold,
    toInt32(coalesce(p.interceptions, 0) - 5) AS triggered_player_interceptions_above_threshold,
    toInt32(coalesce(p.defensive_actions, 0)) AS triggered_player_defensive_actions,
    toInt32(coalesce(p.recoveries, 0)) AS triggered_player_recoveries,
    toInt32(coalesce(p.clearances, 0)) AS triggered_player_clearances,
    toInt32(coalesce(p.blocked_shots, 0)) AS triggered_player_shot_blocks,
    toInt32(coalesce(p.duels_won, 0)) AS triggered_player_duels_won,
    toInt32(coalesce(p.duels_lost, 0)) AS triggered_player_duels_lost,
    toInt32(coalesce(p.fouls_committed, 0)) AS triggered_player_fouls_committed,
    toInt32(coalesce(p.dribbled_past, 0)) AS triggered_player_dribbled_past,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,
    toInt32(coalesce(p.touches, 0)) AS triggered_player_touches,
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

    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.tackles_succeeded_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.tackles_succeeded_away, 0),
        0
    )) AS triggered_team_tackles_won,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.tackles_succeeded_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.tackles_succeeded_home, 0),
        0
    )) AS opponent_tackles_won,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.tackles_succeeded_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.tackles_succeeded_away, 0),
        0
    ) - multiIf(
        p.team_id = m.home_team_id, coalesce(ps.tackles_succeeded_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.tackles_succeeded_home, 0),
        0
    )) AS tackles_won_delta,

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
        p.team_id = m.home_team_id, coalesce(ps.interceptions_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.interceptions_away, 0),
        0
    ) - multiIf(
        p.team_id = m.home_team_id, coalesce(ps.interceptions_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.interceptions_home, 0),
        0
    )) AS interceptions_delta,

    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.clearances_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.clearances_away, 0),
        0
    )) AS triggered_team_clearances,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.clearances_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.clearances_home, 0),
        0
    )) AS opponent_clearances,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.clearances_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.clearances_away, 0),
        0
    ) - multiIf(
        p.team_id = m.home_team_id, coalesce(ps.clearances_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.clearances_home, 0),
        0
    )) AS clearances_delta,

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
        p.team_id = m.home_team_id, coalesce(ps.duels_won_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.duels_won_away, 0),
        0
    ) - multiIf(
        p.team_id = m.home_team_id, coalesce(ps.duels_won_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.duels_won_home, 0),
        0
    )) AS duels_won_delta,

    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.fouls_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.fouls_away, 0),
        0
    )) AS triggered_team_fouls,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.fouls_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.fouls_home, 0),
        0
    )) AS opponent_fouls,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.fouls_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.fouls_away, 0),
        0
    ) - multiIf(
        p.team_id = m.home_team_id, coalesce(ps.fouls_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.fouls_home, 0),
        0
    )) AS fouls_delta,

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
    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.ball_possession_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.ball_possession_away, 0),
        0
    ) - multiIf(
        p.team_id = m.home_team_id, coalesce(ps.ball_possession_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.ball_possession_home, 0),
        0
    )) AS possession_delta_pct,

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
    ) - round(
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
    ), 1), 0.0)) AS pass_accuracy_delta_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(p.tackles_won, 0)
            / nullIf(toFloat64(multiIf(
                p.team_id = m.home_team_id, coalesce(ps.tackles_succeeded_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.tackles_succeeded_away, 0),
                0
            )), 0.0),
        1
    ), 0.0)) AS player_share_of_team_tackles_won_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(p.interceptions, 0)
            / nullIf(toFloat64(multiIf(
                p.team_id = m.home_team_id, coalesce(ps.interceptions_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.interceptions_away, 0),
                0
            )), 0.0),
        1
    ), 0.0)) AS player_share_of_team_interceptions_pct
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
  AND coalesce(p.tackles_won, 0) >= 5
  AND coalesce(p.interceptions, 0) >= 5
ORDER BY
    triggered_player_tackles_won DESC,
    triggered_player_interceptions DESC,
    triggered_player_defensive_actions DESC,
    m.match_date DESC,
    m.match_id DESC,
    p.player_id ASC;
