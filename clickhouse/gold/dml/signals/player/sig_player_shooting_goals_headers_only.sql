INSERT INTO gold.sig_player_shooting_goals_headers_only (
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
    trigger_threshold_min_goals,
    triggered_player_goals,
    triggered_player_header_goals,
    triggered_player_non_header_goals,
    triggered_player_header_goal_share_pct,
    triggered_player_total_shots,
    triggered_player_shots_on_target,
    triggered_player_shot_accuracy_pct,
    triggered_player_header_shots,
    triggered_player_header_shots_on_target,
    triggered_player_header_shot_accuracy_pct,
    triggered_player_expected_goals,
    triggered_player_header_expected_goals,
    triggered_player_goal_minus_expected_goals,
    triggered_player_minutes_played,
    goals_above_threshold,
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
    triggered_team_header_goals,
    opponent_header_goals,
    triggered_team_header_shots,
    opponent_header_shots,
    triggered_team_header_expected_goals,
    opponent_header_expected_goals,
    player_share_of_team_goals_pct,
    player_share_of_team_expected_goals_pct,
    player_share_of_team_total_shots_pct,
    player_share_of_team_header_goals_pct
)
-- Signal: sig_player_shooting_goals_headers_only
-- Trigger: player scores >= 2 goals and every one of those goals is a header in the same finished match.
-- Intent: isolate aerial-dominant brace-or-better finishing performances with bilateral match and team-header context.

