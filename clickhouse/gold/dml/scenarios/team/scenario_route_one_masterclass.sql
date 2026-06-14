-- scenario_route_one_masterclass: low-possession teams using direct long-ball routes to generate threat and avoid defeat
INSERT INTO gold_scenarios.scenario_route_one_masterclass
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
    long_balls_accurate_home,
    long_ball_pct_home,
    long_balls_accurate_away,
    long_ball_pct_away,
    possession_home,
    possession_away,
    passes_home,
    passes_away,
    xg_home,
    xg_away,
    total_shots_home,
    total_shots_away,
    big_chances_home,
    big_chances_away
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
    toString(g.match_date) AS match_time_utc_date,
    coalesce(p.accurate_long_balls_home, 0) AS long_balls_accurate_home,
    if(
        coalesce(p.long_ball_attempts_home, 0) > 0,
        toInt32(round((coalesce(p.accurate_long_balls_home, 0) / toFloat64(p.long_ball_attempts_home)) * 100.0)),
        0
    ) AS long_ball_pct_home,
    coalesce(p.accurate_long_balls_away, 0) AS long_balls_accurate_away,
    if(
        coalesce(p.long_ball_attempts_away, 0) > 0,
        toInt32(round((coalesce(p.accurate_long_balls_away, 0) / toFloat64(p.long_ball_attempts_away)) * 100.0)),
        0
    ) AS long_ball_pct_away,
    coalesce(p.ball_possession_home, 0) AS possession_home,
    coalesce(p.ball_possession_away, 0) AS possession_away,
    coalesce(p.passes_home, 0) AS passes_home,
    coalesce(p.passes_away, 0) AS passes_away,
    coalesce(p.expected_goals_home, 0) AS xg_home,
    coalesce(p.expected_goals_away, 0) AS xg_away,
    coalesce(p.total_shots_home, 0) AS total_shots_home,
    coalesce(p.total_shots_away, 0) AS total_shots_away,
    coalesce(p.big_chances_home, 0) AS big_chances_home,
    coalesce(p.big_chances_away, 0) AS big_chances_away
FROM silver.period_stat AS p
FINAL
INNER JOIN silver.match AS g
    FINAL ON p.match_id = g.match_id
WHERE
    g.match_finished = 1
    AND p.period = 'All'
    AND
    (
        (coalesce(p.long_ball_attempts_home, 0) / nullIf(toFloat64(passes_home), 0.0)) > 0.20
        AND possession_home < 45
        AND (xg_home > 1.2 OR home_score >= 2)
        AND home_score >= away_score
    )
    OR
    (
        (coalesce(p.long_ball_attempts_away, 0) / nullIf(toFloat64(passes_away), 0.0)) > 0.20
        AND possession_away < 45
        AND (xg_away > 1.2 OR away_score >= 2)
        AND away_score >= home_score
    )
ORDER BY
    match_time_utc_date DESC;
