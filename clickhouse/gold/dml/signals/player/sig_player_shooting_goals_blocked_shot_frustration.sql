INSERT INTO gold.sig_player_shooting_goals_blocked_shot_frustration (
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
    trigger_threshold_min_blocked_shots,
    triggered_player_blocked_shots,
    triggered_player_total_shots,
    triggered_player_shots_on_target,
    triggered_player_goals,
    triggered_player_expected_goals,
    triggered_player_shot_accuracy_pct,
    triggered_player_shot_conversion_pct,
    triggered_player_expected_goals_per_shot,
    triggered_player_goal_minus_expected_goals,
    triggered_player_minutes_played,
    triggered_player_blocked_shot_ratio_pct,
    blocked_shots_above_threshold,
    triggered_player_unblocked_shots,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_expected_goals,
    opponent_expected_goals,
    expected_goals_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    total_shots_delta,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    triggered_team_blocked_shots,
    opponent_blocked_shots,
    blocked_shots_delta,
    triggered_team_big_chances,
    opponent_big_chances,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    player_share_of_team_total_shots_pct,
    player_share_of_team_shots_on_target_pct,
    player_share_of_team_expected_goals_pct,
    player_share_of_team_blocked_shots_pct
)
-- Signal: sig_player_shooting_goals_blocked_shot_frustration
-- Trigger: player records >= 4 blocked shots in a finished match.
-- Intent: isolate high-frustration shooting profiles where repeated player attempts are
-- blocked by defenders, with bilateral team and opponent shooting context.

