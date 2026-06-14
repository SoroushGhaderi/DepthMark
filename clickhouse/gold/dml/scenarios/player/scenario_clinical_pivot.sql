-- scenario_clinical_pivot: deep distributors with elite passing volume/precision and controlled final-third progression
INSERT INTO gold_scenarios.scenario_clinical_pivot
(
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    league_name,
    match_time_utc_date,
    player_id,
    player_name,
    team_id,
    team_name,
    minutes_played,
    fotmob_rating,
    total_passes,
    accurate_passes,
    pass_accuracy,
    passes_final_third,
    touches_opp_box,
    touches,
    expected_goals,
    expected_assists,
    chances_created,
    successful_dribbles,
    interceptions,
    recoveries,
    defensive_actions,
    xg_plus_xa
)
SELECT
    g.match_id,
    g.home_team_id,
    g.away_team_id,
    g.home_team_name,
    g.away_team_name,
    g.home_score,
    g.away_score,
    g.league_name,
    toString(g.match_date),
    p.player_id,
    p.player_name,
    p.team_id,
    p.team_name,
    p.minutes_played,
    p.fotmob_rating,
    p.total_passes,
    p.accurate_passes,
    p.pass_accuracy,
    p.passes_final_third,
    p.touches_opp_box,
    p.touches,
    p.expected_goals,
    p.expected_assists,
    p.chances_created,
    p.successful_dribbles,
    p.interceptions,
    p.recoveries,
    p.defensive_actions,
    p.xg_plus_xa
FROM silver.player_match_stat AS p
FINAL
INNER JOIN silver.match AS g
    FINAL ON p.match_id = g.match_id
WHERE
    g.match_finished = 1
    AND p.is_goalkeeper = 0
    AND coalesce(p.total_passes, 0) >= 70
    AND coalesce(p.pass_accuracy, 0) >= 90.0
    AND coalesce(p.passes_final_third, 0) >= 10
    AND coalesce(p.touches_opp_box, 0) <= 1
ORDER BY
    p.total_passes DESC,
    p.pass_accuracy DESC,
    p.passes_final_third DESC;
