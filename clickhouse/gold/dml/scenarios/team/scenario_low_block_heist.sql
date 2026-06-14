-- scenario_low_block_heist: low-possession winner takes the match
INSERT INTO gold_scenarios.scenario_low_block_heist
(
    -- 1. Match Identity
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    -- 2. Possession Control Metrics
    goal_diff,
    possession_home,
    possession_away,
    -- 3. Match Result Logic
    winning_team,
    match_result,
    winning_side,
    winner_possession,
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
    -- 2. Possession Control Metrics
    abs(g.home_score - g.away_score) AS goal_diff,
    p.ball_possession_home AS possession_home,
    p.ball_possession_away AS possession_away,
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
    CASE
        WHEN g.home_score > g.away_score THEN p.ball_possession_home
        WHEN g.away_score > g.home_score THEN p.ball_possession_away
    END AS winner_possession,
    toString(g.match_date)
FROM silver.match AS g
INNER JOIN silver.period_stat AS p
    ON g.match_id = p.match_id
    AND p.period = 'All'
WHERE
    -- Finished non-draw matches where the winner had less than 35% possession.
    g.match_finished = 1
    AND g.home_score != g.away_score
    AND (
        (g.home_score > g.away_score AND p.ball_possession_home < 35)
        OR
        (g.away_score > g.home_score AND p.ball_possession_away < 35)
    )
ORDER BY winner_possession ASC;
