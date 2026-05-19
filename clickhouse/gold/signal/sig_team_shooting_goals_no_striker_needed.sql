INSERT INTO gold.sig_team_shooting_goals_no_striker_needed (
    match_id,
    match_date,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,
    triggered_side,
    triggered_team_id,
    triggered_team_name,
    opponent_team_id,
    opponent_team_name,
    trigger_threshold_min_non_own_goals,
    trigger_threshold_required_forward_non_own_goals,
    triggered_team_non_own_goals,
    opponent_non_own_goals,
    non_own_goals_delta,
    triggered_team_midfielder_non_own_goals,
    opponent_midfielder_non_own_goals,
    midfielder_non_own_goals_delta,
    triggered_team_defender_non_own_goals,
    opponent_defender_non_own_goals,
    defender_non_own_goals_delta,
    triggered_team_midfielder_defender_non_own_goals,
    opponent_midfielder_defender_non_own_goals,
    midfielder_defender_non_own_goals_delta,
    triggered_team_forward_non_own_goals,
    opponent_forward_non_own_goals,
    forward_non_own_goals_delta,
    triggered_team_other_or_unknown_non_own_goals,
    opponent_other_or_unknown_non_own_goals,
    other_or_unknown_non_own_goals_delta,
    triggered_team_distinct_midfielder_defender_goal_scorers,
    opponent_distinct_midfielder_defender_goal_scorers,
    distinct_midfielder_defender_goal_scorers_delta,
    triggered_team_distinct_forward_goal_scorers,
    opponent_distinct_forward_goal_scorers,
    distinct_forward_goal_scorers_delta,
    triggered_team_midfielder_defender_goal_share_pct,
    opponent_midfielder_defender_goal_share_pct,
    midfielder_defender_goal_share_delta_pct,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_big_chances,
    opponent_big_chances,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct
)
-- Signal: sig_team_shooting_goals_no_striker_needed
-- Trigger: Team scores > 2 non-own goals and all of those goals are scored by defenders or midfielders.
-- Intent: Capture team finishing profiles that produce high goal output without forward scorers,
--         with bilateral context on role-based scoring composition and shooting control profile.
WITH player_role AS (
    SELECT
        mp.match_id,
        toInt32(mp.person_id) AS player_id,
        argMax(mp.position_id, if(mp.role = 'starter', 2, 1)) AS position_id,
        argMax(mp.usual_playing_position_id, if(mp.role = 'starter', 2, 1)) AS usual_playing_position_id
    FROM silver.match_personnel AS mp
    WHERE mp.role IN ('starter', 'substitute')
      AND coalesce(mp.person_id, 0) > 0
    GROUP BY
        mp.match_id,
        toInt32(mp.person_id)
),
goal_events AS (
    SELECT
        s.match_id,
        toInt32(s.team_id) AS team_id,
        multiIf(
            coalesce(s.player_id, 0) > 0,
            concat('id:', toString(toInt32(s.player_id))),
            length(trimBoth(coalesce(s.player_name, ''))) > 0,
            concat('name:', lowerUTF8(trimBoth(coalesce(s.player_name, '')))),
            concat('fallback_shot:', toString(toInt64(coalesce(s.shot_id, 0))))
        ) AS scorer_key,
        toInt32(coalesce(pr.usual_playing_position_id, 0)) AS usual_playing_position_id
    FROM silver.shot AS s
    LEFT JOIN player_role AS pr
        ON pr.match_id = s.match_id
       AND pr.player_id = toInt32(s.player_id)
    WHERE s.match_id > 0
      AND coalesce(s.team_id, 0) > 0
      AND coalesce(s.is_goal, 0) = 1
      AND coalesce(s.is_own_goal, 0) = 0
),
team_goal_role_rollup AS (
    SELECT
        ge.match_id,
        ge.team_id,
        toInt32(count()) AS team_non_own_goals,
        toInt32(countIf(ge.usual_playing_position_id = 2)) AS team_midfielder_non_own_goals,
        toInt32(countIf(ge.usual_playing_position_id = 1)) AS team_defender_non_own_goals,
        toInt32(countIf(ge.usual_playing_position_id = 3)) AS team_forward_non_own_goals,
        toInt32(countIf(ge.usual_playing_position_id IN (1, 2)))
            AS team_midfielder_defender_non_own_goals,
        toInt32(countIf(ge.usual_playing_position_id NOT IN (1, 2, 3)))
            AS team_other_or_unknown_non_own_goals,
        toInt32(uniqExactIf(ge.scorer_key, ge.usual_playing_position_id IN (1, 2)))
            AS team_distinct_midfielder_defender_goal_scorers,
        toInt32(uniqExactIf(ge.scorer_key, ge.usual_playing_position_id = 3))
            AS team_distinct_forward_goal_scorers
    FROM goal_events AS ge
    GROUP BY
        ge.match_id,
        ge.team_id
)

