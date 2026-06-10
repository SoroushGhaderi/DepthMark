INSERT INTO gold.sig_team_shooting_goals_rapid_response_goal (
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
    trigger_threshold_max_response_minutes,
    trigger_threshold_min_rapid_response_goals,
    triggered_team_rapid_response_goals,
    opponent_rapid_response_goals,
    rapid_response_goals_delta,
    triggered_team_first_conceded_goal_minute_before_response,
    triggered_team_first_conceded_goal_added_time_before_response,
    triggered_team_first_conceded_goal_effective_minute_before_response,
    triggered_team_first_response_goal_minute,
    triggered_team_first_response_goal_added_time,
    triggered_team_first_response_goal_effective_minute,
    minutes_to_first_response_goal,
    triggered_team_average_response_time_minutes,
    opponent_average_response_time_minutes,
    average_response_time_delta_minutes,
    rapid_response_window_margin_minutes,
    triggered_team_rapid_response_goals_above_threshold,
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
-- Signal: sig_team_shooting_goals_rapid_response_goal
-- Trigger: Team scores a non-own goal within 2 effective minutes of conceding a non-own goal.
-- Intent: Detect immediate scoring responses after conceding and preserve bilateral team context for
--         finishing quality, control profile, and tempo diagnostics.
WITH goal_events AS (
    SELECT
        s.match_id AS match_id,
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
ordered_goal_events AS (
    SELECT
        ge.match_id AS match_id,
        ge.goal_side AS goal_side,
        ge.goal_minute AS goal_minute,
        ge.goal_added_time AS goal_added_time,
        ge.goal_effective_minute AS goal_effective_minute,
        ge.shot_id AS shot_id,
        row_number() OVER (
            PARTITION BY ge.match_id
            ORDER BY
                ge.goal_effective_minute ASC,
                ge.goal_minute ASC,
                ge.goal_added_time ASC,
                ge.shot_id ASC
        ) AS goal_event_order
    FROM goal_events AS ge
),
rapid_response_candidates AS (
    SELECT
        curr.match_id AS match_id,
        curr.goal_side AS triggered_side,
        prev.goal_minute AS conceded_goal_minute_before_response,
        prev.goal_added_time AS conceded_goal_added_time_before_response,
        prev.goal_effective_minute AS conceded_goal_effective_minute_before_response,
        prev.shot_id AS conceded_goal_shot_id,
        curr.goal_minute AS response_goal_minute,
        curr.goal_added_time AS response_goal_added_time,
        curr.goal_effective_minute AS response_goal_effective_minute,
        curr.shot_id AS response_goal_shot_id,
        toInt32(curr.goal_effective_minute - prev.goal_effective_minute) AS response_gap_minutes
    FROM ordered_goal_events AS prev
    INNER JOIN ordered_goal_events AS curr
        ON curr.match_id = prev.match_id
       AND curr.goal_event_order = prev.goal_event_order + 1
    WHERE curr.goal_side != prev.goal_side
      AND curr.goal_effective_minute - prev.goal_effective_minute BETWEEN 0 AND 2
),
rapid_response_rollup_base AS (
    SELECT
        rrc.match_id,
        rrc.triggered_side,
        toInt32(count()) AS triggered_team_rapid_response_goals,
        toFloat32(round(avg(toFloat32(rrc.response_gap_minutes)), 2)) AS triggered_team_average_response_time_minutes,
        arraySort(groupArray(tuple(
            rrc.response_goal_effective_minute,
            rrc.response_goal_minute,
            rrc.response_goal_added_time,
            rrc.conceded_goal_effective_minute_before_response,
            rrc.conceded_goal_minute_before_response,
            rrc.conceded_goal_added_time_before_response,
            rrc.response_gap_minutes,
            rrc.conceded_goal_shot_id,
            rrc.response_goal_shot_id
        ))) AS ordered_response_tuples
    FROM rapid_response_candidates AS rrc
    GROUP BY
        rrc.match_id,
        rrc.triggered_side
),
rapid_response_rollup AS (
    SELECT
        rrrb.match_id,
        rrrb.triggered_side,
        rrrb.triggered_team_rapid_response_goals,
        rrrb.triggered_team_average_response_time_minutes,
        toInt32(tupleElement(arrayElement(rrrb.ordered_response_tuples, 1), 5))
            AS triggered_team_first_conceded_goal_minute_before_response,
        toInt32(tupleElement(arrayElement(rrrb.ordered_response_tuples, 1), 6))
            AS triggered_team_first_conceded_goal_added_time_before_response,
        toInt32(tupleElement(arrayElement(rrrb.ordered_response_tuples, 1), 4))
            AS triggered_team_first_conceded_goal_effective_minute_before_response,
        toInt32(tupleElement(arrayElement(rrrb.ordered_response_tuples, 1), 2))
            AS triggered_team_first_response_goal_minute,
        toInt32(tupleElement(arrayElement(rrrb.ordered_response_tuples, 1), 3))
            AS triggered_team_first_response_goal_added_time,
        toInt32(tupleElement(arrayElement(rrrb.ordered_response_tuples, 1), 1))
            AS triggered_team_first_response_goal_effective_minute,
        toInt32(tupleElement(arrayElement(rrrb.ordered_response_tuples, 1), 7))
            AS minutes_to_first_response_goal
    FROM rapid_response_rollup_base AS rrrb
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

    rrr.triggered_side,
    if(rrr.triggered_side = 'home', m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(rrr.triggered_side = 'home', m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(rrr.triggered_side = 'home', m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(rrr.triggered_side = 'home', m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(2) AS trigger_threshold_max_response_minutes,
    toInt32(1) AS trigger_threshold_min_rapid_response_goals,
    rrr.triggered_team_rapid_response_goals,
    toInt32(coalesce(opp_rrr.triggered_team_rapid_response_goals, 0)) AS opponent_rapid_response_goals,
    toInt32(
        rrr.triggered_team_rapid_response_goals
      - coalesce(opp_rrr.triggered_team_rapid_response_goals, 0)
    ) AS rapid_response_goals_delta,
    rrr.triggered_team_first_conceded_goal_minute_before_response,
    rrr.triggered_team_first_conceded_goal_added_time_before_response,
    rrr.triggered_team_first_conceded_goal_effective_minute_before_response,
    rrr.triggered_team_first_response_goal_minute,
    rrr.triggered_team_first_response_goal_added_time,
    rrr.triggered_team_first_response_goal_effective_minute,
    rrr.minutes_to_first_response_goal,
    toFloat32(rrr.triggered_team_average_response_time_minutes) AS triggered_team_average_response_time_minutes,
    toFloat32(coalesce(opp_rrr.triggered_team_average_response_time_minutes, 0.0))
        AS opponent_average_response_time_minutes,
    toFloat32(round(
        rrr.triggered_team_average_response_time_minutes
      - coalesce(opp_rrr.triggered_team_average_response_time_minutes, 0.0),
        2
    )) AS average_response_time_delta_minutes,
    toInt32(2 - rrr.minutes_to_first_response_goal) AS rapid_response_window_margin_minutes,
    toInt32(rrr.triggered_team_rapid_response_goals - 1) AS triggered_team_rapid_response_goals_above_threshold,

    toInt32(if(
        rrr.triggered_side = 'home',
        coalesce(m.home_score, 0),
        coalesce(m.away_score, 0)
    )) AS triggered_team_goals_final,
    toInt32(if(
        rrr.triggered_side = 'home',
        coalesce(m.away_score, 0),
        coalesce(m.home_score, 0)
    )) AS opponent_goals_final,
    toInt32(if(
        rrr.triggered_side = 'home',
        coalesce(m.home_score, 0) - coalesce(m.away_score, 0),
        coalesce(m.away_score, 0) - coalesce(m.home_score, 0)
    )) AS goal_delta_final,

    toInt32(if(
        rrr.triggered_side = 'home',
        coalesce(ps.total_shots_home, 0),
        coalesce(ps.total_shots_away, 0)
    )) AS triggered_team_total_shots,
    toInt32(if(
        rrr.triggered_side = 'home',
        coalesce(ps.total_shots_away, 0),
        coalesce(ps.total_shots_home, 0)
    )) AS opponent_total_shots,
    toInt32(if(
        rrr.triggered_side = 'home',
        coalesce(ps.total_shots_home, 0) - coalesce(ps.total_shots_away, 0),
        coalesce(ps.total_shots_away, 0) - coalesce(ps.total_shots_home, 0)
    )) AS total_shots_delta,

    toInt32(if(
        rrr.triggered_side = 'home',
        coalesce(ps.shots_on_target_home, 0),
        coalesce(ps.shots_on_target_away, 0)
    )) AS triggered_team_shots_on_target,
    toInt32(if(
        rrr.triggered_side = 'home',
        coalesce(ps.shots_on_target_away, 0),
        coalesce(ps.shots_on_target_home, 0)
    )) AS opponent_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * if(
            rrr.triggered_side = 'home',
            coalesce(ps.shots_on_target_home, 0),
            coalesce(ps.shots_on_target_away, 0)
        ) / nullIf(if(
            rrr.triggered_side = 'home',
            coalesce(ps.total_shots_home, 0),
            coalesce(ps.total_shots_away, 0)
        ), 0),
        1
    ), 0.0)) AS triggered_team_on_target_ratio_pct,
    toFloat32(coalesce(round(
        100.0 * if(
            rrr.triggered_side = 'home',
            coalesce(ps.shots_on_target_away, 0),
            coalesce(ps.shots_on_target_home, 0)
        ) / nullIf(if(
            rrr.triggered_side = 'home',
            coalesce(ps.total_shots_away, 0),
            coalesce(ps.total_shots_home, 0)
        ), 0),
        1
    ), 0.0)) AS opponent_on_target_ratio_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * if(
                rrr.triggered_side = 'home',
                coalesce(ps.shots_on_target_home, 0),
                coalesce(ps.shots_on_target_away, 0)
            ) / nullIf(if(
                rrr.triggered_side = 'home',
                coalesce(ps.total_shots_home, 0),
                coalesce(ps.total_shots_away, 0)
            ), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * if(
                rrr.triggered_side = 'home',
                coalesce(ps.shots_on_target_away, 0),
                coalesce(ps.shots_on_target_home, 0)
            ) / nullIf(if(
                rrr.triggered_side = 'home',
                coalesce(ps.total_shots_away, 0),
                coalesce(ps.total_shots_home, 0)
            ), 0),
            1
        ), 0.0),
        1
    )) AS on_target_ratio_delta_pct,

    toFloat32(if(
        rrr.triggered_side = 'home',
        coalesce(ps.expected_goals_home, 0.0),
        coalesce(ps.expected_goals_away, 0.0)
    )) AS triggered_team_xg,
    toFloat32(if(
        rrr.triggered_side = 'home',
        coalesce(ps.expected_goals_away, 0.0),
        coalesce(ps.expected_goals_home, 0.0)
    )) AS opponent_xg,
    toFloat32(round(
        if(
            rrr.triggered_side = 'home',
            coalesce(ps.expected_goals_home, 0.0) - coalesce(ps.expected_goals_away, 0.0),
            coalesce(ps.expected_goals_away, 0.0) - coalesce(ps.expected_goals_home, 0.0)
        ),
        3
    )) AS xg_delta,

    toInt32(if(
        rrr.triggered_side = 'home',
        coalesce(ps.big_chances_home, 0),
        coalesce(ps.big_chances_away, 0)
    )) AS triggered_team_big_chances,
    toInt32(if(
        rrr.triggered_side = 'home',
        coalesce(ps.big_chances_away, 0),
        coalesce(ps.big_chances_home, 0)
    )) AS opponent_big_chances,
    toInt32(if(
        rrr.triggered_side = 'home',
        coalesce(ps.big_chances_missed_home, 0),
        coalesce(ps.big_chances_missed_away, 0)
    )) AS triggered_team_big_chances_missed,
    toInt32(if(
        rrr.triggered_side = 'home',
        coalesce(ps.big_chances_missed_away, 0),
        coalesce(ps.big_chances_missed_home, 0)
    )) AS opponent_big_chances_missed,

    toFloat32(if(
        rrr.triggered_side = 'home',
        coalesce(ps.ball_possession_home, 0.0),
        coalesce(ps.ball_possession_away, 0.0)
    )) AS triggered_team_possession_pct,
    toFloat32(if(
        rrr.triggered_side = 'home',
        coalesce(ps.ball_possession_away, 0.0),
        coalesce(ps.ball_possession_home, 0.0)
    )) AS opponent_possession_pct,
    toFloat32(round(
        if(
            rrr.triggered_side = 'home',
            coalesce(ps.ball_possession_home, 0.0) - coalesce(ps.ball_possession_away, 0.0),
            coalesce(ps.ball_possession_away, 0.0) - coalesce(ps.ball_possession_home, 0.0)
        ),
        1
    )) AS possession_delta_pct,

    toInt32(if(
        rrr.triggered_side = 'home',
        coalesce(ps.pass_attempts_home, 0),
        coalesce(ps.pass_attempts_away, 0)
    )) AS triggered_team_pass_attempts,
    toInt32(if(
        rrr.triggered_side = 'home',
        coalesce(ps.pass_attempts_away, 0),
        coalesce(ps.pass_attempts_home, 0)
    )) AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * if(
            rrr.triggered_side = 'home',
            coalesce(ps.accurate_passes_home, 0),
            coalesce(ps.accurate_passes_away, 0)
        ) / nullIf(if(
            rrr.triggered_side = 'home',
            coalesce(ps.pass_attempts_home, 0),
            coalesce(ps.pass_attempts_away, 0)
        ), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * if(
            rrr.triggered_side = 'home',
            coalesce(ps.accurate_passes_away, 0),
            coalesce(ps.accurate_passes_home, 0)
        ) / nullIf(if(
            rrr.triggered_side = 'home',
            coalesce(ps.pass_attempts_away, 0),
            coalesce(ps.pass_attempts_home, 0)
        ), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * if(
                rrr.triggered_side = 'home',
                coalesce(ps.accurate_passes_home, 0),
                coalesce(ps.accurate_passes_away, 0)
            ) / nullIf(if(
                rrr.triggered_side = 'home',
                coalesce(ps.pass_attempts_home, 0),
                coalesce(ps.pass_attempts_away, 0)
            ), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * if(
                rrr.triggered_side = 'home',
                coalesce(ps.accurate_passes_away, 0),
                coalesce(ps.accurate_passes_home, 0)
            ) / nullIf(if(
                rrr.triggered_side = 'home',
                coalesce(ps.pass_attempts_away, 0),
                coalesce(ps.pass_attempts_home, 0)
            ), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    toInt32(if(
        rrr.triggered_side = 'home',
        coalesce(ps.corners_home, 0),
        coalesce(ps.corners_away, 0)
    )) AS triggered_team_corners,
    toInt32(if(
        rrr.triggered_side = 'home',
        coalesce(ps.corners_away, 0),
        coalesce(ps.corners_home, 0)
    )) AS opponent_corners

FROM rapid_response_rollup AS rrr
INNER JOIN silver.match AS m
    ON m.match_id = rrr.match_id
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN rapid_response_rollup AS opp_rrr
    ON opp_rrr.match_id = rrr.match_id
   AND opp_rrr.triggered_side = if(rrr.triggered_side = 'home', 'away', 'home')
WHERE m.match_finished = 1
  AND m.match_id > 0

ORDER BY
    rrr.triggered_team_rapid_response_goals DESC,
    rrr.minutes_to_first_response_goal ASC,
    m.match_date DESC,
    m.match_id DESC;
