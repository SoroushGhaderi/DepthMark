INSERT INTO gold.sig_player_creativity_playmaking_deadball_wizard (
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
    trigger_threshold_min_corner_assists,
    triggered_player_corner_assists,
    triggered_player_corner_assists_above_threshold,
    triggered_player_corner_chances_created,
    triggered_player_corner_assisted_shots_on_target,
    triggered_player_corner_assisted_shot_expected_goals,
    triggered_player_assists,
    triggered_player_expected_assists,
    triggered_player_assist_minus_expected_assists,
    triggered_player_chances_created,
    triggered_player_assists_per_chance_created_pct,
    triggered_player_cross_attempts,
    triggered_player_accurate_crosses,
    triggered_player_cross_success_rate_pct,
    triggered_player_passes_final_third,
    triggered_player_touches_opposition_box,
    triggered_player_accurate_passes,
    triggered_player_total_passes,
    triggered_player_pass_accuracy_pct,
    triggered_player_minutes_played,
    triggered_player_touches,
    triggered_team_corner_goals,
    opponent_corner_goals,
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
    triggered_team_accurate_passes,
    opponent_accurate_passes,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    player_share_of_team_corner_goals_assisted_pct,
    player_share_of_team_goals_assisted_pct,
    player_share_of_team_crosses_pct
)
-- Signal: sig_player_creativity_playmaking_deadball_wizard
-- Trigger: player records >= 2 assists from corner situations in a single finished match.
-- Intent: identify elite dead-ball playmakers whose corner deliveries directly create multiple
--         goals, with bilateral crossing, passing, and territorial context.
WITH
    corner_player_assists AS (
        SELECT
            s.match_id,
            assumeNotNull(s.assist_player_id) AS triggered_player_id,
            assumeNotNull(s.team_id) AS triggered_team_id,
            countIf(coalesce(s.is_goal, 0) = 1 AND coalesce(s.is_own_goal, 0) = 0)
                AS triggered_player_corner_assists,
            count() AS triggered_player_corner_chances_created,
            countIf(coalesce(s.is_on_target, 0) = 1) AS triggered_player_corner_assisted_shots_on_target,
            toFloat32(round(sum(coalesce(s.expected_goals, 0.0)), 3))
                AS triggered_player_corner_assisted_shot_expected_goals
        FROM silver.shot AS s
        WHERE s.situation = 'FromCorner'
          AND s.assist_player_id IS NOT NULL
          AND s.team_id IS NOT NULL
        GROUP BY
            s.match_id,
            s.assist_player_id,
            s.team_id
        HAVING triggered_player_corner_assists >= 2
    ),
    corner_team_output AS (
        SELECT
            s.match_id,
            assumeNotNull(s.team_id) AS team_id,
            countIf(coalesce(s.is_goal, 0) = 1 AND coalesce(s.is_own_goal, 0) = 0)
                AS team_corner_goals,
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

    toInt32(p.player_id) AS triggered_player_id,
    p.player_name AS triggered_player_name,

    if(p.team_id = m.home_team_id, m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(p.team_id = m.home_team_id, m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(p.team_id = m.home_team_id, m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(p.team_id = m.home_team_id, m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(2) AS trigger_threshold_min_corner_assists,
    toInt32(cpa.triggered_player_corner_assists) AS triggered_player_corner_assists,
    toInt32(cpa.triggered_player_corner_assists - 2) AS triggered_player_corner_assists_above_threshold,
    toInt32(cpa.triggered_player_corner_chances_created) AS triggered_player_corner_chances_created,
    toInt32(cpa.triggered_player_corner_assisted_shots_on_target)
        AS triggered_player_corner_assisted_shots_on_target,
    cpa.triggered_player_corner_assisted_shot_expected_goals,
    toInt32(coalesce(p.assists, 0)) AS triggered_player_assists,
    toFloat32(coalesce(p.expected_assists, 0.0)) AS triggered_player_expected_assists,
    toFloat32(round(coalesce(p.assists, 0) - coalesce(p.expected_assists, 0.0), 3))
        AS triggered_player_assist_minus_expected_assists,
    toInt32(coalesce(p.chances_created, 0)) AS triggered_player_chances_created,
    toFloat32(coalesce(
        round(
            100.0 * coalesce(p.assists, 0)
            / nullIf(toFloat64(coalesce(p.chances_created, 0)), 0),
            1
        ),
        0.0
    )) AS triggered_player_assists_per_chance_created_pct,
    toInt32(coalesce(p.cross_attempts, 0)) AS triggered_player_cross_attempts,
    toInt32(coalesce(p.accurate_crosses, 0)) AS triggered_player_accurate_crosses,
    toFloat32(coalesce(
        p.cross_success_rate,
        round(
            100.0 * coalesce(p.accurate_crosses, 0)
            / nullIf(coalesce(p.cross_attempts, 0), 0),
            1
        ),
        0.0
    )) AS triggered_player_cross_success_rate_pct,
    toInt32(coalesce(p.passes_final_third, 0)) AS triggered_player_passes_final_third,
    toInt32(coalesce(p.touches_opp_box, 0)) AS triggered_player_touches_opposition_box,
    toInt32(coalesce(p.accurate_passes, 0)) AS triggered_player_accurate_passes,
    toInt32(coalesce(p.total_passes, 0)) AS triggered_player_total_passes,
    toFloat32(coalesce(
        p.pass_accuracy,
        round(
            100.0 * coalesce(p.accurate_passes, 0)
            / nullIf(coalesce(p.total_passes, 0), 0),
            1
        ),
        0.0
    )) AS triggered_player_pass_accuracy_pct,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,
    toInt32(coalesce(p.touches, 0)) AS triggered_player_touches,

    toInt32(coalesce(tco.team_corner_goals, 0)) AS triggered_team_corner_goals,
    toInt32(coalesce(oco.team_corner_goals, 0)) AS opponent_corner_goals,
    toInt32(coalesce(tco.team_corner_shots, 0)) AS triggered_team_corner_shots,
    toInt32(coalesce(oco.team_corner_shots, 0)) AS opponent_corner_shots,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.corners_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.corners_away, 0),
        0
    )) AS triggered_team_corners,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.corners_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.corners_home, 0),
        0
    )) AS opponent_corners,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.cross_attempts_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.cross_attempts_away, 0),
        0
    )) AS triggered_team_cross_attempts,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.cross_attempts_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.cross_attempts_home, 0),
        0
    )) AS opponent_cross_attempts,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.accurate_crosses_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.accurate_crosses_away, 0),
        0
    )) AS triggered_team_accurate_crosses,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.accurate_crosses_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.accurate_crosses_home, 0),
        0
    )) AS opponent_accurate_crosses,
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
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.pass_attempts_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.pass_attempts_away, 0),
        0
    )) AS triggered_team_pass_attempts,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.pass_attempts_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.pass_attempts_home, 0),
        0
    )) AS opponent_pass_attempts,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.accurate_passes_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.accurate_passes_away, 0),
        0
    )) AS triggered_team_accurate_passes,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.accurate_passes_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.accurate_passes_home, 0),
        0
    )) AS opponent_accurate_passes,
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
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.touches_opp_box_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.touches_opp_box_away, 0),
        0
    )) AS triggered_team_touches_opposition_box,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.touches_opp_box_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.touches_opp_box_home, 0),
        0
    )) AS opponent_touches_opposition_box,
    toFloat32(coalesce(
        round(
            100.0 * cpa.triggered_player_corner_assists
            / nullIf(toFloat64(coalesce(tco.team_corner_goals, 0)), 0),
            1
        ),
        0.0
    )) AS player_share_of_team_corner_goals_assisted_pct,
    toFloat32(coalesce(
        round(
            100.0 * coalesce(p.assists, 0)
            / nullIf(
                toFloat64(multiIf(
                    p.team_id = m.home_team_id, coalesce(m.home_score, 0),
                    p.team_id = m.away_team_id, coalesce(m.away_score, 0),
                    0
                )),
                0
            ),
            1
        ),
        0.0
    )) AS player_share_of_team_goals_assisted_pct,
    toFloat32(coalesce(
        round(
            100.0 * coalesce(p.cross_attempts, 0)
            / nullIf(
                toFloat64(multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.cross_attempts_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.cross_attempts_away, 0),
                    0
                )),
                0
            ),
            1
        ),
        0.0
    )) AS player_share_of_team_crosses_pct

FROM silver.player_match_stat AS p
INNER JOIN silver.match AS m
    ON m.match_id = p.match_id
INNER JOIN corner_player_assists AS cpa
    ON cpa.match_id = p.match_id
   AND cpa.triggered_player_id = p.player_id
   AND cpa.triggered_team_id = p.team_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = p.match_id
   AND ps.period = 'All'
LEFT JOIN corner_team_output AS tco
    ON tco.match_id = p.match_id
   AND tco.team_id = p.team_id
LEFT JOIN corner_team_output AS oco
    ON oco.match_id = p.match_id
   AND oco.team_id = if(p.team_id = m.home_team_id, m.away_team_id, m.home_team_id)
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)

ORDER BY
    triggered_player_corner_assists DESC,
    triggered_player_corner_chances_created DESC,
    triggered_player_corner_assisted_shot_expected_goals DESC,
    m.match_date DESC,
    m.match_id DESC;