WITH player_header_stats AS (
    SELECT
        s.match_id,
        toInt32(s.player_id) AS player_id,
        toInt32(s.team_id) AS team_id,
        toInt32(sum(if(
            coalesce(s.is_goal, 0) = 1
            AND positionCaseInsensitiveUTF8(coalesce(s.shot_type, ''), 'header') > 0,
            1,
            0
        ))) AS triggered_player_header_goals,
        toInt32(sum(if(
            coalesce(s.is_goal, 0) = 1
            AND positionCaseInsensitiveUTF8(coalesce(s.shot_type, ''), 'header') = 0,
            1,
            0
        ))) AS triggered_player_non_header_goals,
        toInt32(sum(if(
            positionCaseInsensitiveUTF8(coalesce(s.shot_type, ''), 'header') > 0,
            1,
            0
        ))) AS triggered_player_header_shots,
        toInt32(sum(if(
            positionCaseInsensitiveUTF8(coalesce(s.shot_type, ''), 'header') > 0
            AND coalesce(s.is_on_target, 0) = 1,
            1,
            0
        ))) AS triggered_player_header_shots_on_target,
        toFloat32(round(sum(if(
            positionCaseInsensitiveUTF8(coalesce(s.shot_type, ''), 'header') > 0,
            coalesce(s.expected_goals, 0.0),
            0.0
        )), 3)) AS triggered_player_header_expected_goals
    FROM silver.shot AS s
    WHERE coalesce(s.player_id, 0) > 0
      AND coalesce(s.team_id, 0) > 0
      AND coalesce(s.is_own_goal, 0) = 0
    GROUP BY
        s.match_id,
        toInt32(s.player_id),
        toInt32(s.team_id)
),
team_header_stats AS (
    SELECT
        s.match_id,
        toInt32(s.team_id) AS team_id,
        toInt32(sum(if(
            coalesce(s.is_goal, 0) = 1
            AND positionCaseInsensitiveUTF8(coalesce(s.shot_type, ''), 'header') > 0,
            1,
            0
        ))) AS team_header_goals,
        toInt32(sum(if(
            positionCaseInsensitiveUTF8(coalesce(s.shot_type, ''), 'header') > 0,
            1,
            0
        ))) AS team_header_shots,
        toFloat32(round(sum(if(
            positionCaseInsensitiveUTF8(coalesce(s.shot_type, ''), 'header') > 0,
            coalesce(s.expected_goals, 0.0),
            0.0
        )), 3)) AS team_header_expected_goals
    FROM silver.shot AS s
    WHERE coalesce(s.team_id, 0) > 0
      AND coalesce(s.is_own_goal, 0) = 0
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

    toInt32(2) AS trigger_threshold_min_goals,

    toInt32(coalesce(p.goals, 0)) AS triggered_player_goals,
    toInt32(coalesce(phs.triggered_player_header_goals, 0)) AS triggered_player_header_goals,
    toInt32(coalesce(phs.triggered_player_non_header_goals, 0)) AS triggered_player_non_header_goals,
    toFloat32(coalesce(round(
        100.0 * coalesce(phs.triggered_player_header_goals, 0)
        / nullIf(toFloat64(coalesce(p.goals, 0)), 0),
        1
    ), 0.0)) AS triggered_player_header_goal_share_pct,
    toInt32(coalesce(p.total_shots, 0)) AS triggered_player_total_shots,
    toInt32(coalesce(p.shots_on_target, 0)) AS triggered_player_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * coalesce(p.shots_on_target, 0)
        / nullIf(toFloat64(coalesce(p.total_shots, 0)), 0),
        1
    ), 0.0)) AS triggered_player_shot_accuracy_pct,
    toInt32(coalesce(phs.triggered_player_header_shots, 0)) AS triggered_player_header_shots,
    toInt32(coalesce(phs.triggered_player_header_shots_on_target, 0)) AS triggered_player_header_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * coalesce(phs.triggered_player_header_shots_on_target, 0)
        / nullIf(toFloat64(coalesce(phs.triggered_player_header_shots, 0)), 0),
        1
    ), 0.0)) AS triggered_player_header_shot_accuracy_pct,
    toFloat32(coalesce(p.expected_goals, 0.0)) AS triggered_player_expected_goals,
    toFloat32(coalesce(phs.triggered_player_header_expected_goals, 0.0)) AS triggered_player_header_expected_goals,
    toFloat32(round(
        coalesce(p.goals, 0) - coalesce(p.expected_goals, 0.0),
        3
    )) AS triggered_player_goal_minus_expected_goals,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,
    toInt32(coalesce(p.goals, 0) - 2) AS goals_above_threshold,

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

    toInt32(coalesce(ths_triggered.team_header_goals, 0)) AS triggered_team_header_goals,
    toInt32(coalesce(ths_opponent.team_header_goals, 0)) AS opponent_header_goals,
    toInt32(coalesce(ths_triggered.team_header_shots, 0)) AS triggered_team_header_shots,
    toInt32(coalesce(ths_opponent.team_header_shots, 0)) AS opponent_header_shots,
    toFloat32(coalesce(ths_triggered.team_header_expected_goals, 0.0)) AS triggered_team_header_expected_goals,
    toFloat32(coalesce(ths_opponent.team_header_expected_goals, 0.0)) AS opponent_header_expected_goals,

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
        100.0 * coalesce(phs.triggered_player_header_goals, 0)
        / nullIf(toFloat64(coalesce(ths_triggered.team_header_goals, 0)), 0),
        1
    ), 0.0)) AS player_share_of_team_header_goals_pct

FROM silver.player_match_stat AS p
INNER JOIN silver.match AS m
    ON m.match_id = p.match_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = p.match_id
   AND ps.period = 'All'
LEFT JOIN player_header_stats AS phs
    ON phs.match_id = p.match_id
   AND phs.player_id = p.player_id
   AND phs.team_id = p.team_id
LEFT JOIN team_header_stats AS ths_triggered
    ON ths_triggered.match_id = p.match_id
   AND ths_triggered.team_id = p.team_id
LEFT JOIN team_header_stats AS ths_opponent
    ON ths_opponent.match_id = p.match_id
   AND ths_opponent.team_id = if(p.team_id = m.home_team_id, m.away_team_id, m.home_team_id)
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND p.player_id > 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)
  AND coalesce(p.goals, 0) >= 2
  AND coalesce(phs.triggered_player_header_goals, 0) = coalesce(p.goals, 0)
  AND coalesce(phs.triggered_player_non_header_goals, 0) = 0

ORDER BY
    triggered_player_goals DESC,
    triggered_player_header_shots DESC,
    triggered_player_goal_minus_expected_goals DESC,
    m.match_date DESC,
    m.match_id DESC;
