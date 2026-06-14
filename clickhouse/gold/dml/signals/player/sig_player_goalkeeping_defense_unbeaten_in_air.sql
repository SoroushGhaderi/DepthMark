INSERT INTO gold.sig_player_goalkeeping_defense_unbeaten_in_air (
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
    trigger_threshold_min_aerial_duel_attempts,
    trigger_threshold_min_aerial_duel_success_pct,
    triggered_player_position_id,
    triggered_player_usual_playing_position_id,
    triggered_player_minutes_played,
    triggered_player_aerial_duels_won,
    triggered_player_aerial_duel_attempts,
    triggered_player_aerial_duel_success_pct,
    triggered_player_perfect_aerial_duel_flag,
    triggered_player_duels_won,
    triggered_player_duels_lost,
    triggered_player_ground_duels_won,
    triggered_player_ground_duel_attempts,
    triggered_player_ground_duel_success_pct,
    triggered_player_tackles_won,
    triggered_player_tackle_attempts,
    triggered_player_tackle_success_pct,
    triggered_player_interceptions,
    triggered_player_clearances,
    triggered_player_defensive_actions,
    triggered_player_recoveries,
    triggered_player_dribbled_past,
    triggered_player_touches,
    triggered_player_total_passes,
    triggered_player_accurate_passes,
    triggered_player_pass_accuracy_pct,
    triggered_team_aerials_won,
    opponent_aerials_won,
    triggered_team_aerial_attempts,
    opponent_aerial_attempts,
    triggered_team_aerial_success_pct,
    opponent_aerial_success_pct,
    triggered_team_duels_won,
    opponent_duels_won,
    triggered_team_interceptions,
    opponent_interceptions,
    triggered_team_clearances,
    opponent_clearances,
    triggered_team_tackles_won,
    opponent_tackles_won,
    triggered_team_shot_blocks,
    opponent_shot_blocks,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    player_share_of_team_aerials_won_pct
)
-- Signal: sig_player_goalkeeping_defense_unbeaten_in_air
-- Intent: detect defenders who remain unbeaten in aerial duels with meaningful volume.
-- Trigger: player wins 100% of aerial duels with at least 5 attempts in a finished match.
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

    toInt32(5) AS trigger_threshold_min_aerial_duel_attempts,
    toFloat32(100.0) AS trigger_threshold_min_aerial_duel_success_pct,
    toInt32(mp.player_position_id) AS triggered_player_position_id,
    toInt32(mp.player_usual_playing_position_id) AS triggered_player_usual_playing_position_id,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,
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
    toInt8(
        coalesce(p.aerial_duel_attempts, 0) >= 5
        AND coalesce(p.aerial_duels_won, 0) = coalesce(p.aerial_duel_attempts, 0)
    ) AS triggered_player_perfect_aerial_duel_flag,

    toInt32(coalesce(p.duels_won, 0)) AS triggered_player_duels_won,
    toInt32(coalesce(p.duels_lost, 0)) AS triggered_player_duels_lost,
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
    toInt32(coalesce(p.clearances, 0)) AS triggered_player_clearances,
    toInt32(coalesce(p.defensive_actions, 0)) AS triggered_player_defensive_actions,
    toInt32(coalesce(p.recoveries, 0)) AS triggered_player_recoveries,
    toInt32(coalesce(p.dribbled_past, 0)) AS triggered_player_dribbled_past,
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
        p.team_id = m.home_team_id, coalesce(ps.aerials_won_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.aerials_won_away, 0),
        0
    )) AS triggered_team_aerials_won,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.aerials_won_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.aerials_won_home, 0),
        0
    )) AS opponent_aerials_won,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.aerial_attempts_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.aerial_attempts_away, 0),
        0
    )) AS triggered_team_aerial_attempts,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.aerial_attempts_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.aerial_attempts_home, 0),
        0
    )) AS opponent_aerial_attempts,
    toFloat32(coalesce(round(
        100.0 * multiIf(
            p.team_id = m.home_team_id, coalesce(ps.aerials_won_home, 0),
            p.team_id = m.away_team_id, coalesce(ps.aerials_won_away, 0),
            0
        ) / nullIf(toFloat64(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.aerial_attempts_home, 0),
            p.team_id = m.away_team_id, coalesce(ps.aerial_attempts_away, 0),
            0
        )), 0.0),
        1
    ), 0.0)) AS triggered_team_aerial_success_pct,
    toFloat32(coalesce(round(
        100.0 * multiIf(
            p.team_id = m.home_team_id, coalesce(ps.aerials_won_away, 0),
            p.team_id = m.away_team_id, coalesce(ps.aerials_won_home, 0),
            0
        ) / nullIf(toFloat64(multiIf(
            p.team_id = m.home_team_id, coalesce(ps.aerial_attempts_away, 0),
            p.team_id = m.away_team_id, coalesce(ps.aerial_attempts_home, 0),
            0
        )), 0.0),
        1
    ), 0.0)) AS opponent_aerial_success_pct,

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
    )) AS opponent_clearances,
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
        p.team_id = m.home_team_id, coalesce(ps.shot_blocks_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.shot_blocks_away, 0),
        0
    )) AS triggered_team_shot_blocks,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.shot_blocks_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.shot_blocks_home, 0),
        0
    )) AS opponent_shot_blocks,
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
    toFloat32(coalesce(round(
        100.0 * coalesce(p.aerial_duels_won, 0)
            / nullIf(toFloat64(multiIf(
                p.team_id = m.home_team_id, coalesce(ps.aerials_won_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.aerials_won_away, 0),
                0
            )), 0.0),
        1
    ), 0.0)) AS player_share_of_team_aerials_won_pct
FROM silver.player_match_stat AS p
INNER JOIN silver.match AS m
    ON m.match_id = p.match_id
INNER JOIN (
    SELECT
        match_id,
        person_id,
        min(position_id) AS player_position_id,
        min(usual_playing_position_id) AS player_usual_playing_position_id
    FROM silver.match_personnel
    WHERE coalesce(usual_playing_position_id, 0) = 1
    GROUP BY
        match_id,
        person_id
) AS mp
    ON mp.match_id = p.match_id
   AND mp.person_id = p.player_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = p.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)
  AND p.is_goalkeeper = 0
  AND coalesce(p.aerial_duel_attempts, 0) >= 5
  AND coalesce(p.aerial_duels_won, 0) = coalesce(p.aerial_duel_attempts, 0)
ORDER BY
    triggered_player_aerial_duel_attempts DESC,
    triggered_player_aerial_duels_won DESC,
    triggered_player_defensive_actions DESC,
    m.match_date DESC,
    m.match_id DESC,
    p.player_id ASC;
