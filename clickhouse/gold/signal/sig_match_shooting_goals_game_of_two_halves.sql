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
        coalesce(m.home_score, 0) AS home_goals,
        coalesce(m.away_score, 0) AS away_goals,
        g.home_first_half_goals,
        g.away_first_half_goals,
        g.home_second_half_goals,
        g.away_second_half_goals,
        g.home_first_half_goals + g.away_first_half_goals AS match_total_first_half_goals,
        g.home_second_half_goals + g.away_second_half_goals AS match_total_second_half_goals,
        g.home_first_half_goals + g.away_first_half_goals
            + g.home_second_half_goals + g.away_second_half_goals AS match_total_goals,
        coalesce(ps.total_shots_home, 0) AS total_shots_home,
        coalesce(ps.total_shots_away, 0) AS total_shots_away,
        coalesce(ps.shots_on_target_home, 0) AS shots_on_target_home,
        coalesce(ps.shots_on_target_away, 0) AS shots_on_target_away,
        toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS expected_goals_home,
        toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS expected_goals_away,
        coalesce(ps.big_chances_home, 0) AS big_chances_home,
        coalesce(ps.big_chances_away, 0) AS big_chances_away,
        coalesce(ps.big_chances_missed_home, 0) AS big_chances_missed_home,
        coalesce(ps.big_chances_missed_away, 0) AS big_chances_missed_away,
        coalesce(ps.touches_opp_box_home, 0) AS touches_opposition_box_home,
        coalesce(ps.touches_opp_box_away, 0) AS touches_opposition_box_away,
        toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS possession_home_pct,
        toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS possession_away_pct,
        coalesce(ps.accurate_passes_home, 0) AS accurate_passes_home,
        coalesce(ps.accurate_passes_away, 0) AS accurate_passes_away,
        coalesce(ps.pass_attempts_home, 0) AS pass_attempts_home,
        coalesce(ps.pass_attempts_away, 0) AS pass_attempts_away
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
    toInt32(0) AS trigger_threshold_max_first_half_goals,
    toInt32(4) AS trigger_threshold_min_second_half_goals,
    home_first_half_goals,
    away_first_half_goals,
    home_second_half_goals,
    away_second_half_goals,
    match_total_first_half_goals,
    match_total_second_half_goals,
    match_total_goals,
    match_total_second_half_goals - match_total_first_half_goals AS half_goal_intensity_delta,
    match_total_second_half_goals - 4 AS second_half_goals_above_threshold,
    home_first_half_goals AS triggered_team_first_half_goals,
    away_first_half_goals AS opponent_first_half_goals,
    home_second_half_goals AS triggered_team_second_half_goals,
    away_second_half_goals AS opponent_second_half_goals,
    toFloat32(coalesce(round(
        100.0 * home_second_half_goals / nullIf(toFloat64(match_total_second_half_goals), 0),
        1
    ), 0.0)) AS triggered_team_second_half_goal_share_pct,
    toFloat32(coalesce(round(
        100.0 * away_second_half_goals / nullIf(toFloat64(match_total_second_half_goals), 0),
        1
    ), 0.0)) AS opponent_second_half_goal_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * home_second_half_goals / nullIf(toFloat64(match_total_second_half_goals), 0),
            1
        ), 0.0)
        - coalesce(round(
            100.0 * away_second_half_goals / nullIf(toFloat64(match_total_second_half_goals), 0),
            1
        ), 0.0),
        1
    )) AS second_half_goal_share_delta_pct,
    total_shots_home AS triggered_team_total_shots,
    total_shots_away AS opponent_total_shots,
    total_shots_home - total_shots_away AS total_shots_delta,
    shots_on_target_home AS triggered_team_shots_on_target,
    shots_on_target_away AS opponent_shots_on_target,
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
    expected_goals_home AS triggered_team_xg,
    expected_goals_away AS opponent_xg,
    toFloat32(round(expected_goals_home - expected_goals_away, 3)) AS xg_delta,
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
    big_chances_home AS triggered_team_big_chances,
    big_chances_away AS opponent_big_chances,
    big_chances_missed_home AS triggered_team_big_chances_missed,
    big_chances_missed_away AS opponent_big_chances_missed,
    touches_opposition_box_home AS triggered_team_touches_opposition_box,
    touches_opposition_box_away AS opponent_touches_opposition_box,
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
FROM base_stats AS bs

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
    toInt32(0) AS trigger_threshold_max_first_half_goals,
    toInt32(4) AS trigger_threshold_min_second_half_goals,
    home_first_half_goals,
    away_first_half_goals,
    home_second_half_goals,
    away_second_half_goals,
    match_total_first_half_goals,
    match_total_second_half_goals,
    match_total_goals,
    match_total_second_half_goals - match_total_first_half_goals AS half_goal_intensity_delta,
    match_total_second_half_goals - 4 AS second_half_goals_above_threshold,
    away_first_half_goals AS triggered_team_first_half_goals,
    home_first_half_goals AS opponent_first_half_goals,
    away_second_half_goals AS triggered_team_second_half_goals,
    home_second_half_goals AS opponent_second_half_goals,
    toFloat32(coalesce(round(
        100.0 * away_second_half_goals / nullIf(toFloat64(match_total_second_half_goals), 0),
        1
    ), 0.0)) AS triggered_team_second_half_goal_share_pct,
    toFloat32(coalesce(round(
        100.0 * home_second_half_goals / nullIf(toFloat64(match_total_second_half_goals), 0),
        1
    ), 0.0)) AS opponent_second_half_goal_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * away_second_half_goals / nullIf(toFloat64(match_total_second_half_goals), 0),
            1
        ), 0.0)
        - coalesce(round(
            100.0 * home_second_half_goals / nullIf(toFloat64(match_total_second_half_goals), 0),
            1
        ), 0.0),
        1
    )) AS second_half_goal_share_delta_pct,
    total_shots_away AS triggered_team_total_shots,
    total_shots_home AS opponent_total_shots,
    total_shots_away - total_shots_home AS total_shots_delta,
    shots_on_target_away AS triggered_team_shots_on_target,
    shots_on_target_home AS opponent_shots_on_target,
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
    expected_goals_away AS triggered_team_xg,
    expected_goals_home AS opponent_xg,
    toFloat32(round(expected_goals_away - expected_goals_home, 3)) AS xg_delta,
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
    big_chances_away AS triggered_team_big_chances,
    big_chances_home AS opponent_big_chances,
    big_chances_missed_away AS triggered_team_big_chances_missed,
    big_chances_missed_home AS opponent_big_chances_missed,
    touches_opposition_box_away AS triggered_team_touches_opposition_box,
    touches_opposition_box_home AS opponent_touches_opposition_box,
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
FROM base_stats

ORDER BY
    match_total_second_half_goals DESC,
    match_date DESC,
    match_id DESC,
    triggered_side;
