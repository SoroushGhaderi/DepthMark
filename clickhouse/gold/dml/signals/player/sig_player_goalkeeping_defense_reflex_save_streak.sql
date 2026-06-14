INSERT INTO gold.sig_player_goalkeeping_defense_reflex_save_streak (
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
    trigger_threshold_saves_in_window,
    trigger_threshold_rolling_window_minutes,
    triggered_player_saves_in_trigger_window,
    trigger_window_start_effective_minute,
    trigger_window_end_effective_minute,
    triggered_player_first_save_in_trigger_window_effective_minute,
    triggered_player_last_save_in_trigger_window_effective_minute,
    triggered_player_qualifying_save_windows_count,
    triggered_player_window_margin_saves,
    triggered_player_saves_match,
    triggered_player_shots_on_target_faced_match,
    triggered_player_goals_conceded_match,
    triggered_player_save_rate_match_pct,
    triggered_player_minutes_played,
    triggered_player_touches,
    triggered_player_total_passes,
    triggered_player_accurate_passes,
    triggered_player_pass_accuracy_pct,
    triggered_team_saves_in_trigger_window,
    opponent_saves_in_trigger_window,
    triggered_team_shots_on_target_faced_in_trigger_window,
    opponent_shots_on_target_faced_in_trigger_window,
    triggered_team_goals_conceded_in_trigger_window,
    opponent_goals_conceded_in_trigger_window,
    triggered_team_keeper_saves,
    opponent_keeper_saves,
    triggered_team_total_shots_faced,
    opponent_total_shots_faced,
    triggered_team_shots_on_target_faced,
    opponent_shots_on_target_faced,
    triggered_team_expected_goals_faced,
    opponent_expected_goals_faced,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct
)
-- Signal: sig_player_goalkeeping_defense_reflex_save_streak
-- Intent: detect short-burst goalkeeper shot-stopping streaks using save-event density and preserve bilateral pressure/control context.
-- Trigger: goalkeeper records at least 3 saves within a rolling 5-minute window in a finished match.
WITH keeper_shot_events AS (
    SELECT
        s.match_id,
        toInt32(assumeNotNull(s.keeper_id)) AS keeper_id,
        toInt64(coalesce(s.shot_id, 0)) AS shot_id,
        toInt32(
            coalesce(s.minute, s.goal_time, 0) + coalesce(s.minute_added, s.goal_overload_time, 0)
        ) AS shot_effective_minute,
        toUInt8(coalesce(s.is_on_target, 0)) AS is_on_target,
        toUInt8(coalesce(s.is_goal, 0)) AS is_goal,
        toUInt8(
            coalesce(s.is_on_target, 0) = 1
            AND coalesce(s.is_goal, 0) = 0
        ) AS is_save,
        multiIf(
            s.team_id = m.home_team_id, 'away',
            s.team_id = m.away_team_id, 'home',
            'unknown'
        ) AS keeper_side
    FROM silver.shot AS s
    INNER JOIN silver.match AS m
        ON m.match_id = s.match_id
    WHERE s.match_id > 0
      AND s.keeper_id IS NOT NULL
      AND m.match_finished = 1
      AND (s.team_id = m.home_team_id OR s.team_id = m.away_team_id)
      AND coalesce(s.minute, s.goal_time, 0) >= 0
),
keeper_save_events AS (
    SELECT
        kse.match_id,
        kse.keeper_id,
        kse.shot_id,
        kse.shot_effective_minute,
        kse.keeper_side
    FROM keeper_shot_events AS kse
    WHERE kse.is_save = 1
      AND kse.keeper_side IN ('home', 'away')
),
keeper_window_candidates AS (
    SELECT
        anchor.match_id,
        anchor.keeper_id,
        anchor.keeper_side,
        anchor.shot_id AS anchor_shot_id,
        anchor.shot_effective_minute AS trigger_window_start_effective_minute,
        toInt32(anchor.shot_effective_minute + 5) AS trigger_window_end_effective_minute,
        toInt32(count()) AS triggered_player_saves_in_trigger_window,
        toInt32(min(window_save.shot_effective_minute))
            AS triggered_player_first_save_in_trigger_window_effective_minute,
        toInt32(max(window_save.shot_effective_minute))
            AS triggered_player_last_save_in_trigger_window_effective_minute
    FROM keeper_save_events AS anchor
    INNER JOIN keeper_save_events AS window_save
        ON window_save.match_id = anchor.match_id
       AND window_save.keeper_id = anchor.keeper_id
    WHERE window_save.shot_effective_minute >= anchor.shot_effective_minute
      AND window_save.shot_effective_minute <= anchor.shot_effective_minute + 5
    GROUP BY
        anchor.match_id,
        anchor.keeper_id,
        anchor.keeper_side,
        anchor.shot_id,
        anchor.shot_effective_minute
),
ranked_keeper_windows AS (
    SELECT
        kwc.*,
        row_number() OVER (
            PARTITION BY kwc.match_id, kwc.keeper_id
            ORDER BY
                kwc.triggered_player_saves_in_trigger_window DESC,
                kwc.trigger_window_start_effective_minute ASC,
                kwc.trigger_window_end_effective_minute ASC,
                kwc.anchor_shot_id ASC
        ) AS trigger_window_rank
    FROM keeper_window_candidates AS kwc
),
best_keeper_window AS (
    SELECT
        rkw.match_id,
        rkw.keeper_id,
        rkw.keeper_side,
        rkw.trigger_window_start_effective_minute,
        rkw.trigger_window_end_effective_minute,
        rkw.triggered_player_saves_in_trigger_window,
        rkw.triggered_player_first_save_in_trigger_window_effective_minute,
        rkw.triggered_player_last_save_in_trigger_window_effective_minute
    FROM ranked_keeper_windows AS rkw
    WHERE rkw.trigger_window_rank = 1
      AND rkw.triggered_player_saves_in_trigger_window >= 3
),
keeper_qualifying_window_counts AS (
    SELECT
        kwc.match_id,
        kwc.keeper_id,
        toInt32(count()) AS triggered_player_qualifying_save_windows_count
    FROM keeper_window_candidates AS kwc
    WHERE kwc.triggered_player_saves_in_trigger_window >= 3
    GROUP BY
        kwc.match_id,
        kwc.keeper_id
),
keeper_match_totals AS (
    SELECT
        kse.match_id,
        kse.keeper_id,
        toInt32(countIf(kse.is_save = 1)) AS triggered_player_saves_match,
        toInt32(countIf(kse.is_on_target = 1)) AS triggered_player_shots_on_target_faced_match,
        toInt32(countIf(kse.is_on_target = 1 AND kse.is_goal = 1)) AS triggered_player_goals_conceded_match
    FROM keeper_shot_events AS kse
    GROUP BY
        kse.match_id,
        kse.keeper_id
),
window_bilateral_context AS (
    SELECT
        bkw.match_id,
        bkw.keeper_id,
        bkw.keeper_side,
        bkw.trigger_window_start_effective_minute,
        bkw.trigger_window_end_effective_minute,
        toInt32(sumIf(
            kse.is_save,
            kse.keeper_side = bkw.keeper_side
            AND kse.shot_effective_minute >= bkw.trigger_window_start_effective_minute
            AND kse.shot_effective_minute <= bkw.trigger_window_end_effective_minute
        ))
            AS triggered_team_saves_in_trigger_window,
        toInt32(sumIf(
            kse.is_save,
            kse.keeper_side != bkw.keeper_side
            AND kse.shot_effective_minute >= bkw.trigger_window_start_effective_minute
            AND kse.shot_effective_minute <= bkw.trigger_window_end_effective_minute
        ))
            AS opponent_saves_in_trigger_window,
        toInt32(sumIf(
            kse.is_on_target,
            kse.keeper_side = bkw.keeper_side
            AND kse.shot_effective_minute >= bkw.trigger_window_start_effective_minute
            AND kse.shot_effective_minute <= bkw.trigger_window_end_effective_minute
        ))
            AS triggered_team_shots_on_target_faced_in_trigger_window,
        toInt32(sumIf(
            kse.is_on_target,
            kse.keeper_side != bkw.keeper_side
            AND kse.shot_effective_minute >= bkw.trigger_window_start_effective_minute
            AND kse.shot_effective_minute <= bkw.trigger_window_end_effective_minute
        ))
            AS opponent_shots_on_target_faced_in_trigger_window,
        toInt32(sumIf(
            kse.is_goal,
            kse.keeper_side = bkw.keeper_side
            AND kse.shot_effective_minute >= bkw.trigger_window_start_effective_minute
            AND kse.shot_effective_minute <= bkw.trigger_window_end_effective_minute
        ))
            AS triggered_team_goals_conceded_in_trigger_window,
        toInt32(sumIf(
            kse.is_goal,
            kse.keeper_side != bkw.keeper_side
            AND kse.shot_effective_minute >= bkw.trigger_window_start_effective_minute
            AND kse.shot_effective_minute <= bkw.trigger_window_end_effective_minute
        ))
            AS opponent_goals_conceded_in_trigger_window
    FROM best_keeper_window AS bkw
    LEFT JOIN keeper_shot_events AS kse
        ON kse.match_id = bkw.match_id
       AND kse.keeper_side IN ('home', 'away')
    GROUP BY
        bkw.match_id,
        bkw.keeper_id,
        bkw.keeper_side,
        bkw.trigger_window_start_effective_minute,
        bkw.trigger_window_end_effective_minute
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

    bkw.keeper_side AS triggered_side,
    p.player_id AS triggered_player_id,
    coalesce(p.player_name, 'Unknown') AS triggered_player_name,
    if(bkw.keeper_side = 'home', m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(bkw.keeper_side = 'home', m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(bkw.keeper_side = 'home', m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(bkw.keeper_side = 'home', m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(3) AS trigger_threshold_saves_in_window,
    toInt32(5) AS trigger_threshold_rolling_window_minutes,
    toInt32(bkw.triggered_player_saves_in_trigger_window) AS triggered_player_saves_in_trigger_window,
    toInt32(bkw.trigger_window_start_effective_minute) AS trigger_window_start_effective_minute,
    toInt32(bkw.trigger_window_end_effective_minute) AS trigger_window_end_effective_minute,
    toInt32(bkw.triggered_player_first_save_in_trigger_window_effective_minute)
        AS triggered_player_first_save_in_trigger_window_effective_minute,
    toInt32(bkw.triggered_player_last_save_in_trigger_window_effective_minute)
        AS triggered_player_last_save_in_trigger_window_effective_minute,
    toInt32(coalesce(kqwc.triggered_player_qualifying_save_windows_count, 0))
        AS triggered_player_qualifying_save_windows_count,
    toInt32(bkw.triggered_player_saves_in_trigger_window - 3) AS triggered_player_window_margin_saves,

    toInt32(coalesce(kmt.triggered_player_saves_match, 0)) AS triggered_player_saves_match,
    toInt32(coalesce(kmt.triggered_player_shots_on_target_faced_match, 0))
        AS triggered_player_shots_on_target_faced_match,
    toInt32(coalesce(kmt.triggered_player_goals_conceded_match, 0))
        AS triggered_player_goals_conceded_match,
    toFloat32(coalesce(round(
        100.0 * coalesce(kmt.triggered_player_saves_match, 0)
            / nullIf(coalesce(kmt.triggered_player_shots_on_target_faced_match, 0), 0),
        1
    ), 0.0)) AS triggered_player_save_rate_match_pct,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,
    toInt32(coalesce(p.touches, 0)) AS triggered_player_touches,
    toInt32(coalesce(p.total_passes, 0)) AS triggered_player_total_passes,
    toInt32(coalesce(p.accurate_passes, 0)) AS triggered_player_accurate_passes,
    toFloat32(coalesce(
        p.pass_accuracy,
        round(
            100.0 * coalesce(p.accurate_passes, 0)
                / nullIf(coalesce(p.total_passes, 0), 0),
            1
        ),
        0.0
    )) AS triggered_player_pass_accuracy_pct,

    toInt32(coalesce(wbc.triggered_team_saves_in_trigger_window, 0)) AS triggered_team_saves_in_trigger_window,
    toInt32(coalesce(wbc.opponent_saves_in_trigger_window, 0)) AS opponent_saves_in_trigger_window,
    toInt32(coalesce(wbc.triggered_team_shots_on_target_faced_in_trigger_window, 0))
        AS triggered_team_shots_on_target_faced_in_trigger_window,
    toInt32(coalesce(wbc.opponent_shots_on_target_faced_in_trigger_window, 0))
        AS opponent_shots_on_target_faced_in_trigger_window,
    toInt32(coalesce(wbc.triggered_team_goals_conceded_in_trigger_window, 0))
        AS triggered_team_goals_conceded_in_trigger_window,
    toInt32(coalesce(wbc.opponent_goals_conceded_in_trigger_window, 0))
        AS opponent_goals_conceded_in_trigger_window,

    toInt32(multiIf(
        bkw.keeper_side = 'home', coalesce(ps.keeper_saves_home, 0),
        bkw.keeper_side = 'away', coalesce(ps.keeper_saves_away, 0),
        0
    )) AS triggered_team_keeper_saves,
    toInt32(multiIf(
        bkw.keeper_side = 'home', coalesce(ps.keeper_saves_away, 0),
        bkw.keeper_side = 'away', coalesce(ps.keeper_saves_home, 0),
        0
    )) AS opponent_keeper_saves,
    toInt32(multiIf(
        bkw.keeper_side = 'home', coalesce(ps.total_shots_away, 0),
        bkw.keeper_side = 'away', coalesce(ps.total_shots_home, 0),
        0
    )) AS triggered_team_total_shots_faced,
    toInt32(multiIf(
        bkw.keeper_side = 'home', coalesce(ps.total_shots_home, 0),
        bkw.keeper_side = 'away', coalesce(ps.total_shots_away, 0),
        0
    )) AS opponent_total_shots_faced,
    toInt32(multiIf(
        bkw.keeper_side = 'home', coalesce(ps.shots_on_target_away, 0),
        bkw.keeper_side = 'away', coalesce(ps.shots_on_target_home, 0),
        0
    )) AS triggered_team_shots_on_target_faced,
    toInt32(multiIf(
        bkw.keeper_side = 'home', coalesce(ps.shots_on_target_home, 0),
        bkw.keeper_side = 'away', coalesce(ps.shots_on_target_away, 0),
        0
    )) AS opponent_shots_on_target_faced,
    toFloat32(multiIf(
        bkw.keeper_side = 'home', coalesce(ps.expected_goals_away, 0),
        bkw.keeper_side = 'away', coalesce(ps.expected_goals_home, 0),
        0
    )) AS triggered_team_expected_goals_faced,
    toFloat32(multiIf(
        bkw.keeper_side = 'home', coalesce(ps.expected_goals_home, 0),
        bkw.keeper_side = 'away', coalesce(ps.expected_goals_away, 0),
        0
    )) AS opponent_expected_goals_faced,
    toFloat32(multiIf(
        bkw.keeper_side = 'home', coalesce(ps.ball_possession_home, 0),
        bkw.keeper_side = 'away', coalesce(ps.ball_possession_away, 0),
        0
    )) AS triggered_team_possession_pct,
    toFloat32(multiIf(
        bkw.keeper_side = 'home', coalesce(ps.ball_possession_away, 0),
        bkw.keeper_side = 'away', coalesce(ps.ball_possession_home, 0),
        0
    )) AS opponent_possession_pct,
    toFloat32(coalesce(round(
        100.0 * multiIf(
            bkw.keeper_side = 'home', coalesce(ps.accurate_passes_home, 0),
            bkw.keeper_side = 'away', coalesce(ps.accurate_passes_away, 0),
            0
        ) / nullIf(toFloat64(multiIf(
            bkw.keeper_side = 'home', coalesce(ps.pass_attempts_home, 0),
            bkw.keeper_side = 'away', coalesce(ps.pass_attempts_away, 0),
            0
        )), 0.0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * multiIf(
            bkw.keeper_side = 'home', coalesce(ps.accurate_passes_away, 0),
            bkw.keeper_side = 'away', coalesce(ps.accurate_passes_home, 0),
            0
        ) / nullIf(toFloat64(multiIf(
            bkw.keeper_side = 'home', coalesce(ps.pass_attempts_away, 0),
            bkw.keeper_side = 'away', coalesce(ps.pass_attempts_home, 0),
            0
        )), 0.0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct

FROM best_keeper_window AS bkw
INNER JOIN silver.match AS m
    ON m.match_id = bkw.match_id
INNER JOIN silver.player_match_stat AS p
    ON p.match_id = bkw.match_id
   AND p.player_id = bkw.keeper_id
LEFT JOIN keeper_match_totals AS kmt
    ON kmt.match_id = bkw.match_id
   AND kmt.keeper_id = bkw.keeper_id
LEFT JOIN keeper_qualifying_window_counts AS kqwc
    ON kqwc.match_id = bkw.match_id
   AND kqwc.keeper_id = bkw.keeper_id
LEFT JOIN window_bilateral_context AS wbc
    ON wbc.match_id = bkw.match_id
   AND wbc.keeper_id = bkw.keeper_id
   AND wbc.keeper_side = bkw.keeper_side
   AND wbc.trigger_window_start_effective_minute = bkw.trigger_window_start_effective_minute
   AND wbc.trigger_window_end_effective_minute = bkw.trigger_window_end_effective_minute
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = bkw.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND p.is_goalkeeper = 1
  AND (
        (bkw.keeper_side = 'home' AND p.team_id = m.home_team_id)
        OR (bkw.keeper_side = 'away' AND p.team_id = m.away_team_id)
  )

ORDER BY
    triggered_player_saves_in_trigger_window DESC,
    trigger_window_start_effective_minute ASC,
    triggered_player_save_rate_match_pct DESC,
    m.match_date DESC,
    m.match_id DESC,
    p.player_id ASC;
