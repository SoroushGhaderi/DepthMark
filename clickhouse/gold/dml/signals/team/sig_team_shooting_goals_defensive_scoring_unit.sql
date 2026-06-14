INSERT INTO gold.sig_team_shooting_goals_defensive_scoring_unit (
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
    trigger_threshold_min_distinct_defender_goal_scorers,
    triggered_team_distinct_defender_goal_scorers,
    opponent_distinct_defender_goal_scorers,
    distinct_defender_goal_scorers_delta,
    triggered_team_defender_non_own_goals,
    opponent_defender_non_own_goals,
    defender_non_own_goals_delta,
    triggered_team_top_defender_scorer_goals,
    opponent_top_defender_scorer_goals,
    top_defender_scorer_goals_delta,
    triggered_team_non_own_goals,
    opponent_non_own_goals,
    non_own_goals_delta,
    triggered_team_defender_goal_share_pct,
    opponent_defender_goal_share_pct,
    defender_goal_share_delta_pct,
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
-- Signal: sig_team_shooting_goals_defensive_scoring_unit
-- Trigger: Team has >= 2 different defenders score non-own goals in one finished match.
-- Intent: Capture team scoring patterns where defensive players contribute direct finishing output,
--         with bilateral context on defender-goal concentration and shooting control profile.
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
defender_goal_events AS (
    SELECT
        s.match_id,
        toInt32(s.team_id) AS team_id,
        concat('id:', toString(toInt32(s.player_id))) AS scorer_key
    FROM silver.shot AS s
    INNER JOIN player_role AS pr
        ON pr.match_id = s.match_id
       AND pr.player_id = toInt32(s.player_id)
    WHERE s.match_id > 0
      AND coalesce(s.team_id, 0) > 0
      AND coalesce(s.player_id, 0) > 0
      AND coalesce(s.is_goal, 0) = 1
      AND coalesce(s.is_own_goal, 0) = 0
      AND coalesce(pr.usual_playing_position_id, 0) = 1
),
defender_scorer_goal_counts AS (
    SELECT
        dge.match_id,
        dge.team_id,
        dge.scorer_key,
        toInt32(count()) AS goals_by_defender_scorer
    FROM defender_goal_events AS dge
    GROUP BY
        dge.match_id,
        dge.team_id,
        dge.scorer_key
),
team_defender_goal_rollup AS (
    SELECT
        dsgc.match_id,
        dsgc.team_id,
        toInt32(count()) AS team_distinct_defender_goal_scorers,
        toInt32(sum(dsgc.goals_by_defender_scorer)) AS team_defender_non_own_goals,
        toInt32(max(dsgc.goals_by_defender_scorer)) AS team_top_defender_scorer_goals
    FROM defender_scorer_goal_counts AS dsgc
    GROUP BY
        dsgc.match_id,
        dsgc.team_id
),
team_non_own_goal_rollup AS (
    SELECT
        s.match_id,
        toInt32(s.team_id) AS team_id,
        toInt32(count()) AS team_non_own_goals
    FROM silver.shot AS s
    WHERE s.match_id > 0
      AND coalesce(s.team_id, 0) > 0
      AND coalesce(s.is_goal, 0) = 1
      AND coalesce(s.is_own_goal, 0) = 0
    GROUP BY
        s.match_id,
        toInt32(s.team_id)
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

    toInt32(2) AS trigger_threshold_min_distinct_defender_goal_scorers,

    toInt32(coalesce(home_def.team_distinct_defender_goal_scorers, 0))
        AS triggered_team_distinct_defender_goal_scorers,
    toInt32(coalesce(away_def.team_distinct_defender_goal_scorers, 0))
        AS opponent_distinct_defender_goal_scorers,
    toInt32(
        coalesce(home_def.team_distinct_defender_goal_scorers, 0)
      - coalesce(away_def.team_distinct_defender_goal_scorers, 0)
    ) AS distinct_defender_goal_scorers_delta,

    toInt32(coalesce(home_def.team_defender_non_own_goals, 0)) AS triggered_team_defender_non_own_goals,
    toInt32(coalesce(away_def.team_defender_non_own_goals, 0)) AS opponent_defender_non_own_goals,
    toInt32(
        coalesce(home_def.team_defender_non_own_goals, 0)
      - coalesce(away_def.team_defender_non_own_goals, 0)
    ) AS defender_non_own_goals_delta,

    toInt32(coalesce(home_def.team_top_defender_scorer_goals, 0)) AS triggered_team_top_defender_scorer_goals,
    toInt32(coalesce(away_def.team_top_defender_scorer_goals, 0)) AS opponent_top_defender_scorer_goals,
    toInt32(
        coalesce(home_def.team_top_defender_scorer_goals, 0)
      - coalesce(away_def.team_top_defender_scorer_goals, 0)
    ) AS top_defender_scorer_goals_delta,

    toInt32(coalesce(home_goal.team_non_own_goals, 0)) AS triggered_team_non_own_goals,
    toInt32(coalesce(away_goal.team_non_own_goals, 0)) AS opponent_non_own_goals,
    toInt32(
        coalesce(home_goal.team_non_own_goals, 0)
      - coalesce(away_goal.team_non_own_goals, 0)
    ) AS non_own_goals_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(home_def.team_defender_non_own_goals, 0)
        / nullIf(toFloat64(coalesce(home_goal.team_non_own_goals, 0)), 0),
        1
    ), 0.0)) AS triggered_team_defender_goal_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(away_def.team_defender_non_own_goals, 0)
        / nullIf(toFloat64(coalesce(away_goal.team_non_own_goals, 0)), 0),
        1
    ), 0.0)) AS opponent_defender_goal_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(home_def.team_defender_non_own_goals, 0)
            / nullIf(toFloat64(coalesce(home_goal.team_non_own_goals, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(away_def.team_defender_non_own_goals, 0)
            / nullIf(toFloat64(coalesce(away_goal.team_non_own_goals, 0)), 0),
            1
        ), 0.0),
        1
    )) AS defender_goal_share_delta_pct,

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
LEFT JOIN team_defender_goal_rollup AS home_def
    ON home_def.match_id = m.match_id
   AND home_def.team_id = m.home_team_id
