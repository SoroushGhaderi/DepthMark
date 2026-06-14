-- scenario_high_intensity_engine: high-work-rate outfield players with elite defensive volume and event density
INSERT INTO gold_scenarios.scenario_high_intensity_engine
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
    position_id,
    usual_playing_position_id,
    tackles_won,
    interceptions,
    recoveries,
    defensive_volume,
    touches,
    defensive_actions,
    event_density_per90,
    duels_won,
    duels_lost,
    tackles_total,
    tackle_attempts,
    tackle_success_rate,
    clearances,
    dribbled_past,
    fouls_committed,
    was_fouled,
    passes_final_third,
    total_passes,
    pass_accuracy,
    expected_goals,
    expected_assists
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
    s.position_id,
    s.usual_playing_position_id,
    coalesce(p.tackles_won, 0) AS tackles_won,
    coalesce(p.interceptions, 0) AS interceptions,
    coalesce(p.recoveries, 0) AS recoveries,
    coalesce(p.tackles_won, 0)
        + coalesce(p.interceptions, 0)
        + coalesce(p.recoveries, 0) AS defensive_volume,
    coalesce(p.touches, 0) AS touches,
    coalesce(p.defensive_actions, 0) AS defensive_actions,
    round(
        (coalesce(p.touches, 0) + coalesce(p.defensive_actions, 0))
        / nullIf(coalesce(p.minutes_played, 0), 0) * 90,
        1
    ) AS event_density_per90,
    p.duels_won,
    p.duels_lost,
    p.tackles_won AS tackles_total,
    p.tackle_attempts,
    p.tackle_success_rate,
    p.clearances,
    p.dribbled_past,
    p.fouls_committed,
    p.was_fouled,
    p.passes_final_third,
    p.total_passes,
    p.pass_accuracy,
    p.expected_goals,
    p.expected_assists
FROM silver.player_match_stat AS p
FINAL
INNER JOIN silver.match AS g
    FINAL ON p.match_id = g.match_id
INNER JOIN silver.match_personnel AS s
    FINAL
    ON p.match_id = s.match_id
    AND p.player_id = s.person_id
WHERE
    g.match_finished = 1
    AND s.role = 'starter'
    AND p.is_goalkeeper = 0
    AND (
        coalesce(p.tackles_won, 0)
        + coalesce(p.interceptions, 0)
        + coalesce(p.recoveries, 0)
    ) >= 12
    AND coalesce(p.minutes_played, 0) >= 60
    AND coalesce(s.position_id, 0) NOT IN (1, 2, 3, 4)
ORDER BY
    defensive_volume DESC,
    event_density_per90 DESC,
    p.fotmob_rating DESC;
