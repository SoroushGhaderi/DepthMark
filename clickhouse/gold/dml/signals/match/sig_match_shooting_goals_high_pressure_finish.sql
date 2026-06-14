INSERT INTO gold.sig_match_shooting_goals_high_pressure_finish (
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
    trigger_threshold_late_shot_minute_exclusive,
    trigger_threshold_match_total_late_shots_min,
    match_late_shots_total,
    home_late_shots,
    away_late_shots,
    match_late_shots_on_target_total,
    match_late_shot_accuracy_pct,
    triggered_team_late_shots,
    opponent_late_shots,
    late_shot_volume_delta,
    triggered_team_late_shots_on_target,
    opponent_late_shots_on_target,
    late_shot_on_target_delta,
    triggered_team_late_shot_accuracy_pct,
    opponent_late_shot_accuracy_pct,
    late_shot_accuracy_delta_pct,
    triggered_team_total_shots,
    opponent_total_shots,
    shot_volume_delta,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    shot_on_target_delta,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_goals,
    opponent_goals,
    goal_gap,
    triggered_team_shot_conversion_pct,
    opponent_shot_conversion_pct,
    shot_conversion_delta_pct,
    triggered_team_big_chances,
    opponent_big_chances,
    big_chance_delta,
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
-- Signal: sig_match_shooting_goals_high_pressure_finish
-- Intent: detect matches with extreme late attacking pressure by both teams (85'+ combined shots)
--         and emit bilateral side-oriented context for late chaos diagnostics.
-- Trigger: combined late shots with effective minute > 85 is at least 10.
WITH late_shot_stats AS (
    SELECT
        se.match_id,
        toInt32(count()) AS match_late_shots_total,
        toInt32(countIf(se.shot_side = 'home')) AS home_late_shots,
        toInt32(countIf(se.shot_side = 'away')) AS away_late_shots,
        toInt32(countIf(se.is_on_target_flag = 1)) AS match_late_shots_on_target_total,
        toInt32(countIf(se.shot_side = 'home' AND se.is_on_target_flag = 1))
            AS home_late_shots_on_target,
        toInt32(countIf(se.shot_side = 'away' AND se.is_on_target_flag = 1))
            AS away_late_shots_on_target
    FROM (
        SELECT
            s.match_id,
            if(
                s.team_id = m.home_team_id,
                'home',
                if(s.team_id = m.away_team_id, 'away', 'unknown')
            ) AS shot_side,
            toUInt8(coalesce(s.is_on_target, 0)) AS is_on_target_flag
        FROM silver.shot AS s
        INNER JOIN silver.match AS m
            ON m.match_id = s.match_id
        WHERE s.match_id > 0
          AND m.match_finished = 1
          AND isNotNull(s.team_id)
          AND toInt32(
                coalesce(s.goal_time, s.minute, 0)
              + coalesce(s.goal_overload_time, s.minute_added, 0)
          ) > 85
    ) AS se
    WHERE se.shot_side IN ('home', 'away')
    GROUP BY se.match_id
    HAVING count() >= 10
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
    toInt32(85) AS trigger_threshold_late_shot_minute_exclusive,
    toInt32(10) AS trigger_threshold_match_total_late_shots_min,
    lss.match_late_shots_total,
    lss.home_late_shots,
    lss.away_late_shots,
    lss.match_late_shots_on_target_total,
    toFloat32(coalesce(round(
        100.0 * lss.match_late_shots_on_target_total / nullIf(toFloat64(lss.match_late_shots_total), 0),
        1
    ), 0.0)) AS match_late_shot_accuracy_pct,
    lss.home_late_shots AS triggered_team_late_shots,
    lss.away_late_shots AS opponent_late_shots,
    lss.home_late_shots - lss.away_late_shots AS late_shot_volume_delta,
    lss.home_late_shots_on_target AS triggered_team_late_shots_on_target,
    lss.away_late_shots_on_target AS opponent_late_shots_on_target,
    lss.home_late_shots_on_target - lss.away_late_shots_on_target AS late_shot_on_target_delta,
    toFloat32(coalesce(round(
        100.0 * lss.home_late_shots_on_target / nullIf(toFloat64(lss.home_late_shots), 0),
        1
    ), 0.0)) AS triggered_team_late_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * lss.away_late_shots_on_target / nullIf(toFloat64(lss.away_late_shots), 0),
        1
    ), 0.0)) AS opponent_late_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * lss.home_late_shots_on_target / nullIf(toFloat64(lss.home_late_shots), 0), 1), 0.0)
        - coalesce(round(100.0 * lss.away_late_shots_on_target / nullIf(toFloat64(lss.away_late_shots), 0), 1), 0.0),
        1
    )) AS late_shot_accuracy_delta_pct,
    coalesce(ps.total_shots_home, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_away, 0) AS opponent_total_shots,
    coalesce(ps.total_shots_home, 0) - coalesce(ps.total_shots_away, 0) AS shot_volume_delta,
    coalesce(ps.shots_on_target_home, 0) AS triggered_team_shots_on_target,
    coalesce(ps.shots_on_target_away, 0) AS opponent_shots_on_target,
    coalesce(ps.shots_on_target_home, 0) - coalesce(ps.shots_on_target_away, 0) AS shot_on_target_delta,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS opponent_xg,
    toFloat32(round(toFloat32(coalesce(ps.expected_goals_home, 0.0)) - toFloat32(coalesce(ps.expected_goals_away, 0.0)), 3)) AS xg_delta,
    coalesce(m.home_score, 0) AS triggered_team_goals,
    coalesce(m.away_score, 0) AS opponent_goals,
    coalesce(m.home_score, 0) - coalesce(m.away_score, 0) AS goal_gap,
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
    coalesce(ps.big_chances_home, 0) - coalesce(ps.big_chances_away, 0) AS big_chance_delta,
    coalesce(ps.big_chances_missed_home, 0) AS triggered_team_big_chances_missed,
    coalesce(ps.big_chances_missed_away, 0) AS opponent_big_chances_missed,
    coalesce(ps.big_chances_missed_home, 0) - coalesce(ps.big_chances_missed_away, 0) AS big_chances_missed_delta,
    coalesce(ps.touches_opp_box_home, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_away, 0) AS opponent_touches_opposition_box,
    coalesce(ps.touches_opp_box_home, 0) - coalesce(ps.touches_opp_box_away, 0) AS opposition_box_touch_delta,
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
INNER JOIN late_shot_stats AS lss
    ON lss.match_id = m.match_id
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0

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
    toInt32(85) AS trigger_threshold_late_shot_minute_exclusive,
    toInt32(10) AS trigger_threshold_match_total_late_shots_min,
    lss.match_late_shots_total,
    lss.home_late_shots,
    lss.away_late_shots,
    lss.match_late_shots_on_target_total,
    toFloat32(coalesce(round(
        100.0 * lss.match_late_shots_on_target_total / nullIf(toFloat64(lss.match_late_shots_total), 0),
        1
    ), 0.0)) AS match_late_shot_accuracy_pct,
    lss.away_late_shots AS triggered_team_late_shots,
    lss.home_late_shots AS opponent_late_shots,
    lss.away_late_shots - lss.home_late_shots AS late_shot_volume_delta,
    lss.away_late_shots_on_target AS triggered_team_late_shots_on_target,
    lss.home_late_shots_on_target AS opponent_late_shots_on_target,
    lss.away_late_shots_on_target - lss.home_late_shots_on_target AS late_shot_on_target_delta,
    toFloat32(coalesce(round(
        100.0 * lss.away_late_shots_on_target / nullIf(toFloat64(lss.away_late_shots), 0),
        1
    ), 0.0)) AS triggered_team_late_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * lss.home_late_shots_on_target / nullIf(toFloat64(lss.home_late_shots), 0),
        1
    ), 0.0)) AS opponent_late_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * lss.away_late_shots_on_target / nullIf(toFloat64(lss.away_late_shots), 0), 1), 0.0)
        - coalesce(round(100.0 * lss.home_late_shots_on_target / nullIf(toFloat64(lss.home_late_shots), 0), 1), 0.0),
        1
    )) AS late_shot_accuracy_delta_pct,
    coalesce(ps.total_shots_away, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_home, 0) AS opponent_total_shots,
    coalesce(ps.total_shots_away, 0) - coalesce(ps.total_shots_home, 0) AS shot_volume_delta,
    coalesce(ps.shots_on_target_away, 0) AS triggered_team_shots_on_target,
    coalesce(ps.shots_on_target_home, 0) AS opponent_shots_on_target,
    coalesce(ps.shots_on_target_away, 0) - coalesce(ps.shots_on_target_home, 0) AS shot_on_target_delta,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS opponent_xg,
    toFloat32(round(toFloat32(coalesce(ps.expected_goals_away, 0.0)) - toFloat32(coalesce(ps.expected_goals_home, 0.0)), 3)) AS xg_delta,
    coalesce(m.away_score, 0) AS triggered_team_goals,
    coalesce(m.home_score, 0) AS opponent_goals,
    coalesce(m.away_score, 0) - coalesce(m.home_score, 0) AS goal_gap,
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
    coalesce(ps.big_chances_away, 0) - coalesce(ps.big_chances_home, 0) AS big_chance_delta,
    coalesce(ps.big_chances_missed_away, 0) AS triggered_team_big_chances_missed,
    coalesce(ps.big_chances_missed_home, 0) AS opponent_big_chances_missed,
    coalesce(ps.big_chances_missed_away, 0) - coalesce(ps.big_chances_missed_home, 0) AS big_chances_missed_delta,
    coalesce(ps.touches_opp_box_away, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_home, 0) AS opponent_touches_opposition_box,
    coalesce(ps.touches_opp_box_away, 0) - coalesce(ps.touches_opp_box_home, 0) AS opposition_box_touch_delta,
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
INNER JOIN late_shot_stats AS lss
    ON lss.match_id = m.match_id
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0

ORDER BY
    match_late_shots_total DESC,
    match_date DESC,
    match_id DESC,
    triggered_side;