LEFT JOIN team_defender_goal_rollup AS away_def
    ON away_def.match_id = m.match_id
   AND away_def.team_id = m.away_team_id
LEFT JOIN team_non_own_goal_rollup AS home_goal
    ON home_goal.match_id = m.match_id
   AND home_goal.team_id = m.home_team_id
LEFT JOIN team_non_own_goal_rollup AS away_goal
    ON away_goal.match_id = m.match_id
   AND away_goal.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(home_def.team_distinct_defender_goal_scorers, 0) >= 2

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

    toInt32(2) AS trigger_threshold_min_distinct_defender_goal_scorers,

    toInt32(coalesce(away_def.team_distinct_defender_goal_scorers, 0))
        AS triggered_team_distinct_defender_goal_scorers,
    toInt32(coalesce(home_def.team_distinct_defender_goal_scorers, 0))
        AS opponent_distinct_defender_goal_scorers,
    toInt32(
        coalesce(away_def.team_distinct_defender_goal_scorers, 0)
      - coalesce(home_def.team_distinct_defender_goal_scorers, 0)
    ) AS distinct_defender_goal_scorers_delta,

    toInt32(coalesce(away_def.team_defender_non_own_goals, 0)) AS triggered_team_defender_non_own_goals,
    toInt32(coalesce(home_def.team_defender_non_own_goals, 0)) AS opponent_defender_non_own_goals,
    toInt32(
        coalesce(away_def.team_defender_non_own_goals, 0)
      - coalesce(home_def.team_defender_non_own_goals, 0)
    ) AS defender_non_own_goals_delta,

    toInt32(coalesce(away_def.team_top_defender_scorer_goals, 0)) AS triggered_team_top_defender_scorer_goals,
    toInt32(coalesce(home_def.team_top_defender_scorer_goals, 0)) AS opponent_top_defender_scorer_goals,
    toInt32(
        coalesce(away_def.team_top_defender_scorer_goals, 0)
      - coalesce(home_def.team_top_defender_scorer_goals, 0)
    ) AS top_defender_scorer_goals_delta,

    toInt32(coalesce(away_goal.team_non_own_goals, 0)) AS triggered_team_non_own_goals,
    toInt32(coalesce(home_goal.team_non_own_goals, 0)) AS opponent_non_own_goals,
    toInt32(
        coalesce(away_goal.team_non_own_goals, 0)
      - coalesce(home_goal.team_non_own_goals, 0)
    ) AS non_own_goals_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(away_def.team_defender_non_own_goals, 0)
        / nullIf(toFloat64(coalesce(away_goal.team_non_own_goals, 0)), 0),
        1
    ), 0.0)) AS triggered_team_defender_goal_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(home_def.team_defender_non_own_goals, 0)
        / nullIf(toFloat64(coalesce(home_goal.team_non_own_goals, 0)), 0),
        1
    ), 0.0)) AS opponent_defender_goal_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(away_def.team_defender_non_own_goals, 0)
            / nullIf(toFloat64(coalesce(away_goal.team_non_own_goals, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(home_def.team_defender_non_own_goals, 0)
            / nullIf(toFloat64(coalesce(home_goal.team_non_own_goals, 0)), 0),
            1
        ), 0.0),
        1
    )) AS defender_goal_share_delta_pct,

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
LEFT JOIN team_defender_goal_rollup AS home_def
    ON home_def.match_id = m.match_id
   AND home_def.team_id = m.home_team_id
LEFT JOIN team_defender_goal_rollup AS away_def
    ON away_def.match_id = m.match_id
   AND away_def.team_id = m.away_team_id
LEFT JOIN team_non_own_goal_rollup AS home_goal
    ON home_goal.match_id = m.match_id
   AND home_goal.team_id = m.home_team_id
LEFT JOIN team_non_own_goal_rollup AS away_goal
    ON away_goal.match_id = m.match_id
   AND away_goal.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(away_def.team_distinct_defender_goal_scorers, 0) >= 2

ORDER BY
    triggered_team_distinct_defender_goal_scorers DESC,
    triggered_team_defender_non_own_goals DESC,
    triggered_team_defender_goal_share_pct DESC,
    m.match_date DESC,
    m.match_id DESC;
