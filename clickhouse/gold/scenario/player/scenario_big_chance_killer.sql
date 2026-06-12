-- scenario_big_chance_killer: goalkeepers denying multiple big chances in finished matches
INSERT INTO gold_scenarios.scenario_big_chance_killer
(
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    keeper_id,
    goalkeeper_name,
    goalkeeper_team_id,
    goalkeeper_team,
    keeper_side,
    big_chances_denied,
    total_xgot_denied,
    highest_xgot_saved,
    avg_xgot_per_save,
    match_result,
    winning_side,
    match_time_utc_date
)
SELECT
    g.match_id,
    g.home_team_id,
    g.away_team_id,
    g.home_team_name,
    g.away_team_name,
    g.home_score,
    g.away_score,
    s.keeper_id,
    p.player_name AS goalkeeper_name,
    p.team_id AS goalkeeper_team_id,
    p.team_name AS goalkeeper_team,
    CASE
        WHEN p.team_id = g.home_team_id THEN 'home'
        WHEN p.team_id = g.away_team_id THEN 'away'
    END AS keeper_side,
    countIf(s.expected_goals_on_target > 0.4) AS big_chances_denied,
    round(sumIf(s.expected_goals_on_target, s.expected_goals_on_target > 0.4), 3) AS total_xgot_denied,
    round(max(s.expected_goals_on_target), 3) AS highest_xgot_saved,
    round(avg(s.expected_goals_on_target), 3) AS avg_xgot_per_save,
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
FROM silver.shot AS s
INNER JOIN silver.match AS g
    ON s.match_id = g.match_id
INNER JOIN silver.player_match_stat AS p
    ON s.match_id = p.match_id
    AND s.keeper_id = p.player_id
WHERE
    g.match_finished = 1
    AND s.is_on_target = 1
    AND s.event_type != 'Goal'
    AND s.is_own_goal != 1
    AND s.expected_goals_on_target IS NOT NULL
    AND p.is_goalkeeper = 1
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
HAVING
    big_chances_denied >= 2
ORDER BY big_chances_denied DESC, total_xgot_denied DESC;
