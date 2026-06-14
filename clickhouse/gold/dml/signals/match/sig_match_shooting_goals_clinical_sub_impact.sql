INSERT INTO gold.sig_match_shooting_goals_clinical_sub_impact (
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
    trigger_threshold_match_substitute_non_own_goals_min,
    match_substitute_non_own_goals,
    match_total_non_own_goals,
    match_substitute_goal_share_pct,
    home_substitute_non_own_goals,
    away_substitute_non_own_goals,
    home_distinct_substitute_goal_scorers,
    away_distinct_substitute_goal_scorers,
    triggered_team_substitute_non_own_goals,
    opponent_substitute_non_own_goals,
    substitute_non_own_goals_delta,
    triggered_team_distinct_substitute_goal_scorers,
    opponent_distinct_substitute_goal_scorers,
    distinct_substitute_goal_scorers_delta,
    triggered_team_top_substitute_scorer_goals,
    opponent_top_substitute_scorer_goals,
    top_substitute_scorer_goals_delta,
    triggered_team_first_substitute_goal_effective_minute,
    opponent_first_substitute_goal_effective_minute,
    triggered_team_last_substitute_goal_effective_minute,
    opponent_last_substitute_goal_effective_minute,
    triggered_team_substitute_goal_share_pct,
    opponent_substitute_goal_share_pct,
    substitute_goal_share_delta_pct,
    triggered_team_non_own_goals,
    opponent_non_own_goals,
    non_own_goals_delta,
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
    possession_delta_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct
)
-- Signal: sig_match_shooting_goals_clinical_sub_impact
-- Intent: detect finished matches where substitute scorers drive at least three
--         non-own goals and emit side-oriented rows with bilateral shooting context.
-- Trigger: combined substitute non-own goals >= 3 in one finished match.
-- NOTE: All CTEs inlined to work around ClickHouse 24.10 analyzer bug with CTE-to-CTE LEFT JOINs.

