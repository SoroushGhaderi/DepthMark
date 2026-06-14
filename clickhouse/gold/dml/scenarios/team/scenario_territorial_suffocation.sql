-- scenario_territorial_suffocation: possession-led territorial domination that suppresses opponent box access and on-target threat
INSERT INTO gold_scenarios.scenario_territorial_suffocation
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
    possession_home,
    possession_away,
    shots_on_target_home,
    shots_on_target_away,
    total_shots_home,
    total_shots_away,
    touches_opp_box_home,
    touches_opp_box_away,
    xg_home,
    xg_away,
    big_chances_home,
    big_chances_away,
    passes_home,
    passes_away,
    corners_home,
    corners_away
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
    coalesce(p.ball_possession_home, 0) AS possession_home,
    coalesce(p.ball_possession_away, 0) AS possession_away,
    coalesce(p.shots_on_target_home, 0) AS shots_on_target_home,
    coalesce(p.shots_on_target_away, 0) AS shots_on_target_away,
    coalesce(p.total_shots_home, 0) AS total_shots_home,
    coalesce(p.total_shots_away, 0) AS total_shots_away,
    coalesce(p.touches_opp_box_home, 0) AS touches_opp_box_home,
    coalesce(p.touches_opp_box_away, 0) AS touches_opp_box_away,
    coalesce(p.expected_goals_home, 0) AS xg_home,
    coalesce(p.expected_goals_away, 0) AS xg_away,
    coalesce(p.big_chances_home, 0) AS big_chances_home,
    coalesce(p.big_chances_away, 0) AS big_chances_away,
    coalesce(p.passes_home, 0) AS passes_home,
    coalesce(p.passes_away, 0) AS passes_away,
    coalesce(p.corners_home, 0) AS corners_home,
    coalesce(p.corners_away, 0) AS corners_away
FROM silver.period_stat AS p
FINAL
INNER JOIN silver.match AS g
    FINAL ON p.match_id = g.match_id
WHERE
    g.match_finished = 1
    AND p.period = 'All'
    AND (
        (
            coalesce(p.touches_opp_box_away, 0) <= 5
            AND coalesce(p.ball_possession_home, 0) > 65
            AND coalesce(p.shots_on_target_away, 0) <= 1
        )
        OR
        (
            coalesce(p.touches_opp_box_home, 0) <= 5
            AND coalesce(p.ball_possession_away, 0) > 65
            AND coalesce(p.shots_on_target_home, 0) <= 1
        )
    )
ORDER BY
    toString(g.match_date) DESC;
