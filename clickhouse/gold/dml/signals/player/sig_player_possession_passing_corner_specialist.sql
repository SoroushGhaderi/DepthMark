INSERT INTO gold.sig_player_possession_passing_corner_specialist (
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
    triggered_player_corner_chances_created,
    triggered_player_corner_assisted_shots_on_target,
    triggered_player_corner_assisted_shot_expected_goals,
    triggered_player_corner_assisted_goals,
    triggered_player_cross_attempts,
    triggered_player_accurate_crosses,
    triggered_player_cross_success_rate_pct,
    triggered_player_total_passes,
    triggered_player_pass_accuracy_pct,
    triggered_player_minutes_played,
    triggered_player_touches,
    triggered_team_corner_shots,
    opponent_corner_shots,
    triggered_team_corners,
    opponent_corners,
    triggered_team_cross_attempts,
    opponent_cross_attempts,
    triggered_team_accurate_crosses,
    opponent_accurate_crosses,
    triggered_team_cross_accuracy_pct,
    opponent_cross_accuracy_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    player_share_of_triggered_team_corner_shots_pct,
    player_share_of_team_crosses_pct
)
-- Signal: sig_player_possession_passing_corner_specialist
-- Trigger: player creates > 1 chances from corner-kick deliveries in a single match.
-- Intent: identify player-level corner specialists who repeatedly generate shots from dead-ball service, with bilateral crossing and possession context.

WITH
    corner_player_creation AS (
        SELECT
            s.match_id,
            assumeNotNull(s.assist_player_id) AS triggered_player_id,
            count() AS triggered_player_corner_chances_created,
            countIf(coalesce(s.is_on_target, 0) = 1) AS triggered_player_corner_assisted_shots_on_target,
            toFloat32(round(sum(coalesce(s.expected_goals, 0.0)), 3)) AS triggered_player_corner_assisted_shot_expected_goals,
            countIf(coalesce(s.is_goal, 0) = 1 AND coalesce(s.is_own_goal, 0) = 0) AS triggered_player_corner_assisted_goals
        FROM silver.shot AS s
        WHERE s.situation = 'FromCorner'
          AND s.assist_player_id IS NOT NULL
        GROUP BY
            s.match_id,
            s.assist_player_id
        HAVING triggered_player_corner_chances_created > 1
    ),
    corner_team_shots AS (
        SELECT
            s.match_id,
            assumeNotNull(s.team_id) AS team_id,
            count() AS team_corner_shots
        FROM silver.shot AS s
        WHERE s.situation = 'FromCorner'
          AND s.team_id IS NOT NULL
        GROUP BY
            s.match_id,
            s.team_id
    )
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

    toInt32(c.triggered_player_corner_chances_created) AS triggered_player_corner_chances_created,
    toInt32(c.triggered_player_corner_assisted_shots_on_target) AS triggered_player_corner_assisted_shots_on_target,
    c.triggered_player_corner_assisted_shot_expected_goals,
    toInt32(c.triggered_player_corner_assisted_goals) AS triggered_player_corner_assisted_goals,
    coalesce(p.cross_attempts, 0) AS triggered_player_cross_attempts,
    coalesce(p.accurate_crosses, 0) AS triggered_player_accurate_crosses,
    toFloat32(coalesce(
        p.cross_success_rate,
        round(
            100.0 * coalesce(p.accurate_crosses, 0)
            / nullIf(coalesce(p.cross_attempts, 0), 0),
            1
        ),
        0.0
    )) AS triggered_player_cross_success_rate_pct,
    coalesce(p.total_passes, 0) AS triggered_player_total_passes,
    toFloat32(coalesce(
        p.pass_accuracy,
        round(
            100.0 * coalesce(p.accurate_passes, 0)
            / nullIf(coalesce(p.total_passes, 0), 0),
            1
        ),
        0.0
    )) AS triggered_player_pass_accuracy_pct,
    coalesce(p.minutes_played, 0) AS triggered_player_minutes_played,
    coalesce(p.touches, 0) AS triggered_player_touches,

    toInt32(coalesce(tcs.team_corner_shots, 0)) AS triggered_team_corner_shots,
    toInt32(coalesce(ocs.team_corner_shots, 0)) AS opponent_corner_shots,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.corners_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.corners_away, 0),
        0
    ) AS triggered_team_corners,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.corners_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.corners_home, 0),
        0
    ) AS opponent_corners,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.cross_attempts_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.cross_attempts_away, 0),
        0
    ) AS triggered_team_cross_attempts,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.cross_attempts_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.cross_attempts_home, 0),
        0
    ) AS opponent_cross_attempts,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.accurate_crosses_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.accurate_crosses_away, 0),
        0
    ) AS triggered_team_accurate_crosses,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.accurate_crosses_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.accurate_crosses_home, 0),
        0
    ) AS opponent_accurate_crosses,
    toFloat32(coalesce(
        round(
            100.0 * multiIf(
                p.team_id = m.home_team_id, coalesce(ps.accurate_crosses_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.accurate_crosses_away, 0),
                0
            ) / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.cross_attempts_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.cross_attempts_away, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    )) AS triggered_team_cross_accuracy_pct,
    toFloat32(coalesce(
        round(
            100.0 * multiIf(
                p.team_id = m.home_team_id, coalesce(ps.accurate_crosses_away, 0),
                p.team_id = m.away_team_id, coalesce(ps.accurate_crosses_home, 0),
                0
            ) / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.cross_attempts_away, 0),
                    p.team_id = m.away_team_id, coalesce(ps.cross_attempts_home, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    )) AS opponent_cross_accuracy_pct,
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
    toFloat32(coalesce(
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
    )) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(
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
    )) AS opponent_pass_accuracy_pct,
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
    toFloat32(coalesce(
        round(
            100.0 * c.triggered_player_corner_chances_created
            / nullIf(coalesce(tcs.team_corner_shots, 0), 0),
            1
        ),
        0.0
    )) AS player_share_of_triggered_team_corner_shots_pct,
    toFloat32(coalesce(
        round(
            100.0 * coalesce(p.cross_attempts, 0)
            / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.cross_attempts_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.cross_attempts_away, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    )) AS player_share_of_team_crosses_pct

FROM silver.player_match_stat AS p
INNER JOIN silver.match AS m
    ON m.match_id = p.match_id
INNER JOIN corner_player_creation AS c
    ON c.match_id = p.match_id
   AND c.triggered_player_id = p.player_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = p.match_id
   AND ps.period = 'All'
LEFT JOIN corner_team_shots AS tcs
    ON tcs.match_id = p.match_id
   AND tcs.team_id = p.team_id
LEFT JOIN corner_team_shots AS ocs
    ON ocs.match_id = p.match_id
   AND ocs.team_id = if(p.team_id = m.home_team_id, m.away_team_id, m.home_team_id)
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)

ORDER BY
    triggered_player_corner_chances_created DESC,
    triggered_player_corner_assisted_shot_expected_goals DESC,
    triggered_player_corner_assisted_shots_on_target DESC,
    m.match_date DESC,
    m.match_id DESC;
