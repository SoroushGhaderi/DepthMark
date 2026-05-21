INSERT INTO gold.sig_match_shooting_goals_substituted_scoring_fest (
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
    trigger_threshold_match_distinct_substitute_goal_scorers_min,
    match_distinct_substitute_goal_scorers,
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
-- Signal: sig_match_shooting_goals_substituted_scoring_fest
-- Intent: detect finished matches where at least three distinct substitutes score
--         and emit side-oriented rows with bilateral shooting context.
-- Trigger: combined distinct substitute goal scorers >= 3 in one finished match.
WITH substitute_entries AS (
    SELECT
        mp.match_id,
        toInt32(assumeNotNull(mp.person_id)) AS player_id,
        toInt32(max(toInt32OrZero(mp.substitution_time))) AS substitution_time
    FROM silver.match_personnel AS mp
    WHERE mp.match_id > 0
      AND mp.person_id IS NOT NULL
      AND lowerUTF8(coalesce(mp.role, '')) = 'substitute'
      AND toInt32OrZero(mp.substitution_time) > 0
    GROUP BY
        mp.match_id,
        player_id
),
substitute_goal_events AS (
    SELECT
        s.match_id,
        toInt32(s.team_id) AS team_id,
        toInt32(s.player_id) AS player_id,
        toInt32(
            coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
        ) AS goal_effective_minute
    FROM silver.shot AS s
    INNER JOIN substitute_entries AS se
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
),
substitute_scorer_goal_counts AS (
    SELECT
        sge.match_id,
        sge.team_id,
        sge.player_id,
        toInt32(count()) AS goals_by_substitute_scorer
    FROM substitute_goal_events AS sge
    GROUP BY
        sge.match_id,
        sge.team_id,
        sge.player_id
),
team_substitute_goal_rollup AS (
    SELECT
        ssgc.match_id,
        ssgc.team_id,
        toInt32(sum(ssgc.goals_by_substitute_scorer)) AS team_substitute_non_own_goals,
        toInt32(count()) AS team_distinct_substitute_goal_scorers,
        toInt32(max(ssgc.goals_by_substitute_scorer)) AS team_top_substitute_scorer_goals
    FROM substitute_scorer_goal_counts AS ssgc
    GROUP BY
        ssgc.match_id,
        ssgc.team_id
),
team_substitute_goal_timing AS (
    SELECT
        sge.match_id,
        sge.team_id,
        toInt32(min(sge.goal_effective_minute)) AS team_first_substitute_goal_effective_minute,
        toInt32(max(sge.goal_effective_minute)) AS team_last_substitute_goal_effective_minute
    FROM substitute_goal_events AS sge
    GROUP BY
        sge.match_id,
        sge.team_id
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
),
base_stats AS (
    SELECT
        m.match_id,
        m.match_date,
        m.home_team_id,
        m.home_team_name,
        m.away_team_id,
        m.away_team_name,
        m.home_score,
        m.away_score,
        toInt32(coalesce(m.home_score, 0)) AS home_goals,
        toInt32(coalesce(m.away_score, 0)) AS away_goals,

        toInt32(coalesce(home_sub.team_substitute_non_own_goals, 0)) AS home_substitute_non_own_goals,
        toInt32(coalesce(away_sub.team_substitute_non_own_goals, 0)) AS away_substitute_non_own_goals,
        toInt32(coalesce(home_sub.team_distinct_substitute_goal_scorers, 0))
            AS home_distinct_substitute_goal_scorers,
        toInt32(coalesce(away_sub.team_distinct_substitute_goal_scorers, 0))
            AS away_distinct_substitute_goal_scorers,
        toInt32(coalesce(home_sub.team_top_substitute_scorer_goals, 0))
            AS home_top_substitute_scorer_goals,
        toInt32(coalesce(away_sub.team_top_substitute_scorer_goals, 0))
            AS away_top_substitute_scorer_goals,
        toInt32(coalesce(home_sub_time.team_first_substitute_goal_effective_minute, 0))
            AS home_first_substitute_goal_effective_minute,
        toInt32(coalesce(away_sub_time.team_first_substitute_goal_effective_minute, 0))
            AS away_first_substitute_goal_effective_minute,
        toInt32(coalesce(home_sub_time.team_last_substitute_goal_effective_minute, 0))
            AS home_last_substitute_goal_effective_minute,
        toInt32(coalesce(away_sub_time.team_last_substitute_goal_effective_minute, 0))
            AS away_last_substitute_goal_effective_minute,

        toInt32(coalesce(home_goal.team_non_own_goals, 0)) AS home_non_own_goals,
        toInt32(coalesce(away_goal.team_non_own_goals, 0)) AS away_non_own_goals,

        toInt32(coalesce(home_sub.team_substitute_non_own_goals, 0)
            + coalesce(away_sub.team_substitute_non_own_goals, 0)) AS match_substitute_non_own_goals,
        toInt32(coalesce(home_sub.team_distinct_substitute_goal_scorers, 0)
            + coalesce(away_sub.team_distinct_substitute_goal_scorers, 0))
            AS match_distinct_substitute_goal_scorers,
        toInt32(coalesce(home_goal.team_non_own_goals, 0)
            + coalesce(away_goal.team_non_own_goals, 0)) AS match_total_non_own_goals,

        toInt32(coalesce(ps.total_shots_home, 0)) AS total_shots_home,
        toInt32(coalesce(ps.total_shots_away, 0)) AS total_shots_away,
        toInt32(coalesce(ps.shots_on_target_home, 0)) AS shots_on_target_home,
        toInt32(coalesce(ps.shots_on_target_away, 0)) AS shots_on_target_away,
        toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS expected_goals_home,
        toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS expected_goals_away,
        toInt32(coalesce(ps.big_chances_home, 0)) AS big_chances_home,
        toInt32(coalesce(ps.big_chances_away, 0)) AS big_chances_away,
        toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS possession_home_pct,
        toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS possession_away_pct,
        toInt32(coalesce(ps.accurate_passes_home, 0)) AS accurate_passes_home,
        toInt32(coalesce(ps.accurate_passes_away, 0)) AS accurate_passes_away,
        toInt32(coalesce(ps.pass_attempts_home, 0)) AS pass_attempts_home,
        toInt32(coalesce(ps.pass_attempts_away, 0)) AS pass_attempts_away
    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.match_date = m.match_date
       AND ps.period = 'All'
    LEFT JOIN team_substitute_goal_rollup AS home_sub
        ON home_sub.match_id = m.match_id
       AND home_sub.team_id = m.home_team_id
    LEFT JOIN team_substitute_goal_rollup AS away_sub
        ON away_sub.match_id = m.match_id
       AND away_sub.team_id = m.away_team_id
    LEFT JOIN team_substitute_goal_timing AS home_sub_time
        ON home_sub_time.match_id = m.match_id
       AND home_sub_time.team_id = m.home_team_id
    LEFT JOIN team_substitute_goal_timing AS away_sub_time
        ON away_sub_time.match_id = m.match_id
       AND away_sub_time.team_id = m.away_team_id
    LEFT JOIN team_non_own_goal_rollup AS home_goal
        ON home_goal.match_id = m.match_id
       AND home_goal.team_id = m.home_team_id
    LEFT JOIN team_non_own_goal_rollup AS away_goal
        ON away_goal.match_id = m.match_id
       AND away_goal.team_id = m.away_team_id
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND (
            coalesce(home_sub.team_distinct_substitute_goal_scorers, 0)
          + coalesce(away_sub.team_distinct_substitute_goal_scorers, 0)
      ) >= 3
)

SELECT
    b.match_id,
    b.match_date,
    b.home_team_id,
    b.home_team_name,
    b.away_team_id,
    b.away_team_name,
    b.home_score,
    b.away_score,
    'home' AS triggered_side,
    b.home_team_id AS triggered_team_id,
    b.home_team_name AS triggered_team_name,
    b.away_team_id AS opponent_team_id,
    b.away_team_name AS opponent_team_name,
    toInt32(3) AS trigger_threshold_match_distinct_substitute_goal_scorers_min,
    b.match_distinct_substitute_goal_scorers,
    b.match_substitute_non_own_goals,
    b.match_total_non_own_goals,
    toFloat32(coalesce(round(
        100.0 * b.match_substitute_non_own_goals / nullIf(toFloat64(b.match_total_non_own_goals), 0),
        1
    ), 0.0)) AS match_substitute_goal_share_pct,
    b.home_substitute_non_own_goals,
    b.away_substitute_non_own_goals,
    b.home_distinct_substitute_goal_scorers,
    b.away_distinct_substitute_goal_scorers,

    b.home_substitute_non_own_goals AS triggered_team_substitute_non_own_goals,
    b.away_substitute_non_own_goals AS opponent_substitute_non_own_goals,
    b.home_substitute_non_own_goals - b.away_substitute_non_own_goals AS substitute_non_own_goals_delta,
    b.home_distinct_substitute_goal_scorers AS triggered_team_distinct_substitute_goal_scorers,
    b.away_distinct_substitute_goal_scorers AS opponent_distinct_substitute_goal_scorers,
    b.home_distinct_substitute_goal_scorers - b.away_distinct_substitute_goal_scorers
        AS distinct_substitute_goal_scorers_delta,
    b.home_top_substitute_scorer_goals AS triggered_team_top_substitute_scorer_goals,
    b.away_top_substitute_scorer_goals AS opponent_top_substitute_scorer_goals,
    b.home_top_substitute_scorer_goals - b.away_top_substitute_scorer_goals AS top_substitute_scorer_goals_delta,
    b.home_first_substitute_goal_effective_minute AS triggered_team_first_substitute_goal_effective_minute,
    b.away_first_substitute_goal_effective_minute AS opponent_first_substitute_goal_effective_minute,
    b.home_last_substitute_goal_effective_minute AS triggered_team_last_substitute_goal_effective_minute,
    b.away_last_substitute_goal_effective_minute AS opponent_last_substitute_goal_effective_minute,
    toFloat32(coalesce(round(
        100.0 * b.home_substitute_non_own_goals / nullIf(toFloat64(b.home_non_own_goals), 0),
        1
    ), 0.0)) AS triggered_team_substitute_goal_share_pct,
    toFloat32(coalesce(round(
        100.0 * b.away_substitute_non_own_goals / nullIf(toFloat64(b.away_non_own_goals), 0),
        1
    ), 0.0)) AS opponent_substitute_goal_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.home_substitute_non_own_goals / nullIf(toFloat64(b.home_non_own_goals), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * b.away_substitute_non_own_goals / nullIf(toFloat64(b.away_non_own_goals), 0),
            1
        ), 0.0),
        1
    )) AS substitute_goal_share_delta_pct,
    b.home_non_own_goals AS triggered_team_non_own_goals,
    b.away_non_own_goals AS opponent_non_own_goals,
    b.home_non_own_goals - b.away_non_own_goals AS non_own_goals_delta,
    b.home_goals AS triggered_team_goals,
    b.away_goals AS opponent_goals,
    b.home_goals - b.away_goals AS goal_delta,
    b.total_shots_home AS triggered_team_total_shots,
    b.total_shots_away AS opponent_total_shots,
    b.shots_on_target_home AS triggered_team_shots_on_target,
    b.shots_on_target_away AS opponent_shots_on_target,
    b.expected_goals_home AS triggered_team_xg,
    b.expected_goals_away AS opponent_xg,
    toFloat32(round(b.expected_goals_home - b.expected_goals_away, 3)) AS xg_delta,
    b.big_chances_home AS triggered_team_big_chances,
    b.big_chances_away AS opponent_big_chances,
    b.possession_home_pct AS triggered_team_possession_pct,
    b.possession_away_pct AS opponent_possession_pct,
    toFloat32(round(b.possession_home_pct - b.possession_away_pct, 1)) AS possession_delta_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0), 1), 0.0)
        - coalesce(round(100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct
FROM base_stats AS b

UNION ALL

SELECT
    b.match_id,
    b.match_date,
    b.home_team_id,
    b.home_team_name,
    b.away_team_id,
    b.away_team_name,
    b.home_score,
    b.away_score,
    'away' AS triggered_side,
    b.away_team_id AS triggered_team_id,
    b.away_team_name AS triggered_team_name,
    b.home_team_id AS opponent_team_id,
    b.home_team_name AS opponent_team_name,
    toInt32(3) AS trigger_threshold_match_distinct_substitute_goal_scorers_min,
    b.match_distinct_substitute_goal_scorers,
    b.match_substitute_non_own_goals,
    b.match_total_non_own_goals,
    toFloat32(coalesce(round(
        100.0 * b.match_substitute_non_own_goals / nullIf(toFloat64(b.match_total_non_own_goals), 0),
        1
    ), 0.0)) AS match_substitute_goal_share_pct,
    b.home_substitute_non_own_goals,
    b.away_substitute_non_own_goals,
    b.home_distinct_substitute_goal_scorers,
    b.away_distinct_substitute_goal_scorers,

    b.away_substitute_non_own_goals AS triggered_team_substitute_non_own_goals,
    b.home_substitute_non_own_goals AS opponent_substitute_non_own_goals,
    b.away_substitute_non_own_goals - b.home_substitute_non_own_goals AS substitute_non_own_goals_delta,
    b.away_distinct_substitute_goal_scorers AS triggered_team_distinct_substitute_goal_scorers,
    b.home_distinct_substitute_goal_scorers AS opponent_distinct_substitute_goal_scorers,
    b.away_distinct_substitute_goal_scorers - b.home_distinct_substitute_goal_scorers
        AS distinct_substitute_goal_scorers_delta,
    b.away_top_substitute_scorer_goals AS triggered_team_top_substitute_scorer_goals,
    b.home_top_substitute_scorer_goals AS opponent_top_substitute_scorer_goals,
    b.away_top_substitute_scorer_goals - b.home_top_substitute_scorer_goals AS top_substitute_scorer_goals_delta,
    b.away_first_substitute_goal_effective_minute AS triggered_team_first_substitute_goal_effective_minute,
    b.home_first_substitute_goal_effective_minute AS opponent_first_substitute_goal_effective_minute,
    b.away_last_substitute_goal_effective_minute AS triggered_team_last_substitute_goal_effective_minute,
    b.home_last_substitute_goal_effective_minute AS opponent_last_substitute_goal_effective_minute,
    toFloat32(coalesce(round(
        100.0 * b.away_substitute_non_own_goals / nullIf(toFloat64(b.away_non_own_goals), 0),
        1
    ), 0.0)) AS triggered_team_substitute_goal_share_pct,
    toFloat32(coalesce(round(
        100.0 * b.home_substitute_non_own_goals / nullIf(toFloat64(b.home_non_own_goals), 0),
        1
    ), 0.0)) AS opponent_substitute_goal_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.away_substitute_non_own_goals / nullIf(toFloat64(b.away_non_own_goals), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * b.home_substitute_non_own_goals / nullIf(toFloat64(b.home_non_own_goals), 0),
            1
        ), 0.0),
        1
    )) AS substitute_goal_share_delta_pct,
    b.away_non_own_goals AS triggered_team_non_own_goals,
    b.home_non_own_goals AS opponent_non_own_goals,
    b.away_non_own_goals - b.home_non_own_goals AS non_own_goals_delta,
    b.away_goals AS triggered_team_goals,
    b.home_goals AS opponent_goals,
    b.away_goals - b.home_goals AS goal_delta,
    b.total_shots_away AS triggered_team_total_shots,
    b.total_shots_home AS opponent_total_shots,
    b.shots_on_target_away AS triggered_team_shots_on_target,
    b.shots_on_target_home AS opponent_shots_on_target,
    b.expected_goals_away AS triggered_team_xg,
    b.expected_goals_home AS opponent_xg,
    toFloat32(round(b.expected_goals_away - b.expected_goals_home, 3)) AS xg_delta,
    b.big_chances_away AS triggered_team_big_chances,
    b.big_chances_home AS opponent_big_chances,
    b.possession_away_pct AS triggered_team_possession_pct,
    b.possession_home_pct AS opponent_possession_pct,
    toFloat32(round(b.possession_away_pct - b.possession_home_pct, 1)) AS possession_delta_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0), 1), 0.0)
        - coalesce(round(100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct
FROM base_stats AS b

ORDER BY
    match_distinct_substitute_goal_scorers DESC,
    match_substitute_non_own_goals DESC,
    match_substitute_goal_share_pct DESC,
    match_date DESC,
    match_id DESC,
    triggered_side;
