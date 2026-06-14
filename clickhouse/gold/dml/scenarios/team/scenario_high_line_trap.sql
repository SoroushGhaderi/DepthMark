-- scenario_high_line_trap: teams repeatedly catching opponents offside while suppressing threat and final-third access
INSERT INTO gold_scenarios.scenario_high_line_trap
(
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    league_name,
    match_time_utc_date,
    trapping_team_side,
    trapping_team_name,
    opponent_name,
    opponent_offsides_caught,
    opponent_xg,
    opponent_total_shots,
    opponent_shots_on_target,
    opponent_big_chances,
    opponent_xg_per_shot,
    opponent_final_third_passes,
    team_possession,
    team_passes,
    team_xg,
    team_total_shots
)
WITH period_all_cte AS (
    SELECT
        match_id,
        coalesce(offsides_home, 0) AS offsides_home,
        coalesce(offsides_away, 0) AS offsides_away,
        coalesce(expected_goals_home, 0) AS xg_home,
        coalesce(expected_goals_away, 0) AS xg_away,
        coalesce(opposition_half_passes_home, 0) AS opp_half_passes_home,
        coalesce(opposition_half_passes_away, 0) AS opp_half_passes_away,
        coalesce(total_shots_home, 0) AS total_shots_home,
        coalesce(total_shots_away, 0) AS total_shots_away,
        coalesce(big_chances_home, 0) AS big_chances_home,
        coalesce(big_chances_away, 0) AS big_chances_away,
        coalesce(ball_possession_home, 0) AS possession_home,
        coalesce(ball_possession_away, 0) AS possession_away,
        coalesce(passes_home, 0) AS passes_home,
        coalesce(passes_away, 0) AS passes_away,
        coalesce(shots_on_target_home, 0) AS shots_on_target_home,
        coalesce(shots_on_target_away, 0) AS shots_on_target_away
    FROM silver.period_stat
    FINAL
    WHERE period = 'All'
),
team_performances_cte AS (
    SELECT
        p.match_id,
        g.home_team_id,
        g.away_team_id,
        g.home_team_name,
        g.away_team_name,
        g.home_score,
        g.away_score,
        g.league_name,
        toString(g.match_date) AS match_time_utc_date,
        'home' AS trapping_team_side,
        g.home_team_name AS trapping_team_name,
        g.away_team_name AS opponent_name,
        p.offsides_away AS opponent_offsides_caught,
        p.xg_away AS opponent_xg,
        p.total_shots_away AS opponent_total_shots,
        p.shots_on_target_away AS opponent_shots_on_target,
        p.big_chances_away AS opponent_big_chances,
        p.opp_half_passes_away AS opponent_final_third_passes,
        p.possession_home AS team_possession,
        p.passes_home AS team_passes,
        p.xg_home AS team_xg,
        p.total_shots_home AS team_total_shots
    FROM period_all_cte AS p
    INNER JOIN silver.match AS g
        FINAL ON p.match_id = g.match_id
    WHERE g.match_finished = 1

    UNION ALL

    SELECT
        p.match_id,
        g.home_team_id,
        g.away_team_id,
        g.home_team_name,
        g.away_team_name,
        g.home_score,
        g.away_score,
        g.league_name,
        toString(g.match_date) AS match_time_utc_date,
        'away' AS trapping_team_side,
        g.away_team_name AS trapping_team_name,
        g.home_team_name AS opponent_name,
        p.offsides_home AS opponent_offsides_caught,
        p.xg_home AS opponent_xg,
        p.total_shots_home AS opponent_total_shots,
        p.shots_on_target_home AS opponent_shots_on_target,
        p.big_chances_home AS opponent_big_chances,
        p.opp_half_passes_home AS opponent_final_third_passes,
        p.possession_away AS team_possession,
        p.passes_away AS team_passes,
        p.xg_away AS team_xg,
        p.total_shots_away AS team_total_shots
    FROM period_all_cte AS p
    INNER JOIN silver.match AS g
        FINAL ON p.match_id = g.match_id
    WHERE g.match_finished = 1
)
SELECT
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    league_name,
    match_time_utc_date,
    trapping_team_side,
    trapping_team_name,
    opponent_name,
    opponent_offsides_caught,
    opponent_xg,
    opponent_total_shots,
    opponent_shots_on_target,
    opponent_big_chances,
    round(opponent_xg / nullIf(opponent_total_shots, 0), 3) AS opponent_xg_per_shot,
    opponent_final_third_passes,
    team_possession,
    team_passes,
    team_xg,
    team_total_shots
FROM team_performances_cte
WHERE
    opponent_offsides_caught >= 6
    AND opponent_xg < 0.8
    AND opponent_final_third_passes < 75
ORDER BY
    opponent_offsides_caught DESC,
    opponent_xg ASC,
    opponent_final_third_passes ASC;
