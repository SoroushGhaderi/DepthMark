-- scenario_defensive_masterclass: dominant defensive individual displays without fouling
INSERT INTO gold_scenarios.scenario_defensive_masterclass
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
    aerial_duels_won,
    aerial_duel_attempts,
    aerial_duel_success_rate,
    clearances,
    fouls_committed,
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
    p.aerial_duels_won,
    p.aerial_duel_attempts,
    p.aerial_duel_success_rate,
    p.clearances,
    p.fouls_committed,
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
    AND p.aerial_duel_success_rate >= 100.0
    AND p.aerial_duel_attempts >= 5
    AND p.clearances >= 5
    AND p.fouls_committed = 0
ORDER BY toString(g.match_date) DESC, p.clearances DESC;
