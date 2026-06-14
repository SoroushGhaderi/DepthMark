-- scenario_box_to_box_general: complete outfield performances across attack and defense
INSERT INTO gold_scenarios.scenario_box_to_box_general
(
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    match_time_utc_date,
    player_name,
    player_team,
    shots_on_target,
    tackles_won,
    touches_opp_box,
    pass_accuracy,
    fotmob_rating,
    winning_team,
    match_result,
    winning_side
)
SELECT
    p.match_id,
    g.home_team_id,
    g.away_team_id,
    g.home_team_name,
    g.away_team_name,
    g.home_score,
    g.away_score,
    toString(g.match_date),
    p.player_name,
    p.team_name AS player_team,
    p.shots_on_target,
    p.tackles_won,
    p.touches_opp_box,
    p.pass_accuracy,
    p.fotmob_rating,
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
    END AS winning_side
FROM silver.player_match_stat AS p
INNER JOIN silver.match AS g
    ON p.match_id = g.match_id
WHERE
    g.match_finished = 1
    AND p.is_goalkeeper = 0
    AND p.shots_on_target >= 1
    AND p.touches_opp_box >= 3
    AND p.tackles_won >= 2
    AND p.pass_accuracy >= 80.0
ORDER BY p.touches_opp_box DESC, p.tackles_won DESC;
