-- scenario_key_pass_king: elite chance creators in finished matches
INSERT INTO gold_scenarios.scenario_key_pass_king
(
    -- 1. Match Identity
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    -- 2. Chance-Creation Metrics
    player_id,
    player_name,
    team_id,
    team_name,
    chances_created,
    xa,
    assists,
    goals,
    minutes_played,
    fotmob_rating,
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
    -- 2. Chance-Creation Metrics
    p.player_id,
    p.player_name,
    p.team_id,
    p.team_name,
    p.chances_created,
    round(p.expected_assists, 3) AS xa,
    p.assists,
    p.goals,
    p.minutes_played,
    p.fotmob_rating,
    CASE
        WHEN p.team_id = g.home_team_id THEN 'home'
        WHEN p.team_id = g.away_team_id THEN 'away'
    END AS team_side,
    -- 3. Match Result Logic
    CASE
        WHEN g.home_score > g.away_score THEN 'Home Win'
        WHEN g.away_score > g.home_score THEN 'Away Win'
        ELSE 'Draw'
    END AS match_result,
    toString(g.match_date)
FROM silver.player_match_stat AS p
INNER JOIN silver.match AS g
    ON p.match_id = g.match_id
WHERE
    -- Finished matches with elite chance creation and xA.
    g.match_finished = 1
    AND p.chances_created >= 3
    AND p.expected_assists > 0.8
ORDER BY p.expected_assists DESC, p.chances_created DESC;
