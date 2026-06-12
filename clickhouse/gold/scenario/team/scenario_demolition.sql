-- scenario_demolition: finished matches with a 3+ goal winning margin
INSERT INTO gold_scenarios.scenario_demolition
(
    -- 1. Match Identity
    match_id,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,
    -- 2. Blowout Metrics
    goal_diff,
    -- 3. Match Result Logic
    match_result,
    winning_side,
    match_time_utc_date
)
SELECT
    -- 1. Match Identity
    match_id,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,
    -- 2. Blowout Metrics
    abs(home_score - away_score) AS goal_diff,
    -- 3. Match Result Logic
    CAST(CASE
        WHEN home_score > away_score THEN 'Home Win'
        WHEN away_score > home_score THEN 'Away Win'
        ELSE 'Draw'
    END AS LowCardinality(String)) AS match_result,
    CASE
        WHEN home_score - away_score >= 3 THEN 'home'
        WHEN away_score - home_score >= 3 THEN 'away'
        ELSE 'draw'
    END AS winning_side,
    toString(match_date) AS match_time_utc_date
FROM silver.match FINAL
WHERE
    -- Finished matches with a 3+ goal winning margin.
    match_finished = 1
    AND abs(home_score - away_score) >= 3;
