-- scenario_war_zone: high-discipline-intensity matches
INSERT INTO gold_scenarios.scenario_war_zone
(
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    fouls_home,
    fouls_away,
    combined_fouls,
    yellow_cards_home,
    yellow_cards_away,
    combined_yellow_cards,
    red_cards_home,
    red_cards_away,
    combined_red_cards,
    match_result,
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
    p.fouls_home,
    p.fouls_away,
    p.fouls_home + p.fouls_away AS combined_fouls,
    p.yellow_cards_home,
    p.yellow_cards_away,
    p.yellow_cards_home + p.yellow_cards_away AS combined_yellow_cards,
    p.red_cards_home,
    p.red_cards_away,
    p.red_cards_home + p.red_cards_away AS combined_red_cards,
    CASE
        WHEN g.home_score > g.away_score THEN 'Home Win'
        WHEN g.away_score > g.home_score THEN 'Away Win'
        ELSE 'Draw'
    END AS match_result,
    toString(g.match_date)
FROM silver.match AS g
INNER JOIN silver.period_stat AS p
    ON g.match_id = p.match_id
    AND p.period = 'All'
WHERE
    g.match_finished = 1
    AND (
        (p.fouls_home + p.fouls_away) > 35
        OR
        (p.yellow_cards_home + p.yellow_cards_away) >= 5
        OR
        (p.red_cards_home + p.red_cards_away) >= 2
    )
ORDER BY combined_fouls DESC, combined_yellow_cards DESC;
