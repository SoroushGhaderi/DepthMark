-- scenario_pressing_masterclass: team-level pressing dominance converted into wins
INSERT INTO gold_scenarios.scenario_pressing_masterclass
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

    -- 2. Aggregated Pressing Metrics
    total_recoveries_home,
    total_recoveries_away,
    total_interceptions_home,
    total_interceptions_away,

    -- 3. Match Result Logic
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

    -- 2. Aggregated Pressing Metrics (team totals within each match)
    sumIf(p.recoveries, p.team_id = g.home_team_id) AS total_recoveries_home,
    sumIf(p.recoveries, p.team_id = g.away_team_id) AS total_recoveries_away,
    sumIf(p.interceptions, p.team_id = g.home_team_id) AS total_interceptions_home,
    sumIf(p.interceptions, p.team_id = g.away_team_id) AS total_interceptions_away,

    -- 3. Match Result Logic
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
INNER JOIN silver.player_match_stat AS p
    ON g.match_id = p.match_id
WHERE
    g.match_finished = 1
GROUP BY
    g.match_id,
    g.home_team_id,
    g.away_team_id,
    g.home_team_name,
    g.away_team_name,
    g.home_score,
    g.away_score,
    toString(g.match_date)
HAVING
    -- One side crosses elite pressing thresholds and wins the match.
    (total_recoveries_home >= 65 AND total_interceptions_home >= 15 AND g.home_score > g.away_score)
    OR
    (total_recoveries_away >= 65 AND total_interceptions_away >= 15 AND g.away_score > g.home_score)
ORDER BY (total_recoveries_home + total_recoveries_away) DESC;