SELECT
    m.match_id AS match_id,
    m.match_date AS match_date,
    m.home_team_id AS home_team_id,
    m.home_team_name AS home_team_name,
    m.away_team_id AS away_team_id,
    m.away_team_name AS away_team_name,
    m.home_score AS home_score,
    m.away_score AS away_score,
    'home' AS triggered_side,
    m.home_team_id AS triggered_team_id,
    m.home_team_name AS triggered_team_name,
    m.away_team_id AS opponent_team_id,
    m.away_team_name AS opponent_team_name,
    toInt32(3) AS trigger_threshold_match_substitute_non_own_goals_min,
    toInt32(coalesce(home_sub.team_substitute_non_own_goals, 0) + coalesce(away_sub.team_substitute_non_own_goals, 0)) AS match_substitute_non_own_goals,
    toInt32(coalesce(home_goal.team_non_own_goals, 0) + coalesce(away_goal.team_non_own_goals, 0)) AS match_total_non_own_goals,
    toFloat32(coalesce(round(
        100.0 * (coalesce(home_sub.team_substitute_non_own_goals, 0) + coalesce(away_sub.team_substitute_non_own_goals, 0))
        / nullIf(toFloat64(coalesce(home_goal.team_non_own_goals, 0) + coalesce(away_goal.team_non_own_goals, 0)), 0),
        1
    ), 0.0)) AS match_substitute_goal_share_pct,
    toInt32(coalesce(home_sub.team_substitute_non_own_goals, 0)) AS home_substitute_non_own_goals,
    toInt32(coalesce(away_sub.team_substitute_non_own_goals, 0)) AS away_substitute_non_own_goals,
    toInt32(coalesce(home_sub.team_distinct_substitute_goal_scorers, 0)) AS home_distinct_substitute_goal_scorers,
    toInt32(coalesce(away_sub.team_distinct_substitute_goal_scorers, 0)) AS away_distinct_substitute_goal_scorers,
    toInt32(coalesce(home_sub.team_substitute_non_own_goals, 0)) AS triggered_team_substitute_non_own_goals,
    toInt32(coalesce(away_sub.team_substitute_non_own_goals, 0)) AS opponent_substitute_non_own_goals,
    toInt32(coalesce(home_sub.team_substitute_non_own_goals, 0)) - toInt32(coalesce(away_sub.team_substitute_non_own_goals, 0)) AS substitute_non_own_goals_delta,
    toInt32(coalesce(home_sub.team_distinct_substitute_goal_scorers, 0)) AS triggered_team_distinct_substitute_goal_scorers,
    toInt32(coalesce(away_sub.team_distinct_substitute_goal_scorers, 0)) AS opponent_distinct_substitute_goal_scorers,
    toInt32(coalesce(home_sub.team_distinct_substitute_goal_scorers, 0)) - toInt32(coalesce(away_sub.team_distinct_substitute_goal_scorers, 0))
        AS distinct_substitute_goal_scorers_delta,
    toInt32(coalesce(home_sub.team_top_substitute_scorer_goals, 0)) AS triggered_team_top_substitute_scorer_goals,
    toInt32(coalesce(away_sub.team_top_substitute_scorer_goals, 0)) AS opponent_top_substitute_scorer_goals,
    toInt32(coalesce(home_sub.team_top_substitute_scorer_goals, 0)) - toInt32(coalesce(away_sub.team_top_substitute_scorer_goals, 0)) AS top_substitute_scorer_goals_delta,
    toInt32(coalesce(home_sub_time.team_first_substitute_goal_effective_minute, 0)) AS triggered_team_first_substitute_goal_effective_minute,
    toInt32(coalesce(away_sub_time.team_first_substitute_goal_effective_minute, 0)) AS opponent_first_substitute_goal_effective_minute,
    toInt32(coalesce(home_sub_time.team_last_substitute_goal_effective_minute, 0)) AS triggered_team_last_substitute_goal_effective_minute,
    toInt32(coalesce(away_sub_time.team_last_substitute_goal_effective_minute, 0)) AS opponent_last_substitute_goal_effective_minute,
    toFloat32(coalesce(round(
        100.0 * coalesce(home_sub.team_substitute_non_own_goals, 0) / nullIf(toFloat64(coalesce(home_goal.team_non_own_goals, 0)), 0),
        1
    ), 0.0)) AS triggered_team_substitute_goal_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(away_sub.team_substitute_non_own_goals, 0) / nullIf(toFloat64(coalesce(away_goal.team_non_own_goals, 0)), 0),
        1
    ), 0.0)) AS opponent_substitute_goal_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(home_sub.team_substitute_non_own_goals, 0) / nullIf(toFloat64(coalesce(home_goal.team_non_own_goals, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(away_sub.team_substitute_non_own_goals, 0) / nullIf(toFloat64(coalesce(away_goal.team_non_own_goals, 0)), 0),
            1
        ), 0.0),
        1
    )) AS substitute_goal_share_delta_pct,
    toInt32(coalesce(home_goal.team_non_own_goals, 0)) AS triggered_team_non_own_goals,
    toInt32(coalesce(away_goal.team_non_own_goals, 0)) AS opponent_non_own_goals,
    toInt32(coalesce(home_goal.team_non_own_goals, 0)) - toInt32(coalesce(away_goal.team_non_own_goals, 0)) AS non_own_goals_delta,
    toInt32(coalesce(m.home_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.away_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.home_score, 0)) - toInt32(coalesce(m.away_score, 0)) AS goal_delta,
    toInt32(coalesce(ps.total_shots_home, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_away, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS opponent_shots_on_target,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS opponent_xg,
    toFloat32(round(toFloat32(coalesce(ps.expected_goals_home, 0.0)) - toFloat32(coalesce(ps.expected_goals_away, 0.0)), 3)) AS xg_delta,
    toInt32(coalesce(ps.big_chances_home, 0)) AS triggered_team_big_chances,
    toInt32(coalesce(ps.big_chances_away, 0)) AS opponent_big_chances,
    toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS opponent_possession_pct,
    toFloat32(round(toFloat32(coalesce(ps.ball_possession_home, 0.0)) - toFloat32(coalesce(ps.ball_possession_away, 0.0)), 1)) AS possession_delta_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0), 1), 0.0)
        - coalesce(round(100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct
FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN (
    SELECT
        ssgc.match_id,
        ssgc.team_id,
        toInt32(sum(ssgc.goals_by_substitute_scorer)) AS team_substitute_non_own_goals,
        toInt32(count()) AS team_distinct_substitute_goal_scorers,
        toInt32(max(ssgc.goals_by_substitute_scorer)) AS team_top_substitute_scorer_goals
    FROM (
        SELECT
            sge.match_id,
            sge.team_id,
            sge.player_id,
            toInt32(count()) AS goals_by_substitute_scorer
        FROM (
            SELECT
                s.match_id,
                toInt32(s.team_id) AS team_id,
                toInt32(s.player_id) AS player_id,
                toInt32(
                    coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
                ) AS goal_effective_minute
            FROM silver.shot AS s
            INNER JOIN (
                SELECT
                    mp.match_id,
                    toInt32(assumeNotNull(mp.person_id)) AS player_id,
                    toInt32(max(toInt32(coalesce(mp.substitution_time, 0)))) AS substitution_time
                FROM silver.match_personnel AS mp
                WHERE mp.match_id > 0
                  AND mp.person_id IS NOT NULL
                  AND lowerUTF8(coalesce(mp.role, '')) = 'substitute'
                  AND toInt32(coalesce(mp.substitution_time, 0)) > 0
                GROUP BY mp.match_id, player_id
            ) AS se
                ON se.match_id = s.match_id
               AND se.player_id = toInt32(s.player_id)
            WHERE s.match_id > 0
              AND coalesce(s.team_id, 0) > 0
              AND coalesce(s.player_id, 0) > 0
              AND coalesce(s.is_goal, 0) = 1
              AND coalesce(s.is_own_goal, 0) = 0
              AND toInt32(
                    coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
                ) >= se.substitution_time
        ) AS sge
        GROUP BY sge.match_id, sge.team_id, sge.player_id
    ) AS ssgc
    GROUP BY ssgc.match_id, ssgc.team_id
) AS home_sub
    ON home_sub.match_id = m.match_id
   AND home_sub.team_id = m.home_team_id
LEFT JOIN (
    SELECT
        ssgc.match_id,
        ssgc.team_id,
        toInt32(sum(ssgc.goals_by_substitute_scorer)) AS team_substitute_non_own_goals,
        toInt32(count()) AS team_distinct_substitute_goal_scorers,
        toInt32(max(ssgc.goals_by_substitute_scorer)) AS team_top_substitute_scorer_goals
    FROM (
        SELECT
            sge.match_id,
            sge.team_id,
            sge.player_id,
            toInt32(count()) AS goals_by_substitute_scorer
        FROM (
            SELECT
                s.match_id,
                toInt32(s.team_id) AS team_id,
                toInt32(s.player_id) AS player_id,
                toInt32(
                    coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
                ) AS goal_effective_minute
            FROM silver.shot AS s
            INNER JOIN (
                SELECT
                    mp.match_id,
                    toInt32(assumeNotNull(mp.person_id)) AS player_id,
                    toInt32(max(toInt32(coalesce(mp.substitution_time, 0)))) AS substitution_time
                FROM silver.match_personnel AS mp
                WHERE mp.match_id > 0
                  AND mp.person_id IS NOT NULL
                  AND lowerUTF8(coalesce(mp.role, '')) = 'substitute'
                  AND toInt32(coalesce(mp.substitution_time, 0)) > 0
                GROUP BY mp.match_id, player_id
            ) AS se
                ON se.match_id = s.match_id
               AND se.player_id = toInt32(s.player_id)
            WHERE s.match_id > 0
              AND coalesce(s.team_id, 0) > 0
              AND coalesce(s.player_id, 0) > 0
              AND coalesce(s.is_goal, 0) = 1
              AND coalesce(s.is_own_goal, 0) = 0
              AND toInt32(
                    coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
                ) >= se.substitution_time
        ) AS sge
        GROUP BY sge.match_id, sge.team_id, sge.player_id
    ) AS ssgc
    GROUP BY ssgc.match_id, ssgc.team_id
) AS away_sub
    ON away_sub.match_id = m.match_id
   AND away_sub.team_id = m.away_team_id
LEFT JOIN (
    SELECT
        sge.match_id,
        sge.team_id,
        toInt32(min(sge.goal_effective_minute)) AS team_first_substitute_goal_effective_minute,
        toInt32(max(sge.goal_effective_minute)) AS team_last_substitute_goal_effective_minute
    FROM (
        SELECT
            s.match_id,
            toInt32(s.team_id) AS team_id,
            toInt32(s.player_id) AS player_id,
            toInt32(
                coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
            ) AS goal_effective_minute
        FROM silver.shot AS s
        INNER JOIN (
            SELECT
                mp.match_id,
                toInt32(assumeNotNull(mp.person_id)) AS player_id,
                toInt32(max(toInt32(coalesce(mp.substitution_time, 0)))) AS substitution_time
            FROM silver.match_personnel AS mp
            WHERE mp.match_id > 0
              AND mp.person_id IS NOT NULL
              AND lowerUTF8(coalesce(mp.role, '')) = 'substitute'
              AND toInt32(coalesce(mp.substitution_time, 0)) > 0
            GROUP BY mp.match_id, player_id
        ) AS se
            ON se.match_id = s.match_id
           AND se.player_id = toInt32(s.player_id)
        WHERE s.match_id > 0
          AND coalesce(s.team_id, 0) > 0
          AND coalesce(s.player_id, 0) > 0
          AND coalesce(s.is_goal, 0) = 1
          AND coalesce(s.is_own_goal, 0) = 0
          AND toInt32(
                coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
            ) >= se.substitution_time
    ) AS sge
    GROUP BY sge.match_id, sge.team_id
) AS home_sub_time
    ON home_sub_time.match_id = m.match_id
   AND home_sub_time.team_id = m.home_team_id
LEFT JOIN (
    SELECT
        sge.match_id,
        sge.team_id,
        toInt32(min(sge.goal_effective_minute)) AS team_first_substitute_goal_effective_minute,
        toInt32(max(sge.goal_effective_minute)) AS team_last_substitute_goal_effective_minute
    FROM (
        SELECT
            s.match_id,
            toInt32(s.team_id) AS team_id,
            toInt32(s.player_id) AS player_id,
            toInt32(
                coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
            ) AS goal_effective_minute
        FROM silver.shot AS s
        INNER JOIN (
            SELECT
                mp.match_id,
                toInt32(assumeNotNull(mp.person_id)) AS player_id,
                toInt32(max(toInt32(coalesce(mp.substitution_time, 0)))) AS substitution_time
            FROM silver.match_personnel AS mp
            WHERE mp.match_id > 0
              AND mp.person_id IS NOT NULL
              AND lowerUTF8(coalesce(mp.role, '')) = 'substitute'
              AND toInt32(coalesce(mp.substitution_time, 0)) > 0
            GROUP BY mp.match_id, player_id
        ) AS se
            ON se.match_id = s.match_id
           AND se.player_id = toInt32(s.player_id)
        WHERE s.match_id > 0
          AND coalesce(s.team_id, 0) > 0
          AND coalesce(s.player_id, 0) > 0
          AND coalesce(s.is_goal, 0) = 1
          AND coalesce(s.is_own_goal, 0) = 0
          AND toInt32(
                coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
            ) >= se.substitution_time
    ) AS sge
    GROUP BY sge.match_id, sge.team_id
) AS away_sub_time
    ON away_sub_time.match_id = m.match_id
   AND away_sub_time.team_id = m.away_team_id
LEFT JOIN (
    SELECT
        s.match_id,
        toInt32(s.team_id) AS team_id,
        toInt32(count()) AS team_non_own_goals
    FROM silver.shot AS s
    WHERE s.match_id > 0
      AND coalesce(s.team_id, 0) > 0
      AND coalesce(s.is_goal, 0) = 1
      AND coalesce(s.is_own_goal, 0) = 0
    GROUP BY s.match_id, toInt32(s.team_id)
) AS home_goal
    ON home_goal.match_id = m.match_id
   AND home_goal.team_id = m.home_team_id
LEFT JOIN (
    SELECT
        s.match_id,
        toInt32(s.team_id) AS team_id,
        toInt32(count()) AS team_non_own_goals
    FROM silver.shot AS s
    WHERE s.match_id > 0
      AND coalesce(s.team_id, 0) > 0
      AND coalesce(s.is_goal, 0) = 1
      AND coalesce(s.is_own_goal, 0) = 0
    GROUP BY s.match_id, toInt32(s.team_id)
) AS away_goal
    ON away_goal.match_id = m.match_id
   AND away_goal.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND (
        coalesce(home_sub.team_substitute_non_own_goals, 0)
      + coalesce(away_sub.team_substitute_non_own_goals, 0)
  ) >= 3

UNION ALL

SELECT
    m.match_id AS match_id,
    m.match_date AS match_date,
    m.home_team_id AS home_team_id,
    m.home_team_name AS home_team_name,
    m.away_team_id AS away_team_id,
    m.away_team_name AS away_team_name,
    m.home_score AS home_score,
    m.away_score AS away_score,
    'away' AS triggered_side,
    m.away_team_id AS triggered_team_id,
    m.away_team_name AS triggered_team_name,
    m.home_team_id AS opponent_team_id,
    m.home_team_name AS opponent_team_name,
    toInt32(3) AS trigger_threshold_match_substitute_non_own_goals_min,
    toInt32(coalesce(home_sub.team_substitute_non_own_goals, 0) + coalesce(away_sub.team_substitute_non_own_goals, 0)) AS match_substitute_non_own_goals,
    toInt32(coalesce(home_goal.team_non_own_goals, 0) + coalesce(away_goal.team_non_own_goals, 0)) AS match_total_non_own_goals,
    toFloat32(coalesce(round(
        100.0 * (coalesce(home_sub.team_substitute_non_own_goals, 0) + coalesce(away_sub.team_substitute_non_own_goals, 0))
        / nullIf(toFloat64(coalesce(home_goal.team_non_own_goals, 0) + coalesce(away_goal.team_non_own_goals, 0)), 0),
        1
    ), 0.0)) AS match_substitute_goal_share_pct,
    toInt32(coalesce(home_sub.team_substitute_non_own_goals, 0)) AS home_substitute_non_own_goals,
    toInt32(coalesce(away_sub.team_substitute_non_own_goals, 0)) AS away_substitute_non_own_goals,
    toInt32(coalesce(home_sub.team_distinct_substitute_goal_scorers, 0)) AS home_distinct_substitute_goal_scorers,
    toInt32(coalesce(away_sub.team_distinct_substitute_goal_scorers, 0)) AS away_distinct_substitute_goal_scorers,
    toInt32(coalesce(away_sub.team_substitute_non_own_goals, 0)) AS triggered_team_substitute_non_own_goals,
    toInt32(coalesce(home_sub.team_substitute_non_own_goals, 0)) AS opponent_substitute_non_own_goals,
    toInt32(coalesce(away_sub.team_substitute_non_own_goals, 0)) - toInt32(coalesce(home_sub.team_substitute_non_own_goals, 0)) AS substitute_non_own_goals_delta,
    toInt32(coalesce(away_sub.team_distinct_substitute_goal_scorers, 0)) AS triggered_team_distinct_substitute_goal_scorers,
    toInt32(coalesce(home_sub.team_distinct_substitute_goal_scorers, 0)) AS opponent_distinct_substitute_goal_scorers,
    toInt32(coalesce(away_sub.team_distinct_substitute_goal_scorers, 0)) - toInt32(coalesce(home_sub.team_distinct_substitute_goal_scorers, 0))
        AS distinct_substitute_goal_scorers_delta,
    toInt32(coalesce(away_sub.team_top_substitute_scorer_goals, 0)) AS triggered_team_top_substitute_scorer_goals,
    toInt32(coalesce(home_sub.team_top_substitute_scorer_goals, 0)) AS opponent_top_substitute_scorer_goals,
    toInt32(coalesce(away_sub.team_top_substitute_scorer_goals, 0)) - toInt32(coalesce(home_sub.team_top_substitute_scorer_goals, 0)) AS top_substitute_scorer_goals_delta,
    toInt32(coalesce(away_sub_time.team_first_substitute_goal_effective_minute, 0)) AS triggered_team_first_substitute_goal_effective_minute,
    toInt32(coalesce(home_sub_time.team_first_substitute_goal_effective_minute, 0)) AS opponent_first_substitute_goal_effective_minute,
    toInt32(coalesce(away_sub_time.team_last_substitute_goal_effective_minute, 0)) AS triggered_team_last_substitute_goal_effective_minute,
    toInt32(coalesce(home_sub_time.team_last_substitute_goal_effective_minute, 0)) AS opponent_last_substitute_goal_effective_minute,
    toFloat32(coalesce(round(
        100.0 * coalesce(away_sub.team_substitute_non_own_goals, 0) / nullIf(toFloat64(coalesce(away_goal.team_non_own_goals, 0)), 0),
        1
    ), 0.0)) AS triggered_team_substitute_goal_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(home_sub.team_substitute_non_own_goals, 0) / nullIf(toFloat64(coalesce(home_goal.team_non_own_goals, 0)), 0),
        1
    ), 0.0)) AS opponent_substitute_goal_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(away_sub.team_substitute_non_own_goals, 0) / nullIf(toFloat64(coalesce(away_goal.team_non_own_goals, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(home_sub.team_substitute_non_own_goals, 0) / nullIf(toFloat64(coalesce(home_goal.team_non_own_goals, 0)), 0),
            1
        ), 0.0),
        1
    )) AS substitute_goal_share_delta_pct,
    toInt32(coalesce(away_goal.team_non_own_goals, 0)) AS triggered_team_non_own_goals,
    toInt32(coalesce(home_goal.team_non_own_goals, 0)) AS opponent_non_own_goals,
    toInt32(coalesce(away_goal.team_non_own_goals, 0)) - toInt32(coalesce(home_goal.team_non_own_goals, 0)) AS non_own_goals_delta,
    toInt32(coalesce(m.away_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.home_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.away_score, 0)) - toInt32(coalesce(m.home_score, 0)) AS goal_delta,
    toInt32(coalesce(ps.total_shots_away, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_home, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS opponent_shots_on_target,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS opponent_xg,
    toFloat32(round(toFloat32(coalesce(ps.expected_goals_away, 0.0)) - toFloat32(coalesce(ps.expected_goals_home, 0.0)), 3)) AS xg_delta,
    toInt32(coalesce(ps.big_chances_away, 0)) AS triggered_team_big_chances,
    toInt32(coalesce(ps.big_chances_home, 0)) AS opponent_big_chances,
    toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS opponent_possession_pct,
    toFloat32(round(toFloat32(coalesce(ps.ball_possession_away, 0.0)) - toFloat32(coalesce(ps.ball_possession_home, 0.0)), 1)) AS possession_delta_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0), 1), 0.0)
        - coalesce(round(100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct
FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN (
    SELECT
        ssgc.match_id,
        ssgc.team_id,
        toInt32(sum(ssgc.goals_by_substitute_scorer)) AS team_substitute_non_own_goals,
        toInt32(count()) AS team_distinct_substitute_goal_scorers,
        toInt32(max(ssgc.goals_by_substitute_scorer)) AS team_top_substitute_scorer_goals
    FROM (
        SELECT
            sge.match_id,
            sge.team_id,
            sge.player_id,
            toInt32(count()) AS goals_by_substitute_scorer
        FROM (
            SELECT
                s.match_id,
                toInt32(s.team_id) AS team_id,
                toInt32(s.player_id) AS player_id,
                toInt32(
                    coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
                ) AS goal_effective_minute
            FROM silver.shot AS s
            INNER JOIN (
                SELECT
                    mp.match_id,
                    toInt32(assumeNotNull(mp.person_id)) AS player_id,
                    toInt32(max(toInt32(coalesce(mp.substitution_time, 0)))) AS substitution_time
                FROM silver.match_personnel AS mp
                WHERE mp.match_id > 0
                  AND mp.person_id IS NOT NULL
                  AND lowerUTF8(coalesce(mp.role, '')) = 'substitute'
                  AND toInt32(coalesce(mp.substitution_time, 0)) > 0
                GROUP BY mp.match_id, player_id
            ) AS se
                ON se.match_id = s.match_id
               AND se.player_id = toInt32(s.player_id)
            WHERE s.match_id > 0
              AND coalesce(s.team_id, 0) > 0
              AND coalesce(s.player_id, 0) > 0
              AND coalesce(s.is_goal, 0) = 1
              AND coalesce(s.is_own_goal, 0) = 0
              AND toInt32(
                    coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
                ) >= se.substitution_time
        ) AS sge
        GROUP BY sge.match_id, sge.team_id, sge.player_id
    ) AS ssgc
    GROUP BY ssgc.match_id, ssgc.team_id
) AS home_sub
    ON home_sub.match_id = m.match_id
   AND home_sub.team_id = m.home_team_id
LEFT JOIN (
    SELECT
        ssgc.match_id,
        ssgc.team_id,
        toInt32(sum(ssgc.goals_by_substitute_scorer)) AS team_substitute_non_own_goals,
        toInt32(count()) AS team_distinct_substitute_goal_scorers,
        toInt32(max(ssgc.goals_by_substitute_scorer)) AS team_top_substitute_scorer_goals
    FROM (
        SELECT
            sge.match_id,
            sge.team_id,
            sge.player_id,
            toInt32(count()) AS goals_by_substitute_scorer
        FROM (
            SELECT
                s.match_id,
                toInt32(s.team_id) AS team_id,
                toInt32(s.player_id) AS player_id,
                toInt32(
                    coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
                ) AS goal_effective_minute
            FROM silver.shot AS s
            INNER JOIN (
                SELECT
                    mp.match_id,
                    toInt32(assumeNotNull(mp.person_id)) AS player_id,
                    toInt32(max(toInt32(coalesce(mp.substitution_time, 0)))) AS substitution_time
                FROM silver.match_personnel AS mp
                WHERE mp.match_id > 0
                  AND mp.person_id IS NOT NULL
                  AND lowerUTF8(coalesce(mp.role, '')) = 'substitute'
                  AND toInt32(coalesce(mp.substitution_time, 0)) > 0
                GROUP BY mp.match_id, player_id
            ) AS se
                ON se.match_id = s.match_id
               AND se.player_id = toInt32(s.player_id)
            WHERE s.match_id > 0
              AND coalesce(s.team_id, 0) > 0
              AND coalesce(s.player_id, 0) > 0
              AND coalesce(s.is_goal, 0) = 1
              AND coalesce(s.is_own_goal, 0) = 0
              AND toInt32(
                    coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
                ) >= se.substitution_time
        ) AS sge
        GROUP BY sge.match_id, sge.team_id, sge.player_id
    ) AS ssgc
    GROUP BY ssgc.match_id, ssgc.team_id
) AS away_sub
    ON away_sub.match_id = m.match_id
   AND away_sub.team_id = m.away_team_id
LEFT JOIN (
    SELECT
        sge.match_id,
        sge.team_id,
        toInt32(min(sge.goal_effective_minute)) AS team_first_substitute_goal_effective_minute,
        toInt32(max(sge.goal_effective_minute)) AS team_last_substitute_goal_effective_minute
    FROM (
        SELECT
            s.match_id,
            toInt32(s.team_id) AS team_id,
            toInt32(s.player_id) AS player_id,
            toInt32(
                coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
            ) AS goal_effective_minute
        FROM silver.shot AS s
        INNER JOIN (
            SELECT
                mp.match_id,
                toInt32(assumeNotNull(mp.person_id)) AS player_id,
                toInt32(max(toInt32(coalesce(mp.substitution_time, 0)))) AS substitution_time
            FROM silver.match_personnel AS mp
            WHERE mp.match_id > 0
              AND mp.person_id IS NOT NULL
              AND lowerUTF8(coalesce(mp.role, '')) = 'substitute'
              AND toInt32(coalesce(mp.substitution_time, 0)) > 0
            GROUP BY mp.match_id, player_id
        ) AS se
            ON se.match_id = s.match_id
           AND se.player_id = toInt32(s.player_id)
        WHERE s.match_id > 0
          AND coalesce(s.team_id, 0) > 0
          AND coalesce(s.player_id, 0) > 0
          AND coalesce(s.is_goal, 0) = 1
          AND coalesce(s.is_own_goal, 0) = 0
          AND toInt32(
                coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
            ) >= se.substitution_time
    ) AS sge
    GROUP BY sge.match_id, sge.team_id
) AS home_sub_time
    ON home_sub_time.match_id = m.match_id
   AND home_sub_time.team_id = m.home_team_id
LEFT JOIN (
    SELECT
        sge.match_id,
        sge.team_id,
        toInt32(min(sge.goal_effective_minute)) AS team_first_substitute_goal_effective_minute,
        toInt32(max(sge.goal_effective_minute)) AS team_last_substitute_goal_effective_minute
    FROM (
        SELECT
            s.match_id,
            toInt32(s.team_id) AS team_id,
            toInt32(s.player_id) AS player_id,
            toInt32(
                coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
            ) AS goal_effective_minute
        FROM silver.shot AS s
        INNER JOIN (
            SELECT
                mp.match_id,
                toInt32(assumeNotNull(mp.person_id)) AS player_id,
                toInt32(max(toInt32(coalesce(mp.substitution_time, 0)))) AS substitution_time
            FROM silver.match_personnel AS mp
            WHERE mp.match_id > 0
              AND mp.person_id IS NOT NULL
              AND lowerUTF8(coalesce(mp.role, '')) = 'substitute'
              AND toInt32(coalesce(mp.substitution_time, 0)) > 0
            GROUP BY mp.match_id, player_id
        ) AS se
            ON se.match_id = s.match_id
           AND se.player_id = toInt32(s.player_id)
        WHERE s.match_id > 0
          AND coalesce(s.team_id, 0) > 0
          AND coalesce(s.player_id, 0) > 0
          AND coalesce(s.is_goal, 0) = 1
          AND coalesce(s.is_own_goal, 0) = 0
          AND toInt32(
                coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
            ) >= se.substitution_time
    ) AS sge
    GROUP BY sge.match_id, sge.team_id
) AS away_sub_time
    ON away_sub_time.match_id = m.match_id
   AND away_sub_time.team_id = m.away_team_id
LEFT JOIN (
    SELECT
        s.match_id,
        toInt32(s.team_id) AS team_id,
        toInt32(count()) AS team_non_own_goals
    FROM silver.shot AS s
    WHERE s.match_id > 0
      AND coalesce(s.team_id, 0) > 0
      AND coalesce(s.is_goal, 0) = 1
      AND coalesce(s.is_own_goal, 0) = 0
    GROUP BY s.match_id, toInt32(s.team_id)
) AS home_goal
    ON home_goal.match_id = m.match_id
   AND home_goal.team_id = m.home_team_id
LEFT JOIN (
    SELECT
        s.match_id,
        toInt32(s.team_id) AS team_id,
        toInt32(count()) AS team_non_own_goals
    FROM silver.shot AS s
    WHERE s.match_id > 0
      AND coalesce(s.team_id, 0) > 0
      AND coalesce(s.is_goal, 0) = 1
      AND coalesce(s.is_own_goal, 0) = 0
    GROUP BY s.match_id, toInt32(s.team_id)
) AS away_goal
    ON away_goal.match_id = m.match_id
   AND away_goal.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND (
        coalesce(home_sub.team_substitute_non_own_goals, 0)
      + coalesce(away_sub.team_substitute_non_own_goals, 0)
  ) >= 3

ORDER BY
    match_substitute_non_own_goals DESC,
    match_substitute_goal_share_pct DESC,
    match_date DESC,
    match_id DESC,
    triggered_side;
