INSERT INTO gold.sig_player_shooting_goals_distance_threat (
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
    trigger_threshold_min_outside_box_shots,
    triggered_player_outside_box_goals,
    triggered_player_outside_box_shots,
    triggered_player_outside_box_shots_on_target,
    triggered_player_outside_box_expected_goals,
    triggered_player_outside_box_shot_accuracy_pct,
    triggered_player_outside_box_goal_conversion_pct,
    triggered_player_goal_minus_outside_box_expected_goals,
    triggered_player_total_goals,
    triggered_player_total_shots,
    triggered_player_total_expected_goals,
    triggered_player_minutes_played,
    outside_box_shots_above_threshold,
    triggered_player_outside_box_goal_share_pct,
    triggered_player_outside_box_shot_share_pct,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_expected_goals,
    opponent_expected_goals,
    expected_goals_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    triggered_team_shots_outside_box,
    opponent_shots_outside_box,
    triggered_team_big_chances,
    opponent_big_chances,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    player_share_of_team_goals_pct,
    player_share_of_team_expected_goals_pct,
    player_share_of_team_total_shots_pct,
    player_share_of_team_shots_outside_box_pct
)
-- Signal: sig_player_shooting_goals_distance_threat
-- Trigger: player attempts >= 5 shots from outside the 18-yard box in a finished match.
-- Intent: isolate high-distance shot-volume threats using shot-level location evidence while preserving
-- bilateral team/opponent context for tactical interpretation.

WITH outside_box_shot_stats AS (
    SELECT
        s.match_id,
        toInt32(s.player_id) AS player_id,
        toInt32(s.team_id) AS team_id,
        toInt32(count()) AS triggered_player_outside_box_shots,
        toInt32(sum(if(coalesce(s.is_goal, 0) = 1, 1, 0))) AS triggered_player_outside_box_goals,
        toInt32(sum(if(coalesce(s.is_on_target, 0) = 1, 1, 0))) AS triggered_player_outside_box_shots_on_target,
        toFloat32(round(sum(coalesce(s.expected_goals, 0.0)), 3)) AS triggered_player_outside_box_expected_goals
    FROM silver.shot AS s
    WHERE coalesce(s.player_id, 0) > 0
      AND coalesce(s.team_id, 0) > 0
      AND coalesce(s.is_own_goal, 0) = 0
      AND coalesce(s.is_from_inside_box, 1) = 0
    GROUP BY
        s.match_id,
        toInt32(s.player_id),
        toInt32(s.team_id)
    HAVING count() >= 5
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

    toInt32(5) AS trigger_threshold_min_outside_box_shots,
    os.triggered_player_outside_box_goals,
    os.triggered_player_outside_box_shots,
    os.triggered_player_outside_box_shots_on_target,
    os.triggered_player_outside_box_expected_goals,
    toFloat32(coalesce(
        round(
            100.0 * os.triggered_player_outside_box_shots_on_target
            / nullIf(toFloat64(os.triggered_player_outside_box_shots), 0),
            1
        ),
        0.0
    )) AS triggered_player_outside_box_shot_accuracy_pct,
    toFloat32(coalesce(
        round(
            100.0 * os.triggered_player_outside_box_goals
            / nullIf(toFloat64(os.triggered_player_outside_box_shots), 0),
            1
        ),
        0.0
    )) AS triggered_player_outside_box_goal_conversion_pct,
    toFloat32(round(
        os.triggered_player_outside_box_goals - os.triggered_player_outside_box_expected_goals,
        3
    )) AS triggered_player_goal_minus_outside_box_expected_goals,

    toInt32(coalesce(p.goals, 0)) AS triggered_player_total_goals,
    toInt32(coalesce(p.total_shots, 0)) AS triggered_player_total_shots,
    toFloat32(coalesce(p.expected_goals, 0.0)) AS triggered_player_total_expected_goals,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,
    toInt32(os.triggered_player_outside_box_shots - 5) AS outside_box_shots_above_threshold,
    toFloat32(coalesce(
        round(
            100.0 * os.triggered_player_outside_box_goals
            / nullIf(toFloat64(coalesce(p.goals, 0)), 0),
            1
        ),
        0.0
    )) AS triggered_player_outside_box_goal_share_pct,
    toFloat32(coalesce(
        round(
            100.0 * os.triggered_player_outside_box_shots
            / nullIf(toFloat64(coalesce(p.total_shots, 0)), 0),
            1
        ),
        0.0
    )) AS triggered_player_outside_box_shot_share_pct,

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
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.total_shots_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.total_shots_away, 0),
        0
    )) AS triggered_team_total_shots,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.total_shots_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.total_shots_home, 0),
        0
    )) AS opponent_total_shots,
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
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.shots_outside_box_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.shots_outside_box_away, 0),
        0
    )) AS triggered_team_shots_outside_box,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.shots_outside_box_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.shots_outside_box_home, 0),
        0
    )) AS opponent_shots_outside_box,
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
        100.0 * coalesce(p.goals, 0)
        / nullIf(
            toFloat64(multiIf(
                p.team_id = m.home_team_id, coalesce(m.home_score, 0),
                p.team_id = m.away_team_id, coalesce(m.away_score, 0),
                0
            )),
            0
        ),
        1
    ), 0.0)) AS player_share_of_team_goals_pct,
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
        100.0 * coalesce(p.total_shots, 0)
        / nullIf(
            toFloat64(multiIf(
                p.team_id = m.home_team_id, coalesce(ps.total_shots_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.total_shots_away, 0),
                0
            )),
            0
        ),
        1
    ), 0.0)) AS player_share_of_team_total_shots_pct,
    toFloat32(coalesce(round(
        100.0 * os.triggered_player_outside_box_shots
        / nullIf(
            toFloat64(multiIf(
                p.team_id = m.home_team_id, coalesce(ps.shots_outside_box_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.shots_outside_box_away, 0),
                0
            )),
            0
        ),
        1
    ), 0.0)) AS player_share_of_team_shots_outside_box_pct

FROM outside_box_shot_stats AS os
INNER JOIN silver.player_match_stat AS p
    ON p.match_id = os.match_id
   AND p.player_id = os.player_id
   AND p.team_id = os.team_id
INNER JOIN silver.match AS m
    ON m.match_id = os.match_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = os.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND p.player_id > 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)

ORDER BY
    os.triggered_player_outside_box_shots DESC,
    os.triggered_player_outside_box_shots_on_target DESC,
    os.triggered_player_outside_box_expected_goals DESC,
    m.match_date DESC,
    m.match_id DESC;
