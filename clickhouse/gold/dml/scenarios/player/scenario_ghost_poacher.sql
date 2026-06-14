-- scenario_ghost_poacher: low-touch starters with extreme box-touch concentration and high scoring threat
INSERT INTO gold_scenarios.scenario_ghost_poacher
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
    team_name,
    team_id,
    minutes_played,
    fotmob_rating,
    touches,
    touches_opp_box,
    box_touch_concentration_pct,
    expected_goals,
    goals,
    shots_on_target,
    total_shots,
    xg_non_penalty,
    xg_per_shot,
    assists,
    expected_assists,
    chances_created,
    xg_plus_xa
)
WITH starters_cte AS (
    SELECT DISTINCT
        match_id,
        person_id
    FROM silver.match_personnel
    FINAL
    WHERE role = 'starter'
)
SELECT
    p.match_id,
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
    p.team_name,
    p.team_id,
    p.minutes_played,
    p.fotmob_rating,
    p.touches,
    p.touches_opp_box,
    round(p.touches_opp_box / nullIf(p.touches, 0) * 100, 1) AS box_touch_concentration_pct,
    p.expected_goals,
    p.goals,
    p.shots_on_target,
    p.total_shots,
    p.xg_non_penalty,
    round(p.expected_goals / nullIf(p.total_shots, 0), 3) AS xg_per_shot,
    p.assists,
    p.expected_assists,
    p.chances_created,
    p.xg_plus_xa
FROM silver.player_match_stat AS p
FINAL
INNER JOIN silver.match AS g
    FINAL ON p.match_id = g.match_id
INNER JOIN starters_cte AS s
    ON p.match_id = s.match_id
    AND p.player_id = s.person_id
WHERE
    g.match_finished = 1
    AND p.is_goalkeeper = 0
    AND coalesce(p.touches, 0) <= 25
    AND coalesce(p.touches_opp_box, 0) / nullIf(coalesce(p.touches, 0), 0) >= 0.20
    AND (
        coalesce(p.expected_goals, 0) > 0.8
        OR coalesce(p.goals, 0) >= 1
    )
    AND coalesce(p.minutes_played, 0) >= 60
ORDER BY
    box_touch_concentration_pct DESC,
    p.expected_goals DESC,
    p.touches ASC;
