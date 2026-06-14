-- scenario_black_hole: high-volume, low-quality shooters who dominate team shot share without scoring
INSERT INTO gold_scenarios.scenario_black_hole
(
    match_id,
    player_id,
    player_name,
    team_name,
    team_id,
    minutes_played,
    total_shots,
    shots_on_target,
    goals,
    total_xg,
    avg_xg_per_shot,
    team_total_shots,
    shot_share_pct,
    league_name,
    match_time_utc_date,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score
)
WITH team_shots_cte AS (
    SELECT
        match_id,
        team_id,
        sum(coalesce(total_shots, 0)) AS team_total_shots
    FROM silver.player_match_stat
    FINAL
    WHERE is_goalkeeper = 0
    GROUP BY
        match_id,
        team_id
)
SELECT
    p.match_id,
    p.player_id,
    p.player_name,
    p.team_name,
    p.team_id,
    p.minutes_played,
    p.total_shots,
    p.shots_on_target,
    p.goals,
    p.expected_goals AS total_xg,
    round(
        coalesce(
            p.average_xg_per_shot,
            p.expected_goals / nullIf(p.total_shots, 0)
        ),
        4
    ) AS avg_xg_per_shot,
    ts.team_total_shots,
    round(p.total_shots / nullIf(ts.team_total_shots, 0) * 100, 1) AS shot_share_pct,
    g.league_name,
    toString(g.match_date),
    g.home_team_id,
    g.away_team_id,
    g.home_team_name,
    g.away_team_name,
    g.home_score,
    g.away_score
FROM silver.player_match_stat AS p
FINAL
INNER JOIN silver.match AS g
    FINAL ON p.match_id = g.match_id
INNER JOIN team_shots_cte AS ts
    ON p.match_id = ts.match_id
    AND p.team_id = ts.team_id
WHERE
    g.match_finished = 1
    AND p.is_goalkeeper = 0
    AND coalesce(p.total_shots, 0) >= 6
    AND coalesce(
        p.average_xg_per_shot,
        p.expected_goals / nullIf(p.total_shots, 0)
    ) < 0.08
    AND coalesce(p.goals, 0) = 0
    AND (p.total_shots / nullIf(ts.team_total_shots, 0)) >= 0.40
ORDER BY
    shot_share_pct DESC,
    p.total_shots DESC,
    avg_xg_per_shot ASC;
