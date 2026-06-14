-- scenario_elite_shot_stopper: primary goalkeepers with elite save volume and high xG faced in clean sheets
INSERT INTO gold_scenarios.scenario_elite_shot_stopper
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

    -- 2. Goalkeeper Performance
    player_name,
    player_team,
    minutes_played,
    fotmob_rating,
    total_saves,
    xg_conceded,

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

    -- 2. Goalkeeper Performance
    p.player_name,
    p.team_name AS player_team,
    p.minutes_played,
    p.fotmob_rating,
    multiIf(p.team_id = g.home_team_id, per.keeper_saves_home, per.keeper_saves_away) AS total_saves,
    multiIf(p.team_id = g.home_team_id, per.expected_goals_away, per.expected_goals_home) AS xg_conceded,

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
FROM silver.player_match_stat AS p
INNER JOIN silver.match AS g
    ON p.match_id = g.match_id
INNER JOIN silver.period_stat AS per
    ON p.match_id = per.match_id
WHERE
    -- Ensure primary full-match goalkeeper rows.
    g.match_finished = 1
    AND p.is_goalkeeper = 1
    AND p.minutes_played >= 80
    AND per.period = 'All'

    -- Elite shot-stopping profile: clean sheet, 7+ saves, and high xG faced.
    AND (
        (p.team_id = g.home_team_id AND g.away_score = 0 AND per.keeper_saves_home >= 7 AND per.expected_goals_away >= 2.0)
        OR
        (p.team_id = g.away_team_id AND g.home_score = 0 AND per.keeper_saves_away >= 7 AND per.expected_goals_home >= 2.0)
    )
ORDER BY xg_conceded DESC, total_saves DESC;
