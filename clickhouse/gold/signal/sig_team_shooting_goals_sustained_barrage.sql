INSERT INTO gold.sig_team_shooting_goals_sustained_barrage (
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
    trigger_threshold_window_shots,
    trigger_window_minutes,
    triggered_team_shots_in_trigger_window,
    opponent_shots_in_trigger_window,
    shots_in_trigger_window_delta,
    trigger_window_start_effective_minute,
    trigger_window_end_effective_minute,
    triggered_team_first_shot_in_trigger_window_effective_minute,
    triggered_team_last_shot_in_trigger_window_effective_minute,
    triggered_team_shots_on_target_in_trigger_window,
    opponent_shots_on_target_in_trigger_window,
    triggered_team_on_target_ratio_in_trigger_window_pct,
    opponent_on_target_ratio_in_trigger_window_pct,
    on_target_ratio_in_trigger_window_delta_pct,
    triggered_team_xg_in_trigger_window,
    opponent_xg_in_trigger_window,
    xg_in_trigger_window_delta,
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
    triggered_team_xg_per_shot,
    opponent_xg_per_shot,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
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
WITH shot_events AS (
    SELECT
        s.match_id,
        if(s.team_id = m.home_team_id, 'home', 'away') AS shot_side,
        s.team_id,
        toInt32(
            coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
        ) AS shot_effective_minute,
        toInt32(coalesce(s.is_on_target, 0)) AS is_on_target,
        toFloat32(coalesce(s.expected_goals, 0)) AS shot_xg
    FROM silver.shot AS s
    INNER JOIN silver.match AS m
        ON m.match_id = s.match_id
    WHERE s.match_id > 0
      AND m.match_finished = 1
      AND (s.team_id = m.home_team_id OR s.team_id = m.away_team_id)
      AND coalesce(s.minute, s.goal_time, 0) >= 0
),
team_window_candidates AS (
    SELECT
        anchor.match_id,
        anchor.team_id,
        anchor.shot_side AS triggered_side,
        anchor.shot_effective_minute AS trigger_window_start_effective_minute,
        toInt32(anchor.shot_effective_minute + 14) AS trigger_window_end_effective_minute,
        count() AS triggered_team_shots_in_trigger_window,
        toInt32(sum(window_shot.is_on_target)) AS triggered_team_shots_on_target_in_trigger_window,
        toFloat32(round(sum(window_shot.shot_xg), 3)) AS triggered_team_xg_in_trigger_window,
        min(window_shot.shot_effective_minute)
            AS triggered_team_first_shot_in_trigger_window_effective_minute,
        max(window_shot.shot_effective_minute)
            AS triggered_team_last_shot_in_trigger_window_effective_minute
    FROM shot_events AS anchor
    INNER JOIN shot_events AS window_shot
        ON window_shot.match_id = anchor.match_id
       AND window_shot.team_id = anchor.team_id
       AND window_shot.shot_effective_minute >= anchor.shot_effective_minute
       AND window_shot.shot_effective_minute <= anchor.shot_effective_minute + 14
    GROUP BY
        anchor.match_id,
        anchor.team_id,
        anchor.shot_side,
        anchor.shot_effective_minute
),
team_best_window AS (
    SELECT
        ranked.match_id,
        ranked.team_id,
        ranked.triggered_side,
        ranked.trigger_window_start_effective_minute,
        ranked.trigger_window_end_effective_minute,
        ranked.triggered_team_shots_in_trigger_window,
        ranked.triggered_team_shots_on_target_in_trigger_window,
        ranked.triggered_team_xg_in_trigger_window,
        ranked.triggered_team_first_shot_in_trigger_window_effective_minute,
        ranked.triggered_team_last_shot_in_trigger_window_effective_minute
    FROM (
        SELECT
            twc.*,
            row_number() OVER (
                PARTITION BY twc.match_id, twc.team_id
                ORDER BY
                    twc.triggered_team_shots_in_trigger_window DESC,
                    twc.trigger_window_start_effective_minute ASC,
                    twc.triggered_team_last_shot_in_trigger_window_effective_minute ASC
            ) AS trigger_window_rank
        FROM team_window_candidates AS twc
    ) AS ranked
    WHERE ranked.trigger_window_rank = 1
      AND ranked.triggered_team_shots_in_trigger_window >= 10
),
team_best_window_with_opponent AS (
    SELECT
        tbw.match_id,
        tbw.team_id,
        tbw.triggered_side,
        tbw.trigger_window_start_effective_minute,
        tbw.trigger_window_end_effective_minute,
        tbw.triggered_team_shots_in_trigger_window,
        tbw.triggered_team_shots_on_target_in_trigger_window,
        tbw.triggered_team_xg_in_trigger_window,
        tbw.triggered_team_first_shot_in_trigger_window_effective_minute,
        tbw.triggered_team_last_shot_in_trigger_window_effective_minute,
        toInt32(count(opp.match_id)) AS opponent_shots_in_trigger_window,
        toInt32(coalesce(sum(opp.is_on_target), 0)) AS opponent_shots_on_target_in_trigger_window,
        toFloat32(round(coalesce(sum(opp.shot_xg), 0), 3)) AS opponent_xg_in_trigger_window
    FROM team_best_window AS tbw
    LEFT JOIN shot_events AS opp
        ON opp.match_id = tbw.match_id
       AND opp.team_id != tbw.team_id
       AND opp.shot_effective_minute >= tbw.trigger_window_start_effective_minute
       AND opp.shot_effective_minute <= tbw.trigger_window_end_effective_minute
    GROUP BY
        tbw.match_id,
        tbw.team_id,
        tbw.triggered_side,
        tbw.trigger_window_start_effective_minute,
        tbw.trigger_window_end_effective_minute,
        tbw.triggered_team_shots_in_trigger_window,
        tbw.triggered_team_shots_on_target_in_trigger_window,
        tbw.triggered_team_xg_in_trigger_window,
        tbw.triggered_team_first_shot_in_trigger_window_effective_minute,
        tbw.triggered_team_last_shot_in_trigger_window_effective_minute
)
-- Signal: sig_team_shooting_goals_sustained_barrage
-- Trigger: team records >= 10 shots in a single 15-minute effective-minute window.
-- Intent: detect concentrated team shot barrages and preserve bilateral tactical context for severity and translation diagnostics.

-- Home-side trigger.
SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    'home' AS triggered_side,
    m.home_team_id AS triggered_team_id,
    m.home_team_name AS triggered_team_name,
    m.away_team_id AS opponent_team_id,
    m.away_team_name AS opponent_team_name,

    toInt32(10) AS trigger_threshold_window_shots,
    toInt32(15) AS trigger_window_minutes,
    toInt32(tbwo.triggered_team_shots_in_trigger_window) AS triggered_team_shots_in_trigger_window,
    toInt32(tbwo.opponent_shots_in_trigger_window) AS opponent_shots_in_trigger_window,
    toInt32(tbwo.triggered_team_shots_in_trigger_window - tbwo.opponent_shots_in_trigger_window)
        AS shots_in_trigger_window_delta,
    toInt32(tbwo.trigger_window_start_effective_minute) AS trigger_window_start_effective_minute,
    toInt32(tbwo.trigger_window_end_effective_minute) AS trigger_window_end_effective_minute,
    toInt32(tbwo.triggered_team_first_shot_in_trigger_window_effective_minute)
        AS triggered_team_first_shot_in_trigger_window_effective_minute,
    toInt32(tbwo.triggered_team_last_shot_in_trigger_window_effective_minute)
        AS triggered_team_last_shot_in_trigger_window_effective_minute,
    toInt32(tbwo.triggered_team_shots_on_target_in_trigger_window)
        AS triggered_team_shots_on_target_in_trigger_window,
    toInt32(tbwo.opponent_shots_on_target_in_trigger_window) AS opponent_shots_on_target_in_trigger_window,
    toFloat32(coalesce(round(
        100.0 * tbwo.triggered_team_shots_on_target_in_trigger_window
            / nullIf(tbwo.triggered_team_shots_in_trigger_window, 0),
        1
    ), 0.0)) AS triggered_team_on_target_ratio_in_trigger_window_pct,
    toFloat32(coalesce(round(
        100.0 * tbwo.opponent_shots_on_target_in_trigger_window
            / nullIf(tbwo.opponent_shots_in_trigger_window, 0),
        1
    ), 0.0)) AS opponent_on_target_ratio_in_trigger_window_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * tbwo.triggered_team_shots_on_target_in_trigger_window
                / nullIf(tbwo.triggered_team_shots_in_trigger_window, 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * tbwo.opponent_shots_on_target_in_trigger_window
                / nullIf(tbwo.opponent_shots_in_trigger_window, 0),
            1
        ), 0.0),
        1
    )) AS on_target_ratio_in_trigger_window_delta_pct,
    toFloat32(tbwo.triggered_team_xg_in_trigger_window) AS triggered_team_xg_in_trigger_window,
    toFloat32(tbwo.opponent_xg_in_trigger_window) AS opponent_xg_in_trigger_window,
    toFloat32(round(tbwo.triggered_team_xg_in_trigger_window - tbwo.opponent_xg_in_trigger_window, 3))
        AS xg_in_trigger_window_delta,

    toInt32(coalesce(ps.total_shots_home, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_away, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.total_shots_home, 0) - coalesce(ps.total_shots_away, 0)) AS total_shots_delta,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS opponent_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_home, 0) / nullIf(coalesce(ps.total_shots_home, 0), 0),
        1
    ), 0.0)) AS triggered_team_on_target_ratio_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_away, 0) / nullIf(coalesce(ps.total_shots_away, 0), 0),
        1
    ), 0.0)) AS opponent_on_target_ratio_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.shots_on_target_home, 0) / nullIf(coalesce(ps.total_shots_home, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.shots_on_target_away, 0) / nullIf(coalesce(ps.total_shots_away, 0), 0),
            1
        ), 0.0),
        1
    )) AS on_target_ratio_delta_pct,

    toFloat32(coalesce(ps.expected_goals_home, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_home, 0) - coalesce(ps.expected_goals_away, 0), 3)) AS xg_delta,
    toFloat32(coalesce(round(
        coalesce(ps.expected_goals_home, 0) / nullIf(toFloat32(coalesce(ps.total_shots_home, 0)), 0.0),
        3
    ), 0.0)) AS triggered_team_xg_per_shot,
    toFloat32(coalesce(round(
        coalesce(ps.expected_goals_away, 0) / nullIf(toFloat32(coalesce(ps.total_shots_away, 0)), 0.0),
        3
    ), 0.0)) AS opponent_xg_per_shot,

    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS opponent_touches_opposition_box,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_home, 0) - coalesce(ps.ball_possession_away, 0), 1))
        AS possession_delta_pct,

    toInt32(coalesce(ps.pass_attempts_home, 0)) AS triggered_team_pass_attempts,
    toInt32(coalesce(ps.pass_attempts_away, 0)) AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    toInt32(coalesce(ps.corners_home, 0)) AS triggered_team_corners,
    toInt32(coalesce(ps.corners_away, 0)) AS opponent_corners

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
INNER JOIN team_best_window_with_opponent AS tbwo
    ON tbwo.match_id = m.match_id
   AND tbwo.triggered_side = 'home'
