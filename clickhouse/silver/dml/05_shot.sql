INSERT INTO fotmob_silver.shot
SELECT
    s.match_id,
    ifNull(toDate(parseDateTimeBestEffortOrNull(g.match_time_utc_date)), ifNull(toDate(parseDateTimeBestEffortOrNull(g.match_time_utc)), toDate('1970-01-01'))) AS match_date,
    s.shot_id,
    s.event_type,
    s.team_id, s.player_id, s.player_name, s.keeper_id,
    s.minute,
    s.minute_added,
    s.period,
    s.x, s.y,
    s.shot_type, s.situation,
    s.is_on_target, s.is_blocked, s.is_saved_off_line, s.is_from_inside_box,
    s.blocked_x, s.blocked_y,
    s.goal_crossed_y, s.goal_crossed_z,
    s.on_goal_shot_x, s.on_goal_shot_y,
    s.expected_goals, s.expected_goals_on_target,
    toUInt8(gl.event_id IS NOT NULL) AS is_goal,
    ifNull(s.is_own_goal, 0) AS is_own_goal,
    gl.goal_time,
    gl.goal_overload_time,
    gl.home_score AS home_score_after,
    gl.away_score AS away_score_after,
    gl.is_home AS is_home_goal,
    gl.goal_description,
    gl.assist_player_id,
    gl.assist_player_name,
    now() AS _loaded_at
FROM fotmob_bronze.shotmap AS s FINAL
LEFT JOIN fotmob_bronze.goal AS gl FINAL ON s.match_id = gl.match_id AND s.shot_id = gl.shot_event_id
LEFT JOIN fotmob_bronze.general AS g FINAL ON s.match_id = g.match_id;
