INSERT INTO gold.sig_team_shooting_goals_rapid_double_salvo (
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
    trigger_threshold_max_double_salvo_window_minutes,
    trigger_threshold_min_rapid_double_salvo_pairs,
    triggered_team_rapid_double_salvo_pairs,
    opponent_rapid_double_salvo_pairs,
    rapid_double_salvo_pairs_delta,
    triggered_team_first_salvo_first_goal_minute,
    triggered_team_first_salvo_first_goal_added_time,
    triggered_team_first_salvo_first_goal_effective_minute,
    triggered_team_first_salvo_second_goal_minute,
    triggered_team_first_salvo_second_goal_added_time,
    triggered_team_first_salvo_second_goal_effective_minute,
    minutes_between_first_salvo_goals,
    triggered_team_smallest_salvo_gap_minutes,
    triggered_team_average_salvo_gap_minutes,
    opponent_average_salvo_gap_minutes,
    average_salvo_gap_delta_minutes,
    triggered_team_last_salvo_second_goal_effective_minute,
    rapid_double_salvo_window_margin_minutes,
    triggered_team_rapid_double_salvo_pairs_above_threshold,
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
-- Signal: sig_team_shooting_goals_rapid_double_salvo
-- Trigger: team scores 2 non-own goals within 2 effective minutes (120-second proxy).
-- Intent: detect same-team rapid scoring bursts and preserve bilateral finishing, chance-quality,
-- and control context at match-team grain.
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
ordered_team_goal_events AS (
    SELECT
        ge.match_id,
        ge.goal_side,
        ge.goal_minute,
        ge.goal_added_time,
        ge.goal_effective_minute,
        ge.shot_id,
        row_number() OVER (
            PARTITION BY ge.match_id, ge.goal_side
            ORDER BY
                ge.goal_effective_minute ASC,
                ge.goal_minute ASC,
                ge.goal_added_time ASC,
                ge.shot_id ASC
        ) AS goal_event_order
    FROM goal_events AS ge
),
rapid_double_salvo_pairs AS (
    SELECT
        first_goal.match_id,
        first_goal.goal_side AS triggered_side,
        first_goal.goal_minute AS first_salvo_first_goal_minute,
        first_goal.goal_added_time AS first_salvo_first_goal_added_time,
        first_goal.goal_effective_minute AS first_salvo_first_goal_effective_minute,
        second_goal.goal_minute AS first_salvo_second_goal_minute,
        second_goal.goal_added_time AS first_salvo_second_goal_added_time,
        second_goal.goal_effective_minute AS first_salvo_second_goal_effective_minute,
        toInt32(
            second_goal.goal_effective_minute - first_goal.goal_effective_minute
        ) AS salvo_gap_minutes
    FROM ordered_team_goal_events AS first_goal
    INNER JOIN ordered_team_goal_events AS second_goal
        ON second_goal.match_id = first_goal.match_id
       AND second_goal.goal_side = first_goal.goal_side
       AND second_goal.goal_event_order = first_goal.goal_event_order + 1
    WHERE second_goal.goal_effective_minute - first_goal.goal_effective_minute BETWEEN 0 AND 2
),
rapid_double_salvo_rollup_base AS (
    SELECT
        rdsp.match_id,
        rdsp.triggered_side,
        toInt32(count()) AS triggered_team_rapid_double_salvo_pairs,
        toInt32(min(rdsp.salvo_gap_minutes)) AS triggered_team_smallest_salvo_gap_minutes,
        toFloat32(round(avg(toFloat32(rdsp.salvo_gap_minutes)), 2))
            AS triggered_team_average_salvo_gap_minutes,
        arraySort(groupArray(tuple(
            rdsp.first_salvo_first_goal_effective_minute,
            rdsp.first_salvo_first_goal_minute,
            rdsp.first_salvo_first_goal_added_time,
            rdsp.first_salvo_second_goal_effective_minute,
            rdsp.first_salvo_second_goal_minute,
            rdsp.first_salvo_second_goal_added_time,
            rdsp.salvo_gap_minutes
        ))) AS ordered_salvo_tuples
    FROM rapid_double_salvo_pairs AS rdsp
    GROUP BY
        rdsp.match_id,
        rdsp.triggered_side
),
rapid_double_salvo_rollup AS (
    SELECT
        rdsrb.match_id,
        rdsrb.triggered_side,
        rdsrb.triggered_team_rapid_double_salvo_pairs,
        rdsrb.triggered_team_smallest_salvo_gap_minutes,
        rdsrb.triggered_team_average_salvo_gap_minutes,
        toInt32(tupleElement(arrayElement(rdsrb.ordered_salvo_tuples, 1), 2))
            AS triggered_team_first_salvo_first_goal_minute,
        toInt32(tupleElement(arrayElement(rdsrb.ordered_salvo_tuples, 1), 3))
            AS triggered_team_first_salvo_first_goal_added_time,
        toInt32(tupleElement(arrayElement(rdsrb.ordered_salvo_tuples, 1), 1))
            AS triggered_team_first_salvo_first_goal_effective_minute,
        toInt32(tupleElement(arrayElement(rdsrb.ordered_salvo_tuples, 1), 5))
            AS triggered_team_first_salvo_second_goal_minute,
        toInt32(tupleElement(arrayElement(rdsrb.ordered_salvo_tuples, 1), 6))
            AS triggered_team_first_salvo_second_goal_added_time,
        toInt32(tupleElement(arrayElement(rdsrb.ordered_salvo_tuples, 1), 4))
            AS triggered_team_first_salvo_second_goal_effective_minute,
        toInt32(tupleElement(arrayElement(rdsrb.ordered_salvo_tuples, 1), 7))
            AS minutes_between_first_salvo_goals,
        toInt32(tupleElement(arrayElement(
            rdsrb.ordered_salvo_tuples,
            length(rdsrb.ordered_salvo_tuples)
        ), 4)) AS triggered_team_last_salvo_second_goal_effective_minute
    FROM rapid_double_salvo_rollup_base AS rdsrb
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

    rdsr.triggered_side,
    if(rdsr.triggered_side = 'home', m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(rdsr.triggered_side = 'home', m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(rdsr.triggered_side = 'home', m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(rdsr.triggered_side = 'home', m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(2) AS trigger_threshold_max_double_salvo_window_minutes,
    toInt32(1) AS trigger_threshold_min_rapid_double_salvo_pairs,
    rdsr.triggered_team_rapid_double_salvo_pairs,
    toInt32(coalesce(opp_rdsr.triggered_team_rapid_double_salvo_pairs, 0))
        AS opponent_rapid_double_salvo_pairs,
    toInt32(
        rdsr.triggered_team_rapid_double_salvo_pairs
      - coalesce(opp_rdsr.triggered_team_rapid_double_salvo_pairs, 0)
    ) AS rapid_double_salvo_pairs_delta,
    rdsr.triggered_team_first_salvo_first_goal_minute,
    rdsr.triggered_team_first_salvo_first_goal_added_time,
    rdsr.triggered_team_first_salvo_first_goal_effective_minute,
    rdsr.triggered_team_first_salvo_second_goal_minute,
    rdsr.triggered_team_first_salvo_second_goal_added_time,
    rdsr.triggered_team_first_salvo_second_goal_effective_minute,
    rdsr.minutes_between_first_salvo_goals,
    rdsr.triggered_team_smallest_salvo_gap_minutes,
    toFloat32(rdsr.triggered_team_average_salvo_gap_minutes)
        AS triggered_team_average_salvo_gap_minutes,
    toFloat32(coalesce(opp_rdsr.triggered_team_average_salvo_gap_minutes, 0.0))
        AS opponent_average_salvo_gap_minutes,
    toFloat32(round(
        rdsr.triggered_team_average_salvo_gap_minutes
      - coalesce(opp_rdsr.triggered_team_average_salvo_gap_minutes, 0.0),
        2
    )) AS average_salvo_gap_delta_minutes,
    rdsr.triggered_team_last_salvo_second_goal_effective_minute,
    toInt32(2 - rdsr.minutes_between_first_salvo_goals) AS rapid_double_salvo_window_margin_minutes,
    toInt32(rdsr.triggered_team_rapid_double_salvo_pairs - 1)
        AS triggered_team_rapid_double_salvo_pairs_above_threshold,

    toInt32(if(
        rdsr.triggered_side = 'home',
        coalesce(m.home_score, 0),
        coalesce(m.away_score, 0)
    )) AS triggered_team_goals_final,
    toInt32(if(
        rdsr.triggered_side = 'home',
        coalesce(m.away_score, 0),
        coalesce(m.home_score, 0)
    )) AS opponent_goals_final,
    toInt32(if(
        rdsr.triggered_side = 'home',
        coalesce(m.home_score, 0) - coalesce(m.away_score, 0),
        coalesce(m.away_score, 0) - coalesce(m.home_score, 0)
    )) AS goal_delta_final,

    toInt32(if(
        rdsr.triggered_side = 'home',
        coalesce(ps.total_shots_home, 0),
        coalesce(ps.total_shots_away, 0)
    )) AS triggered_team_total_shots,
    toInt32(if(
        rdsr.triggered_side = 'home',
        coalesce(ps.total_shots_away, 0),
        coalesce(ps.total_shots_home, 0)
    )) AS opponent_total_shots,
    toInt32(if(
        rdsr.triggered_side = 'home',
        coalesce(ps.total_shots_home, 0) - coalesce(ps.total_shots_away, 0),
        coalesce(ps.total_shots_away, 0) - coalesce(ps.total_shots_home, 0)
    )) AS total_shots_delta,

    toInt32(if(
        rdsr.triggered_side = 'home',
        coalesce(ps.shots_on_target_home, 0),
        coalesce(ps.shots_on_target_away, 0)
    )) AS triggered_team_shots_on_target,
    toInt32(if(
        rdsr.triggered_side = 'home',
        coalesce(ps.shots_on_target_away, 0),
        coalesce(ps.shots_on_target_home, 0)
    )) AS opponent_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * if(
            rdsr.triggered_side = 'home',
            coalesce(ps.shots_on_target_home, 0),
            coalesce(ps.shots_on_target_away, 0)
        ) / nullIf(if(
            rdsr.triggered_side = 'home',
            coalesce(ps.total_shots_home, 0),
            coalesce(ps.total_shots_away, 0)
        ), 0),
        1
    ), 0.0)) AS triggered_team_on_target_ratio_pct,
    toFloat32(coalesce(round(
        100.0 * if(
            rdsr.triggered_side = 'home',
            coalesce(ps.shots_on_target_away, 0),
            coalesce(ps.shots_on_target_home, 0)
        ) / nullIf(if(
            rdsr.triggered_side = 'home',
            coalesce(ps.total_shots_away, 0),
            coalesce(ps.total_shots_home, 0)
        ), 0),
        1
    ), 0.0)) AS opponent_on_target_ratio_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * if(
                rdsr.triggered_side = 'home',
                coalesce(ps.shots_on_target_home, 0),
                coalesce(ps.shots_on_target_away, 0)
            ) / nullIf(if(
                rdsr.triggered_side = 'home',
                coalesce(ps.total_shots_home, 0),
                coalesce(ps.total_shots_away, 0)
            ), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * if(
                rdsr.triggered_side = 'home',
                coalesce(ps.shots_on_target_away, 0),
                coalesce(ps.shots_on_target_home, 0)
            ) / nullIf(if(
                rdsr.triggered_side = 'home',
                coalesce(ps.total_shots_away, 0),
                coalesce(ps.total_shots_home, 0)
            ), 0),
            1
        ), 0.0),
        1
    )) AS on_target_ratio_delta_pct,

    toFloat32(if(
        rdsr.triggered_side = 'home',
        coalesce(ps.expected_goals_home, 0.0),
        coalesce(ps.expected_goals_away, 0.0)
    )) AS triggered_team_xg,
    toFloat32(if(
        rdsr.triggered_side = 'home',
        coalesce(ps.expected_goals_away, 0.0),
        coalesce(ps.expected_goals_home, 0.0)
    )) AS opponent_xg,
    toFloat32(round(
        if(
            rdsr.triggered_side = 'home',
            coalesce(ps.expected_goals_home, 0.0) - coalesce(ps.expected_goals_away, 0.0),
            coalesce(ps.expected_goals_away, 0.0) - coalesce(ps.expected_goals_home, 0.0)
        ),
        3
    )) AS xg_delta,

    toInt32(if(
        rdsr.triggered_side = 'home',
        coalesce(ps.big_chances_home, 0),
        coalesce(ps.big_chances_away, 0)
    )) AS triggered_team_big_chances,
    toInt32(if(
        rdsr.triggered_side = 'home',
        coalesce(ps.big_chances_away, 0),
        coalesce(ps.big_chances_home, 0)
    )) AS opponent_big_chances,
    toInt32(if(
        rdsr.triggered_side = 'home',
        coalesce(ps.big_chances_missed_home, 0),
        coalesce(ps.big_chances_missed_away, 0)
    )) AS triggered_team_big_chances_missed,
    toInt32(if(
        rdsr.triggered_side = 'home',
        coalesce(ps.big_chances_missed_away, 0),
        coalesce(ps.big_chances_missed_home, 0)
    )) AS opponent_big_chances_missed,

    toFloat32(if(
        rdsr.triggered_side = 'home',
        coalesce(ps.ball_possession_home, 0.0),
        coalesce(ps.ball_possession_away, 0.0)
    )) AS triggered_team_possession_pct,
    toFloat32(if(
        rdsr.triggered_side = 'home',
        coalesce(ps.ball_possession_away, 0.0),
        coalesce(ps.ball_possession_home, 0.0)
    )) AS opponent_possession_pct,
    toFloat32(round(
        if(
            rdsr.triggered_side = 'home',
            coalesce(ps.ball_possession_home, 0.0) - coalesce(ps.ball_possession_away, 0.0),
            coalesce(ps.ball_possession_away, 0.0) - coalesce(ps.ball_possession_home, 0.0)
        ),
        1
    )) AS possession_delta_pct,

    toInt32(if(
        rdsr.triggered_side = 'home',
        coalesce(ps.pass_attempts_home, 0),
        coalesce(ps.pass_attempts_away, 0)
    )) AS triggered_team_pass_attempts,
    toInt32(if(
        rdsr.triggered_side = 'home',
        coalesce(ps.pass_attempts_away, 0),
        coalesce(ps.pass_attempts_home, 0)
    )) AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * if(
            rdsr.triggered_side = 'home',
            coalesce(ps.accurate_passes_home, 0),
            coalesce(ps.accurate_passes_away, 0)
        ) / nullIf(if(
            rdsr.triggered_side = 'home',
            coalesce(ps.pass_attempts_home, 0),
            coalesce(ps.pass_attempts_away, 0)
        ), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * if(
            rdsr.triggered_side = 'home',
            coalesce(ps.accurate_passes_away, 0),
            coalesce(ps.accurate_passes_home, 0)
        ) / nullIf(if(
            rdsr.triggered_side = 'home',
            coalesce(ps.pass_attempts_away, 0),
            coalesce(ps.pass_attempts_home, 0)
        ), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * if(
                rdsr.triggered_side = 'home',
                coalesce(ps.accurate_passes_home, 0),
                coalesce(ps.accurate_passes_away, 0)
            ) / nullIf(if(
                rdsr.triggered_side = 'home',
                coalesce(ps.pass_attempts_home, 0),
                coalesce(ps.pass_attempts_away, 0)
            ), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * if(
                rdsr.triggered_side = 'home',
                coalesce(ps.accurate_passes_away, 0),
                coalesce(ps.accurate_passes_home, 0)
            ) / nullIf(if(
                rdsr.triggered_side = 'home',
                coalesce(ps.pass_attempts_away, 0),
                coalesce(ps.pass_attempts_home, 0)
            ), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    toInt32(if(
        rdsr.triggered_side = 'home',
        coalesce(ps.corners_home, 0),
        coalesce(ps.corners_away, 0)
    )) AS triggered_team_corners,
    toInt32(if(
        rdsr.triggered_side = 'home',
        coalesce(ps.corners_away, 0),
        coalesce(ps.corners_home, 0)
    )) AS opponent_corners

FROM rapid_double_salvo_rollup AS rdsr
INNER JOIN silver.match AS m
    ON m.match_id = rdsr.match_id
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN rapid_double_salvo_rollup AS opp_rdsr
    ON opp_rdsr.match_id = rdsr.match_id
   AND opp_rdsr.triggered_side = if(rdsr.triggered_side = 'home', 'away', 'home')
WHERE m.match_finished = 1
  AND m.match_id > 0;
