INSERT INTO gold.sig_player_possession_passing_impact_sub_passing (
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
    triggered_player_substitution_time,
    triggered_player_accurate_passes,
    triggered_player_total_passes,
    triggered_player_pass_accuracy_pct,
    triggered_player_minutes_played,
    triggered_player_touches,
    triggered_player_passes_final_third,
    triggered_player_accurate_passes_per_minute,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_accurate_passes,
    opponent_accurate_passes,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_own_half_passes,
    opponent_own_half_passes,
    triggered_team_own_half_pass_share_pct,
    opponent_own_half_pass_share_pct,
    player_share_of_team_passes_pct,
    triggered_player_vs_team_pass_accuracy_delta_pct
)
-- Signal: sig_player_possession_passing_impact_sub_passing
-- Trigger: Substituted player completes >15 passes in less than 20 minutes of play.
-- Intent: identify high-impact substitute passing cameos where short-minute players deliver meaningful circulation volume and quality under compressed game time.

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

    coalesce(mp.substitution_time, 0) AS triggered_player_substitution_time,
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
    coalesce(p.minutes_played, 0) AS triggered_player_minutes_played,
    coalesce(p.touches, 0) AS triggered_player_touches,
    coalesce(p.passes_final_third, 0) AS triggered_player_passes_final_third,
    coalesce(
        round(
            coalesce(p.accurate_passes, 0)
            / nullIf(coalesce(p.minutes_played, 0), 0),
            2
        ),
        0.0
    ) AS triggered_player_accurate_passes_per_minute,

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
    ) AS triggered_player_vs_team_pass_accuracy_delta_pct

FROM silver.player_match_stat AS p
INNER JOIN silver.match AS m
    ON m.match_id = p.match_id
INNER JOIN (
    SELECT
        match_id,
        person_id,
        max(substitution_time) AS substitution_time
    FROM silver.match_personnel
    WHERE role = 'substitute'
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
  AND coalesce(p.minutes_played, 0) > 0
  AND coalesce(p.minutes_played, 0) < 20
  AND coalesce(p.accurate_passes, 0) > 15

ORDER BY
    triggered_player_accurate_passes DESC,
    triggered_player_accurate_passes_per_minute DESC,
    triggered_player_minutes_played ASC,
    m.match_date DESC,
    m.match_id DESC;
