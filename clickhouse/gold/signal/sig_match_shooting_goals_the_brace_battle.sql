INSERT INTO gold.sig_match_shooting_goals_the_brace_battle (
    match_id,
    match_date,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,
    triggered_side,
    triggered_team_id,
    triggered_team_name,
    opponent_team_id,
    opponent_team_name,
    trigger_threshold_min_goals_per_brace_scorer,
    trigger_threshold_min_brace_scorers_per_team,
    match_total_brace_scorers,
    match_total_goals_by_brace_scorers,
    home_brace_scorers_count,
    away_brace_scorers_count,
    triggered_team_brace_scorers_count,
    opponent_brace_scorers_count,
    brace_scorers_count_delta,
    triggered_team_goals_by_brace_scorers,
    opponent_goals_by_brace_scorers,
    goals_by_brace_scorers_delta,
    triggered_team_top_brace_scorer_player_id,
    triggered_team_top_brace_scorer_player_name,
    triggered_team_top_brace_scorer_goals,
    opponent_top_brace_scorer_player_id,
    opponent_top_brace_scorer_player_name,
    opponent_top_brace_scorer_goals,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    shot_volume_delta,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    shot_on_target_delta,
    triggered_team_shot_accuracy_pct,
    opponent_shot_accuracy_pct,
    shot_accuracy_delta_pct,
    triggered_team_shot_conversion_pct,
    opponent_shot_conversion_pct,
    shot_conversion_delta_pct,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_big_chances,
    opponent_big_chances,
    big_chance_delta,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    opposition_box_touch_delta,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct
)
-- Signal: sig_match_shooting_goals_the_brace_battle
-- Intent: detect finished matches where both teams have a brace scorer and emit
--         side-oriented bilateral finishing and control context.
-- Trigger: at least one home player and one away player each score >= 2 non-own goals.
WITH scorer_goal_rollup AS (
    SELECT
        s.match_id,
        toInt32(s.team_id) AS team_id,
        toInt32(s.player_id) AS player_id,
        argMax(coalesce(s.player_name, 'Unknown'), coalesce(s.shot_id, 0)) AS player_name,
        toInt32(count()) AS player_goals,
        toFloat32(round(sum(coalesce(s.expected_goals, 0.0)), 3)) AS player_goals_xg
    FROM silver.shot AS s
    WHERE s.match_id > 0
      AND coalesce(s.team_id, 0) > 0
      AND coalesce(s.player_id, 0) > 0
      AND coalesce(s.is_goal, 0) = 1
      AND coalesce(s.is_own_goal, 0) = 0
    GROUP BY
        s.match_id,
        toInt32(s.team_id),
        toInt32(s.player_id)
),
brace_scorers AS (
    SELECT
        sgr.match_id,
        sgr.team_id,
        sgr.player_id,
        sgr.player_name,
        sgr.player_goals,
        sgr.player_goals_xg
    FROM scorer_goal_rollup AS sgr
    WHERE sgr.player_goals >= 2
),
team_brace_rollup AS (
    SELECT
        match_id,
        team_id,
        toInt32(count()) AS team_brace_scorers_count,
        toInt32(sum(player_goals)) AS team_goals_by_brace_scorers,
        toInt32(argMax(player_id, tuple(player_goals, player_goals_xg, -player_id)))
            AS top_brace_scorer_player_id,
        argMax(player_name, tuple(player_goals, player_goals_xg, -player_id))
            AS top_brace_scorer_player_name,
        toInt32(max(player_goals)) AS top_brace_scorer_goals
    FROM brace_scorers AS bs
    GROUP BY
        match_id,
        team_id
),
base_stats AS (
    SELECT
        m.match_id,
        m.match_date,
        m.home_team_id,
        m.home_team_name,
        m.away_team_id,
        m.away_team_name,
        m.home_score,
        m.away_score,

        toInt32(coalesce(m.home_score, 0)) AS home_goals,
        toInt32(coalesce(m.away_score, 0)) AS away_goals,

        toInt32(coalesce(home_brace.team_brace_scorers_count, 0)) AS home_brace_scorers_count,
        toInt32(coalesce(away_brace.team_brace_scorers_count, 0)) AS away_brace_scorers_count,
        toInt32(coalesce(home_brace.team_goals_by_brace_scorers, 0)) AS home_goals_by_brace_scorers,
        toInt32(coalesce(away_brace.team_goals_by_brace_scorers, 0)) AS away_goals_by_brace_scorers,
        toInt32(coalesce(home_brace.top_brace_scorer_player_id, 0)) AS home_top_brace_scorer_player_id,
        coalesce(home_brace.top_brace_scorer_player_name, 'Unknown') AS home_top_brace_scorer_player_name,
        toInt32(coalesce(home_brace.top_brace_scorer_goals, 0)) AS home_top_brace_scorer_goals,
        toInt32(coalesce(away_brace.top_brace_scorer_player_id, 0)) AS away_top_brace_scorer_player_id,
        coalesce(away_brace.top_brace_scorer_player_name, 'Unknown') AS away_top_brace_scorer_player_name,
        toInt32(coalesce(away_brace.top_brace_scorer_goals, 0)) AS away_top_brace_scorer_goals,

        toInt32(coalesce(ps.total_shots_home, 0)) AS total_shots_home,
        toInt32(coalesce(ps.total_shots_away, 0)) AS total_shots_away,
        toInt32(coalesce(ps.shots_on_target_home, 0)) AS shots_on_target_home,
        toInt32(coalesce(ps.shots_on_target_away, 0)) AS shots_on_target_away,
        toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS expected_goals_home,
        toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS expected_goals_away,
        toInt32(coalesce(ps.big_chances_home, 0)) AS big_chances_home,
        toInt32(coalesce(ps.big_chances_away, 0)) AS big_chances_away,
        toInt32(coalesce(ps.touches_opp_box_home, 0)) AS touches_opposition_box_home,
        toInt32(coalesce(ps.touches_opp_box_away, 0)) AS touches_opposition_box_away,
        toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS possession_home_pct,
        toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS possession_away_pct,
        toInt32(coalesce(ps.pass_attempts_home, 0)) AS pass_attempts_home,
        toInt32(coalesce(ps.pass_attempts_away, 0)) AS pass_attempts_away,
        toInt32(coalesce(ps.accurate_passes_home, 0)) AS accurate_passes_home,
        toInt32(coalesce(ps.accurate_passes_away, 0)) AS accurate_passes_away,

        toInt32(coalesce(home_brace.team_brace_scorers_count, 0) + coalesce(away_brace.team_brace_scorers_count, 0))
            AS match_total_brace_scorers,
        toInt32(coalesce(home_brace.team_goals_by_brace_scorers, 0) + coalesce(away_brace.team_goals_by_brace_scorers, 0))
            AS match_total_goals_by_brace_scorers
    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.match_date = m.match_date
       AND ps.period = 'All'
    LEFT JOIN team_brace_rollup AS home_brace
        ON home_brace.match_id = m.match_id
       AND home_brace.team_id = m.home_team_id
    LEFT JOIN team_brace_rollup AS away_brace
        ON away_brace.match_id = m.match_id
       AND away_brace.team_id = m.away_team_id
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND coalesce(home_brace.team_brace_scorers_count, 0) >= 1
      AND coalesce(away_brace.team_brace_scorers_count, 0) >= 1
      AND coalesce(home_brace.top_brace_scorer_player_id, 0) > 0
      AND coalesce(away_brace.top_brace_scorer_player_id, 0) > 0
      AND coalesce(home_brace.top_brace_scorer_player_id, 0)
          != coalesce(away_brace.top_brace_scorer_player_id, 0)
)

