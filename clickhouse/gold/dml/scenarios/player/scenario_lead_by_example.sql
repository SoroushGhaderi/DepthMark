-- scenario_lead_by_example: captains leading winning teams with above-average impact
INSERT INTO gold_scenarios.scenario_lead_by_example
(
    -- 1. Match Identity
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    -- 2. Captain Impact Metrics
    goal_diff,
    player_id,
    captain_name,
    team_side,
    goals,
    assists,
    goal_contributions,
    xg,
    xa,
    rating,
    avg_rating,
    rating_above_avg,
    minutes_played,
    -- 3. Match Result Logic
    winning_team,
    match_result,
    winning_side,
    match_time_utc_date
)
WITH avg_rating AS (
    SELECT avg(fotmob_rating) AS overall_avg_rating
    FROM silver.player_match_stat
    WHERE fotmob_rating IS NOT NULL
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
    -- 2. Captain Impact Metrics
    abs(g.home_score - g.away_score) AS goal_diff,
    st.person_id,
    st.name AS captain_name,
    st.team_side,
    p.goals,
    p.assists,
    p.goals + p.assists AS goal_contributions,
    round(p.expected_goals, 3) AS xg,
    round(p.expected_assists, 3) AS xa,
    round(p.fotmob_rating, 2) AS rating,
    round(ar.overall_avg_rating, 2) AS avg_rating,
    round(p.fotmob_rating - ar.overall_avg_rating, 2) AS rating_above_avg,
    p.minutes_played,
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
    toString(g.match_date)
FROM silver.match_personnel AS st
INNER JOIN silver.match AS g
    ON st.match_id = g.match_id
INNER JOIN silver.player_match_stat AS p
    ON st.match_id = p.match_id
    AND st.person_id = p.player_id
CROSS JOIN avg_rating AS ar
WHERE
    -- Winning captains with above-average impact and direct output.
    g.match_finished = 1
    AND st.role = 'starter'
    AND g.home_score != g.away_score
    AND st.is_captain = 1
    AND p.fotmob_rating > ar.overall_avg_rating
    AND (p.goals >= 1 OR p.assists >= 1)
    AND (
        (st.team_side = 'home' AND g.home_score > g.away_score)
        OR
        (st.team_side = 'away' AND g.away_score > g.home_score)
    )
ORDER BY rating_above_avg DESC, goal_contributions DESC;
