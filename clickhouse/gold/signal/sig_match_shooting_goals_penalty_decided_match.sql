INSERT INTO gold.sig_match_shooting_goals_penalty_decided_match (
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
    trigger_threshold_home_goals_max,
    trigger_threshold_away_goals_max,
    trigger_threshold_match_total_goals_max,
    trigger_threshold_all_goals_penalty_flag,
    is_one_nil_final_flag,
    is_one_one_final_flag,
    match_total_goals,
    match_total_penalty_goals,
    match_total_non_penalty_goals,
    match_goal_count_consistent_with_shots_flag,
    home_penalty_goals,
    away_penalty_goals,
    home_non_penalty_goals,
    away_non_penalty_goals,
    triggered_team_penalty_goals,
    opponent_penalty_goals,
    penalty_goals_delta,
    triggered_team_non_penalty_goals,
    opponent_non_penalty_goals,
    non_penalty_goals_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    shot_volume_delta,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    shot_on_target_delta,
    triggered_team_shot_accuracy_pct,
    opponent_shot_accuracy_pct,
    shot_accuracy_delta_pct,
    triggered_team_goals,
    opponent_goals,
    goal_gap,
    triggered_team_shot_conversion_pct,
    opponent_shot_conversion_pct,
    shot_conversion_delta_pct,
    match_total_xg,
    match_total_xg_non_penalty,
    match_total_penalty_xg_proxy,
    triggered_team_xg,
    opponent_xg,
    xg_gap,
    triggered_team_xg_non_penalty,
    opponent_xg_non_penalty,
    xg_non_penalty_gap,
    triggered_team_big_chances,
    opponent_big_chances,
    triggered_team_big_chances_missed,
    opponent_big_chances_missed,
    big_chances_missed_delta,
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
-- Signal: sig_match_shooting_goals_penalty_decided_match
-- Intent: detect low-score finished matches where every recorded goal is scored from
--         a penalty and emit side-oriented rows for bilateral shooting and control context.
-- Trigger: scoreline is 1-0, 0-1, or 1-1 and match_total_penalty_goals = match_total_goals.
WITH goal_events AS (
    SELECT
        s.match_id,
        toUInt8(coalesce(s.is_home_goal, 0)) AS is_home_goal_flag,
        toUInt8(
            positionCaseInsensitiveUTF8(coalesce(s.situation, ''), 'penalty') > 0
            OR positionCaseInsensitiveUTF8(coalesce(s.shot_type, ''), 'penalty') > 0
        ) AS is_penalty_goal
    FROM silver.shot AS s
    WHERE s.match_id > 0
      AND coalesce(s.is_goal, 0) = 1
),
goal_breakdown AS (
    SELECT
        ge.match_id,
        toInt32(count()) AS match_total_goals_from_shots,
        toInt32(countIf(ge.is_penalty_goal = 1)) AS match_total_penalty_goals,
        toInt32(countIf(ge.is_penalty_goal = 0)) AS match_total_non_penalty_goals,
        toInt32(countIf(ge.is_home_goal_flag = 1 AND ge.is_penalty_goal = 1)) AS home_penalty_goals,
        toInt32(countIf(ge.is_home_goal_flag = 0 AND ge.is_penalty_goal = 1)) AS away_penalty_goals,
        toInt32(countIf(ge.is_home_goal_flag = 1 AND ge.is_penalty_goal = 0)) AS home_non_penalty_goals,
        toInt32(countIf(ge.is_home_goal_flag = 0 AND ge.is_penalty_goal = 0)) AS away_non_penalty_goals
    FROM goal_events AS ge
    GROUP BY ge.match_id
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
        coalesce(gb.match_total_goals_from_shots, 0) AS match_total_goals_from_shots,
        coalesce(gb.match_total_penalty_goals, 0) AS match_total_penalty_goals,
        coalesce(gb.match_total_non_penalty_goals, 0) AS match_total_non_penalty_goals,
        coalesce(gb.home_penalty_goals, 0) AS home_penalty_goals,
        coalesce(gb.away_penalty_goals, 0) AS away_penalty_goals,
        coalesce(gb.home_non_penalty_goals, 0) AS home_non_penalty_goals,
        coalesce(gb.away_non_penalty_goals, 0) AS away_non_penalty_goals,
        toFloat32(coalesce(ps.expected_goals_home, 0)) AS expected_goals_home,
        toFloat32(coalesce(ps.expected_goals_away, 0)) AS expected_goals_away,
        toFloat32(coalesce(ps.expected_goals_non_penalty_home, 0)) AS expected_goals_non_penalty_home,
        toFloat32(coalesce(ps.expected_goals_non_penalty_away, 0)) AS expected_goals_non_penalty_away,
        coalesce(ps.total_shots_home, 0) AS total_shots_home,
        coalesce(ps.total_shots_away, 0) AS total_shots_away,
        coalesce(ps.shots_on_target_home, 0) AS shots_on_target_home,
        coalesce(ps.shots_on_target_away, 0) AS shots_on_target_away,
        coalesce(ps.big_chances_home, 0) AS big_chances_home,
        coalesce(ps.big_chances_away, 0) AS big_chances_away,
        coalesce(ps.big_chances_missed_home, 0) AS big_chances_missed_home,
        coalesce(ps.big_chances_missed_away, 0) AS big_chances_missed_away,
        coalesce(ps.touches_opp_box_home, 0) AS touches_opposition_box_home,
        coalesce(ps.touches_opp_box_away, 0) AS touches_opposition_box_away,
        toFloat32(coalesce(ps.ball_possession_home, 0)) AS possession_home_pct,
        toFloat32(coalesce(ps.ball_possession_away, 0)) AS possession_away_pct,
        coalesce(ps.accurate_passes_home, 0) AS accurate_passes_home,
        coalesce(ps.accurate_passes_away, 0) AS accurate_passes_away,
        coalesce(ps.pass_attempts_home, 0) AS pass_attempts_home,
        coalesce(ps.pass_attempts_away, 0) AS pass_attempts_away,
        coalesce(m.home_score, 0) + coalesce(m.away_score, 0) AS match_total_goals,
        toFloat32(round(
            coalesce(ps.expected_goals_home, 0) + coalesce(ps.expected_goals_away, 0),
            3
        )) AS match_total_xg,
        toFloat32(round(
            coalesce(ps.expected_goals_non_penalty_home, 0)
            + coalesce(ps.expected_goals_non_penalty_away, 0),
            3
        )) AS match_total_xg_non_penalty
    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.match_date = m.match_date
       AND ps.period = 'All'
    LEFT JOIN goal_breakdown AS gb
        ON gb.match_id = m.match_id
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND (
          (coalesce(m.home_score, 0) = 1 AND coalesce(m.away_score, 0) = 0)
          OR (coalesce(m.home_score, 0) = 0 AND coalesce(m.away_score, 0) = 1)
          OR (coalesce(m.home_score, 0) = 1 AND coalesce(m.away_score, 0) = 1)
      )
      AND (coalesce(m.home_score, 0) + coalesce(m.away_score, 0)) <= 2
      AND coalesce(gb.match_total_penalty_goals, 0)
          = (coalesce(m.home_score, 0) + coalesce(m.away_score, 0))
      AND coalesce(gb.match_total_non_penalty_goals, 0) = 0
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
    toInt32(1) AS trigger_threshold_home_goals_max,
    toInt32(1) AS trigger_threshold_away_goals_max,
    toInt32(2) AS trigger_threshold_match_total_goals_max,
    toUInt8(1) AS trigger_threshold_all_goals_penalty_flag,
    toUInt8(if(
        (
            (home_goals = 1 AND away_goals = 0)
            OR (home_goals = 0 AND away_goals = 1)
        ),
        1,
        0
    )) AS is_one_nil_final_flag,
    toUInt8(if((home_goals = 1 AND away_goals = 1), 1, 0)) AS is_one_one_final_flag,
    match_total_goals,
    match_total_penalty_goals,
    match_total_non_penalty_goals,
    toUInt8(if(match_total_goals_from_shots = match_total_goals, 1, 0))
        AS match_goal_count_consistent_with_shots_flag,
    home_penalty_goals,
    away_penalty_goals,
    home_non_penalty_goals,
    away_non_penalty_goals,
    home_penalty_goals AS triggered_team_penalty_goals,
    away_penalty_goals AS opponent_penalty_goals,
    home_penalty_goals - away_penalty_goals AS penalty_goals_delta,
    home_non_penalty_goals AS triggered_team_non_penalty_goals,
    away_non_penalty_goals AS opponent_non_penalty_goals,
    home_non_penalty_goals - away_non_penalty_goals AS non_penalty_goals_delta,
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
    home_goals AS triggered_team_goals,
    away_goals AS opponent_goals,
    home_goals - away_goals AS goal_gap,
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
    match_total_xg,
    match_total_xg_non_penalty,
    toFloat32(round(match_total_xg - match_total_xg_non_penalty, 3))
        AS match_total_penalty_xg_proxy,
    expected_goals_home AS triggered_team_xg,
    expected_goals_away AS opponent_xg,
    toFloat32(round(expected_goals_home - expected_goals_away, 3)) AS xg_gap,
    expected_goals_non_penalty_home AS triggered_team_xg_non_penalty,
    expected_goals_non_penalty_away AS opponent_xg_non_penalty,
    toFloat32(round(
        expected_goals_non_penalty_home - expected_goals_non_penalty_away,
        3
    )) AS xg_non_penalty_gap,
    big_chances_home AS triggered_team_big_chances,
    big_chances_away AS opponent_big_chances,
    big_chances_missed_home AS triggered_team_big_chances_missed,
    big_chances_missed_away AS opponent_big_chances_missed,
    big_chances_missed_home - big_chances_missed_away AS big_chances_missed_delta,
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
    toInt32(1) AS trigger_threshold_home_goals_max,
    toInt32(1) AS trigger_threshold_away_goals_max,
    toInt32(2) AS trigger_threshold_match_total_goals_max,
    toUInt8(1) AS trigger_threshold_all_goals_penalty_flag,
    toUInt8(if(
        (
            (home_goals = 1 AND away_goals = 0)
            OR (home_goals = 0 AND away_goals = 1)
        ),
        1,
        0
    )) AS is_one_nil_final_flag,
    toUInt8(if((home_goals = 1 AND away_goals = 1), 1, 0)) AS is_one_one_final_flag,
    match_total_goals,
    match_total_penalty_goals,
    match_total_non_penalty_goals,
    toUInt8(if(match_total_goals_from_shots = match_total_goals, 1, 0))
        AS match_goal_count_consistent_with_shots_flag,
    home_penalty_goals,
    away_penalty_goals,
    home_non_penalty_goals,
    away_non_penalty_goals,
    away_penalty_goals AS triggered_team_penalty_goals,
    home_penalty_goals AS opponent_penalty_goals,
    away_penalty_goals - home_penalty_goals AS penalty_goals_delta,
    away_non_penalty_goals AS triggered_team_non_penalty_goals,
    home_non_penalty_goals AS opponent_non_penalty_goals,
    away_non_penalty_goals - home_non_penalty_goals AS non_penalty_goals_delta,
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
    away_goals AS triggered_team_goals,
    home_goals AS opponent_goals,
    away_goals - home_goals AS goal_gap,
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
    match_total_xg,
    match_total_xg_non_penalty,
    toFloat32(round(match_total_xg - match_total_xg_non_penalty, 3))
        AS match_total_penalty_xg_proxy,
    expected_goals_away AS triggered_team_xg,
    expected_goals_home AS opponent_xg,
    toFloat32(round(expected_goals_away - expected_goals_home, 3)) AS xg_gap,
    expected_goals_non_penalty_away AS triggered_team_xg_non_penalty,
    expected_goals_non_penalty_home AS opponent_xg_non_penalty,
    toFloat32(round(
        expected_goals_non_penalty_away - expected_goals_non_penalty_home,
        3
    )) AS xg_non_penalty_gap,
    big_chances_away AS triggered_team_big_chances,
    big_chances_home AS opponent_big_chances,
    big_chances_missed_away AS triggered_team_big_chances_missed,
    big_chances_missed_home AS opponent_big_chances_missed,
    big_chances_missed_away - big_chances_missed_home AS big_chances_missed_delta,
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
FROM base_stats

ORDER BY
    match_total_penalty_goals DESC,
    match_date DESC,
    match_id DESC,
    triggered_side;
