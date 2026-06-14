INSERT INTO gold.sig_player_possession_passing_target_man_aerials (
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
    triggered_player_position_id,
    triggered_player_usual_playing_position_id,
    triggered_player_minutes_played,
    triggered_player_aerial_duels_won,
    triggered_player_aerial_duel_attempts,
    triggered_player_aerial_duel_success_pct,
    triggered_player_total_passes,
    triggered_player_accurate_passes,
    triggered_player_pass_accuracy_pct,
    triggered_player_touches,
    triggered_player_touches_opposition_box,
    triggered_player_total_shots,
    triggered_player_expected_goals,
    triggered_team_aerials_won,
    opponent_aerials_won,
    triggered_team_aerial_attempts,
    opponent_aerial_attempts,
    triggered_team_aerial_success_pct,
    opponent_aerial_success_pct,
    triggered_team_long_ball_attempts,
    opponent_long_ball_attempts,
    triggered_team_accurate_long_balls,
    opponent_accurate_long_balls,
    triggered_team_long_ball_accuracy_pct,
    opponent_long_ball_accuracy_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    player_share_of_team_aerials_won_pct,
    player_share_of_team_long_ball_attempts_pct
)
-- Signal: sig_player_possession_passing_target_man_aerials
-- Trigger: forward wins >= 10 aerial duels (proxy for long-ball possession).
-- Intent: identify forward target men who dominate aerial duels while preserving bilateral team directness and passing context.

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

    mp.player_position_id AS triggered_player_position_id,
    mp.player_usual_playing_position_id AS triggered_player_usual_playing_position_id,
    coalesce(p.minutes_played, 0) AS triggered_player_minutes_played,
    coalesce(p.aerial_duels_won, 0) AS triggered_player_aerial_duels_won,
    coalesce(p.aerial_duel_attempts, 0) AS triggered_player_aerial_duel_attempts,
    coalesce(
        p.aerial_duel_success_rate,
        round(
            100.0 * coalesce(p.aerial_duels_won, 0)
            / nullIf(coalesce(p.aerial_duel_attempts, 0), 0),
            1
        ),
        0.0
    ) AS triggered_player_aerial_duel_success_pct,
    coalesce(p.total_passes, 0) AS triggered_player_total_passes,
    coalesce(p.accurate_passes, 0) AS triggered_player_accurate_passes,
    coalesce(
        p.pass_accuracy,
        round(
            100.0 * coalesce(p.accurate_passes, 0)
            / nullIf(coalesce(p.total_passes, 0), 0),
            1
        ),
        0.0
    ) AS triggered_player_pass_accuracy_pct,
    coalesce(p.touches, 0) AS triggered_player_touches,
    coalesce(p.touches_opp_box, 0) AS triggered_player_touches_opposition_box,
    coalesce(p.total_shots, 0) AS triggered_player_total_shots,
    toFloat32(coalesce(p.expected_goals, 0.0)) AS triggered_player_expected_goals,

    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.aerials_won_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.aerials_won_away, 0),
        0
    ) AS triggered_team_aerials_won,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.aerials_won_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.aerials_won_home, 0),
        0
    ) AS opponent_aerials_won,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.aerial_attempts_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.aerial_attempts_away, 0),
        0
    ) AS triggered_team_aerial_attempts,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.aerial_attempts_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.aerial_attempts_home, 0),
        0
    ) AS opponent_aerial_attempts,
    coalesce(
        round(
            100.0 * multiIf(
                p.team_id = m.home_team_id, coalesce(ps.aerials_won_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.aerials_won_away, 0),
                0
            ) / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.aerial_attempts_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.aerial_attempts_away, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    ) AS triggered_team_aerial_success_pct,
    coalesce(
        round(
            100.0 * multiIf(
                p.team_id = m.home_team_id, coalesce(ps.aerials_won_away, 0),
                p.team_id = m.away_team_id, coalesce(ps.aerials_won_home, 0),
                0
            ) / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.aerial_attempts_away, 0),
                    p.team_id = m.away_team_id, coalesce(ps.aerial_attempts_home, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    ) AS opponent_aerial_success_pct,

    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.long_ball_attempts_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.long_ball_attempts_away, 0),
        0
    ) AS triggered_team_long_ball_attempts,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.long_ball_attempts_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.long_ball_attempts_home, 0),
        0
    ) AS opponent_long_ball_attempts,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.accurate_long_balls_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.accurate_long_balls_away, 0),
        0
    ) AS triggered_team_accurate_long_balls,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.accurate_long_balls_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.accurate_long_balls_home, 0),
        0
    ) AS opponent_accurate_long_balls,
    coalesce(
        round(
            100.0 * multiIf(
                p.team_id = m.home_team_id, coalesce(ps.accurate_long_balls_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.accurate_long_balls_away, 0),
                0
            ) / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.long_ball_attempts_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.long_ball_attempts_away, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    ) AS triggered_team_long_ball_accuracy_pct,
    coalesce(
        round(
            100.0 * multiIf(
                p.team_id = m.home_team_id, coalesce(ps.accurate_long_balls_away, 0),
                p.team_id = m.away_team_id, coalesce(ps.accurate_long_balls_home, 0),
                0
            ) / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.long_ball_attempts_away, 0),
                    p.team_id = m.away_team_id, coalesce(ps.long_ball_attempts_home, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    ) AS opponent_long_ball_accuracy_pct,

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
    coalesce(
        round(
            100.0 * coalesce(p.aerial_duels_won, 0)
            / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.aerials_won_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.aerials_won_away, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    ) AS player_share_of_team_aerials_won_pct,
    coalesce(
        round(
            100.0 * coalesce(p.aerial_duel_attempts, 0)
            / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.long_ball_attempts_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.long_ball_attempts_away, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    ) AS player_share_of_team_long_ball_attempts_pct

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
    WHERE coalesce(usual_playing_position_id, 0) = 3
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
  AND coalesce(p.aerial_duels_won, 0) >= 10

ORDER BY
    triggered_player_aerial_duels_won DESC,
    triggered_player_aerial_duel_success_pct DESC,
    triggered_player_aerial_duel_attempts DESC,
    m.match_date DESC,
    m.match_id DESC;