-- Home-side trigger.
SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    'home' AS triggered_side,
    m.home_team_id AS triggered_team_id,
    m.home_team_name AS triggered_team_name,
    m.away_team_id AS opponent_team_id,
    m.away_team_name AS opponent_team_name,

    toInt32(3) AS trigger_threshold_min_non_own_goals,
    toInt32(0) AS trigger_threshold_required_forward_non_own_goals,

    toInt32(coalesce(home_role.team_non_own_goals, 0)) AS triggered_team_non_own_goals,
    toInt32(coalesce(away_role.team_non_own_goals, 0)) AS opponent_non_own_goals,
    toInt32(
        coalesce(home_role.team_non_own_goals, 0)
      - coalesce(away_role.team_non_own_goals, 0)
    ) AS non_own_goals_delta,

    toInt32(coalesce(home_role.team_midfielder_non_own_goals, 0)) AS triggered_team_midfielder_non_own_goals,
    toInt32(coalesce(away_role.team_midfielder_non_own_goals, 0)) AS opponent_midfielder_non_own_goals,
    toInt32(
        coalesce(home_role.team_midfielder_non_own_goals, 0)
      - coalesce(away_role.team_midfielder_non_own_goals, 0)
    ) AS midfielder_non_own_goals_delta,

    toInt32(coalesce(home_role.team_defender_non_own_goals, 0)) AS triggered_team_defender_non_own_goals,
    toInt32(coalesce(away_role.team_defender_non_own_goals, 0)) AS opponent_defender_non_own_goals,
    toInt32(
        coalesce(home_role.team_defender_non_own_goals, 0)
      - coalesce(away_role.team_defender_non_own_goals, 0)
    ) AS defender_non_own_goals_delta,

    toInt32(coalesce(home_role.team_midfielder_defender_non_own_goals, 0))
        AS triggered_team_midfielder_defender_non_own_goals,
    toInt32(coalesce(away_role.team_midfielder_defender_non_own_goals, 0))
        AS opponent_midfielder_defender_non_own_goals,
    toInt32(
        coalesce(home_role.team_midfielder_defender_non_own_goals, 0)
      - coalesce(away_role.team_midfielder_defender_non_own_goals, 0)
    ) AS midfielder_defender_non_own_goals_delta,

    toInt32(coalesce(home_role.team_forward_non_own_goals, 0)) AS triggered_team_forward_non_own_goals,
    toInt32(coalesce(away_role.team_forward_non_own_goals, 0)) AS opponent_forward_non_own_goals,
    toInt32(
        coalesce(home_role.team_forward_non_own_goals, 0)
      - coalesce(away_role.team_forward_non_own_goals, 0)
    ) AS forward_non_own_goals_delta,

    toInt32(coalesce(home_role.team_other_or_unknown_non_own_goals, 0))
        AS triggered_team_other_or_unknown_non_own_goals,
    toInt32(coalesce(away_role.team_other_or_unknown_non_own_goals, 0))
        AS opponent_other_or_unknown_non_own_goals,
    toInt32(
        coalesce(home_role.team_other_or_unknown_non_own_goals, 0)
      - coalesce(away_role.team_other_or_unknown_non_own_goals, 0)
    ) AS other_or_unknown_non_own_goals_delta,

    toInt32(coalesce(home_role.team_distinct_midfielder_defender_goal_scorers, 0))
        AS triggered_team_distinct_midfielder_defender_goal_scorers,
    toInt32(coalesce(away_role.team_distinct_midfielder_defender_goal_scorers, 0))
        AS opponent_distinct_midfielder_defender_goal_scorers,
    toInt32(
        coalesce(home_role.team_distinct_midfielder_defender_goal_scorers, 0)
      - coalesce(away_role.team_distinct_midfielder_defender_goal_scorers, 0)
    ) AS distinct_midfielder_defender_goal_scorers_delta,

    toInt32(coalesce(home_role.team_distinct_forward_goal_scorers, 0))
        AS triggered_team_distinct_forward_goal_scorers,
    toInt32(coalesce(away_role.team_distinct_forward_goal_scorers, 0))
        AS opponent_distinct_forward_goal_scorers,
    toInt32(
        coalesce(home_role.team_distinct_forward_goal_scorers, 0)
      - coalesce(away_role.team_distinct_forward_goal_scorers, 0)
    ) AS distinct_forward_goal_scorers_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(home_role.team_midfielder_defender_non_own_goals, 0)
        / nullIf(toFloat64(coalesce(home_role.team_non_own_goals, 0)), 0),
        1
    ), 0.0)) AS triggered_team_midfielder_defender_goal_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(away_role.team_midfielder_defender_non_own_goals, 0)
        / nullIf(toFloat64(coalesce(away_role.team_non_own_goals, 0)), 0),
        1
    ), 0.0)) AS opponent_midfielder_defender_goal_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(home_role.team_midfielder_defender_non_own_goals, 0)
            / nullIf(toFloat64(coalesce(home_role.team_non_own_goals, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(away_role.team_midfielder_defender_non_own_goals, 0)
            / nullIf(toFloat64(coalesce(away_role.team_non_own_goals, 0)), 0),
            1
        ), 0.0),
        1
    )) AS midfielder_defender_goal_share_delta_pct,

    toInt32(coalesce(m.home_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.away_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.home_score, 0) - coalesce(m.away_score, 0)) AS goal_delta,

    toInt32(coalesce(ps.total_shots_home, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_away, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS opponent_shots_on_target,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS opponent_xg,
    toFloat32(round(
        coalesce(ps.expected_goals_home, 0.0) - coalesce(ps.expected_goals_away, 0.0),
        3
    )) AS xg_delta,
    toInt32(coalesce(ps.big_chances_home, 0)) AS triggered_team_big_chances,
    toInt32(coalesce(ps.big_chances_away, 0)) AS opponent_big_chances,
    toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS opponent_possession_pct,
    toFloat32(round(
        coalesce(ps.ball_possession_home, 0.0) - coalesce(ps.ball_possession_away, 0.0),
        1
    )) AS possession_delta_pct

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN team_goal_role_rollup AS home_role
    ON home_role.match_id = m.match_id
   AND home_role.team_id = m.home_team_id
LEFT JOIN team_goal_role_rollup AS away_role
    ON away_role.match_id = m.match_id
   AND away_role.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(home_role.team_non_own_goals, 0) > 2
  AND coalesce(home_role.team_non_own_goals, 0) = coalesce(home_role.team_midfielder_defender_non_own_goals, 0)

UNION ALL

-- Away-side trigger.
SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    'away' AS triggered_side,
    m.away_team_id AS triggered_team_id,
    m.away_team_name AS triggered_team_name,
    m.home_team_id AS opponent_team_id,
    m.home_team_name AS opponent_team_name,

    toInt32(3) AS trigger_threshold_min_non_own_goals,
    toInt32(0) AS trigger_threshold_required_forward_non_own_goals,

    toInt32(coalesce(away_role.team_non_own_goals, 0)) AS triggered_team_non_own_goals,
    toInt32(coalesce(home_role.team_non_own_goals, 0)) AS opponent_non_own_goals,
    toInt32(
        coalesce(away_role.team_non_own_goals, 0)
      - coalesce(home_role.team_non_own_goals, 0)
    ) AS non_own_goals_delta,

    toInt32(coalesce(away_role.team_midfielder_non_own_goals, 0)) AS triggered_team_midfielder_non_own_goals,
    toInt32(coalesce(home_role.team_midfielder_non_own_goals, 0)) AS opponent_midfielder_non_own_goals,
    toInt32(
        coalesce(away_role.team_midfielder_non_own_goals, 0)
      - coalesce(home_role.team_midfielder_non_own_goals, 0)
    ) AS midfielder_non_own_goals_delta,

    toInt32(coalesce(away_role.team_defender_non_own_goals, 0)) AS triggered_team_defender_non_own_goals,
    toInt32(coalesce(home_role.team_defender_non_own_goals, 0)) AS opponent_defender_non_own_goals,
    toInt32(
        coalesce(away_role.team_defender_non_own_goals, 0)
      - coalesce(home_role.team_defender_non_own_goals, 0)
    ) AS defender_non_own_goals_delta,

    toInt32(coalesce(away_role.team_midfielder_defender_non_own_goals, 0))
        AS triggered_team_midfielder_defender_non_own_goals,
    toInt32(coalesce(home_role.team_midfielder_defender_non_own_goals, 0))
        AS opponent_midfielder_defender_non_own_goals,
    toInt32(
        coalesce(away_role.team_midfielder_defender_non_own_goals, 0)
      - coalesce(home_role.team_midfielder_defender_non_own_goals, 0)
    ) AS midfielder_defender_non_own_goals_delta,

    toInt32(coalesce(away_role.team_forward_non_own_goals, 0)) AS triggered_team_forward_non_own_goals,
    toInt32(coalesce(home_role.team_forward_non_own_goals, 0)) AS opponent_forward_non_own_goals,
    toInt32(
        coalesce(away_role.team_forward_non_own_goals, 0)
      - coalesce(home_role.team_forward_non_own_goals, 0)
    ) AS forward_non_own_goals_delta,

    toInt32(coalesce(away_role.team_other_or_unknown_non_own_goals, 0))
        AS triggered_team_other_or_unknown_non_own_goals,
    toInt32(coalesce(home_role.team_other_or_unknown_non_own_goals, 0))
        AS opponent_other_or_unknown_non_own_goals,
    toInt32(
        coalesce(away_role.team_other_or_unknown_non_own_goals, 0)
      - coalesce(home_role.team_other_or_unknown_non_own_goals, 0)
    ) AS other_or_unknown_non_own_goals_delta,

    toInt32(coalesce(away_role.team_distinct_midfielder_defender_goal_scorers, 0))
        AS triggered_team_distinct_midfielder_defender_goal_scorers,
    toInt32(coalesce(home_role.team_distinct_midfielder_defender_goal_scorers, 0))
        AS opponent_distinct_midfielder_defender_goal_scorers,
    toInt32(
        coalesce(away_role.team_distinct_midfielder_defender_goal_scorers, 0)
      - coalesce(home_role.team_distinct_midfielder_defender_goal_scorers, 0)
    ) AS distinct_midfielder_defender_goal_scorers_delta,

    toInt32(coalesce(away_role.team_distinct_forward_goal_scorers, 0))
        AS triggered_team_distinct_forward_goal_scorers,
    toInt32(coalesce(home_role.team_distinct_forward_goal_scorers, 0))
        AS opponent_distinct_forward_goal_scorers,
    toInt32(
        coalesce(away_role.team_distinct_forward_goal_scorers, 0)
      - coalesce(home_role.team_distinct_forward_goal_scorers, 0)
    ) AS distinct_forward_goal_scorers_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(away_role.team_midfielder_defender_non_own_goals, 0)
        / nullIf(toFloat64(coalesce(away_role.team_non_own_goals, 0)), 0),
        1
    ), 0.0)) AS triggered_team_midfielder_defender_goal_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(home_role.team_midfielder_defender_non_own_goals, 0)
        / nullIf(toFloat64(coalesce(home_role.team_non_own_goals, 0)), 0),
        1
    ), 0.0)) AS opponent_midfielder_defender_goal_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(away_role.team_midfielder_defender_non_own_goals, 0)
            / nullIf(toFloat64(coalesce(away_role.team_non_own_goals, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(home_role.team_midfielder_defender_non_own_goals, 0)
            / nullIf(toFloat64(coalesce(home_role.team_non_own_goals, 0)), 0),
            1
        ), 0.0),
        1
    )) AS midfielder_defender_goal_share_delta_pct,

    toInt32(coalesce(m.away_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.home_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.away_score, 0) - coalesce(m.home_score, 0)) AS goal_delta,

    toInt32(coalesce(ps.total_shots_away, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_home, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS opponent_shots_on_target,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS opponent_xg,
    toFloat32(round(
        coalesce(ps.expected_goals_away, 0.0) - coalesce(ps.expected_goals_home, 0.0),
        3
    )) AS xg_delta,
    toInt32(coalesce(ps.big_chances_away, 0)) AS triggered_team_big_chances,
    toInt32(coalesce(ps.big_chances_home, 0)) AS opponent_big_chances,
    toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS opponent_possession_pct,
    toFloat32(round(
        coalesce(ps.ball_possession_away, 0.0) - coalesce(ps.ball_possession_home, 0.0),
        1
    )) AS possession_delta_pct

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN team_goal_role_rollup AS home_role
    ON home_role.match_id = m.match_id
   AND home_role.team_id = m.home_team_id
LEFT JOIN team_goal_role_rollup AS away_role
    ON away_role.match_id = m.match_id
   AND away_role.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(away_role.team_non_own_goals, 0) > 2
  AND coalesce(away_role.team_non_own_goals, 0) = coalesce(away_role.team_midfielder_defender_non_own_goals, 0);
