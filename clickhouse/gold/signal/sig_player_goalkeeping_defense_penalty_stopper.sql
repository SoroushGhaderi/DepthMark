INSERT INTO gold.sig_player_goalkeeping_defense_penalty_stopper (
    match_id,
    match_date,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,
    triggered_side,
    triggered_player_id,
    triggered_player_name,
    triggered_team_id,
    triggered_team_name,
    opponent_team_id,
    opponent_team_name,
    trigger_threshold_penalties_saved,
    triggered_player_penalties_saved,
    triggered_player_first_penalty_save_minute,
    triggered_player_total_penalty_shots_faced,
    triggered_player_penalty_goals_conceded,
    triggered_player_penalty_save_success_pct,
    triggered_player_penalty_saved_expected_goals_on_target_total,
    triggered_player_penalty_saved_expected_goals_on_target_avg,
    triggered_player_minutes_played,
    triggered_team_score_at_first_penalty_save,
    opponent_score_at_first_penalty_save,
    score_margin_at_first_penalty_save,
    triggered_team_penalties_faced,
    opponent_penalties_faced,
    triggered_team_penalty_goals_conceded,
    opponent_penalty_goals_conceded,
    triggered_team_penalty_saves,
    opponent_penalty_saves,
    triggered_team_keeper_saves,
    opponent_keeper_saves,
    triggered_team_shots_on_target_faced,
    opponent_shots_on_target_faced,
    triggered_team_expected_goals_on_target_faced,
    opponent_expected_goals_on_target_faced,
    triggered_team_possession_pct,
    opponent_possession_pct
)
-- Signal: sig_player_goalkeeping_defense_penalty_stopper
-- Intent: isolate goalkeepers who save penalties and preserve bilateral match-pressure context.
-- Trigger: goalkeeper records at least one saved penalty kick in a finished match.
WITH penalty_attempts_all AS (
    SELECT
        s.match_id,
        s.shot_id,
        if(s.team_id = m.home_team_id, 'home', 'away') AS penalty_taking_side,
        if(s.team_id = m.home_team_id, 'away', 'home') AS penalty_defending_side,
        toInt32(coalesce(s.minute, 0)) AS penalty_minute,
        toInt32(coalesce(s.minute_added, 0)) AS penalty_added_time,
        toInt32(coalesce(s.home_score_after, 0)) AS home_score_after_penalty_event,
        toInt32(coalesce(s.away_score_after, 0)) AS away_score_after_penalty_event,
        toUInt8(coalesce(s.is_on_target, 0)) AS is_on_target,
        toUInt8(coalesce(s.is_saved_off_line, 0)) AS is_saved_off_line,
        toUInt8(
            coalesce(s.is_goal, 0) = 1
            OR positionCaseInsensitiveUTF8(coalesce(s.event_type, ''), 'goal') > 0
        ) AS is_penalty_goal,
        s.keeper_id,
        toFloat32(coalesce(s.expected_goals_on_target, s.expected_goals, 0.0))
            AS penalty_expected_goals_on_target
    FROM silver.shot AS s
    INNER JOIN silver.match AS m
        ON m.match_id = s.match_id
    WHERE m.match_finished = 1
      AND s.match_id > 0
      AND (s.team_id = m.home_team_id OR s.team_id = m.away_team_id)
      AND (
            positionCaseInsensitiveUTF8(coalesce(s.situation, ''), 'penalty') > 0
            OR positionCaseInsensitiveUTF8(coalesce(s.shot_type, ''), 'penalty') > 0
      )
),
penalty_saved_events AS (
    SELECT
        pa.match_id,
        pa.shot_id,
        toInt32(coalesce(pa.keeper_id, 0)) AS keeper_id,
        pa.penalty_defending_side,
        pa.penalty_minute,
        pa.penalty_added_time,
        pa.home_score_after_penalty_event,
        pa.away_score_after_penalty_event,
        pa.penalty_expected_goals_on_target
    FROM penalty_attempts_all AS pa
    WHERE pa.keeper_id IS NOT NULL
      AND coalesce(pa.keeper_id, 0) > 0
      AND pa.is_penalty_goal = 0
      AND pa.is_on_target = 1
      AND pa.is_saved_off_line = 0
),
player_penalty_save_rollup AS (
    SELECT
        pse.match_id,
        pse.keeper_id AS triggered_player_id,
        argMin(
            pse.penalty_defending_side,
            tuple(pse.penalty_minute, pse.penalty_added_time, pse.shot_id)
        ) AS triggered_side_from_events,
        min(pse.penalty_minute) AS triggered_player_first_penalty_save_minute,
        argMin(
            pse.home_score_after_penalty_event,
            tuple(pse.penalty_minute, pse.penalty_added_time, pse.shot_id)
        ) AS home_score_at_first_penalty_save,
        argMin(
            pse.away_score_after_penalty_event,
            tuple(pse.penalty_minute, pse.penalty_added_time, pse.shot_id)
        ) AS away_score_at_first_penalty_save,
        toInt32(countDistinct(pse.shot_id)) AS triggered_player_penalties_saved,
        toFloat32(round(sum(pse.penalty_expected_goals_on_target), 3))
            AS triggered_player_penalty_saved_expected_goals_on_target_total,
        toFloat32(round(avg(pse.penalty_expected_goals_on_target), 3))
            AS triggered_player_penalty_saved_expected_goals_on_target_avg
    FROM penalty_saved_events AS pse
    GROUP BY
        pse.match_id,
        triggered_player_id
),
keeper_penalty_faced_rollup AS (
    SELECT
        pa.match_id,
        toInt32(coalesce(pa.keeper_id, 0)) AS triggered_player_id,
        toInt32(countDistinct(pa.shot_id)) AS triggered_player_total_penalty_shots_faced,
        toInt32(countIf(pa.is_penalty_goal = 1)) AS triggered_player_penalty_goals_conceded
    FROM penalty_attempts_all AS pa
    WHERE pa.keeper_id IS NOT NULL
      AND coalesce(pa.keeper_id, 0) > 0
    GROUP BY
        pa.match_id,
        triggered_player_id
),
match_penalty_totals AS (
    SELECT
        pa.match_id,
        toInt32(countIf(pa.penalty_taking_side = 'home')) AS home_penalty_attempts,
        toInt32(countIf(pa.penalty_taking_side = 'away')) AS away_penalty_attempts,
        toInt32(countIf(pa.penalty_taking_side = 'home' AND pa.is_penalty_goal = 1))
            AS home_penalty_goals,
        toInt32(countIf(pa.penalty_taking_side = 'away' AND pa.is_penalty_goal = 1))
            AS away_penalty_goals,
        toInt32(countIf(
            pa.penalty_taking_side = 'away'
            AND pa.is_penalty_goal = 0
            AND pa.is_on_target = 1
            AND pa.is_saved_off_line = 0
            AND pa.keeper_id IS NOT NULL
            AND coalesce(pa.keeper_id, 0) > 0
        )) AS home_penalty_saves_by_keeper,
        toInt32(countIf(
            pa.penalty_taking_side = 'home'
            AND pa.is_penalty_goal = 0
            AND pa.is_on_target = 1
            AND pa.is_saved_off_line = 0
            AND pa.keeper_id IS NOT NULL
            AND coalesce(pa.keeper_id, 0) > 0
        )) AS away_penalty_saves_by_keeper
    FROM penalty_attempts_all AS pa
    GROUP BY pa.match_id
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

    if(p.team_id = m.home_team_id, 'home', 'away') AS triggered_side,
    p.player_id AS triggered_player_id,
    coalesce(p.player_name, 'Unknown') AS triggered_player_name,
    if(p.team_id = m.home_team_id, m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(p.team_id = m.home_team_id, m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(p.team_id = m.home_team_id, m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(p.team_id = m.home_team_id, m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(1) AS trigger_threshold_penalties_saved,
    toInt32(pps.triggered_player_penalties_saved) AS triggered_player_penalties_saved,
    toInt32(pps.triggered_player_first_penalty_save_minute)
        AS triggered_player_first_penalty_save_minute,
    toInt32(coalesce(kpf.triggered_player_total_penalty_shots_faced, 0))
        AS triggered_player_total_penalty_shots_faced,
    toInt32(coalesce(kpf.triggered_player_penalty_goals_conceded, 0))
        AS triggered_player_penalty_goals_conceded,
    toFloat32(coalesce(round(
        100.0 * pps.triggered_player_penalties_saved
        / nullIf(coalesce(kpf.triggered_player_total_penalty_shots_faced, 0), 0),
        1
    ), 0.0)) AS triggered_player_penalty_save_success_pct,
    pps.triggered_player_penalty_saved_expected_goals_on_target_total,
    pps.triggered_player_penalty_saved_expected_goals_on_target_avg,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,
    toInt32(
        if(
            p.team_id = m.home_team_id,
            pps.home_score_at_first_penalty_save,
            pps.away_score_at_first_penalty_save
        )
    ) AS triggered_team_score_at_first_penalty_save,
    toInt32(
        if(
            p.team_id = m.home_team_id,
            pps.away_score_at_first_penalty_save,
            pps.home_score_at_first_penalty_save
        )
    ) AS opponent_score_at_first_penalty_save,
    toInt32(
        if(
            p.team_id = m.home_team_id,
            pps.home_score_at_first_penalty_save - pps.away_score_at_first_penalty_save,
            pps.away_score_at_first_penalty_save - pps.home_score_at_first_penalty_save
        )
    ) AS score_margin_at_first_penalty_save,

    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(mpt.away_penalty_attempts, 0),
        p.team_id = m.away_team_id, coalesce(mpt.home_penalty_attempts, 0),
        0
    )) AS triggered_team_penalties_faced,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(mpt.home_penalty_attempts, 0),
        p.team_id = m.away_team_id, coalesce(mpt.away_penalty_attempts, 0),
        0
    )) AS opponent_penalties_faced,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(mpt.away_penalty_goals, 0),
        p.team_id = m.away_team_id, coalesce(mpt.home_penalty_goals, 0),
        0
    )) AS triggered_team_penalty_goals_conceded,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(mpt.home_penalty_goals, 0),
        p.team_id = m.away_team_id, coalesce(mpt.away_penalty_goals, 0),
        0
    )) AS opponent_penalty_goals_conceded,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(mpt.home_penalty_saves_by_keeper, 0),
        p.team_id = m.away_team_id, coalesce(mpt.away_penalty_saves_by_keeper, 0),
        0
    )) AS triggered_team_penalty_saves,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(mpt.away_penalty_saves_by_keeper, 0),
        p.team_id = m.away_team_id, coalesce(mpt.home_penalty_saves_by_keeper, 0),
        0
    )) AS opponent_penalty_saves,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.keeper_saves_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.keeper_saves_away, 0),
        0
    )) AS triggered_team_keeper_saves,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.keeper_saves_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.keeper_saves_home, 0),
        0
    )) AS opponent_keeper_saves,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.shots_on_target_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.shots_on_target_home, 0),
        0
    )) AS triggered_team_shots_on_target_faced,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.shots_on_target_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.shots_on_target_away, 0),
        0
    )) AS opponent_shots_on_target_faced,
    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.expected_goals_on_target_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.expected_goals_on_target_home, 0),
        0
    )) AS triggered_team_expected_goals_on_target_faced,
    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.expected_goals_on_target_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.expected_goals_on_target_away, 0),
        0
    )) AS opponent_expected_goals_on_target_faced,
    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.ball_possession_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.ball_possession_away, 0),
        0
    )) AS triggered_team_possession_pct,
    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.ball_possession_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.ball_possession_home, 0),
        0
    )) AS opponent_possession_pct
FROM player_penalty_save_rollup AS pps
INNER JOIN silver.player_match_stat AS p
    ON p.match_id = pps.match_id
   AND p.player_id = pps.triggered_player_id
INNER JOIN silver.match AS m
    ON m.match_id = pps.match_id
LEFT JOIN keeper_penalty_faced_rollup AS kpf
    ON kpf.match_id = pps.match_id
   AND kpf.triggered_player_id = pps.triggered_player_id
LEFT JOIN match_penalty_totals AS mpt
    ON mpt.match_id = pps.match_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = pps.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND p.player_id > 0
  AND p.is_goalkeeper = 1
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)
  AND pps.triggered_player_penalties_saved >= 1
  AND (
        (pps.triggered_side_from_events = 'home' AND p.team_id = m.home_team_id)
        OR
        (pps.triggered_side_from_events = 'away' AND p.team_id = m.away_team_id)
      )
ORDER BY
    triggered_player_penalties_saved DESC,
    triggered_player_penalty_saved_expected_goals_on_target_total DESC,
    triggered_player_first_penalty_save_minute ASC,
    m.match_date DESC,
    m.match_id DESC,
    p.player_id ASC;
