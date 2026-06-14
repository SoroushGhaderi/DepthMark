-- scenario_clinical_finisher: multi-goal output from low shot/xG volume
INSERT INTO gold_scenarios.scenario_clinical_finisher
(
    -- 1. Match Identity
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    -- 2. Clinical Finisher Metrics
    player_id,
    player_name,
    team_id,
    goals,
    total_shots,
    combined_xg,
    team_side,
    -- 3. Match Result Logic
    match_result,
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
    -- 2. Clinical Finisher Metrics
    s.player_id,
    s.player_name,
    s.team_id,
    countIf(s.event_type = 'Goal') AS goals,
    count() AS total_shots,
    round(sum(s.expected_goals), 3) AS combined_xg,
    CASE
        WHEN s.team_id = g.home_team_id THEN 'home'
        WHEN s.team_id = g.away_team_id THEN 'away'
    END AS team_side,
    -- 3. Match Result Logic
    CAST(CASE
        WHEN g.home_score > g.away_score THEN 'Home Win'
        WHEN g.away_score > g.home_score THEN 'Away Win'
        ELSE 'Draw'
    END AS LowCardinality(String)) AS match_result,
    toString(g.match_date)
FROM silver.shot AS s
INNER JOIN silver.match AS g
    ON s.match_id = g.match_id
WHERE
    -- Finished matches only with valid non-own-goal shot quality data.
    g.match_finished = 1
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
    s.player_id,
    s.player_name,
    s.team_id,
    toString(g.match_date)
HAVING
    -- Efficient multi-goal output from low volume/low xG chance creation.
    goals >= 2
    AND total_shots <= 3
    AND combined_xg < 1.0
ORDER BY combined_xg ASC;
