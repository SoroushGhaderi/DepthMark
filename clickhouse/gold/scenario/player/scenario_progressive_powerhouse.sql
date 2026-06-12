-- scenario_progressive_powerhouse: high-accuracy progressors with end-product carrying
INSERT INTO gold_scenarios.scenario_progressive_powerhouse
(
    match_id,
    player_id,
    player_name,
    team_id,
    player_team,
    pass_accuracy,
    passes_final_third,
    successful_dribbles,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    winning_team,
    match_result,
    winning_side,
    match_time_utc_date
)
SELECT
    p.match_id,
    p.player_id,
    p.player_name,
    p.team_id,
    p.team_name AS player_team,
    p.pass_accuracy,
    p.passes_final_third,
    p.successful_dribbles,
    g.home_team_id,
    g.away_team_id,
    g.home_team_name,
    g.away_team_name,
    g.home_score,
    g.away_score,
    CASE
        WHEN g.home_score > g.away_score THEN g.home_team_name
        WHEN g.away_score > g.home_score THEN g.away_team_name
        ELSE 'Draw'
    END AS winning_team,
    CASE
        WHEN g.home_score > g.away_score THEN 'Home Win'
        WHEN g.away_score > g.home_score THEN 'Away Win'
        ELSE 'Draw'
    END AS match_result,
    CASE
        WHEN g.home_score > g.away_score THEN 'home'
        WHEN g.away_score > g.home_score THEN 'away'
        ELSE 'draw'
    END AS winning_side,
    toString(g.match_date)
FROM silver.player_match_stat AS p
INNER JOIN silver.match AS g
    ON p.match_id = g.match_id
WHERE
    g.match_finished = 1
    AND p.pass_accuracy >= 85.0
    AND p.passes_final_third >= 8
    AND p.successful_dribbles >= 3
    AND p.is_goalkeeper = 0
ORDER BY p.passes_final_third DESC, p.successful_dribbles DESC;
