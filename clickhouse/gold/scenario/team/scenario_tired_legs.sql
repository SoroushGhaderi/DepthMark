-- scenario_tired_legs: late-match chaos signatures driven by fatigue, shot surges, and substitution swings
INSERT INTO gold_scenarios.scenario_tired_legs
(
    -- 1. Match Identity
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    goal_diff,
    match_time_utc_date,

    -- 2. Late Goal Metrics
    total_goals,
    late_goals,
    late_goals_home,
    late_goals_away,
    late_goal_pct,

    -- 3. Late Shot Escalation Metrics
    total_shots,
    late_shots,
    late_shots_on_target,
    late_shot_pct,

    -- 4. Late xG Metrics
    total_xg,
    late_xg_total,
    late_xg_pct,

    -- 5. Substitution-Driven Chaos Metrics
    total_attacking_subs_60_75,
    total_subs_after_75,
    total_subs,
    chaos_score,
    trigger_type,

    -- 6. Outcome Labeling
    winning_team,
    match_result,
    winning_side
)
WITH late_goals AS (
    SELECT
        match_id,
        countIf(is_goal = 1 AND goal_time >= 75) AS late_goals,
        countIf(is_goal = 1 AND goal_time >= 75 AND is_home_goal = 1) AS late_goals_home,
        countIf(is_goal = 1 AND goal_time >= 75 AND is_home_goal = 0) AS late_goals_away,
        countIf(is_goal = 1) AS total_goals
    FROM silver.shot
    GROUP BY match_id
),
shot_volumes AS (
    SELECT
        match_id,
        countIf(minute >= 75) AS late_shots,
        countIf(minute >= 75 AND is_on_target = 1) AS late_shots_on_target,
        count() AS total_shots,
        round(countIf(minute >= 75) / nullIf(count(), 0) * 100, 2) AS late_shot_pct
    FROM silver.shot
    GROUP BY match_id
),
late_xg AS (
    SELECT
        match_id,
        round(sumIf(expected_goals, minute >= 75), 3) AS late_xg_total,
        round(sum(expected_goals), 3) AS total_xg
    FROM silver.shot
    WHERE expected_goals IS NOT NULL
    GROUP BY match_id
),
attacking_subs AS (
    SELECT
        match_id,
        team_side,
        countIf(substitution_time >= 60 AND substitution_time <= 75) AS attacking_subs_60_75,
        countIf(substitution_time >= 75) AS subs_after_75,
        count() AS total_subs
FROM silver.match_personnel
WHERE substitution_time IS NOT NULL
  AND role = 'substitute'
GROUP BY match_id, team_side
),
subs_per_match AS (
    SELECT
        match_id,
        sum(attacking_subs_60_75) AS total_attacking_subs_60_75,
        sum(subs_after_75) AS total_subs_after_75,
        sum(total_subs) AS total_subs
    FROM attacking_subs
    GROUP BY match_id
)
SELECT
    -- 1. Match Identity
    g.match_id,
    g.home_team_id,
    g.away_team_id,
    g.home_team_name,
    g.away_team_name,
    g.home_score,
    g.away_score,
    abs(g.home_score - g.away_score) AS goal_diff,
    toString(g.match_date),

    -- 2. Late Goal Metrics
    lg.total_goals,
    lg.late_goals,
    lg.late_goals_home,
    lg.late_goals_away,
    round(lg.late_goals / nullIf(lg.total_goals, 0) * 100, 1) AS late_goal_pct,

    -- 3. Late Shot Escalation Metrics
    sv.total_shots,
    sv.late_shots,
    sv.late_shots_on_target,
    sv.late_shot_pct,

    -- 4. Late xG Metrics
    lx.total_xg,
    lx.late_xg_total,
    round(lx.late_xg_total / nullIf(lx.total_xg, 0) * 100, 1) AS late_xg_pct,

    -- 5. Substitution-Driven Chaos Metrics
    sm.total_attacking_subs_60_75,
    sm.total_subs_after_75,
    sm.total_subs,
    round(
          (lg.late_goals * 10)
        + (sv.late_shot_pct * 0.5)
        + (sm.total_attacking_subs_60_75 * 5)
        + (lx.late_xg_total * 8),
        2
    ) AS chaos_score,
    CASE
        WHEN lg.late_goals >= 2 AND sv.late_shot_pct >= 25 AND sm.total_attacking_subs_60_75 >= 3 THEN 'full_collapse'
        WHEN lg.late_goals >= 2 AND sv.late_shot_pct >= 25 THEN 'late_storm'
        WHEN lg.late_goals >= 2 AND sm.total_attacking_subs_60_75 >= 3 THEN 'sub_triggered'
        WHEN sv.late_shot_pct >= 25 AND sm.total_attacking_subs_60_75 >= 3 THEN 'shot_surge'
        ELSE 'partial'
    END AS trigger_type,

    -- 6. Outcome Labeling
    multiIf(
        g.home_score > g.away_score, g.home_team_name,
        g.away_score > g.home_score, g.away_team_name,
        'Draw'
    ) AS winning_team,
    CAST(
        multiIf(
            g.home_score > g.away_score, 'Home Win',
            g.away_score > g.home_score, 'Away Win',
            'Draw'
        ),
        'LowCardinality(String)'
    ) AS match_result,
    CASE
        WHEN g.home_score > g.away_score THEN 'home'
        WHEN g.away_score > g.home_score THEN 'away'
        ELSE 'draw'
    END AS winning_side
FROM silver.match AS g
INNER JOIN late_goals AS lg
    ON g.match_id = lg.match_id
INNER JOIN shot_volumes AS sv
    ON g.match_id = sv.match_id
INNER JOIN late_xg AS lx
    ON g.match_id = lx.match_id
INNER JOIN subs_per_match AS sm
    ON g.match_id = sm.match_id
WHERE
    -- Finished matches with at least one late-chaos signal active.
    g.match_finished = 1
    AND (
        lg.late_goals >= 2
        OR sv.late_shot_pct >= 25
        OR sm.total_attacking_subs_60_75 >= 3
    )
    -- Require at least two late-chaos signals for robust classification.
    AND (
        (CASE WHEN lg.late_goals >= 2 THEN 1 ELSE 0 END)
      + (CASE WHEN sv.late_shot_pct >= 25 THEN 1 ELSE 0 END)
      + (CASE WHEN sm.total_attacking_subs_60_75 >= 3 THEN 1 ELSE 0 END)
    ) >= 2
ORDER BY chaos_score DESC;