WHERE m.match_finished = 1
  AND m.match_id > 0

UNION ALL

-- Away-side trigger.
SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    'away' AS triggered_side,
    m.away_team_id AS triggered_team_id,
    m.away_team_name AS triggered_team_name,
    m.home_team_id AS opponent_team_id,
    m.home_team_name AS opponent_team_name,

    toInt32(10) AS trigger_threshold_window_shots,
    toInt32(15) AS trigger_window_minutes,
    toInt32(tbwo.triggered_team_shots_in_trigger_window) AS triggered_team_shots_in_trigger_window,
    toInt32(tbwo.opponent_shots_in_trigger_window) AS opponent_shots_in_trigger_window,
    toInt32(tbwo.triggered_team_shots_in_trigger_window - tbwo.opponent_shots_in_trigger_window)
        AS shots_in_trigger_window_delta,
    toInt32(tbwo.trigger_window_start_effective_minute) AS trigger_window_start_effective_minute,
    toInt32(tbwo.trigger_window_end_effective_minute) AS trigger_window_end_effective_minute,
    toInt32(tbwo.triggered_team_first_shot_in_trigger_window_effective_minute)
        AS triggered_team_first_shot_in_trigger_window_effective_minute,
    toInt32(tbwo.triggered_team_last_shot_in_trigger_window_effective_minute)
        AS triggered_team_last_shot_in_trigger_window_effective_minute,
    toInt32(tbwo.triggered_team_shots_on_target_in_trigger_window)
        AS triggered_team_shots_on_target_in_trigger_window,
    toInt32(tbwo.opponent_shots_on_target_in_trigger_window) AS opponent_shots_on_target_in_trigger_window,
    toFloat32(coalesce(round(
        100.0 * tbwo.triggered_team_shots_on_target_in_trigger_window
            / nullIf(tbwo.triggered_team_shots_in_trigger_window, 0),
        1
    ), 0.0)) AS triggered_team_on_target_ratio_in_trigger_window_pct,
    toFloat32(coalesce(round(
        100.0 * tbwo.opponent_shots_on_target_in_trigger_window
            / nullIf(tbwo.opponent_shots_in_trigger_window, 0),
        1
    ), 0.0)) AS opponent_on_target_ratio_in_trigger_window_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * tbwo.triggered_team_shots_on_target_in_trigger_window
                / nullIf(tbwo.triggered_team_shots_in_trigger_window, 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * tbwo.opponent_shots_on_target_in_trigger_window
                / nullIf(tbwo.opponent_shots_in_trigger_window, 0),
            1
        ), 0.0),
        1
    )) AS on_target_ratio_in_trigger_window_delta_pct,
    toFloat32(tbwo.triggered_team_xg_in_trigger_window) AS triggered_team_xg_in_trigger_window,
    toFloat32(tbwo.opponent_xg_in_trigger_window) AS opponent_xg_in_trigger_window,
    toFloat32(round(tbwo.triggered_team_xg_in_trigger_window - tbwo.opponent_xg_in_trigger_window, 3))
        AS xg_in_trigger_window_delta,

    toInt32(coalesce(ps.total_shots_away, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_home, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.total_shots_away, 0) - coalesce(ps.total_shots_home, 0)) AS total_shots_delta,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS opponent_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_away, 0) / nullIf(coalesce(ps.total_shots_away, 0), 0),
        1
    ), 0.0)) AS triggered_team_on_target_ratio_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_home, 0) / nullIf(coalesce(ps.total_shots_home, 0), 0),
        1
    ), 0.0)) AS opponent_on_target_ratio_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.shots_on_target_away, 0) / nullIf(coalesce(ps.total_shots_away, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.shots_on_target_home, 0) / nullIf(coalesce(ps.total_shots_home, 0), 0),
            1
        ), 0.0),
        1
    )) AS on_target_ratio_delta_pct,

    toFloat32(coalesce(ps.expected_goals_away, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_away, 0) - coalesce(ps.expected_goals_home, 0), 3)) AS xg_delta,
    toFloat32(coalesce(round(
        coalesce(ps.expected_goals_away, 0) / nullIf(toFloat32(coalesce(ps.total_shots_away, 0)), 0.0),
        3
    ), 0.0)) AS triggered_team_xg_per_shot,
    toFloat32(coalesce(round(
        coalesce(ps.expected_goals_home, 0) / nullIf(toFloat32(coalesce(ps.total_shots_home, 0)), 0.0),
        3
    ), 0.0)) AS opponent_xg_per_shot,

    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS opponent_touches_opposition_box,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_away, 0) - coalesce(ps.ball_possession_home, 0), 1))
        AS possession_delta_pct,

    toInt32(coalesce(ps.pass_attempts_away, 0)) AS triggered_team_pass_attempts,
    toInt32(coalesce(ps.pass_attempts_home, 0)) AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    toInt32(coalesce(ps.corners_away, 0)) AS triggered_team_corners,
    toInt32(coalesce(ps.corners_home, 0)) AS opponent_corners

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
INNER JOIN team_best_window_with_opponent AS tbwo
    ON tbwo.match_id = m.match_id
   AND tbwo.triggered_side = 'away'
WHERE m.match_finished = 1
  AND m.match_id > 0

ORDER BY
    triggered_team_shots_in_trigger_window DESC,
    triggered_team_xg_in_trigger_window DESC,
    m.match_date DESC,
    m.match_id DESC;
