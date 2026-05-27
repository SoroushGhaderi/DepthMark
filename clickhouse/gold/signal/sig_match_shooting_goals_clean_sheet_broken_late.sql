INSERT INTO gold.sig_match_shooting_goals_clean_sheet_broken_late (
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
    trigger_threshold_min_first_goal_effective_minute,
    trigger_threshold_max_home_score_before_first_goal,
    trigger_threshold_max_away_score_before_first_goal,
    first_goal_side,
    first_goal_scoring_team_id,
    first_goal_scoring_team_name,
    first_goal_conceding_team_id,
    first_goal_conceding_team_name,
    first_goal_minute,
    first_goal_added_time,
    first_goal_effective_minute,
    home_score_before_first_goal,
    away_score_before_first_goal,
    home_score_after_first_goal,
    away_score_after_first_goal,
    scoreline_zero_zero_before_first_goal_flag,
    match_total_goals,
    goals_after_first_goal,
    first_goal_scoring_side_won_match_flag,
    triggered_team_scored_first_goal_flag,
    triggered_team_clean_sheet_broken_flag,
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
-- Signal: sig_match_shooting_goals_clean_sheet_broken_late
-- Intent: detect finished matches where the first non-own goal arrives after the 88th minute,
--         breaking a 0-0 scoreline, then emit bilateral shooting and control context.
-- Trigger: first_goal_effective_minute >= 89 and score before first goal is 0-0.
WITH goal_events AS (
    SELECT
        s.match_id,
        if(coalesce(s.is_home_goal, 0) = 1, 'home', 'away') AS goal_side,
        toInt32(coalesce(s.goal_time, s.minute, 0)) AS goal_minute,
        toInt32(coalesce(s.goal_overload_time, s.minute_added, 0)) AS goal_added_time,
        toInt32(
            coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
        ) AS goal_effective_minute,
        toInt32(coalesce(s.home_score_after, 0)) AS home_score_after_goal,
        toInt32(coalesce(s.away_score_after, 0)) AS away_score_after_goal,
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
        ge.home_score_after_goal,
        ge.away_score_after_goal,
        toInt32(if(
            ge.goal_side = 'home',
            ge.home_score_after_goal - 1,
            ge.home_score_after_goal
        )) AS home_score_before_goal,
        toInt32(if(
            ge.goal_side = 'away',
            ge.away_score_after_goal - 1,
            ge.away_score_after_goal
        )) AS away_score_before_goal,
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
first_goal_events AS (
    SELECT
        oge.match_id,
        oge.goal_side AS first_goal_side,
        oge.goal_minute AS first_goal_minute,
        oge.goal_added_time AS first_goal_added_time,
        oge.goal_effective_minute AS first_goal_effective_minute,
        oge.home_score_before_goal AS home_score_before_first_goal,
        oge.away_score_before_goal AS away_score_before_first_goal,
        oge.home_score_after_goal AS home_score_after_first_goal,
        oge.away_score_after_goal AS away_score_after_first_goal
    FROM ordered_goal_events AS oge
    WHERE oge.goal_event_order = 1
      AND oge.goal_effective_minute >= 89
      AND oge.home_score_before_goal = 0
      AND oge.away_score_before_goal = 0
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
        fge.first_goal_side,
        fge.first_goal_minute,
        fge.first_goal_added_time,
        fge.first_goal_effective_minute,
        fge.home_score_before_first_goal,
        fge.away_score_before_first_goal,
        fge.home_score_after_first_goal,
        fge.away_score_after_first_goal,
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
        coalesce(ps.pass_attempts_away, 0) AS pass_attempts_away,
        coalesce(m.home_score, 0) + coalesce(m.away_score, 0) AS match_total_goals
    FROM silver.match AS m
    INNER JOIN first_goal_events AS fge
        ON fge.match_id = m.match_id
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.match_date = m.match_date
       AND ps.period = 'All'
    WHERE m.match_finished = 1
      AND m.match_id > 0
)

SELECT
    bs.match_id AS match_id,
    bs.match_date AS match_date,
    bs.home_team_id AS home_team_id,
    bs.home_team_name AS home_team_name,
    bs.away_team_id AS away_team_id,
    bs.away_team_name AS away_team_name,
    bs.home_score AS home_score,
    bs.away_score AS away_score,
    side.triggered_side AS triggered_side,
    if(side.triggered_side = 'home', home_team_id, away_team_id) AS triggered_team_id,
    if(side.triggered_side = 'home', home_team_name, away_team_name) AS triggered_team_name,
    if(side.triggered_side = 'home', away_team_id, home_team_id) AS opponent_team_id,
    if(side.triggered_side = 'home', away_team_name, home_team_name) AS opponent_team_name,
    toInt32(89) AS trigger_threshold_min_first_goal_effective_minute,
    toInt32(0) AS trigger_threshold_max_home_score_before_first_goal,
    toInt32(0) AS trigger_threshold_max_away_score_before_first_goal,
    first_goal_side,
    if(first_goal_side = 'home', home_team_id, away_team_id) AS first_goal_scoring_team_id,
    if(first_goal_side = 'home', home_team_name, away_team_name) AS first_goal_scoring_team_name,
    if(first_goal_side = 'home', away_team_id, home_team_id) AS first_goal_conceding_team_id,
    if(first_goal_side = 'home', away_team_name, home_team_name) AS first_goal_conceding_team_name,
    first_goal_minute,
    first_goal_added_time,
    first_goal_effective_minute,
    home_score_before_first_goal,
    away_score_before_first_goal,
    home_score_after_first_goal,
    away_score_after_first_goal,
    toUInt8(home_score_before_first_goal = 0 AND away_score_before_first_goal = 0)
        AS scoreline_zero_zero_before_first_goal_flag,
    match_total_goals,
    toInt32(match_total_goals - 1) AS goals_after_first_goal,
    toUInt8(if(
        first_goal_side = 'home',
        home_goals > away_goals,
        away_goals > home_goals
    )) AS first_goal_scoring_side_won_match_flag,
    toUInt8(side.triggered_side = first_goal_side) AS triggered_team_scored_first_goal_flag,
    toUInt8(side.triggered_side != first_goal_side) AS triggered_team_clean_sheet_broken_flag,
    if(side.triggered_side = 'home', home_goals, away_goals) AS triggered_team_goals,
    if(side.triggered_side = 'home', away_goals, home_goals) AS opponent_goals,
    if(side.triggered_side = 'home', home_goals - away_goals, away_goals - home_goals)
        AS goal_gap,
    if(side.triggered_side = 'home', total_shots_home, total_shots_away) AS triggered_team_total_shots,
    if(side.triggered_side = 'home', total_shots_away, total_shots_home) AS opponent_total_shots,
    if(side.triggered_side = 'home', total_shots_home - total_shots_away, total_shots_away - total_shots_home)
        AS shot_volume_delta,
    if(side.triggered_side = 'home', shots_on_target_home, shots_on_target_away) AS triggered_team_shots_on_target,
    if(side.triggered_side = 'home', shots_on_target_away, shots_on_target_home) AS opponent_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * if(side.triggered_side = 'home', shots_on_target_home, shots_on_target_away)
        / nullIf(toFloat64(if(side.triggered_side = 'home', total_shots_home, total_shots_away)), 0),
        1
    ), 0.0)) AS triggered_team_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * if(side.triggered_side = 'home', shots_on_target_away, shots_on_target_home)
        / nullIf(toFloat64(if(side.triggered_side = 'home', total_shots_away, total_shots_home)), 0),
        1
    ), 0.0)) AS opponent_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * if(side.triggered_side = 'home', shots_on_target_home, shots_on_target_away)
            / nullIf(toFloat64(if(side.triggered_side = 'home', total_shots_home, total_shots_away)), 0),
            1
        ), 0.0)
        - coalesce(round(
            100.0 * if(side.triggered_side = 'home', shots_on_target_away, shots_on_target_home)
            / nullIf(toFloat64(if(side.triggered_side = 'home', total_shots_away, total_shots_home)), 0),
            1
        ), 0.0),
        1
    )) AS shot_accuracy_delta_pct,
    if(side.triggered_side = 'home', expected_goals_home, expected_goals_away) AS triggered_team_xg,
    if(side.triggered_side = 'home', expected_goals_away, expected_goals_home) AS opponent_xg,
    toFloat32(round(
        if(side.triggered_side = 'home', expected_goals_home - expected_goals_away, expected_goals_away - expected_goals_home),
        3
    )) AS xg_delta,
    toFloat32(coalesce(round(
        100.0 * if(side.triggered_side = 'home', home_goals, away_goals)
        / nullIf(toFloat64(if(side.triggered_side = 'home', total_shots_home, total_shots_away)), 0),
        1
    ), 0.0)) AS triggered_team_shot_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * if(side.triggered_side = 'home', away_goals, home_goals)
        / nullIf(toFloat64(if(side.triggered_side = 'home', total_shots_away, total_shots_home)), 0),
        1
    ), 0.0)) AS opponent_shot_conversion_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * if(side.triggered_side = 'home', home_goals, away_goals)
            / nullIf(toFloat64(if(side.triggered_side = 'home', total_shots_home, total_shots_away)), 0),
            1
        ), 0.0)
        - coalesce(round(
            100.0 * if(side.triggered_side = 'home', away_goals, home_goals)
            / nullIf(toFloat64(if(side.triggered_side = 'home', total_shots_away, total_shots_home)), 0),
            1
        ), 0.0),
        1
    )) AS shot_conversion_delta_pct,
    if(side.triggered_side = 'home', big_chances_home, big_chances_away) AS triggered_team_big_chances,
    if(side.triggered_side = 'home', big_chances_away, big_chances_home) AS opponent_big_chances,
    if(side.triggered_side = 'home', big_chances_missed_home, big_chances_missed_away) AS triggered_team_big_chances_missed,
    if(side.triggered_side = 'home', big_chances_missed_away, big_chances_missed_home) AS opponent_big_chances_missed,
    if(side.triggered_side = 'home', big_chances_missed_home - big_chances_missed_away, big_chances_missed_away - big_chances_missed_home)
        AS big_chances_missed_delta,
    if(side.triggered_side = 'home', touches_opposition_box_home, touches_opposition_box_away) AS triggered_team_touches_opposition_box,
    if(side.triggered_side = 'home', touches_opposition_box_away, touches_opposition_box_home) AS opponent_touches_opposition_box,
    if(side.triggered_side = 'home', touches_opposition_box_home - touches_opposition_box_away, touches_opposition_box_away - touches_opposition_box_home)
        AS opposition_box_touch_delta,
    if(side.triggered_side = 'home', possession_home_pct, possession_away_pct) AS triggered_team_possession_pct,
    if(side.triggered_side = 'home', possession_away_pct, possession_home_pct) AS opponent_possession_pct,
    toFloat32(round(
        if(side.triggered_side = 'home', possession_home_pct - possession_away_pct, possession_away_pct - possession_home_pct),
        1
    )) AS possession_delta_pct,
    toFloat32(coalesce(round(
        100.0 * if(side.triggered_side = 'home', accurate_passes_home, accurate_passes_away)
        / nullIf(toFloat64(if(side.triggered_side = 'home', pass_attempts_home, pass_attempts_away)), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * if(side.triggered_side = 'home', accurate_passes_away, accurate_passes_home)
        / nullIf(toFloat64(if(side.triggered_side = 'home', pass_attempts_away, pass_attempts_home)), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * if(side.triggered_side = 'home', accurate_passes_home, accurate_passes_away)
            / nullIf(toFloat64(if(side.triggered_side = 'home', pass_attempts_home, pass_attempts_away)), 0),
            1
        ), 0.0)
        - coalesce(round(
            100.0 * if(side.triggered_side = 'home', accurate_passes_away, accurate_passes_home)
            / nullIf(toFloat64(if(side.triggered_side = 'home', pass_attempts_away, pass_attempts_home)), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct
FROM base_stats AS bs
CROSS JOIN (
    SELECT arrayJoin(['home', 'away']) AS triggered_side
) AS side;
