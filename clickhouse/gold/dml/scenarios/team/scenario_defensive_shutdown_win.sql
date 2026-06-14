-- scenario_defensive_shutdown_win: winning side concedes very low xG (<0.3)
INSERT INTO gold_scenarios.scenario_defensive_shutdown_win
(
    -- 1. Match Identity
    match_id,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,
    -- 2. Defensive Control Metrics
    expected_goals_home,
    expected_goals_away,
    -- 3. Match Result Logic
    winning_team,
    match_result,
    winning_side,
    xg_conceded,
    match_time_utc_date
)
SELECT
    -- 1. Match Identity
    g.match_id,
    g.home_team_id,
    g.home_team_name,
    g.away_team_id,
    g.away_team_name,
    g.home_score,
    g.away_score,
    -- 2. Defensive Control Metrics
    p.expected_goals_home,
    p.expected_goals_away,
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
        WHEN g.home_score > g.away_score THEN p.expected_goals_away
        WHEN g.away_score > g.home_score THEN p.expected_goals_home
    END AS xg_conceded,
    toString(g.match_date)
FROM silver.match AS g
INNER JOIN silver.period_stat AS p
    ON g.match_id = p.match_id
    AND p.period = 'All'
WHERE
    -- Finished non-draw matches where winner concedes < 0.3 xG.
    g.match_finished = 1
    AND g.home_score != g.away_score
    AND (
        (g.home_score > g.away_score AND p.expected_goals_away < 0.3)
        OR
        (g.away_score > g.home_score AND p.expected_goals_home < 0.3)
    );
