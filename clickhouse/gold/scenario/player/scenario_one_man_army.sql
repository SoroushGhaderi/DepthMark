-- scenario_one_man_army: high individual output in finished matches
INSERT INTO gold_scenarios.scenario_one_man_army
(
    -- 1. Match Identity
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    -- 2. Individual Output Metrics
    player_id,
    player_name,
    team_id,
    team_name,
    goals,
    assists,
    goal_contributions,
    xg,
    xa,
    xg_xa,
    team_side,
    -- 3. Match Result Logic
    match_result,
    match_time_utc_date
)
SELECT
    -- 1. Match Identity
    p.match_id,
    g.home_team_id,
    g.away_team_id,
    g.home_team_name,
    g.away_team_name,
    g.home_score,
    g.away_score,
    -- 2. Individual Output Metrics
    p.player_id,
    p.player_name,
    p.team_id,
    p.team_name,
    p.goals,
    p.assists,
    p.goals + p.assists AS goal_contributions,
    p.expected_goals AS xg,
    p.expected_assists AS xa,
    p.expected_goals + p.expected_assists AS xg_xa,
    CASE
        WHEN p.team_id = g.home_team_id THEN 'home'
        WHEN p.team_id = g.away_team_id THEN 'away'
    END AS team_side,
    -- 3. Match Result Logic
    CAST(CASE
        WHEN g.home_score > g.away_score THEN 'Home Win'
        WHEN g.away_score > g.home_score THEN 'Away Win'
        ELSE 'Draw'
    END AS LowCardinality(String)) AS match_result,
    toString(g.match_date)
FROM silver.player_match_stat AS p
INNER JOIN silver.match AS g
    ON p.match_id = g.match_id
WHERE
    -- Finished matches with high direct goal involvement by one player.
    g.match_finished = 1
    AND (
        p.goals >= 2
        OR p.assists >= 2
    )
ORDER BY goal_contributions DESC, p.goals DESC;
