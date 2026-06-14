-- scenario_line_breaker: deep distributors breaking lines with high-volume accurate long passing
INSERT INTO gold_scenarios.scenario_line_breaker
(
    -- 1. Match Identity & Result Context
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    match_time_utc_date,

    -- 2. Line-Breaking Metrics
    player_name,
    player_team,
    accurate_long_balls,
    accurate_passes,
    pass_accuracy,
    chances_created,
    touches_opp_box,
    fotmob_rating,

    -- 3. Outcome Labeling
    winning_team,
    match_result,
    winning_side
)
SELECT
    -- 1. Match Identity & Result Context
    g.match_id,
    g.home_team_id,
    g.away_team_id,
    g.home_team_name,
    g.away_team_name,
    g.home_score,
    g.away_score,
    toString(g.match_date),

    -- 2. Line-Breaking Metrics
    p.player_name,
    p.team_name AS player_team,
    p.accurate_long_balls,
    p.accurate_passes,
    p.pass_accuracy,
    p.chances_created,
    p.touches_opp_box,
    p.fotmob_rating,

    -- 3. Outcome Labeling
    multiIf(
        g.home_score > g.away_score, g.home_team_name,
        g.away_score > g.home_score, g.away_team_name,
        'Draw'
    ) AS winning_team,
    CAST(
        multiIf(
            g.home_score > g.away_score, 'Home Win',
            g.away_score > g.home_score, 'Away Win',
            'Draw'
        ),
        'LowCardinality(String)'
    ) AS match_result,
    CASE
        WHEN g.home_score > g.away_score THEN 'home'
        WHEN g.away_score > g.home_score THEN 'away'
        ELSE 'draw'
    END AS winning_side
FROM silver.player_match_stat AS p
INNER JOIN silver.match AS g
    ON p.match_id = g.match_id
WHERE
    -- Outfield players with substantial minutes to represent true role profile.
    g.match_finished = 1
    AND p.is_goalkeeper = 0
    AND p.minutes_played >= 75

    -- Line-breaker profile: high long-ball progression with technical security from deep zones.
    AND p.accurate_long_balls >= 8
    AND p.pass_accuracy >= 85.0
    AND p.touches_opp_box <= 1
    AND p.accurate_passes >= 50
ORDER BY p.accurate_long_balls DESC, p.pass_accuracy DESC;
