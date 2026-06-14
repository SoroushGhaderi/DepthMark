-- scenario_efficiency_machine: winners with low shot volume but high shot quality
INSERT INTO gold_scenarios.scenario_efficiency_machine
(
    -- 1. Match Identity
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    -- 2. Efficiency Metrics
    goal_diff,
    winning_team,
    match_result,
    winning_side,
    home_total_shots,
    away_total_shots,
    home_avg_xg_per_shot,
    away_avg_xg_per_shot,
    home_total_xg,
    away_total_xg,
    winner_total_shots,
    winner_avg_xg_per_shot,
    match_time_utc_date
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
    -- 2. Efficiency Metrics
    abs(g.home_score - g.away_score) AS goal_diff,
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
    countIf(s.team_id = g.home_team_id) AS home_total_shots,
    countIf(s.team_id = g.away_team_id) AS away_total_shots,
    round(avgIf(s.expected_goals, s.team_id = g.home_team_id), 3) AS home_avg_xg_per_shot,
    round(avgIf(s.expected_goals, s.team_id = g.away_team_id), 3) AS away_avg_xg_per_shot,
    round(sumIf(s.expected_goals, s.team_id = g.home_team_id), 3) AS home_total_xg,
    round(sumIf(s.expected_goals, s.team_id = g.away_team_id), 3) AS away_total_xg,
    CASE
        WHEN g.home_score > g.away_score THEN countIf(s.team_id = g.home_team_id)
        WHEN g.away_score > g.home_score THEN countIf(s.team_id = g.away_team_id)
    END AS winner_total_shots,
    CASE
        WHEN g.home_score > g.away_score THEN round(avgIf(s.expected_goals, s.team_id = g.home_team_id), 3)
        WHEN g.away_score > g.home_score THEN round(avgIf(s.expected_goals, s.team_id = g.away_team_id), 3)
    END AS winner_avg_xg_per_shot,
    toString(g.match_date)
FROM silver.shot AS s
INNER JOIN silver.match AS g
    ON s.match_id = g.match_id
WHERE
    -- Finished non-draw matches with valid xG and shot data.
    g.match_finished = 1
    AND g.home_score != g.away_score
    AND s.is_own_goal != 1
    AND s.expected_goals IS NOT NULL
GROUP BY
    g.match_id,
    g.home_team_id,
    g.away_team_id,
    g.home_team_name,
    g.away_team_name,
    g.home_score,
    g.away_score,
    toString(g.match_date)
HAVING
    -- Winner must combine low shot volume with high average xG per shot.
    (g.home_score > g.away_score AND home_total_shots <= 5 AND home_avg_xg_per_shot > 0.25)
    OR
    (g.away_score > g.home_score AND away_total_shots <= 5 AND away_avg_xg_per_shot > 0.25)
ORDER BY winner_avg_xg_per_shot DESC;
