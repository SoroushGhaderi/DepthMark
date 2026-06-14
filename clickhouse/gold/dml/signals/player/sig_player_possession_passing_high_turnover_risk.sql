INSERT INTO gold.sig_player_possession_passing_high_turnover_risk (
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
    triggered_player_possession_losses,
    triggered_player_failed_passes,
    triggered_player_failed_dribbles,
    triggered_player_duels_lost,
    triggered_player_accurate_passes,
    triggered_player_total_passes,
    triggered_player_pass_accuracy_pct,
    triggered_player_successful_dribbles,
    triggered_player_dribble_attempts,
    triggered_player_dribble_success_rate_pct,
    triggered_player_minutes_played,
    triggered_player_touches,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_accurate_passes,
    opponent_accurate_passes,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_dribble_attempts,
    opponent_dribble_attempts,
    triggered_team_successful_dribbles,
    opponent_successful_dribbles,
    triggered_team_dribble_success_pct,
    opponent_dribble_success_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    player_share_of_team_passes_pct,
    player_share_of_team_dribbles_pct
)
-- Signal: sig_player_possession_passing_high_turnover_risk
-- Trigger: Player loses possession >25 times in a single match.
-- Intent: identify player-level turnover risk by combining failed passes, failed dribbles, and duels lost, with bilateral possession and passing context.

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

    (
        greatest(coalesce(p.total_passes, 0) - coalesce(p.accurate_passes, 0), 0)
        + greatest(coalesce(p.dribble_attempts, 0) - coalesce(p.successful_dribbles, 0), 0)
        + coalesce(p.duels_lost, 0)
    ) AS triggered_player_possession_losses,
    greatest(coalesce(p.total_passes, 0) - coalesce(p.accurate_passes, 0), 0) AS triggered_player_failed_passes,
    greatest(coalesce(p.dribble_attempts, 0) - coalesce(p.successful_dribbles, 0), 0) AS triggered_player_failed_dribbles,
    coalesce(p.duels_lost, 0) AS triggered_player_duels_lost,
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
    coalesce(p.successful_dribbles, 0) AS triggered_player_successful_dribbles,
    coalesce(p.dribble_attempts, 0) AS triggered_player_dribble_attempts,
    coalesce(
        p.dribble_success_rate,
        round(
            100.0 * coalesce(p.successful_dribbles, 0)
            / nullIf(coalesce(p.dribble_attempts, 0), 0),
            1
        ),
        0.0
    ) AS triggered_player_dribble_success_rate_pct,
    coalesce(p.minutes_played, 0) AS triggered_player_minutes_played,
    coalesce(p.touches, 0) AS triggered_player_touches,

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

    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.dribble_attempts_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.dribble_attempts_away, 0),
        0
    ) AS triggered_team_dribble_attempts,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.dribble_attempts_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.dribble_attempts_home, 0),
        0
    ) AS opponent_dribble_attempts,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.dribbles_succeeded_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.dribbles_succeeded_away, 0),
        0
    ) AS triggered_team_successful_dribbles,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.dribbles_succeeded_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.dribbles_succeeded_home, 0),
        0
    ) AS opponent_successful_dribbles,
    coalesce(
        round(
            100.0 * multiIf(
                p.team_id = m.home_team_id, coalesce(ps.dribbles_succeeded_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.dribbles_succeeded_away, 0),
                0
            ) / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.dribble_attempts_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.dribble_attempts_away, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    ) AS triggered_team_dribble_success_pct,
    coalesce(
        round(
            100.0 * multiIf(
                p.team_id = m.home_team_id, coalesce(ps.dribbles_succeeded_away, 0),
                p.team_id = m.away_team_id, coalesce(ps.dribbles_succeeded_home, 0),
                0
            ) / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.dribble_attempts_away, 0),
                    p.team_id = m.away_team_id, coalesce(ps.dribble_attempts_home, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    ) AS opponent_dribble_success_pct,

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
    ) AS player_share_of_team_passes_pct,
    coalesce(
        round(
            100.0 * coalesce(p.dribble_attempts, 0)
            / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.dribble_attempts_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.dribble_attempts_away, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    ) AS player_share_of_team_dribbles_pct

FROM silver.player_match_stat AS p
INNER JOIN silver.match AS m
    ON m.match_id = p.match_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = p.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)
  AND (
        greatest(coalesce(p.total_passes, 0) - coalesce(p.accurate_passes, 0), 0)
        + greatest(coalesce(p.dribble_attempts, 0) - coalesce(p.successful_dribbles, 0), 0)
        + coalesce(p.duels_lost, 0)
    ) > 25

ORDER BY
    triggered_player_possession_losses DESC,
    triggered_player_failed_passes DESC,
    triggered_player_failed_dribbles DESC,
    m.match_date DESC,
    m.match_id DESC;
