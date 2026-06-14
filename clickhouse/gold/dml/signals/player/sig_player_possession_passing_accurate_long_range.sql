INSERT INTO gold.sig_player_possession_passing_accurate_long_range (
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
    triggered_player_long_ball_attempts,
    triggered_player_accurate_long_balls,
    triggered_player_long_ball_success_rate_pct,
    triggered_player_minutes_played,
    triggered_player_touches,
    triggered_player_total_passes,
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
    player_share_of_team_long_balls_pct,
    player_share_of_team_passes_pct
)
-- Signal: sig_player_possession_passing_accurate_long_range
-- Trigger: player completes >= 10 accurate long balls with > 80% long-ball success rate.
-- Intent: identify player-level long-ball specialists who combine high accurate long-ball volume with strong precision, while preserving bilateral passing context.

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

    coalesce(p.long_ball_attempts, 0) AS triggered_player_long_ball_attempts,
    coalesce(p.accurate_long_balls, 0) AS triggered_player_accurate_long_balls,
    coalesce(
        p.long_ball_success_rate,
        round(
            100.0 * coalesce(p.accurate_long_balls, 0)
            / nullIf(coalesce(p.long_ball_attempts, 0), 0),
            1
        ),
        0.0
    ) AS triggered_player_long_ball_success_rate_pct,
    coalesce(p.minutes_played, 0) AS triggered_player_minutes_played,
    coalesce(p.touches, 0) AS triggered_player_touches,
    coalesce(p.total_passes, 0) AS triggered_player_total_passes,

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
            100.0 * coalesce(p.long_ball_attempts, 0)
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
    ) AS player_share_of_team_long_balls_pct,
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
  AND coalesce(p.accurate_long_balls, 0) >= 10
  AND coalesce(
        p.long_ball_success_rate,
        round(
            100.0 * coalesce(p.accurate_long_balls, 0)
            / nullIf(coalesce(p.long_ball_attempts, 0), 0),
            1
        ),
        0.0
    ) > 80

ORDER BY
    triggered_player_accurate_long_balls DESC,
    triggered_player_long_ball_success_rate_pct DESC,
    triggered_player_long_ball_attempts DESC,
    m.match_date DESC,
    m.match_id DESC;
