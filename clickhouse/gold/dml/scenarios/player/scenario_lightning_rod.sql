-- scenario_lightning_rod: high-foul-drawing attackers who absorb contact and destabilize defenses
INSERT INTO gold_scenarios.scenario_lightning_rod
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

    -- 2. Lightning Rod Metrics
    player_name,
    player_team,
    was_fouled,
    dribble_attempts,
    touches_opp_box,
    fotmob_rating,

    -- 3. Outcome Labeling
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

    -- 2. Lightning Rod Metrics
    p.player_name,
    p.team_name AS player_team,
    p.was_fouled,
    p.dribble_attempts,
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
    -- Outfield players with enough minutes to absorb sustained pressure.
    g.match_finished = 1
    AND p.is_goalkeeper = 0
    AND p.minutes_played >= 45

    -- Lightning-rod profile: high foul volume plus active take-ons or dangerous-area involvement.
    AND p.was_fouled >= 6
    AND (
        p.dribble_attempts >= 4
        OR p.touches_opp_box >= 5
    )
ORDER BY p.was_fouled DESC, p.dribble_attempts DESC;
