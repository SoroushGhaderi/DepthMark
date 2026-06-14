-- scenario_dead_ball_dominance: winner scores at least two set-piece goals
INSERT INTO gold_scenarios.scenario_dead_ball_dominance
(
    -- 1. Match Identity
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    -- 2. Set-Piece Metrics
    home_set_piece_goals,
    away_set_piece_goals,
    -- 3. Match Result Logic
    winning_team,
    match_result,
    winning_side,
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
    -- 2. Set-Piece Metrics
    countIf(gl.is_home_goal = 1 AND gl.is_goal = 1 AND gl.situation IN ('SetPiece', 'FromCorner', 'FreeKick')) AS home_set_piece_goals,
    countIf(gl.is_home_goal = 0 AND gl.is_goal = 1 AND gl.situation IN ('SetPiece', 'FromCorner', 'FreeKick')) AS away_set_piece_goals,
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
INNER JOIN silver.shot AS gl
    ON g.match_id = gl.match_id
WHERE
    -- Finished non-draw matches only.
    g.match_finished = 1
    AND g.home_score != g.away_score
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
    -- Winning side must score at least two set-piece goals.
    (g.home_score > g.away_score AND home_set_piece_goals >= 2)
    OR
    (g.away_score > g.home_score AND away_set_piece_goals >= 2)
ORDER BY
    greatest(home_set_piece_goals, away_set_piece_goals) DESC;
