-- scenario_underdog_heist: low-xG winner pulls off a win
INSERT INTO gold_scenarios.scenario_underdog_heist
(
    -- 1. Match Identity
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    -- 2. Underdog xG Metrics
    goal_diff,
    xg_home,
    xg_away,
    xg_diff,
    -- 3. Match Result Logic
    winning_team,
    match_result,
    winning_side,
    winner_xg,
    match_time_utc_date
)
SELECT
    -- 1. Match Identity
    g.match_id,
    g.home_team_id,
    g.away_team_id,
    g.home_team_name,
    g.away_team_name,
    g.home_score,
    g.away_score,
    -- 2. Underdog xG Metrics
    abs(g.home_score - g.away_score) AS goal_diff,
    p.expected_goals_home AS xg_home,
    p.expected_goals_away AS xg_away,
    abs(p.expected_goals_home - p.expected_goals_away) AS xg_diff,
    -- 3. Match Result Logic
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
    END AS winning_side,
    CASE
        WHEN g.home_score > g.away_score THEN p.expected_goals_home
        WHEN g.away_score > g.home_score THEN p.expected_goals_away
    END AS winner_xg,
    toString(g.match_date)
FROM silver.match AS g
INNER JOIN silver.period_stat AS p
    ON g.match_id = p.match_id
    AND p.period = 'All'
WHERE
    -- Finished non-draw matches where winner's xG is both lower than opponent and under 1.0.
    g.match_finished = 1
    AND g.home_score != g.away_score
    AND (
        (g.home_score > g.away_score AND p.expected_goals_home < p.expected_goals_away AND p.expected_goals_home < 1.0)
        OR
        (g.away_score > g.home_score AND p.expected_goals_away < p.expected_goals_home AND p.expected_goals_away < 1.0)
    )
ORDER BY winner_xg ASC;
