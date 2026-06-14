INSERT INTO gold.sig_match_shooting_goals_game_of_two_halves (
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
    trigger_threshold_max_first_half_goals,
    trigger_threshold_min_second_half_goals,
    home_first_half_goals,
    away_first_half_goals,
    home_second_half_goals,
    away_second_half_goals,
    match_total_first_half_goals,
    match_total_second_half_goals,
    match_total_goals,
    half_goal_intensity_delta,
    second_half_goals_above_threshold,
    triggered_team_first_half_goals,
    opponent_first_half_goals,
    triggered_team_second_half_goals,
    opponent_second_half_goals,
    triggered_team_second_half_goal_share_pct,
    opponent_second_half_goal_share_pct,
    second_half_goal_share_delta_pct,
    triggered_team_total_shots,
    opponent_total_shots,
    total_shots_delta,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    triggered_team_shot_accuracy_pct,
    opponent_shot_accuracy_pct,
    shot_accuracy_delta_pct,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_shot_conversion_pct,
    opponent_shot_conversion_pct,
    shot_conversion_delta_pct,
    triggered_team_big_chances,
    opponent_big_chances,
    triggered_team_big_chances_missed,
    opponent_big_chances_missed,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct
)
-- Signal: sig_match_shooting_goals_game_of_two_halves
-- Intent: detect matches that are goalless in the first half but explode into a high-scoring
--         second half, then emit side-oriented goal-flow, shooting, and control diagnostics.
-- Trigger: match_total_first_half_goals = 0 and match_total_second_half_goals >= 4.
WITH goals_by_half AS (
    SELECT
        s.match_id,
        toInt32(countIf(
            coalesce(s.is_goal, 0) = 1
            AND coalesce(s.period, '') = 'FirstHalf'
            AND coalesce(s.is_home_goal, 0) = 1
        )) AS home_first_half_goals,
        toInt32(countIf(
            coalesce(s.is_goal, 0) = 1
            AND coalesce(s.period, '') = 'FirstHalf'
            AND coalesce(s.is_home_goal, 0) = 0
        )) AS away_first_half_goals,
        toInt32(countIf(
            coalesce(s.is_goal, 0) = 1
            AND coalesce(s.period, '') = 'SecondHalf'
            AND coalesce(s.is_home_goal, 0) = 1
        )) AS home_second_half_goals,
        toInt32(countIf(
            coalesce(s.is_goal, 0) = 1
            AND coalesce(s.period, '') = 'SecondHalf'
            AND coalesce(s.is_home_goal, 0) = 0
        )) AS away_second_half_goals
    FROM silver.shot AS s
    WHERE s.match_id > 0
      AND coalesce(s.is_goal, 0) = 1
      AND coalesce(s.period, '') IN ('FirstHalf', 'SecondHalf')
    GROUP BY s.match_id
)

