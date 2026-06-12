-- scenario_last_gasp: late winner after minute 85 from draw/losing state
INSERT INTO gold_scenarios.scenario_last_gasp
(
    -- 1. Match Identity
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    -- 2. Decisive Late-Goal Metrics
    goal_diff,
    winning_goal_minute,
    winning_goal_added_time,
    winning_goal_scorer,
    home_score_before,
    away_score_before,
    -- 3. Match Result Logic
    winning_team,
    match_result,
    winning_side,
    match_time_utc_date
)
WITH final_score_goals AS (
    SELECT
        match_id,
        goal_time,
        goal_overload_time,
        is_home_goal,
        home_score_after,
        away_score_after,
        if(is_home_goal = 1, home_score_after - 1, home_score_after) AS home_score_before,
        if(is_home_goal = 0, away_score_after - 1, away_score_after) AS away_score_before,
        player_id,
        player_name,
        row_number() OVER (PARTITION BY match_id ORDER BY goal_time DESC, goal_overload_time DESC) AS rn
    FROM silver.shot
    WHERE is_goal = 1
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
    -- 2. Decisive Late-Goal Metrics
    abs(g.home_score - g.away_score) AS goal_diff,
    wg.goal_time AS winning_goal_minute,
    wg.goal_overload_time AS winning_goal_added_time,
    wg.player_name AS winning_goal_scorer,
    wg.home_score_before,
    wg.away_score_before,
    -- 3. Match Result Logic
    CASE
        WHEN g.home_score > g.away_score THEN g.home_team_name
        WHEN g.away_score > g.home_score THEN g.away_team_name
        ELSE 'Draw'
    END AS winning_team,
    CAST(CASE
        WHEN g.home_score > g.away_score THEN 'Home Win'
        WHEN g.away_score > g.home_score THEN 'Away Win'
        ELSE 'Draw'
    END AS LowCardinality(String)) AS match_result,
    CASE
        WHEN g.home_score > g.away_score THEN 'home'
        WHEN g.away_score > g.home_score THEN 'away'
        ELSE 'draw'
    END AS winning_side,
    toString(g.match_date)
FROM silver.match AS g
INNER JOIN final_score_goals AS wg
    ON g.match_id = wg.match_id
    AND wg.rn = 1
WHERE
    -- Finished non-draw matches decided by a late state-changing goal.
    g.match_finished = 1
    AND g.home_score != g.away_score
    AND wg.goal_time >= 85
    AND (
        (g.home_score > g.away_score AND wg.is_home_goal = 1 AND wg.home_score_before <= wg.away_score_before)
        OR
        (g.away_score > g.home_score AND wg.is_home_goal = 0 AND wg.away_score_before <= wg.home_score_before)
    )
ORDER BY wg.goal_time DESC, wg.goal_overload_time DESC;
