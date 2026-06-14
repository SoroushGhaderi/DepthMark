INSERT INTO gold.sig_player_possession_passing_keeper_distributor (
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
    trigger_threshold_accurate_short_passes,
    triggered_player_accurate_short_passes_proxy,
    triggered_player_short_pass_attempts_proxy,
    triggered_player_short_pass_accuracy_pct,
    triggered_player_total_passes,
    triggered_player_accurate_passes,
    triggered_player_accurate_long_balls,
    triggered_player_long_ball_attempts,
    triggered_player_minutes_played,
    triggered_player_touches,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_accurate_passes,
    opponent_accurate_passes,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_own_half_passes,
    opponent_own_half_passes,
    triggered_team_possession_pct,
    opponent_possession_pct,
    player_share_of_team_passes_pct,
    player_share_of_team_accurate_passes_pct,
    triggered_player_short_pass_share_of_accurate_passes_pct
)
-- Signal: sig_player_possession_passing_keeper_distributor
-- Intent: identify goalkeepers who circulate heavily via short distribution and enrich with bilateral passing context.
-- Trigger: goalkeeper accurate short passes proxy >= 25, where short proxy = accurate_passes - accurate_long_balls.

WITH
    greatest(
        coalesce(p.accurate_passes, 0) - coalesce(p.accurate_long_balls, 0),
        0
    ) AS accurate_short_passes_proxy,
    greatest(
        coalesce(p.total_passes, 0) - coalesce(p.long_ball_attempts, 0),
        0
    ) AS short_pass_attempts_proxy
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

    25 AS trigger_threshold_accurate_short_passes,
    accurate_short_passes_proxy AS triggered_player_accurate_short_passes_proxy,
    short_pass_attempts_proxy AS triggered_player_short_pass_attempts_proxy,
    coalesce(
        round(
            100.0 * accurate_short_passes_proxy
            / nullIf(short_pass_attempts_proxy, 0),
            1
        ),
        0.0
    ) AS triggered_player_short_pass_accuracy_pct,
    coalesce(p.total_passes, 0) AS triggered_player_total_passes,
    coalesce(p.accurate_passes, 0) AS triggered_player_accurate_passes,
    coalesce(p.accurate_long_balls, 0) AS triggered_player_accurate_long_balls,
    coalesce(p.long_ball_attempts, 0) AS triggered_player_long_ball_attempts,
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
        p.team_id = m.home_team_id, coalesce(ps.own_half_passes_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.own_half_passes_away, 0),
        0
    ) AS triggered_team_own_half_passes,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.own_half_passes_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.own_half_passes_home, 0),
        0
    ) AS opponent_own_half_passes,
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
            100.0 * coalesce(p.accurate_passes, 0)
            / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.accurate_passes_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.accurate_passes_away, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    ) AS player_share_of_team_accurate_passes_pct,
    coalesce(
        round(
            100.0 * accurate_short_passes_proxy
            / nullIf(coalesce(p.accurate_passes, 0), 0),
            1
        ),
        0.0
    ) AS triggered_player_short_pass_share_of_accurate_passes_pct

FROM silver.player_match_stat AS p
INNER JOIN silver.match AS m
    ON m.match_id = p.match_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = p.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)
  AND p.is_goalkeeper = 1
  AND accurate_short_passes_proxy >= 25

ORDER BY
    triggered_player_accurate_short_passes_proxy DESC,
    triggered_player_short_pass_attempts_proxy DESC,
    triggered_player_total_passes DESC,
    m.match_date DESC,
    m.match_id DESC;