SELECT
    m.match_id AS match_id,
    m.match_date AS match_date,
    m.home_team_id AS home_team_id,
    m.home_team_name AS home_team_name,
    m.away_team_id AS away_team_id,
    m.away_team_name AS away_team_name,
    m.home_score AS home_score,
    m.away_score AS away_score,
    'home' AS triggered_side,
    m.home_team_id AS triggered_team_id,
    m.home_team_name AS triggered_team_name,
    m.away_team_id AS opponent_team_id,
    m.away_team_name AS opponent_team_name,
    toInt32(0) AS trigger_threshold_max_first_half_goals,
    toInt32(4) AS trigger_threshold_min_second_half_goals,
    g.home_first_half_goals,
    g.away_first_half_goals,
    g.home_second_half_goals,
    g.away_second_half_goals,
    g.home_first_half_goals + g.away_first_half_goals AS match_total_first_half_goals,
    g.home_second_half_goals + g.away_second_half_goals AS match_total_second_half_goals,
    g.home_first_half_goals + g.away_first_half_goals
        + g.home_second_half_goals + g.away_second_half_goals AS match_total_goals,
    (g.home_second_half_goals + g.away_second_half_goals)
        - (g.home_first_half_goals + g.away_first_half_goals) AS half_goal_intensity_delta,
    (g.home_second_half_goals + g.away_second_half_goals) - 4 AS second_half_goals_above_threshold,
    g.home_first_half_goals AS triggered_team_first_half_goals,
    g.away_first_half_goals AS opponent_first_half_goals,
    g.home_second_half_goals AS triggered_team_second_half_goals,
    g.away_second_half_goals AS opponent_second_half_goals,
    toFloat32(coalesce(round(
        100.0 * g.home_second_half_goals / nullIf(toFloat64(g.home_second_half_goals + g.away_second_half_goals), 0),
        1
    ), 0.0)) AS triggered_team_second_half_goal_share_pct,
    toFloat32(coalesce(round(
        100.0 * g.away_second_half_goals / nullIf(toFloat64(g.home_second_half_goals + g.away_second_half_goals), 0),
        1
    ), 0.0)) AS opponent_second_half_goal_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * g.home_second_half_goals / nullIf(toFloat64(g.home_second_half_goals + g.away_second_half_goals), 0),
            1
        ), 0.0)
        - coalesce(round(
            100.0 * g.away_second_half_goals / nullIf(toFloat64(g.home_second_half_goals + g.away_second_half_goals), 0),
            1
        ), 0.0),
        1
    )) AS second_half_goal_share_delta_pct,
    coalesce(ps.total_shots_home, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_away, 0) AS opponent_total_shots,
    coalesce(ps.total_shots_home, 0) - coalesce(ps.total_shots_away, 0) AS total_shots_delta,
    coalesce(ps.shots_on_target_home, 0) AS triggered_team_shots_on_target,
    coalesce(ps.shots_on_target_away, 0) AS opponent_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_home, 0) / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_away, 0) / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        1
    ), 0.0)) AS opponent_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * coalesce(ps.shots_on_target_home, 0) / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0), 1), 0.0)
        - coalesce(round(100.0 * coalesce(ps.shots_on_target_away, 0) / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0), 1), 0.0),
        1
    )) AS shot_accuracy_delta_pct,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS opponent_xg,
    toFloat32(round(toFloat32(coalesce(ps.expected_goals_home, 0.0)) - toFloat32(coalesce(ps.expected_goals_away, 0.0)), 3)) AS xg_delta,
    toFloat32(coalesce(round(
        100.0 * coalesce(m.home_score, 0) / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_shot_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(m.away_score, 0) / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        1
    ), 0.0)) AS opponent_shot_conversion_pct,
    toFloat32(round(
        coalesce(round(100.0 * coalesce(m.home_score, 0) / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0), 1), 0.0)
        - coalesce(round(100.0 * coalesce(m.away_score, 0) / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0), 1), 0.0),
        1
    )) AS shot_conversion_delta_pct,
    coalesce(ps.big_chances_home, 0) AS triggered_team_big_chances,
    coalesce(ps.big_chances_away, 0) AS opponent_big_chances,
    coalesce(ps.big_chances_missed_home, 0) AS triggered_team_big_chances_missed,
    coalesce(ps.big_chances_missed_away, 0) AS opponent_big_chances_missed,
    coalesce(ps.touches_opp_box_home, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_away, 0) AS opponent_touches_opposition_box,
    toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS opponent_possession_pct,
    toFloat32(round(toFloat32(coalesce(ps.ball_possession_home, 0.0)) - toFloat32(coalesce(ps.ball_possession_away, 0.0)), 1)) AS possession_delta_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0), 1), 0.0)
        - coalesce(round(100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct
FROM silver.match AS m
INNER JOIN goals_by_half AS g
    ON g.match_id = m.match_id
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND g.home_first_half_goals + g.away_first_half_goals = 0
  AND g.home_second_half_goals + g.away_second_half_goals >= 4

UNION ALL

SELECT
    m.match_id AS match_id,
    m.match_date AS match_date,
    m.home_team_id AS home_team_id,
    m.home_team_name AS home_team_name,
    m.away_team_id AS away_team_id,
    m.away_team_name AS away_team_name,
    m.home_score AS home_score,
    m.away_score AS away_score,
    'away' AS triggered_side,
    m.away_team_id AS triggered_team_id,
    m.away_team_name AS triggered_team_name,
    m.home_team_id AS opponent_team_id,
    m.home_team_name AS opponent_team_name,
    toInt32(0) AS trigger_threshold_max_first_half_goals,
    toInt32(4) AS trigger_threshold_min_second_half_goals,
    g.home_first_half_goals,
    g.away_first_half_goals,
    g.home_second_half_goals,
    g.away_second_half_goals,
    g.home_first_half_goals + g.away_first_half_goals AS match_total_first_half_goals,
    g.home_second_half_goals + g.away_second_half_goals AS match_total_second_half_goals,
    g.home_first_half_goals + g.away_first_half_goals
        + g.home_second_half_goals + g.away_second_half_goals AS match_total_goals,
    (g.home_second_half_goals + g.away_second_half_goals)
        - (g.home_first_half_goals + g.away_first_half_goals) AS half_goal_intensity_delta,
    (g.home_second_half_goals + g.away_second_half_goals) - 4 AS second_half_goals_above_threshold,
    g.away_first_half_goals AS triggered_team_first_half_goals,
    g.home_first_half_goals AS opponent_first_half_goals,
    g.away_second_half_goals AS triggered_team_second_half_goals,
    g.home_second_half_goals AS opponent_second_half_goals,
    toFloat32(coalesce(round(
        100.0 * g.away_second_half_goals / nullIf(toFloat64(g.home_second_half_goals + g.away_second_half_goals), 0),
        1
    ), 0.0)) AS triggered_team_second_half_goal_share_pct,
    toFloat32(coalesce(round(
        100.0 * g.home_second_half_goals / nullIf(toFloat64(g.home_second_half_goals + g.away_second_half_goals), 0),
        1
    ), 0.0)) AS opponent_second_half_goal_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * g.away_second_half_goals / nullIf(toFloat64(g.home_second_half_goals + g.away_second_half_goals), 0),
            1
        ), 0.0)
        - coalesce(round(
            100.0 * g.home_second_half_goals / nullIf(toFloat64(g.home_second_half_goals + g.away_second_half_goals), 0),
            1
        ), 0.0),
        1
    )) AS second_half_goal_share_delta_pct,
    coalesce(ps.total_shots_away, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_home, 0) AS opponent_total_shots,
    coalesce(ps.total_shots_away, 0) - coalesce(ps.total_shots_home, 0) AS total_shots_delta,
    coalesce(ps.shots_on_target_away, 0) AS triggered_team_shots_on_target,
    coalesce(ps.shots_on_target_home, 0) AS opponent_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_away, 0) / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_home, 0) / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        1
    ), 0.0)) AS opponent_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * coalesce(ps.shots_on_target_away, 0) / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0), 1), 0.0)
        - coalesce(round(100.0 * coalesce(ps.shots_on_target_home, 0) / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0), 1), 0.0),
        1
    )) AS shot_accuracy_delta_pct,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS opponent_xg,
    toFloat32(round(toFloat32(coalesce(ps.expected_goals_away, 0.0)) - toFloat32(coalesce(ps.expected_goals_home, 0.0)), 3)) AS xg_delta,
    toFloat32(coalesce(round(
        100.0 * coalesce(m.away_score, 0) / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_shot_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(m.home_score, 0) / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        1
    ), 0.0)) AS opponent_shot_conversion_pct,
    toFloat32(round(
        coalesce(round(100.0 * coalesce(m.away_score, 0) / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0), 1), 0.0)
        - coalesce(round(100.0 * coalesce(m.home_score, 0) / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0), 1), 0.0),
        1
    )) AS shot_conversion_delta_pct,
    coalesce(ps.big_chances_away, 0) AS triggered_team_big_chances,
    coalesce(ps.big_chances_home, 0) AS opponent_big_chances,
    coalesce(ps.big_chances_missed_away, 0) AS triggered_team_big_chances_missed,
    coalesce(ps.big_chances_missed_home, 0) AS opponent_big_chances_missed,
    coalesce(ps.touches_opp_box_away, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_home, 0) AS opponent_touches_opposition_box,
    toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS opponent_possession_pct,
    toFloat32(round(toFloat32(coalesce(ps.ball_possession_away, 0.0)) - toFloat32(coalesce(ps.ball_possession_home, 0.0)), 1)) AS possession_delta_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0), 1), 0.0)
        - coalesce(round(100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct
FROM silver.match AS m
INNER JOIN goals_by_half AS g
    ON g.match_id = m.match_id
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND g.home_first_half_goals + g.away_first_half_goals = 0
  AND g.home_second_half_goals + g.away_second_half_goals >= 4

ORDER BY
    match_total_second_half_goals DESC,
    match_date DESC,
    match_id DESC,
    triggered_side;
