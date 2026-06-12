-- scenario_second_half_warriors: teams recovering from halftime deficits
INSERT INTO gold_scenarios.scenario_second_half_warriors
(
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    home_score_ft,
    away_score_ft,
    home_score_ht,
    away_score_ht,
    home_second_half_goals,
    away_second_half_goals,
    losing_team_at_ht,
    match_result,
    comeback_team,
    comeback_type,
    match_time_utc_date
)
WITH ht_score AS (
    SELECT
        match_id,
        sumIf(is_home_goal = 1, is_goal = 1 AND period = 'FirstHalf') AS home_score_ht,
        sumIf(is_home_goal = 0, is_goal = 1 AND period = 'FirstHalf') AS away_score_ht
    FROM silver.shot
    GROUP BY match_id
)
SELECT
    g.match_id,
    g.home_team_id,
    g.away_team_id,
    g.home_team_name,
    g.away_team_name,
    g.home_score,
    g.away_score,
    g.home_score AS home_score_ft,
    g.away_score AS away_score_ft,
    ht.home_score_ht,
    ht.away_score_ht,
    g.home_score - ht.home_score_ht AS home_second_half_goals,
    g.away_score - ht.away_score_ht AS away_second_half_goals,
    CASE
        WHEN ht.home_score_ht < ht.away_score_ht THEN 'home'
        WHEN ht.away_score_ht < ht.home_score_ht THEN 'away'
    END AS losing_team_at_ht,
    CASE
        WHEN g.home_score > g.away_score THEN 'Home Win'
        WHEN g.away_score > g.home_score THEN 'Away Win'
        ELSE 'Draw'
    END AS match_result,
    CASE
        WHEN ht.home_score_ht < ht.away_score_ht AND g.home_score >= g.away_score THEN g.home_team_name
        WHEN ht.away_score_ht < ht.home_score_ht AND g.away_score >= g.home_score THEN g.away_team_name
    END AS comeback_team,
    CASE
        WHEN ht.home_score_ht < ht.away_score_ht AND g.home_score > g.away_score THEN 'win'
        WHEN ht.home_score_ht < ht.away_score_ht AND g.home_score = g.away_score THEN 'draw'
        WHEN ht.away_score_ht < ht.home_score_ht AND g.away_score > g.home_score THEN 'win'
        WHEN ht.away_score_ht < ht.home_score_ht AND g.away_score = g.home_score THEN 'draw'
    END AS comeback_type,
    toString(g.match_date)
FROM silver.match AS g
INNER JOIN ht_score AS ht
    ON g.match_id = ht.match_id
WHERE
    g.match_finished = 1
    AND (
        (ht.home_score_ht < ht.away_score_ht AND g.home_score >= g.away_score)
        OR
        (ht.away_score_ht < ht.home_score_ht AND g.away_score >= g.home_score)
    )
ORDER BY comeback_type DESC, home_second_half_goals + away_second_half_goals DESC;
