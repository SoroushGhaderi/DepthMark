INSERT INTO gold.sig_team_shooting_goals_late_surge_goals (
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
    trigger_threshold_min_goals_after_80,
    trigger_threshold_min_effective_minute,
    triggered_team_goals_after_80,
    opponent_goals_after_80,
    goals_after_80_delta,
    triggered_team_first_goal_minute_after_80,
    triggered_team_first_goal_added_time_after_80,
    triggered_team_first_goal_effective_minute_after_80,
    triggered_team_second_goal_minute_after_80,
    triggered_team_second_goal_added_time_after_80,
    triggered_team_second_goal_effective_minute_after_80,
    minutes_between_first_two_goals_after_80,
    triggered_team_goals_after_80_above_threshold,
    triggered_team_goals_final,
    opponent_goals_final,
    goal_delta_final,
    triggered_team_total_shots,
    opponent_total_shots,
    total_shots_delta,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    triggered_team_on_target_ratio_pct,
    opponent_on_target_ratio_pct,
    on_target_ratio_delta_pct,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_big_chances,
    opponent_big_chances,
    triggered_team_big_chances_missed,
    opponent_big_chances_missed,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_corners,
    opponent_corners
)
-- Signal: sig_team_shooting_goals_late_surge_goals
-- Trigger: Team scores at least 2 non-own goals after the 80th minute (effective minute > 80).
-- Intent: Detect late-match scoring surges and preserve bilateral match context for shot quality,
--         control profile, and conversion diagnostics.
WITH goal_events AS (
    SELECT
        s.match_id,
        if(coalesce(s.is_home_goal, 0) = 1, 'home', 'away') AS goal_side,
        toInt32(coalesce(s.goal_time, s.minute, 0)) AS goal_minute,
        toInt32(coalesce(s.goal_overload_time, s.minute_added, 0)) AS goal_added_time,
        toInt32(
            coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
        ) AS goal_effective_minute,
        toInt64(coalesce(s.shot_id, 0)) AS shot_id
    FROM silver.shot AS s
    WHERE s.match_id > 0
      AND coalesce(s.is_goal, 0) = 1
      AND coalesce(s.is_own_goal, 0) = 0
      AND isNotNull(s.is_home_goal)
      AND toInt32(coalesce(s.goal_time, s.minute, 0)) > 0
),
late_goal_events AS (
    SELECT
        ge.match_id,
        ge.goal_side,
        ge.goal_minute,
        ge.goal_added_time,
        ge.goal_effective_minute,
        ge.shot_id
    FROM goal_events AS ge
    WHERE ge.goal_effective_minute > 80
),
late_goal_counts AS (
    SELECT
        ege.match_id,
        ege.goal_side,
        count() AS goals_after_80
    FROM late_goal_events AS ege
    GROUP BY
        ege.match_id,
        ege.goal_side
),
late_goal_rollup_base AS (
    SELECT
        ege.match_id,
        ege.goal_side AS triggered_side,
        count() AS triggered_team_goals_after_80,
        arraySort(groupArray(tuple(
            ege.goal_effective_minute,
            ege.goal_minute,
            ege.goal_added_time,
            ege.shot_id
        ))) AS ordered_goal_tuples
    FROM late_goal_events AS ege
    GROUP BY
        ege.match_id,
        ege.goal_side
    HAVING count() >= 2
),
late_goal_rollup AS (
    SELECT
        egrb.match_id,
        egrb.triggered_side,
        toInt32(egrb.triggered_team_goals_after_80) AS triggered_team_goals_after_80,
        toInt32(tupleElement(arrayElement(egrb.ordered_goal_tuples, 1), 2))
            AS triggered_team_first_goal_minute_after_80,
        toInt32(tupleElement(arrayElement(egrb.ordered_goal_tuples, 1), 3))
            AS triggered_team_first_goal_added_time_after_80,
        toInt32(tupleElement(arrayElement(egrb.ordered_goal_tuples, 1), 1))
            AS triggered_team_first_goal_effective_minute_after_80,
        toInt32(tupleElement(arrayElement(egrb.ordered_goal_tuples, 2), 2))
            AS triggered_team_second_goal_minute_after_80,
        toInt32(tupleElement(arrayElement(egrb.ordered_goal_tuples, 2), 3))
            AS triggered_team_second_goal_added_time_after_80,
        toInt32(tupleElement(arrayElement(egrb.ordered_goal_tuples, 2), 1))
            AS triggered_team_second_goal_effective_minute_after_80,
        toInt32(
            tupleElement(arrayElement(egrb.ordered_goal_tuples, 2), 1)
            - tupleElement(arrayElement(egrb.ordered_goal_tuples, 1), 1)
        ) AS minutes_between_first_two_goals_after_80
    FROM late_goal_rollup_base AS egrb
)
SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    egr.triggered_side,
    if(egr.triggered_side = 'home', m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(egr.triggered_side = 'home', m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(egr.triggered_side = 'home', m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(egr.triggered_side = 'home', m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(2) AS trigger_threshold_min_goals_after_80,
    toInt32(80) AS trigger_threshold_min_effective_minute,
    egr.triggered_team_goals_after_80,
    toInt32(coalesce(ogc.goals_after_80, 0)) AS opponent_goals_after_80,
    toInt32(egr.triggered_team_goals_after_80 - coalesce(ogc.goals_after_80, 0)) AS goals_after_80_delta,
    egr.triggered_team_first_goal_minute_after_80,
    egr.triggered_team_first_goal_added_time_after_80,
    egr.triggered_team_first_goal_effective_minute_after_80,
    egr.triggered_team_second_goal_minute_after_80,
    egr.triggered_team_second_goal_added_time_after_80,
    egr.triggered_team_second_goal_effective_minute_after_80,
    egr.minutes_between_first_two_goals_after_80,
    toInt32(egr.triggered_team_goals_after_80 - 2) AS triggered_team_goals_after_80_above_threshold,

    toInt32(if(
        egr.triggered_side = 'home',
        coalesce(m.home_score, 0),
        coalesce(m.away_score, 0)
    )) AS triggered_team_goals_final,
    toInt32(if(
        egr.triggered_side = 'home',
        coalesce(m.away_score, 0),
        coalesce(m.home_score, 0)
    )) AS opponent_goals_final,
    toInt32(if(
        egr.triggered_side = 'home',
        coalesce(m.home_score, 0) - coalesce(m.away_score, 0),
        coalesce(m.away_score, 0) - coalesce(m.home_score, 0)
    )) AS goal_delta_final,

    toInt32(if(
        egr.triggered_side = 'home',
        coalesce(ps.total_shots_home, 0),
        coalesce(ps.total_shots_away, 0)
    )) AS triggered_team_total_shots,
    toInt32(if(
        egr.triggered_side = 'home',
        coalesce(ps.total_shots_away, 0),
        coalesce(ps.total_shots_home, 0)
    )) AS opponent_total_shots,
    toInt32(if(
        egr.triggered_side = 'home',
        coalesce(ps.total_shots_home, 0) - coalesce(ps.total_shots_away, 0),
        coalesce(ps.total_shots_away, 0) - coalesce(ps.total_shots_home, 0)
    )) AS total_shots_delta,

    toInt32(if(
        egr.triggered_side = 'home',
        coalesce(ps.shots_on_target_home, 0),
        coalesce(ps.shots_on_target_away, 0)
    )) AS triggered_team_shots_on_target,
    toInt32(if(
        egr.triggered_side = 'home',
        coalesce(ps.shots_on_target_away, 0),
        coalesce(ps.shots_on_target_home, 0)
    )) AS opponent_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * if(
            egr.triggered_side = 'home',
            coalesce(ps.shots_on_target_home, 0),
            coalesce(ps.shots_on_target_away, 0)
        ) / nullIf(if(
            egr.triggered_side = 'home',
            coalesce(ps.total_shots_home, 0),
            coalesce(ps.total_shots_away, 0)
        ), 0),
        1
    ), 0.0)) AS triggered_team_on_target_ratio_pct,
    toFloat32(coalesce(round(
        100.0 * if(
            egr.triggered_side = 'home',
            coalesce(ps.shots_on_target_away, 0),
            coalesce(ps.shots_on_target_home, 0)
        ) / nullIf(if(
            egr.triggered_side = 'home',
            coalesce(ps.total_shots_away, 0),
            coalesce(ps.total_shots_home, 0)
        ), 0),
        1
    ), 0.0)) AS opponent_on_target_ratio_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * if(
                egr.triggered_side = 'home',
                coalesce(ps.shots_on_target_home, 0),
                coalesce(ps.shots_on_target_away, 0)
            ) / nullIf(if(
                egr.triggered_side = 'home',
                coalesce(ps.total_shots_home, 0),
                coalesce(ps.total_shots_away, 0)
            ), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * if(
                egr.triggered_side = 'home',
                coalesce(ps.shots_on_target_away, 0),
                coalesce(ps.shots_on_target_home, 0)
            ) / nullIf(if(
                egr.triggered_side = 'home',
                coalesce(ps.total_shots_away, 0),
                coalesce(ps.total_shots_home, 0)
            ), 0),
            1
        ), 0.0),
        1
    )) AS on_target_ratio_delta_pct,

    toFloat32(if(
        egr.triggered_side = 'home',
        coalesce(ps.expected_goals_home, 0.0),
        coalesce(ps.expected_goals_away, 0.0)
    )) AS triggered_team_xg,
    toFloat32(if(
        egr.triggered_side = 'home',
        coalesce(ps.expected_goals_away, 0.0),
        coalesce(ps.expected_goals_home, 0.0)
    )) AS opponent_xg,
    toFloat32(round(
        if(
            egr.triggered_side = 'home',
            coalesce(ps.expected_goals_home, 0.0) - coalesce(ps.expected_goals_away, 0.0),
            coalesce(ps.expected_goals_away, 0.0) - coalesce(ps.expected_goals_home, 0.0)
        ),
        3
    )) AS xg_delta,

    toInt32(if(
        egr.triggered_side = 'home',
        coalesce(ps.big_chances_home, 0),
        coalesce(ps.big_chances_away, 0)
    )) AS triggered_team_big_chances,
    toInt32(if(
        egr.triggered_side = 'home',
        coalesce(ps.big_chances_away, 0),
        coalesce(ps.big_chances_home, 0)
    )) AS opponent_big_chances,
    toInt32(if(
        egr.triggered_side = 'home',
        coalesce(ps.big_chances_missed_home, 0),
        coalesce(ps.big_chances_missed_away, 0)
    )) AS triggered_team_big_chances_missed,
    toInt32(if(
        egr.triggered_side = 'home',
        coalesce(ps.big_chances_missed_away, 0),
        coalesce(ps.big_chances_missed_home, 0)
    )) AS opponent_big_chances_missed,

    toFloat32(if(
        egr.triggered_side = 'home',
        coalesce(ps.ball_possession_home, 0.0),
        coalesce(ps.ball_possession_away, 0.0)
    )) AS triggered_team_possession_pct,
    toFloat32(if(
        egr.triggered_side = 'home',
        coalesce(ps.ball_possession_away, 0.0),
        coalesce(ps.ball_possession_home, 0.0)
    )) AS opponent_possession_pct,
    toFloat32(round(
        if(
            egr.triggered_side = 'home',
            coalesce(ps.ball_possession_home, 0.0) - coalesce(ps.ball_possession_away, 0.0),
            coalesce(ps.ball_possession_away, 0.0) - coalesce(ps.ball_possession_home, 0.0)
        ),
        1
    )) AS possession_delta_pct,

    toInt32(if(
        egr.triggered_side = 'home',
        coalesce(ps.pass_attempts_home, 0),
        coalesce(ps.pass_attempts_away, 0)
    )) AS triggered_team_pass_attempts,
    toInt32(if(
        egr.triggered_side = 'home',
        coalesce(ps.pass_attempts_away, 0),
        coalesce(ps.pass_attempts_home, 0)
    )) AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * if(
            egr.triggered_side = 'home',
            coalesce(ps.accurate_passes_home, 0),
            coalesce(ps.accurate_passes_away, 0)
        ) / nullIf(if(
            egr.triggered_side = 'home',
            coalesce(ps.pass_attempts_home, 0),
            coalesce(ps.pass_attempts_away, 0)
        ), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * if(
            egr.triggered_side = 'home',
            coalesce(ps.accurate_passes_away, 0),
            coalesce(ps.accurate_passes_home, 0)
        ) / nullIf(if(
            egr.triggered_side = 'home',
            coalesce(ps.pass_attempts_away, 0),
            coalesce(ps.pass_attempts_home, 0)
        ), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * if(
                egr.triggered_side = 'home',
                coalesce(ps.accurate_passes_home, 0),
                coalesce(ps.accurate_passes_away, 0)
            ) / nullIf(if(
                egr.triggered_side = 'home',
                coalesce(ps.pass_attempts_home, 0),
                coalesce(ps.pass_attempts_away, 0)
            ), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * if(
                egr.triggered_side = 'home',
                coalesce(ps.accurate_passes_away, 0),
                coalesce(ps.accurate_passes_home, 0)
            ) / nullIf(if(
                egr.triggered_side = 'home',
                coalesce(ps.pass_attempts_away, 0),
                coalesce(ps.pass_attempts_home, 0)
            ), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    toInt32(if(
        egr.triggered_side = 'home',
        coalesce(ps.corners_home, 0),
        coalesce(ps.corners_away, 0)
    )) AS triggered_team_corners,
    toInt32(if(
        egr.triggered_side = 'home',
        coalesce(ps.corners_away, 0),
        coalesce(ps.corners_home, 0)
    )) AS opponent_corners

FROM late_goal_rollup AS egr
INNER JOIN silver.match AS m
    ON m.match_id = egr.match_id
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN late_goal_counts AS ogc
    ON ogc.match_id = egr.match_id
   AND ogc.goal_side = if(egr.triggered_side = 'home', 'away', 'home')
WHERE m.match_finished = 1
  AND m.match_id > 0

ORDER BY
    egr.triggered_team_goals_after_80 DESC,
    egr.minutes_between_first_two_goals_after_80 ASC,
    m.match_date DESC,
    m.match_id DESC;
