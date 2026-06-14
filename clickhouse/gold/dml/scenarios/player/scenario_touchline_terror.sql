-- scenario_touchline_terror: wide attackers dominating isolation duels and box entries
INSERT INTO gold_scenarios.scenario_touchline_terror
(
    -- 1. Match Identity
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    match_time_utc_date,

    -- 2. Specialist Metrics (Dribbling & Box Activity)
    player_name,
    player_team,
    successful_dribbles,
    dribble_attempts,
    dribble_success_rate,
    touches_opp_box,
    expected_assists,
    fotmob_rating,

    -- 3. Match Result Logic
    winning_team,
    match_result,
    winning_side
)
SELECT
    -- 1. Match Identity
    p.match_id,
    g.home_team_id,
    g.away_team_id,
    g.home_team_name,
    g.away_team_name,
    g.home_score,
    g.away_score,
    toString(g.match_date),

    -- 2. Specialist Metrics (Dribbling & Box Activity)
    p.player_name,
    p.team_name AS player_team,
    p.successful_dribbles,
    p.dribble_attempts,
    p.dribble_success_rate,
    p.touches_opp_box,
    p.expected_assists,
    p.fotmob_rating,

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
    END AS winning_side
FROM silver.player_match_stat AS p
INNER JOIN silver.match AS g
    ON p.match_id = g.match_id
WHERE
    -- Outfield players with enough minutes to influence wing play.
    g.match_finished = 1
    AND p.is_goalkeeper = 0
    AND p.minutes_played >= 45

    -- Isolation specialist profile: volume, efficiency, and danger-zone entries.
    AND p.successful_dribbles >= 5
    AND p.dribble_success_rate >= 60.0
    AND p.touches_opp_box >= 4
ORDER BY p.successful_dribbles DESC, p.touches_opp_box DESC;
