-- scenario_shot_stopper: goalkeepers with high expected-goals prevented
INSERT INTO gold_scenarios.scenario_shot_stopper
(
    -- 1. Match Identity
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    -- 2. Goalkeeper Shot-Stopping Metrics
    keeper_id,
    goalkeeper_name,
    goalkeeper_team_id,
    goalkeeper_team,
    saves,
    xg_saved,
    keeper_side,
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
    -- 2. Goalkeeper Shot-Stopping Metrics
    s.keeper_id,
    p.player_name AS goalkeeper_name,
    p.team_id AS goalkeeper_team_id,
    p.team_name AS goalkeeper_team,
    count() AS saves,
    round(sum(s.expected_goals_on_target), 3) AS xg_saved,
    CASE
        WHEN p.team_id = g.home_team_id THEN 'home'
        WHEN p.team_id = g.away_team_id THEN 'away'
    END AS keeper_side,
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
INNER JOIN silver.player_match_stat AS p
    ON s.match_id = p.match_id
    AND s.keeper_id = p.player_id
WHERE
    -- Saved on-target non-own-goal shots in finished matches only.
    g.match_finished = 1
    AND s.is_on_target = 1
    AND s.event_type != 'Goal'
    AND s.is_own_goal != 1
    AND s.expected_goals_on_target IS NOT NULL
GROUP BY
    g.match_id,
    g.home_team_id,
    g.away_team_id,
    g.home_team_name,
    g.away_team_name,
    g.home_score,
    g.away_score,
    s.keeper_id,
    p.player_name,
    p.team_id,
    p.team_name,
    toString(g.match_date)
HAVING xg_saved >= 1.5
ORDER BY xg_saved DESC;
