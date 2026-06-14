-- scenario_great_escape: winner was losing at minute 60 and still won
INSERT INTO gold_scenarios.scenario_great_escape
(
    -- 1. Match Identity
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    -- 2. Comeback Metrics
    goal_diff,
    home_score_at_60,
    away_score_at_60,
    -- 3. Match Result Logic
    winning_team,
    match_result,
    winning_side,
    match_time_utc_date
)
WITH goals_at_60 AS (
    SELECT
        match_id,
        sumIf(is_home_goal = 1, is_goal = 1 AND goal_time <= 60) AS home_score_at_60,
        sumIf(is_home_goal = 0, is_goal = 1 AND goal_time <= 60) AS away_score_at_60
    FROM silver.shot
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
    -- 2. Comeback Metrics
    abs(g.home_score - g.away_score) AS goal_diff,
    s.home_score_at_60,
    s.away_score_at_60,
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
INNER JOIN goals_at_60 AS s
    ON g.match_id = s.match_id
WHERE
    -- Finished non-draw matches where winner trailed at minute 60.
    g.match_finished = 1
    AND g.home_score != g.away_score
    AND (
        (g.home_score > g.away_score AND s.home_score_at_60 < s.away_score_at_60)
        OR
        (g.away_score > g.home_score AND s.away_score_at_60 < s.home_score_at_60)
    )
ORDER BY goal_diff DESC;
