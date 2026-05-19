INSERT INTO gold.sig_match_shooting_goals_rapid_fire_exchange (
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
    trigger_threshold_rapid_fire_window_minutes,
    trigger_threshold_min_rapid_fire_exchanges,
    match_rapid_fire_exchange_count,
    home_goals_in_rapid_fire_exchanges,
    away_goals_in_rapid_fire_exchanges,
    first_rapid_fire_exchange_start_effective_minute,
    first_rapid_fire_exchange_end_effective_minute,
    first_rapid_fire_exchange_gap_minutes,
    smallest_exchange_gap_minutes,
    average_exchange_gap_minutes,
    last_rapid_fire_exchange_end_effective_minute,
    match_rapid_fire_exchange_span_minutes,
    both_sides_scored_in_rapid_fire_flag,
    triggered_team_rapid_fire_goals,
    opponent_rapid_fire_goals,
    rapid_fire_goals_delta,
    triggered_team_goals,
    opponent_goals,
    goal_gap,
    triggered_team_total_shots,
    opponent_total_shots,
    shot_volume_delta,
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
-- Signal: sig_match_shooting_goals_rapid_fire_exchange
-- Intent: detect bilateral goal-trading bursts where both teams score within a tight 3-minute
--         effective window and emit side-oriented finishing, tempo, and control diagnostics.
-- Trigger: at least one opposite-side consecutive non-own-goal pair with effective-minute gap <= 3.
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
ordered_goal_events AS (
    SELECT
        ge.match_id,
        ge.goal_side,
        ge.goal_minute,
        ge.goal_added_time,
        ge.goal_effective_minute,
        ge.shot_id,
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
rapid_fire_pairs AS (
    SELECT
        prev.match_id,
        prev.goal_side AS first_goal_side,
        curr.goal_side AS second_goal_side,
        prev.goal_effective_minute AS first_goal_effective_minute,
        curr.goal_effective_minute AS second_goal_effective_minute,
        toInt32(curr.goal_effective_minute - prev.goal_effective_minute) AS exchange_gap_minutes
    FROM ordered_goal_events AS prev
    INNER JOIN ordered_goal_events AS curr
        ON curr.match_id = prev.match_id
       AND curr.goal_event_order = prev.goal_event_order + 1
    WHERE prev.goal_side != curr.goal_side
      AND curr.goal_effective_minute - prev.goal_effective_minute BETWEEN 0 AND 3
),
rapid_fire_rollup_base AS (
    SELECT
        rfp.match_id,
        toInt32(count()) AS match_rapid_fire_exchange_count,
        toInt32(countIf(rfp.first_goal_side = 'home') + countIf(rfp.second_goal_side = 'home'))
            AS home_goals_in_rapid_fire_exchanges,
        toInt32(countIf(rfp.first_goal_side = 'away') + countIf(rfp.second_goal_side = 'away'))
            AS away_goals_in_rapid_fire_exchanges,
        toInt32(min(rfp.exchange_gap_minutes)) AS smallest_exchange_gap_minutes,
        toFloat32(round(avg(toFloat32(rfp.exchange_gap_minutes)), 2)) AS average_exchange_gap_minutes,
        arraySort(groupArray(tuple(
            rfp.first_goal_effective_minute,
            rfp.second_goal_effective_minute,
            rfp.exchange_gap_minutes
        ))) AS ordered_exchange_tuples
    FROM rapid_fire_pairs AS rfp
    GROUP BY rfp.match_id
),
rapid_fire_rollup AS (
    SELECT
        rfrb.match_id,
        rfrb.match_rapid_fire_exchange_count,
        rfrb.home_goals_in_rapid_fire_exchanges,
        rfrb.away_goals_in_rapid_fire_exchanges,
        toInt32(tupleElement(arrayElement(rfrb.ordered_exchange_tuples, 1), 1))
            AS first_rapid_fire_exchange_start_effective_minute,
        toInt32(tupleElement(arrayElement(rfrb.ordered_exchange_tuples, 1), 2))
            AS first_rapid_fire_exchange_end_effective_minute,
        toInt32(tupleElement(arrayElement(rfrb.ordered_exchange_tuples, 1), 3))
            AS first_rapid_fire_exchange_gap_minutes,
        rfrb.smallest_exchange_gap_minutes,
        rfrb.average_exchange_gap_minutes,
        toInt32(tupleElement(arrayElement(
            rfrb.ordered_exchange_tuples,
            length(rfrb.ordered_exchange_tuples)
        ), 2)) AS last_rapid_fire_exchange_end_effective_minute
    FROM rapid_fire_rollup_base AS rfrb
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
        rfr.match_rapid_fire_exchange_count,
        rfr.home_goals_in_rapid_fire_exchanges,
        rfr.away_goals_in_rapid_fire_exchanges,
        rfr.first_rapid_fire_exchange_start_effective_minute,
        rfr.first_rapid_fire_exchange_end_effective_minute,
        rfr.first_rapid_fire_exchange_gap_minutes,
        rfr.smallest_exchange_gap_minutes,
        rfr.average_exchange_gap_minutes,
        rfr.last_rapid_fire_exchange_end_effective_minute,
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
    INNER JOIN rapid_fire_rollup AS rfr
        ON rfr.match_id = m.match_id
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.match_date = m.match_date
       AND ps.period = 'All'
    WHERE m.match_finished = 1
      AND m.match_id > 0
)

SELECT
    b.match_id,
    b.match_date,
    b.home_team_id,
    b.home_team_name,
    b.away_team_id,
    b.away_team_name,
    b.home_score,
    b.away_score,
    'home' AS triggered_side,
    b.home_team_id AS triggered_team_id,
    b.home_team_name AS triggered_team_name,
    b.away_team_id AS opponent_team_id,
    b.away_team_name AS opponent_team_name,
    toInt32(3) AS trigger_threshold_rapid_fire_window_minutes,
    toInt32(1) AS trigger_threshold_min_rapid_fire_exchanges,
    b.match_rapid_fire_exchange_count,
    b.home_goals_in_rapid_fire_exchanges,
    b.away_goals_in_rapid_fire_exchanges,
    b.first_rapid_fire_exchange_start_effective_minute,
    b.first_rapid_fire_exchange_end_effective_minute,
    b.first_rapid_fire_exchange_gap_minutes,
    b.smallest_exchange_gap_minutes,
    b.average_exchange_gap_minutes,
    b.last_rapid_fire_exchange_end_effective_minute,
    toInt32(
        b.last_rapid_fire_exchange_end_effective_minute
      - b.first_rapid_fire_exchange_start_effective_minute
    ) AS match_rapid_fire_exchange_span_minutes,
    toUInt8(
        b.home_goals_in_rapid_fire_exchanges > 0
        AND b.away_goals_in_rapid_fire_exchanges > 0
    ) AS both_sides_scored_in_rapid_fire_flag,
    b.home_goals_in_rapid_fire_exchanges AS triggered_team_rapid_fire_goals,
    b.away_goals_in_rapid_fire_exchanges AS opponent_rapid_fire_goals,
    b.home_goals_in_rapid_fire_exchanges - b.away_goals_in_rapid_fire_exchanges
        AS rapid_fire_goals_delta,
    b.home_goals AS triggered_team_goals,
    b.away_goals AS opponent_goals,
    b.home_goals - b.away_goals AS goal_gap,
    b.total_shots_home AS triggered_team_total_shots,
    b.total_shots_away AS opponent_total_shots,
    b.total_shots_home - b.total_shots_away AS shot_volume_delta,
    b.shots_on_target_home AS triggered_team_shots_on_target,
    b.shots_on_target_away AS opponent_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * b.shots_on_target_home / nullIf(toFloat64(b.total_shots_home), 0),
        1
    ), 0.0)) AS triggered_team_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.shots_on_target_away / nullIf(toFloat64(b.total_shots_away), 0),
        1
    ), 0.0)) AS opponent_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.shots_on_target_home / nullIf(toFloat64(b.total_shots_home), 0), 1), 0.0)
        - coalesce(round(100.0 * b.shots_on_target_away / nullIf(toFloat64(b.total_shots_away), 0), 1), 0.0),
        1
    )) AS shot_accuracy_delta_pct,
    b.expected_goals_home AS triggered_team_xg,
    b.expected_goals_away AS opponent_xg,
    toFloat32(round(b.expected_goals_home - b.expected_goals_away, 3)) AS xg_delta,
    toFloat32(coalesce(round(
        100.0 * b.home_goals / nullIf(toFloat64(b.total_shots_home), 0),
        1
    ), 0.0)) AS triggered_team_shot_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * b.away_goals / nullIf(toFloat64(b.total_shots_away), 0),
        1
    ), 0.0)) AS opponent_shot_conversion_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.home_goals / nullIf(toFloat64(b.total_shots_home), 0), 1), 0.0)
        - coalesce(round(100.0 * b.away_goals / nullIf(toFloat64(b.total_shots_away), 0), 1), 0.0),
        1
    )) AS shot_conversion_delta_pct,
    b.big_chances_home AS triggered_team_big_chances,
    b.big_chances_away AS opponent_big_chances,
    b.big_chances_missed_home AS triggered_team_big_chances_missed,
    b.big_chances_missed_away AS opponent_big_chances_missed,
    b.touches_opposition_box_home AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_away AS opponent_touches_opposition_box,
    b.possession_home_pct AS triggered_team_possession_pct,
    b.possession_away_pct AS opponent_possession_pct,
    toFloat32(round(b.possession_home_pct - b.possession_away_pct, 1)) AS possession_delta_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0), 1), 0.0)
        - coalesce(round(100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct
FROM base_stats AS b

UNION ALL

SELECT
    b.match_id,
    b.match_date,
    b.home_team_id,
    b.home_team_name,
    b.away_team_id,
    b.away_team_name,
    b.home_score,
    b.away_score,
    'away' AS triggered_side,
    b.away_team_id AS triggered_team_id,
    b.away_team_name AS triggered_team_name,
    b.home_team_id AS opponent_team_id,
    b.home_team_name AS opponent_team_name,
    toInt32(3) AS trigger_threshold_rapid_fire_window_minutes,
    toInt32(1) AS trigger_threshold_min_rapid_fire_exchanges,
    b.match_rapid_fire_exchange_count,
    b.home_goals_in_rapid_fire_exchanges,
    b.away_goals_in_rapid_fire_exchanges,
    b.first_rapid_fire_exchange_start_effective_minute,
    b.first_rapid_fire_exchange_end_effective_minute,
    b.first_rapid_fire_exchange_gap_minutes,
    b.smallest_exchange_gap_minutes,
    b.average_exchange_gap_minutes,
    b.last_rapid_fire_exchange_end_effective_minute,
    toInt32(
        b.last_rapid_fire_exchange_end_effective_minute
      - b.first_rapid_fire_exchange_start_effective_minute
    ) AS match_rapid_fire_exchange_span_minutes,
    toUInt8(
        b.home_goals_in_rapid_fire_exchanges > 0
        AND b.away_goals_in_rapid_fire_exchanges > 0
    ) AS both_sides_scored_in_rapid_fire_flag,
    b.away_goals_in_rapid_fire_exchanges AS triggered_team_rapid_fire_goals,
    b.home_goals_in_rapid_fire_exchanges AS opponent_rapid_fire_goals,
    b.away_goals_in_rapid_fire_exchanges - b.home_goals_in_rapid_fire_exchanges
        AS rapid_fire_goals_delta,
    b.away_goals AS triggered_team_goals,
    b.home_goals AS opponent_goals,
    b.away_goals - b.home_goals AS goal_gap,
    b.total_shots_away AS triggered_team_total_shots,
    b.total_shots_home AS opponent_total_shots,
    b.total_shots_away - b.total_shots_home AS shot_volume_delta,
    b.shots_on_target_away AS triggered_team_shots_on_target,
    b.shots_on_target_home AS opponent_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * b.shots_on_target_away / nullIf(toFloat64(b.total_shots_away), 0),
        1
    ), 0.0)) AS triggered_team_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.shots_on_target_home / nullIf(toFloat64(b.total_shots_home), 0),
        1
    ), 0.0)) AS opponent_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.shots_on_target_away / nullIf(toFloat64(b.total_shots_away), 0), 1), 0.0)
        - coalesce(round(100.0 * b.shots_on_target_home / nullIf(toFloat64(b.total_shots_home), 0), 1), 0.0),
        1
    )) AS shot_accuracy_delta_pct,
    b.expected_goals_away AS triggered_team_xg,
    b.expected_goals_home AS opponent_xg,
    toFloat32(round(b.expected_goals_away - b.expected_goals_home, 3)) AS xg_delta,
    toFloat32(coalesce(round(
        100.0 * b.away_goals / nullIf(toFloat64(b.total_shots_away), 0),
        1
    ), 0.0)) AS triggered_team_shot_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * b.home_goals / nullIf(toFloat64(b.total_shots_home), 0),
        1
    ), 0.0)) AS opponent_shot_conversion_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.away_goals / nullIf(toFloat64(b.total_shots_away), 0), 1), 0.0)
        - coalesce(round(100.0 * b.home_goals / nullIf(toFloat64(b.total_shots_home), 0), 1), 0.0),
        1
    )) AS shot_conversion_delta_pct,
    b.big_chances_away AS triggered_team_big_chances,
    b.big_chances_home AS opponent_big_chances,
    b.big_chances_missed_away AS triggered_team_big_chances_missed,
    b.big_chances_missed_home AS opponent_big_chances_missed,
    b.touches_opposition_box_away AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_home AS opponent_touches_opposition_box,
    b.possession_away_pct AS triggered_team_possession_pct,
    b.possession_home_pct AS opponent_possession_pct,
    toFloat32(round(b.possession_away_pct - b.possession_home_pct, 1)) AS possession_delta_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0), 1), 0.0)
        - coalesce(round(100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct
FROM base_stats AS b;