WITH player_blocked_shot_stats AS (
    SELECT
        s.match_id,
        toInt32(s.player_id) AS triggered_player_id,
        toInt32(s.team_id) AS triggered_team_id,
        toInt32(countIf(coalesce(s.is_own_goal, 0) = 0)) AS triggered_player_total_shots,
        toInt32(countIf(
            coalesce(s.is_own_goal, 0) = 0
            AND coalesce(s.is_blocked, 0) = 1
        )) AS triggered_player_blocked_shots
    FROM silver.shot AS s
    WHERE coalesce(s.player_id, 0) > 0
      AND coalesce(s.team_id, 0) > 0
    GROUP BY
        s.match_id,
        toInt32(s.player_id),
        toInt32(s.team_id)
    HAVING countIf(
        coalesce(s.is_own_goal, 0) = 0
        AND coalesce(s.is_blocked, 0) = 1
    ) >= 4
),
team_blocked_shot_stats AS (
    SELECT
        s.match_id,
        toInt32(s.team_id) AS team_id,
        toInt32(countIf(coalesce(s.is_own_goal, 0) = 0)) AS team_total_shots,
        toInt32(countIf(
            coalesce(s.is_own_goal, 0) = 0
            AND coalesce(s.is_blocked, 0) = 1
        )) AS team_blocked_shots
    FROM silver.shot AS s
    WHERE coalesce(s.team_id, 0) > 0
    GROUP BY
        s.match_id,
        toInt32(s.team_id)
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
    coalesce(p.player_name, 'Unknown') AS triggered_player_name,
    if(p.team_id = m.home_team_id, m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(p.team_id = m.home_team_id, m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(p.team_id = m.home_team_id, m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(p.team_id = m.home_team_id, m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(4) AS trigger_threshold_min_blocked_shots,

    c.triggered_player_blocked_shots,
    c.triggered_player_total_shots,
    toInt32(coalesce(p.shots_on_target, 0)) AS triggered_player_shots_on_target,
    toInt32(coalesce(p.goals, 0)) AS triggered_player_goals,
    toFloat32(coalesce(p.expected_goals, 0.0)) AS triggered_player_expected_goals,
    toFloat32(coalesce(
        round(
            100.0 * coalesce(p.shots_on_target, 0)
            / nullIf(toFloat64(c.triggered_player_total_shots), 0),
            1
        ),
        0.0
    )) AS triggered_player_shot_accuracy_pct,
    toFloat32(coalesce(
        round(
            100.0 * coalesce(p.goals, 0)
            / nullIf(toFloat64(c.triggered_player_total_shots), 0),
            1
        ),
        0.0
    )) AS triggered_player_shot_conversion_pct,
    toFloat32(coalesce(
        round(
            coalesce(p.expected_goals, 0.0)
            / nullIf(toFloat64(c.triggered_player_total_shots), 0),
            3
        ),
        0.0
    )) AS triggered_player_expected_goals_per_shot,
    toFloat32(round(
        coalesce(p.goals, 0) - coalesce(p.expected_goals, 0.0),
        3
    )) AS triggered_player_goal_minus_expected_goals,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,
    toFloat32(coalesce(
        round(
            100.0 * c.triggered_player_blocked_shots
            / nullIf(toFloat64(c.triggered_player_total_shots), 0),
            1
        ),
        0.0
    )) AS triggered_player_blocked_shot_ratio_pct,
    toInt32(c.triggered_player_blocked_shots - 4) AS blocked_shots_above_threshold,
    toInt32(c.triggered_player_total_shots - c.triggered_player_blocked_shots)
        AS triggered_player_unblocked_shots,

    toInt32(if(
        p.team_id = m.home_team_id,
        coalesce(m.home_score, 0),
        coalesce(m.away_score, 0)
    )) AS triggered_team_goals,
    toInt32(if(
        p.team_id = m.home_team_id,
        coalesce(m.away_score, 0),
        coalesce(m.home_score, 0)
    )) AS opponent_goals,
    toInt32(if(
        p.team_id = m.home_team_id,
        coalesce(m.home_score, 0) - coalesce(m.away_score, 0),
        coalesce(m.away_score, 0) - coalesce(m.home_score, 0)
    )) AS goal_delta,
    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.expected_goals_home, 0.0),
        p.team_id = m.away_team_id, coalesce(ps.expected_goals_away, 0.0),
        0.0
    )) AS triggered_team_expected_goals,
    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.expected_goals_away, 0.0),
        p.team_id = m.away_team_id, coalesce(ps.expected_goals_home, 0.0),
        0.0
    )) AS opponent_expected_goals,
    toFloat32(round(
        multiIf(
            p.team_id = m.home_team_id,
                coalesce(ps.expected_goals_home, 0.0) - coalesce(ps.expected_goals_away, 0.0),
            p.team_id = m.away_team_id,
                coalesce(ps.expected_goals_away, 0.0) - coalesce(ps.expected_goals_home, 0.0),
            0.0
        ),
        3
    )) AS expected_goals_delta,
    toInt32(coalesce(ts.team_total_shots, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(os.team_total_shots, 0)) AS opponent_total_shots,
    toInt32(coalesce(ts.team_total_shots, 0) - coalesce(os.team_total_shots, 0))
        AS total_shots_delta,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.shots_on_target_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.shots_on_target_away, 0),
        0
    )) AS triggered_team_shots_on_target,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.shots_on_target_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.shots_on_target_home, 0),
        0
    )) AS opponent_shots_on_target,
    toInt32(coalesce(ts.team_blocked_shots, 0)) AS triggered_team_blocked_shots,
    toInt32(coalesce(os.team_blocked_shots, 0)) AS opponent_blocked_shots,
    toInt32(coalesce(ts.team_blocked_shots, 0) - coalesce(os.team_blocked_shots, 0))
        AS blocked_shots_delta,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.big_chances_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.big_chances_away, 0),
        0
    )) AS triggered_team_big_chances,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.big_chances_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.big_chances_home, 0),
        0
    )) AS opponent_big_chances,
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
    toFloat32(round(
        multiIf(
            p.team_id = m.home_team_id,
                coalesce(ps.ball_possession_home, 0) - coalesce(ps.ball_possession_away, 0),
            p.team_id = m.away_team_id,
                coalesce(ps.ball_possession_away, 0) - coalesce(ps.ball_possession_home, 0),
            0
        ),
        1
    )) AS possession_delta_pct,
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
    toFloat32(coalesce(round(
        100.0 * c.triggered_player_total_shots
        / nullIf(toFloat64(coalesce(ts.team_total_shots, 0)), 0),
        1
    ), 0.0)) AS player_share_of_team_total_shots_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(p.shots_on_target, 0)
        / nullIf(
            toFloat64(multiIf(
                p.team_id = m.home_team_id, coalesce(ps.shots_on_target_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.shots_on_target_away, 0),
                0
            )),
            0
        ),
        1
    ), 0.0)) AS player_share_of_team_shots_on_target_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(p.expected_goals, 0.0)
        / nullIf(
            multiIf(
                p.team_id = m.home_team_id, coalesce(ps.expected_goals_home, 0.0),
                p.team_id = m.away_team_id, coalesce(ps.expected_goals_away, 0.0),
                0.0
            ),
            0.0
        ),
        1
    ), 0.0)) AS player_share_of_team_expected_goals_pct,
    toFloat32(coalesce(round(
        100.0 * c.triggered_player_blocked_shots
        / nullIf(toFloat64(coalesce(ts.team_blocked_shots, 0)), 0),
        1
    ), 0.0)) AS player_share_of_team_blocked_shots_pct

FROM silver.player_match_stat AS p
INNER JOIN player_blocked_shot_stats AS c
    ON c.match_id = p.match_id
   AND c.triggered_player_id = p.player_id
   AND c.triggered_team_id = p.team_id
INNER JOIN silver.match AS m
    ON m.match_id = p.match_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = p.match_id
   AND ps.period = 'All'
LEFT JOIN team_blocked_shot_stats AS ts
    ON ts.match_id = p.match_id
   AND ts.team_id = p.team_id
LEFT JOIN team_blocked_shot_stats AS os
    ON os.match_id = p.match_id
   AND os.team_id = if(p.team_id = m.home_team_id, m.away_team_id, m.home_team_id)
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND p.player_id > 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id);
