-- scenario_sterile_control: high-control teams with sterile attacking output
INSERT INTO gold_scenarios.scenario_sterile_control
(
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    match_time_utc_date,
    period,
    ball_possession_home,
    ball_possession_away,
    passes_home,
    passes_away,
    expected_goals_home,
    expected_goals_away,
    shots_on_target_home,
    shots_on_target_away,
    winning_team,
    match_result,
    winning_side
)
SELECT
    g.match_id,
    g.home_team_id,
    g.away_team_id,
    g.home_team_name,
    g.away_team_name,
    g.home_score,
    g.away_score,
    toString(g.match_date),
    p.period,
    p.ball_possession_home,
    p.ball_possession_away,
    p.passes_home,
    p.passes_away,
    p.expected_goals_home,
    p.expected_goals_away,
    p.shots_on_target_home,
    p.shots_on_target_away,
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
FROM silver.match AS g
INNER JOIN silver.period_stat AS p
    ON g.match_id = p.match_id
WHERE
    g.match_finished = 1
    AND p.period = 'All'
    AND (
        (p.ball_possession_home > 65 AND p.passes_home > 600 AND (p.expected_goals_home < 0.75 OR p.shots_on_target_home < 2))
        OR
        (p.ball_possession_away > 65 AND p.passes_away > 600 AND (p.expected_goals_away < 0.75 OR p.shots_on_target_away < 2))
    )
ORDER BY toString(g.match_date) DESC;
