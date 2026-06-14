-- scenario_golden_touch: late-substitute low-touch contributions ranked by impact efficiency
INSERT INTO gold_scenarios.scenario_golden_touch
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
    team_id,
    team_name,
    team_side,
    substitution_time,
    substitution_reason,
    touches,
    goals,
    assists,
    goal_contributions,
    minutes_played,
    xg,
    xa,
    xg_xa,
    contribution_per_touch,
    minutes_available,
    total_shots,
    shots_on_target,
    xg_per_shot,
    fotmob_rating,
    match_result,
    match_time_utc_date
)
WITH late_subs AS (
    SELECT
        match_id,
        person_id,
        team_side,
        substitution_time,
        substitution_reason
    FROM silver.match_personnel
    WHERE
        role = 'substitute'
        AND
        substitution_time >= 70
        AND substitution_time IS NOT NULL
)

SELECT
    g.match_id,
    g.home_team_id,
    g.away_team_id,
    g.home_team_name,
    g.away_team_name,
    g.home_score,
    g.away_score,
    ls.person_id,
    p.player_name,
    p.team_id,
    p.team_name,
    ls.team_side,
    ls.substitution_time,
    ls.substitution_reason,
    p.touches,
    p.goals,
    p.assists,
    p.goals + p.assists                         AS goal_contributions,
    p.minutes_played,
    p.expected_goals                            AS xg,
    p.expected_assists                          AS xa,
    round(p.expected_goals
        + p.expected_assists, 3)                AS xg_xa,
    round(
        (p.goals + p.assists)
        / nullIf(p.touches, 0)
    , 3)                                        AS contribution_per_touch,
    90 - ls.substitution_time                   AS minutes_available,
    p.total_shots,
    p.shots_on_target,
    round(p.expected_goals
        / nullIf(p.total_shots, 0), 3)          AS xg_per_shot,
    p.fotmob_rating,

    CASE
        WHEN g.home_score > g.away_score THEN 'Home Win'
        WHEN g.away_score > g.home_score THEN 'Away Win'
        ELSE 'Draw'
    END AS match_result,
    toString(g.match_date)

FROM silver.match AS g
INNER JOIN late_subs AS ls
    ON g.match_id = ls.match_id
INNER JOIN silver.player_match_stat AS p
    ON g.match_id = p.match_id
    AND ls.person_id = p.player_id
WHERE
    g.match_finished = 1
    AND p.touches <= 12
    AND (p.goals >= 1 OR p.assists >= 1)
    AND p.touches > 0
    AND p.minutes_played > 0
ORDER BY
    contribution_per_touch DESC,
    p.touches ASC,
    ls.substitution_time DESC;
