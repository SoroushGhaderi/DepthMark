-- scenario_unpunished_aggression: high-foul matches with unusually low yellow-card punishment
INSERT INTO gold_scenarios.scenario_unpunished_aggression
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

    -- 2. Aggression Metrics
    total_match_fouls,
    total_match_yellows,

    -- 3. Contextual Data
    league_name,
    fouls_home,
    fouls_away,
    yellow_cards_home,
    yellow_cards_away,

    -- 4. Match Result Logic
    winning_team,
    match_result,
    winning_side
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
    toString(g.match_date),

    -- 2. Aggression Metrics (home + away combined)
    (ifNull(p.fouls_home, 0) + ifNull(p.fouls_away, 0)) AS total_match_fouls,
    (ifNull(p.yellow_cards_home, 0) + ifNull(p.yellow_cards_away, 0)) AS total_match_yellows,

    -- 3. Contextual Data
    g.league_name,
    p.fouls_home,
    p.fouls_away,
    p.yellow_cards_home,
    p.yellow_cards_away,

    -- 4. Match Result Logic
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
FROM silver.match AS g
INNER JOIN silver.period_stat AS p
    ON g.match_id = p.match_id
WHERE
    -- Full-match team aggregates only.
    g.match_finished = 1
    AND p.period = 'All'
    -- Total fouls threshold.
    AND (ifNull(p.fouls_home, 0) + ifNull(p.fouls_away, 0)) >= 35
    -- Limited yellow-card punishment despite heavy fouling.
    AND (ifNull(p.yellow_cards_home, 0) + ifNull(p.yellow_cards_away, 0)) <= 2
ORDER BY total_match_fouls DESC;