SELECT
    match_id,
    match_date,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,
    'home' AS triggered_side,
    home_team_id AS triggered_team_id,
    home_team_name AS triggered_team_name,
    away_team_id AS opponent_team_id,
    away_team_name AS opponent_team_name,
    toInt32(2) AS trigger_threshold_min_goals_per_brace_scorer,
    toInt32(1) AS trigger_threshold_min_brace_scorers_per_team,
    match_total_brace_scorers,
    match_total_goals_by_brace_scorers,
    home_brace_scorers_count,
    away_brace_scorers_count,
    home_brace_scorers_count AS triggered_team_brace_scorers_count,
    away_brace_scorers_count AS opponent_brace_scorers_count,
    home_brace_scorers_count - away_brace_scorers_count AS brace_scorers_count_delta,
    home_goals_by_brace_scorers AS triggered_team_goals_by_brace_scorers,
    away_goals_by_brace_scorers AS opponent_goals_by_brace_scorers,
    home_goals_by_brace_scorers - away_goals_by_brace_scorers AS goals_by_brace_scorers_delta,
    home_top_brace_scorer_player_id AS triggered_team_top_brace_scorer_player_id,
    home_top_brace_scorer_player_name AS triggered_team_top_brace_scorer_player_name,
    home_top_brace_scorer_goals AS triggered_team_top_brace_scorer_goals,
    away_top_brace_scorer_player_id AS opponent_top_brace_scorer_player_id,
    away_top_brace_scorer_player_name AS opponent_top_brace_scorer_player_name,
    away_top_brace_scorer_goals AS opponent_top_brace_scorer_goals,
    home_goals AS triggered_team_goals,
    away_goals AS opponent_goals,
    home_goals - away_goals AS goal_delta,
    total_shots_home AS triggered_team_total_shots,
    total_shots_away AS opponent_total_shots,
    total_shots_home - total_shots_away AS shot_volume_delta,
    shots_on_target_home AS triggered_team_shots_on_target,
    shots_on_target_away AS opponent_shots_on_target,
    shots_on_target_home - shots_on_target_away AS shot_on_target_delta,
    toFloat32(coalesce(round(
        100.0 * shots_on_target_home / nullIf(toFloat64(total_shots_home), 0),
        1
    ), 0.0)) AS triggered_team_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * shots_on_target_away / nullIf(toFloat64(total_shots_away), 0),
        1
    ), 0.0)) AS opponent_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * shots_on_target_home / nullIf(toFloat64(total_shots_home), 0), 1), 0.0)
      - coalesce(round(100.0 * shots_on_target_away / nullIf(toFloat64(total_shots_away), 0), 1), 0.0),
        1
    )) AS shot_accuracy_delta_pct,
    toFloat32(coalesce(round(
        100.0 * home_goals / nullIf(toFloat64(total_shots_home), 0),
        1
    ), 0.0)) AS triggered_team_shot_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * away_goals / nullIf(toFloat64(total_shots_away), 0),
        1
    ), 0.0)) AS opponent_shot_conversion_pct,
    toFloat32(round(
        coalesce(round(100.0 * home_goals / nullIf(toFloat64(total_shots_home), 0), 1), 0.0)
      - coalesce(round(100.0 * away_goals / nullIf(toFloat64(total_shots_away), 0), 1), 0.0),
        1
    )) AS shot_conversion_delta_pct,
    expected_goals_home AS triggered_team_xg,
    expected_goals_away AS opponent_xg,
    toFloat32(round(expected_goals_home - expected_goals_away, 3)) AS xg_delta,
    big_chances_home AS triggered_team_big_chances,
    big_chances_away AS opponent_big_chances,
    big_chances_home - big_chances_away AS big_chance_delta,
    touches_opposition_box_home AS triggered_team_touches_opposition_box,
    touches_opposition_box_away AS opponent_touches_opposition_box,
    touches_opposition_box_home - touches_opposition_box_away AS opposition_box_touch_delta,
    possession_home_pct AS triggered_team_possession_pct,
    possession_away_pct AS opponent_possession_pct,
    toFloat32(round(possession_home_pct - possession_away_pct, 1)) AS possession_delta_pct,
    toFloat32(coalesce(round(
        100.0 * accurate_passes_home / nullIf(toFloat64(pass_attempts_home), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * accurate_passes_away / nullIf(toFloat64(pass_attempts_away), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * accurate_passes_home / nullIf(toFloat64(pass_attempts_home), 0), 1), 0.0)
      - coalesce(round(100.0 * accurate_passes_away / nullIf(toFloat64(pass_attempts_away), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct
FROM base_stats

UNION ALL

SELECT
    match_id,
    match_date,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,
    'away' AS triggered_side,
    away_team_id AS triggered_team_id,
    away_team_name AS triggered_team_name,
    home_team_id AS opponent_team_id,
    home_team_name AS opponent_team_name,
    toInt32(2) AS trigger_threshold_min_goals_per_brace_scorer,
    toInt32(1) AS trigger_threshold_min_brace_scorers_per_team,
    match_total_brace_scorers,
    match_total_goals_by_brace_scorers,
    home_brace_scorers_count,
    away_brace_scorers_count,
    away_brace_scorers_count AS triggered_team_brace_scorers_count,
    home_brace_scorers_count AS opponent_brace_scorers_count,
    away_brace_scorers_count - home_brace_scorers_count AS brace_scorers_count_delta,
    away_goals_by_brace_scorers AS triggered_team_goals_by_brace_scorers,
    home_goals_by_brace_scorers AS opponent_goals_by_brace_scorers,
    away_goals_by_brace_scorers - home_goals_by_brace_scorers AS goals_by_brace_scorers_delta,
    away_top_brace_scorer_player_id AS triggered_team_top_brace_scorer_player_id,
    away_top_brace_scorer_player_name AS triggered_team_top_brace_scorer_player_name,
    away_top_brace_scorer_goals AS triggered_team_top_brace_scorer_goals,
    home_top_brace_scorer_player_id AS opponent_top_brace_scorer_player_id,
    home_top_brace_scorer_player_name AS opponent_top_brace_scorer_player_name,
    home_top_brace_scorer_goals AS opponent_top_brace_scorer_goals,
    away_goals AS triggered_team_goals,
    home_goals AS opponent_goals,
    away_goals - home_goals AS goal_delta,
    total_shots_away AS triggered_team_total_shots,
    total_shots_home AS opponent_total_shots,
    total_shots_away - total_shots_home AS shot_volume_delta,
    shots_on_target_away AS triggered_team_shots_on_target,
    shots_on_target_home AS opponent_shots_on_target,
    shots_on_target_away - shots_on_target_home AS shot_on_target_delta,
    toFloat32(coalesce(round(
        100.0 * shots_on_target_away / nullIf(toFloat64(total_shots_away), 0),
        1
    ), 0.0)) AS triggered_team_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * shots_on_target_home / nullIf(toFloat64(total_shots_home), 0),
        1
    ), 0.0)) AS opponent_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * shots_on_target_away / nullIf(toFloat64(total_shots_away), 0), 1), 0.0)
      - coalesce(round(100.0 * shots_on_target_home / nullIf(toFloat64(total_shots_home), 0), 1), 0.0),
        1
    )) AS shot_accuracy_delta_pct,
    toFloat32(coalesce(round(
        100.0 * away_goals / nullIf(toFloat64(total_shots_away), 0),
        1
    ), 0.0)) AS triggered_team_shot_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * home_goals / nullIf(toFloat64(total_shots_home), 0),
        1
    ), 0.0)) AS opponent_shot_conversion_pct,
    toFloat32(round(
        coalesce(round(100.0 * away_goals / nullIf(toFloat64(total_shots_away), 0), 1), 0.0)
      - coalesce(round(100.0 * home_goals / nullIf(toFloat64(total_shots_home), 0), 1), 0.0),
        1
    )) AS shot_conversion_delta_pct,
    expected_goals_away AS triggered_team_xg,
    expected_goals_home AS opponent_xg,
    toFloat32(round(expected_goals_away - expected_goals_home, 3)) AS xg_delta,
    big_chances_away AS triggered_team_big_chances,
    big_chances_home AS opponent_big_chances,
    big_chances_away - big_chances_home AS big_chance_delta,
    touches_opposition_box_away AS triggered_team_touches_opposition_box,
    touches_opposition_box_home AS opponent_touches_opposition_box,
    touches_opposition_box_away - touches_opposition_box_home AS opposition_box_touch_delta,
    possession_away_pct AS triggered_team_possession_pct,
    possession_home_pct AS opponent_possession_pct,
    toFloat32(round(possession_away_pct - possession_home_pct, 1)) AS possession_delta_pct,
    toFloat32(coalesce(round(
        100.0 * accurate_passes_away / nullIf(toFloat64(pass_attempts_away), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * accurate_passes_home / nullIf(toFloat64(pass_attempts_home), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * accurate_passes_away / nullIf(toFloat64(pass_attempts_away), 0), 1), 0.0)
      - coalesce(round(100.0 * accurate_passes_home / nullIf(toFloat64(pass_attempts_home), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct
FROM base_stats;
