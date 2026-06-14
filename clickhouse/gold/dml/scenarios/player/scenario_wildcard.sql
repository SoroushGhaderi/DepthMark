-- scenario_wildcard: substitutes with immediate attacking impact
INSERT INTO gold_scenarios.scenario_wildcard
(
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    player_id,
    player_name,
    team_side,
    substitution_time,
    substitution_reason,
    goals,
    assists,
    goal_contributions,
    xg,
    xa,
    minutes_played,
    fotmob_rating,
    match_result,
    match_time_utc_date
)
SELECT
    g.match_id,
    g.home_team_id,
    g.away_team_id,
    g.home_team_name,
    g.away_team_name,
    g.home_score,
    g.away_score,
    sub.person_id,
    sub.name AS player_name,
    sub.team_side,
    sub.substitution_time,
    sub.substitution_reason,
    p.goals,
    p.assists,
    p.goals + p.assists AS goal_contributions,
    round(p.expected_goals, 3) AS xg,
    round(p.expected_assists, 3) AS xa,
    p.minutes_played,
    p.fotmob_rating,
    CASE
        WHEN g.home_score > g.away_score THEN 'Home Win'
        WHEN g.away_score > g.home_score THEN 'Away Win'
        ELSE 'Draw'
    END AS match_result,
    toString(g.match_date)
FROM silver.match_personnel AS sub
INNER JOIN silver.match AS g
    ON sub.match_id = g.match_id
INNER JOIN silver.player_match_stat AS p
    ON sub.match_id = p.match_id
    AND sub.person_id = p.player_id
WHERE
    g.match_finished = 1
    AND sub.role = 'substitute'
    AND sub.substitution_time IS NOT NULL
    AND (
        p.goals >= 1
        OR p.assists >= 1
    )
ORDER BY goal_contributions DESC, sub.substitution_time DESC;
