INSERT INTO gold.sig_team_shooting_goals_late_game_salvage (
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
    trigger_threshold_min_goal_effective_minute,
    trigger_threshold_min_late_salvage_goals,
    triggered_team_late_salvage_goals,
    triggered_team_late_tying_goals,
    triggered_team_late_winning_goals,
    opponent_late_salvage_goals,
    late_salvage_goals_delta,
    triggered_team_first_late_salvage_goal_minute,
    triggered_team_first_late_salvage_goal_added_time,
    triggered_team_first_late_salvage_goal_effective_minute,
    triggered_team_first_late_salvage_goal_type,
    triggered_team_score_before_first_late_salvage_goal,
    opponent_score_before_first_late_salvage_goal,
    triggered_team_score_after_first_late_salvage_goal,
    opponent_score_after_first_late_salvage_goal,
    triggered_team_late_salvage_goals_above_threshold,
    triggered_team_final_result_points,
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
-- Signal: sig_team_shooting_goals_late_game_salvage
-- Trigger: team scores a tying or winning non-own goal after the 90th minute (effective minute > 90).
-- Intent: detect late-game score-state salvage events and preserve bilateral context for finishing,
--         chance quality, and control-profile diagnostics.
WITH late_salvage_goal_events AS (
    SELECT
        s.match_id,
        if(coalesce(s.is_home_goal, 0) = 1, 'home', 'away') AS triggered_side,
        toInt32(coalesce(s.goal_time, s.minute, 0)) AS goal_minute,
        toInt32(coalesce(s.goal_overload_time, s.minute_added, 0)) AS goal_added_time,
        toInt32(
            coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
        ) AS goal_effective_minute,
        toInt32(if(
            coalesce(s.is_home_goal, 0) = 1,
            coalesce(s.home_score_after, 0) - 1,
            coalesce(s.away_score_after, 0) - 1
        )) AS triggered_team_score_before,
        toInt32(if(
            coalesce(s.is_home_goal, 0) = 1,
            coalesce(s.away_score_after, 0),
            coalesce(s.home_score_after, 0)
        )) AS opponent_score_before,
        toInt32(if(
            coalesce(s.is_home_goal, 0) = 1,
            coalesce(s.home_score_after, 0),
            coalesce(s.away_score_after, 0)
        )) AS triggered_team_score_after,
        toInt32(if(
            coalesce(s.is_home_goal, 0) = 1,
            coalesce(s.away_score_after, 0),
            coalesce(s.home_score_after, 0)
        )) AS opponent_score_after,
        if(
            coalesce(s.home_score_after, -1) = coalesce(s.away_score_after, -1),
            'tying',
            'winning'
        ) AS late_salvage_goal_type,
        toInt64(coalesce(s.shot_id, 0)) AS shot_id
    FROM silver.shot AS s
    INNER JOIN silver.match AS m
        ON m.match_id = s.match_id
    WHERE s.match_id > 0
      AND m.match_id > 0
      AND m.match_finished = 1
      AND coalesce(s.is_goal, 0) = 1
      AND coalesce(s.is_own_goal, 0) = 0
      AND isNotNull(s.is_home_goal)
      AND toInt32(
            coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
        ) > 90
      AND (
            coalesce(s.home_score_after, -1) = coalesce(s.away_score_after, -1)
            OR if(
                coalesce(s.is_home_goal, 0) = 1,
                coalesce(s.home_score_after, 0) > coalesce(s.away_score_after, 0),
                coalesce(s.away_score_after, 0) > coalesce(s.home_score_after, 0)
            )
        )
      AND (
            (
                coalesce(s.home_score_after, -1) = coalesce(s.away_score_after, -1)
                AND if(
                    coalesce(s.is_home_goal, 0) = 1,
                    coalesce(m.home_score, 0) >= coalesce(m.away_score, 0),
                    coalesce(m.away_score, 0) >= coalesce(m.home_score, 0)
                )
            )
            OR
            (
                if(
                    coalesce(s.is_home_goal, 0) = 1,
                    coalesce(s.home_score_after, 0) > coalesce(s.away_score_after, 0),
                    coalesce(s.away_score_after, 0) > coalesce(s.home_score_after, 0)
                )
                AND if(
                    coalesce(s.is_home_goal, 0) = 1,
                    coalesce(m.home_score, 0) > coalesce(m.away_score, 0),
                    coalesce(m.away_score, 0) > coalesce(m.home_score, 0)
                )
            )
        )
),
late_salvage_rollup AS (
    SELECT
        lse.match_id,
        lse.triggered_side,
        toInt32(count()) AS triggered_team_late_salvage_goals,
        toInt32(sum(if(lse.late_salvage_goal_type = 'tying', 1, 0))) AS triggered_team_late_tying_goals,
        toInt32(sum(if(lse.late_salvage_goal_type = 'winning', 1, 0))) AS triggered_team_late_winning_goals,
        toInt32(argMin(
            lse.goal_minute,
            tuple(lse.goal_effective_minute, lse.goal_minute, lse.goal_added_time, lse.shot_id)
        )) AS triggered_team_first_late_salvage_goal_minute,
        toInt32(argMin(
            lse.goal_added_time,
            tuple(lse.goal_effective_minute, lse.goal_minute, lse.goal_added_time, lse.shot_id)
        )) AS triggered_team_first_late_salvage_goal_added_time,
        toInt32(min(lse.goal_effective_minute)) AS triggered_team_first_late_salvage_goal_effective_minute,
        argMin(
            lse.late_salvage_goal_type,
            tuple(lse.goal_effective_minute, lse.goal_minute, lse.goal_added_time, lse.shot_id)
        ) AS triggered_team_first_late_salvage_goal_type,
        toInt32(argMin(
            lse.triggered_team_score_before,
            tuple(lse.goal_effective_minute, lse.goal_minute, lse.goal_added_time, lse.shot_id)
        )) AS triggered_team_score_before_first_late_salvage_goal,
        toInt32(argMin(
            lse.opponent_score_before,
            tuple(lse.goal_effective_minute, lse.goal_minute, lse.goal_added_time, lse.shot_id)
        )) AS opponent_score_before_first_late_salvage_goal,
        toInt32(argMin(
            lse.triggered_team_score_after,
            tuple(lse.goal_effective_minute, lse.goal_minute, lse.goal_added_time, lse.shot_id)
        )) AS triggered_team_score_after_first_late_salvage_goal,
        toInt32(argMin(
            lse.opponent_score_after,
            tuple(lse.goal_effective_minute, lse.goal_minute, lse.goal_added_time, lse.shot_id)
        )) AS opponent_score_after_first_late_salvage_goal
    FROM late_salvage_goal_events AS lse
    GROUP BY
        lse.match_id,
        lse.triggered_side
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

    lsr.triggered_side,
    if(lsr.triggered_side = 'home', m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(lsr.triggered_side = 'home', m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(lsr.triggered_side = 'home', m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(lsr.triggered_side = 'home', m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(90) AS trigger_threshold_min_goal_effective_minute,
    toInt32(1) AS trigger_threshold_min_late_salvage_goals,
    lsr.triggered_team_late_salvage_goals,
    lsr.triggered_team_late_tying_goals,
    lsr.triggered_team_late_winning_goals,
    toInt32(coalesce(opp_lsr.triggered_team_late_salvage_goals, 0)) AS opponent_late_salvage_goals,
    toInt32(
        lsr.triggered_team_late_salvage_goals - coalesce(opp_lsr.triggered_team_late_salvage_goals, 0)
    ) AS late_salvage_goals_delta,
    lsr.triggered_team_first_late_salvage_goal_minute,
    lsr.triggered_team_first_late_salvage_goal_added_time,
    lsr.triggered_team_first_late_salvage_goal_effective_minute,
    lsr.triggered_team_first_late_salvage_goal_type,
    lsr.triggered_team_score_before_first_late_salvage_goal,
    lsr.opponent_score_before_first_late_salvage_goal,
    lsr.triggered_team_score_after_first_late_salvage_goal,
    lsr.opponent_score_after_first_late_salvage_goal,
    toInt32(lsr.triggered_team_late_salvage_goals - 1) AS triggered_team_late_salvage_goals_above_threshold,

    toInt32(if(
        if(
            lsr.triggered_side = 'home',
            coalesce(m.home_score, 0) - coalesce(m.away_score, 0),
            coalesce(m.away_score, 0) - coalesce(m.home_score, 0)
        ) > 0,
        3,
        if(
            if(
                lsr.triggered_side = 'home',
                coalesce(m.home_score, 0) - coalesce(m.away_score, 0),
                coalesce(m.away_score, 0) - coalesce(m.home_score, 0)
            ) = 0,
            1,
            0
        )
    )) AS triggered_team_final_result_points,
    toInt32(if(
        lsr.triggered_side = 'home',
        coalesce(m.home_score, 0),
        coalesce(m.away_score, 0)
    )) AS triggered_team_goals_final,
    toInt32(if(
        lsr.triggered_side = 'home',
        coalesce(m.away_score, 0),
        coalesce(m.home_score, 0)
    )) AS opponent_goals_final,
    toInt32(if(
        lsr.triggered_side = 'home',
        coalesce(m.home_score, 0) - coalesce(m.away_score, 0),
        coalesce(m.away_score, 0) - coalesce(m.home_score, 0)
    )) AS goal_delta_final,

    toInt32(if(
        lsr.triggered_side = 'home',
        coalesce(ps.total_shots_home, 0),
        coalesce(ps.total_shots_away, 0)
    )) AS triggered_team_total_shots,
    toInt32(if(
        lsr.triggered_side = 'home',
        coalesce(ps.total_shots_away, 0),
        coalesce(ps.total_shots_home, 0)
    )) AS opponent_total_shots,
    toInt32(if(
        lsr.triggered_side = 'home',
        coalesce(ps.total_shots_home, 0) - coalesce(ps.total_shots_away, 0),
        coalesce(ps.total_shots_away, 0) - coalesce(ps.total_shots_home, 0)
    )) AS total_shots_delta,

    toInt32(if(
        lsr.triggered_side = 'home',
        coalesce(ps.shots_on_target_home, 0),
        coalesce(ps.shots_on_target_away, 0)
    )) AS triggered_team_shots_on_target,
    toInt32(if(
        lsr.triggered_side = 'home',
        coalesce(ps.shots_on_target_away, 0),
        coalesce(ps.shots_on_target_home, 0)
    )) AS opponent_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * if(
            lsr.triggered_side = 'home',
            coalesce(ps.shots_on_target_home, 0),
            coalesce(ps.shots_on_target_away, 0)
        ) / nullIf(if(
            lsr.triggered_side = 'home',
            coalesce(ps.total_shots_home, 0),
            coalesce(ps.total_shots_away, 0)
        ), 0),
        1
    ), 0.0)) AS triggered_team_on_target_ratio_pct,
    toFloat32(coalesce(round(
        100.0 * if(
            lsr.triggered_side = 'home',
            coalesce(ps.shots_on_target_away, 0),
            coalesce(ps.shots_on_target_home, 0)
        ) / nullIf(if(
            lsr.triggered_side = 'home',
            coalesce(ps.total_shots_away, 0),
            coalesce(ps.total_shots_home, 0)
        ), 0),
        1
    ), 0.0)) AS opponent_on_target_ratio_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * if(
                lsr.triggered_side = 'home',
                coalesce(ps.shots_on_target_home, 0),
                coalesce(ps.shots_on_target_away, 0)
            ) / nullIf(if(
                lsr.triggered_side = 'home',
                coalesce(ps.total_shots_home, 0),
                coalesce(ps.total_shots_away, 0)
            ), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * if(
                lsr.triggered_side = 'home',
                coalesce(ps.shots_on_target_away, 0),
                coalesce(ps.shots_on_target_home, 0)
            ) / nullIf(if(
                lsr.triggered_side = 'home',
                coalesce(ps.total_shots_away, 0),
                coalesce(ps.total_shots_home, 0)
            ), 0),
            1
        ), 0.0),
        1
    )) AS on_target_ratio_delta_pct,

    toFloat32(if(
        lsr.triggered_side = 'home',
        coalesce(ps.expected_goals_home, 0.0),
        coalesce(ps.expected_goals_away, 0.0)
    )) AS triggered_team_xg,
    toFloat32(if(
        lsr.triggered_side = 'home',
        coalesce(ps.expected_goals_away, 0.0),
        coalesce(ps.expected_goals_home, 0.0)
    )) AS opponent_xg,
    toFloat32(round(
        if(
            lsr.triggered_side = 'home',
            coalesce(ps.expected_goals_home, 0.0) - coalesce(ps.expected_goals_away, 0.0),
            coalesce(ps.expected_goals_away, 0.0) - coalesce(ps.expected_goals_home, 0.0)
        ),
        3
    )) AS xg_delta,

    toInt32(if(
        lsr.triggered_side = 'home',
        coalesce(ps.big_chances_home, 0),
        coalesce(ps.big_chances_away, 0)
    )) AS triggered_team_big_chances,
    toInt32(if(
        lsr.triggered_side = 'home',
        coalesce(ps.big_chances_away, 0),
        coalesce(ps.big_chances_home, 0)
    )) AS opponent_big_chances,
    toInt32(if(
        lsr.triggered_side = 'home',
        coalesce(ps.big_chances_missed_home, 0),
        coalesce(ps.big_chances_missed_away, 0)
    )) AS triggered_team_big_chances_missed,
    toInt32(if(
        lsr.triggered_side = 'home',
        coalesce(ps.big_chances_missed_away, 0),
        coalesce(ps.big_chances_missed_home, 0)
    )) AS opponent_big_chances_missed,

    toFloat32(if(
        lsr.triggered_side = 'home',
        coalesce(ps.ball_possession_home, 0.0),
        coalesce(ps.ball_possession_away, 0.0)
    )) AS triggered_team_possession_pct,
    toFloat32(if(
        lsr.triggered_side = 'home',
        coalesce(ps.ball_possession_away, 0.0),
        coalesce(ps.ball_possession_home, 0.0)
    )) AS opponent_possession_pct,
    toFloat32(round(
        if(
            lsr.triggered_side = 'home',
            coalesce(ps.ball_possession_home, 0.0) - coalesce(ps.ball_possession_away, 0.0),
            coalesce(ps.ball_possession_away, 0.0) - coalesce(ps.ball_possession_home, 0.0)
        ),
        1
    )) AS possession_delta_pct,

    toInt32(if(
        lsr.triggered_side = 'home',
        coalesce(ps.pass_attempts_home, 0),
        coalesce(ps.pass_attempts_away, 0)
    )) AS triggered_team_pass_attempts,
    toInt32(if(
        lsr.triggered_side = 'home',
        coalesce(ps.pass_attempts_away, 0),
        coalesce(ps.pass_attempts_home, 0)
    )) AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * if(
            lsr.triggered_side = 'home',
            coalesce(ps.accurate_passes_home, 0),
            coalesce(ps.accurate_passes_away, 0)
        ) / nullIf(if(
            lsr.triggered_side = 'home',
            coalesce(ps.pass_attempts_home, 0),
            coalesce(ps.pass_attempts_away, 0)
        ), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * if(
            lsr.triggered_side = 'home',
            coalesce(ps.accurate_passes_away, 0),
            coalesce(ps.accurate_passes_home, 0)
        ) / nullIf(if(
            lsr.triggered_side = 'home',
            coalesce(ps.pass_attempts_away, 0),
            coalesce(ps.pass_attempts_home, 0)
        ), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * if(
                lsr.triggered_side = 'home',
                coalesce(ps.accurate_passes_home, 0),
                coalesce(ps.accurate_passes_away, 0)
            ) / nullIf(if(
                lsr.triggered_side = 'home',
                coalesce(ps.pass_attempts_home, 0),
                coalesce(ps.pass_attempts_away, 0)
            ), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * if(
                lsr.triggered_side = 'home',
                coalesce(ps.accurate_passes_away, 0),
                coalesce(ps.accurate_passes_home, 0)
            ) / nullIf(if(
                lsr.triggered_side = 'home',
                coalesce(ps.pass_attempts_away, 0),
                coalesce(ps.pass_attempts_home, 0)
            ), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    toInt32(if(
        lsr.triggered_side = 'home',
        coalesce(ps.corners_home, 0),
        coalesce(ps.corners_away, 0)
    )) AS triggered_team_corners,
    toInt32(if(
        lsr.triggered_side = 'home',
        coalesce(ps.corners_away, 0),
        coalesce(ps.corners_home, 0)
    )) AS opponent_corners

FROM late_salvage_rollup AS lsr
INNER JOIN silver.match AS m
    ON m.match_id = lsr.match_id
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN late_salvage_rollup AS opp_lsr
    ON opp_lsr.match_id = lsr.match_id
   AND opp_lsr.triggered_side = if(lsr.triggered_side = 'home', 'away', 'home')
WHERE m.match_finished = 1
  AND m.match_id > 0

ORDER BY
    lsr.triggered_team_late_salvage_goals DESC,
    lsr.triggered_team_first_late_salvage_goal_effective_minute DESC,
    m.match_date DESC,
    m.match_id DESC;
