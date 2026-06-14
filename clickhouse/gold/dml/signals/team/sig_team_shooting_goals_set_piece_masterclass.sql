INSERT INTO gold.sig_team_shooting_goals_set_piece_masterclass (
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
    trigger_threshold_min_corner_goals,
    trigger_threshold_min_free_kick_goals,
    trigger_threshold_min_penalty_goals,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_corner_goals,
    opponent_corner_goals,
    corner_goals_delta,
    triggered_team_free_kick_goals,
    opponent_free_kick_goals,
    free_kick_goals_delta,
    triggered_team_penalty_goals,
    opponent_penalty_goals,
    penalty_goals_delta,
    triggered_team_set_piece_components_hit,
    opponent_set_piece_components_hit,
    set_piece_components_hit_delta,
    triggered_team_corner_free_kick_penalty_goals,
    opponent_corner_free_kick_penalty_goals,
    corner_free_kick_penalty_goals_delta,
    triggered_team_corner_free_kick_penalty_goal_share_pct,
    opponent_corner_free_kick_penalty_goal_share_pct,
    corner_free_kick_penalty_goal_share_delta_pct,
    triggered_team_corner_free_kick_penalty_shots,
    opponent_corner_free_kick_penalty_shots,
    triggered_team_corner_free_kick_penalty_expected_goals,
    opponent_corner_free_kick_penalty_expected_goals,
    corner_free_kick_penalty_expected_goals_delta,
    triggered_team_corner_free_kick_penalty_goals_per_shot,
    opponent_corner_free_kick_penalty_goals_per_shot,
    corner_free_kick_penalty_goals_per_shot_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    triggered_team_expected_goals,
    opponent_expected_goals,
    expected_goals_delta,
    triggered_team_set_play_expected_goals,
    opponent_set_play_expected_goals,
    set_play_expected_goals_delta,
    triggered_team_corners,
    opponent_corners,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct
)
-- Signal: sig_team_shooting_goals_set_piece_masterclass
-- Trigger: team scores from a corner, a free-kick, and a penalty in one finished match.
-- Intent: capture multi-channel set-piece scoring mastery and preserve bilateral context around chance quality,
--         finishing intensity, and overall match control.
WITH shot_classified AS (
    SELECT
        s.match_id,
        toInt32(s.team_id) AS team_id,
        toInt32(coalesce(s.is_goal, 0)) AS is_goal,
        toInt32(coalesce(s.is_own_goal, 0)) AS is_own_goal,
        toFloat32(coalesce(s.expected_goals, 0.0)) AS expected_goals,
        coalesce(s.situation, '') AS situation,
        coalesce(s.shot_type, '') AS shot_type,
        toUInt8(coalesce(s.situation, '') = 'FromCorner') AS is_corner_situation,
        toUInt8(
            coalesce(s.situation, '') = 'FreeKick'
            OR positionCaseInsensitiveUTF8(coalesce(s.shot_type, ''), 'free kick') > 0
            OR positionCaseInsensitiveUTF8(coalesce(s.shot_type, ''), 'freekick') > 0
        ) AS is_free_kick_situation,
        toUInt8(
            positionCaseInsensitiveUTF8(coalesce(s.situation, ''), 'penalty') > 0
            OR positionCaseInsensitiveUTF8(coalesce(s.shot_type, ''), 'penalty') > 0
        ) AS is_penalty_situation
    FROM silver.shot AS s
    WHERE s.match_id > 0
      AND coalesce(s.team_id, 0) > 0
),
set_piece_team_stats AS (
    SELECT
        sc.match_id,
        sc.team_id,
        toInt32(countIf(
            sc.is_goal = 1
            AND sc.is_own_goal = 0
            AND sc.is_corner_situation = 1
        )) AS team_corner_goals,
        toInt32(countIf(
            sc.is_goal = 1
            AND sc.is_own_goal = 0
            AND sc.is_free_kick_situation = 1
        )) AS team_free_kick_goals,
        toInt32(countIf(
            sc.is_goal = 1
            AND sc.is_own_goal = 0
            AND sc.is_penalty_situation = 1
        )) AS team_penalty_goals,
        toInt32(countIf(
            sc.is_goal = 1
            AND sc.is_own_goal = 0
            AND (
                sc.is_corner_situation = 1
                OR sc.is_free_kick_situation = 1
                OR sc.is_penalty_situation = 1
            )
        )) AS team_corner_free_kick_penalty_goals,
        toInt32(countIf(
            sc.is_own_goal = 0
            AND (
                sc.is_corner_situation = 1
                OR sc.is_free_kick_situation = 1
                OR sc.is_penalty_situation = 1
            )
        )) AS team_corner_free_kick_penalty_shots,
        toFloat32(round(sumIf(
            sc.expected_goals,
            sc.is_own_goal = 0
            AND (
                sc.is_corner_situation = 1
                OR sc.is_free_kick_situation = 1
                OR sc.is_penalty_situation = 1
            )
        ), 3)) AS team_corner_free_kick_penalty_expected_goals
    FROM shot_classified AS sc
    GROUP BY
        sc.match_id,
        sc.team_id
)

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

    toInt32(1) AS trigger_threshold_min_corner_goals,
    toInt32(1) AS trigger_threshold_min_free_kick_goals,
    toInt32(1) AS trigger_threshold_min_penalty_goals,

    coalesce(m.home_score, 0) AS triggered_team_goals,
    coalesce(m.away_score, 0) AS opponent_goals,
    coalesce(m.home_score, 0) - coalesce(m.away_score, 0) AS goal_delta,

    coalesce(home_sp.team_corner_goals, 0) AS triggered_team_corner_goals,
    coalesce(away_sp.team_corner_goals, 0) AS opponent_corner_goals,
    coalesce(home_sp.team_corner_goals, 0) - coalesce(away_sp.team_corner_goals, 0)
        AS corner_goals_delta,

    coalesce(home_sp.team_free_kick_goals, 0) AS triggered_team_free_kick_goals,
    coalesce(away_sp.team_free_kick_goals, 0) AS opponent_free_kick_goals,
    coalesce(home_sp.team_free_kick_goals, 0) - coalesce(away_sp.team_free_kick_goals, 0)
        AS free_kick_goals_delta,

    coalesce(home_sp.team_penalty_goals, 0) AS triggered_team_penalty_goals,
    coalesce(away_sp.team_penalty_goals, 0) AS opponent_penalty_goals,
    coalesce(home_sp.team_penalty_goals, 0) - coalesce(away_sp.team_penalty_goals, 0)
        AS penalty_goals_delta,

    toInt32(
        if(coalesce(home_sp.team_corner_goals, 0) > 0, 1, 0)
        + if(coalesce(home_sp.team_free_kick_goals, 0) > 0, 1, 0)
        + if(coalesce(home_sp.team_penalty_goals, 0) > 0, 1, 0)
    ) AS triggered_team_set_piece_components_hit,
    toInt32(
        if(coalesce(away_sp.team_corner_goals, 0) > 0, 1, 0)
        + if(coalesce(away_sp.team_free_kick_goals, 0) > 0, 1, 0)
        + if(coalesce(away_sp.team_penalty_goals, 0) > 0, 1, 0)
    ) AS opponent_set_piece_components_hit,
    toInt32(
        (
            if(coalesce(home_sp.team_corner_goals, 0) > 0, 1, 0)
            + if(coalesce(home_sp.team_free_kick_goals, 0) > 0, 1, 0)
            + if(coalesce(home_sp.team_penalty_goals, 0) > 0, 1, 0)
        )
        - (
            if(coalesce(away_sp.team_corner_goals, 0) > 0, 1, 0)
            + if(coalesce(away_sp.team_free_kick_goals, 0) > 0, 1, 0)
            + if(coalesce(away_sp.team_penalty_goals, 0) > 0, 1, 0)
        )
    ) AS set_piece_components_hit_delta,

    coalesce(home_sp.team_corner_free_kick_penalty_goals, 0)
        AS triggered_team_corner_free_kick_penalty_goals,
    coalesce(away_sp.team_corner_free_kick_penalty_goals, 0)
        AS opponent_corner_free_kick_penalty_goals,
    coalesce(home_sp.team_corner_free_kick_penalty_goals, 0)
        - coalesce(away_sp.team_corner_free_kick_penalty_goals, 0)
        AS corner_free_kick_penalty_goals_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(home_sp.team_corner_free_kick_penalty_goals, 0)
            / nullIf(toFloat64(coalesce(m.home_score, 0)), 0),
        1
    ), 0.0)) AS triggered_team_corner_free_kick_penalty_goal_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(away_sp.team_corner_free_kick_penalty_goals, 0)
            / nullIf(toFloat64(coalesce(m.away_score, 0)), 0),
        1
    ), 0.0)) AS opponent_corner_free_kick_penalty_goal_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(home_sp.team_corner_free_kick_penalty_goals, 0)
                / nullIf(toFloat64(coalesce(m.home_score, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(away_sp.team_corner_free_kick_penalty_goals, 0)
                / nullIf(toFloat64(coalesce(m.away_score, 0)), 0),
            1
        ), 0.0),
        1
    )) AS corner_free_kick_penalty_goal_share_delta_pct,

    coalesce(home_sp.team_corner_free_kick_penalty_shots, 0)
        AS triggered_team_corner_free_kick_penalty_shots,
    coalesce(away_sp.team_corner_free_kick_penalty_shots, 0)
        AS opponent_corner_free_kick_penalty_shots,
    toFloat32(coalesce(home_sp.team_corner_free_kick_penalty_expected_goals, 0.0))
        AS triggered_team_corner_free_kick_penalty_expected_goals,
    toFloat32(coalesce(away_sp.team_corner_free_kick_penalty_expected_goals, 0.0))
        AS opponent_corner_free_kick_penalty_expected_goals,
    toFloat32(round(
        coalesce(home_sp.team_corner_free_kick_penalty_expected_goals, 0.0)
        - coalesce(away_sp.team_corner_free_kick_penalty_expected_goals, 0.0),
        3
    )) AS corner_free_kick_penalty_expected_goals_delta,

    toFloat32(coalesce(round(
        coalesce(home_sp.team_corner_free_kick_penalty_goals, 0)
            / nullIf(toFloat64(coalesce(home_sp.team_corner_free_kick_penalty_shots, 0)), 0),
        3
    ), 0.0)) AS triggered_team_corner_free_kick_penalty_goals_per_shot,
    toFloat32(coalesce(round(
        coalesce(away_sp.team_corner_free_kick_penalty_goals, 0)
            / nullIf(toFloat64(coalesce(away_sp.team_corner_free_kick_penalty_shots, 0)), 0),
        3
    ), 0.0)) AS opponent_corner_free_kick_penalty_goals_per_shot,
    toFloat32(round(
        coalesce(round(
            coalesce(home_sp.team_corner_free_kick_penalty_goals, 0)
                / nullIf(toFloat64(coalesce(home_sp.team_corner_free_kick_penalty_shots, 0)), 0),
            3
        ), 0.0)
      - coalesce(round(
            coalesce(away_sp.team_corner_free_kick_penalty_goals, 0)
                / nullIf(toFloat64(coalesce(away_sp.team_corner_free_kick_penalty_shots, 0)), 0),
            3
        ), 0.0),
        3
    )) AS corner_free_kick_penalty_goals_per_shot_delta,

    coalesce(ps.total_shots_home, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_away, 0) AS opponent_total_shots,
    coalesce(ps.shots_on_target_home, 0) AS triggered_team_shots_on_target,
    coalesce(ps.shots_on_target_away, 0) AS opponent_shots_on_target,

    toFloat32(coalesce(ps.expected_goals_home, 0)) AS triggered_team_expected_goals,
    toFloat32(coalesce(ps.expected_goals_away, 0)) AS opponent_expected_goals,
    toFloat32(round(
        coalesce(ps.expected_goals_home, 0) - coalesce(ps.expected_goals_away, 0),
        3
    )) AS expected_goals_delta,

    toFloat32(coalesce(ps.expected_goals_set_play_home, 0)) AS triggered_team_set_play_expected_goals,
    toFloat32(coalesce(ps.expected_goals_set_play_away, 0)) AS opponent_set_play_expected_goals,
    toFloat32(round(
        coalesce(ps.expected_goals_set_play_home, 0) - coalesce(ps.expected_goals_set_play_away, 0),
        3
    )) AS set_play_expected_goals_delta,

    coalesce(ps.corners_home, 0) AS triggered_team_corners,
    coalesce(ps.corners_away, 0) AS opponent_corners,
    coalesce(ps.touches_opp_box_home, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_away, 0) AS opponent_touches_opposition_box,

    toFloat32(coalesce(ps.ball_possession_home, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS opponent_possession_pct,
    toFloat32(round(
        coalesce(ps.ball_possession_home, 0) - coalesce(ps.ball_possession_away, 0),
        1
    )) AS possession_delta_pct,

    coalesce(ps.pass_attempts_home, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_away, 0) AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0)
            / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0)
            / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0)
                / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0)
                / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN set_piece_team_stats AS home_sp
    ON home_sp.match_id = m.match_id
   AND home_sp.team_id = m.home_team_id
LEFT JOIN set_piece_team_stats AS away_sp
    ON away_sp.match_id = m.match_id
   AND away_sp.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(home_sp.team_corner_goals, 0) >= 1
  AND coalesce(home_sp.team_free_kick_goals, 0) >= 1
  AND coalesce(home_sp.team_penalty_goals, 0) >= 1

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

    toInt32(1) AS trigger_threshold_min_corner_goals,
    toInt32(1) AS trigger_threshold_min_free_kick_goals,
    toInt32(1) AS trigger_threshold_min_penalty_goals,

    coalesce(m.away_score, 0) AS triggered_team_goals,
    coalesce(m.home_score, 0) AS opponent_goals,
    coalesce(m.away_score, 0) - coalesce(m.home_score, 0) AS goal_delta,

    coalesce(away_sp.team_corner_goals, 0) AS triggered_team_corner_goals,
    coalesce(home_sp.team_corner_goals, 0) AS opponent_corner_goals,
    coalesce(away_sp.team_corner_goals, 0) - coalesce(home_sp.team_corner_goals, 0)
        AS corner_goals_delta,

    coalesce(away_sp.team_free_kick_goals, 0) AS triggered_team_free_kick_goals,
    coalesce(home_sp.team_free_kick_goals, 0) AS opponent_free_kick_goals,
    coalesce(away_sp.team_free_kick_goals, 0) - coalesce(home_sp.team_free_kick_goals, 0)
        AS free_kick_goals_delta,

    coalesce(away_sp.team_penalty_goals, 0) AS triggered_team_penalty_goals,
    coalesce(home_sp.team_penalty_goals, 0) AS opponent_penalty_goals,
    coalesce(away_sp.team_penalty_goals, 0) - coalesce(home_sp.team_penalty_goals, 0)
        AS penalty_goals_delta,

    toInt32(
        if(coalesce(away_sp.team_corner_goals, 0) > 0, 1, 0)
        + if(coalesce(away_sp.team_free_kick_goals, 0) > 0, 1, 0)
        + if(coalesce(away_sp.team_penalty_goals, 0) > 0, 1, 0)
    ) AS triggered_team_set_piece_components_hit,
    toInt32(
        if(coalesce(home_sp.team_corner_goals, 0) > 0, 1, 0)
        + if(coalesce(home_sp.team_free_kick_goals, 0) > 0, 1, 0)
        + if(coalesce(home_sp.team_penalty_goals, 0) > 0, 1, 0)
    ) AS opponent_set_piece_components_hit,
    toInt32(
        (
            if(coalesce(away_sp.team_corner_goals, 0) > 0, 1, 0)
            + if(coalesce(away_sp.team_free_kick_goals, 0) > 0, 1, 0)
            + if(coalesce(away_sp.team_penalty_goals, 0) > 0, 1, 0)
        )
        - (
            if(coalesce(home_sp.team_corner_goals, 0) > 0, 1, 0)
            + if(coalesce(home_sp.team_free_kick_goals, 0) > 0, 1, 0)
            + if(coalesce(home_sp.team_penalty_goals, 0) > 0, 1, 0)
        )
    ) AS set_piece_components_hit_delta,

    coalesce(away_sp.team_corner_free_kick_penalty_goals, 0)
        AS triggered_team_corner_free_kick_penalty_goals,
    coalesce(home_sp.team_corner_free_kick_penalty_goals, 0)
        AS opponent_corner_free_kick_penalty_goals,
    coalesce(away_sp.team_corner_free_kick_penalty_goals, 0)
        - coalesce(home_sp.team_corner_free_kick_penalty_goals, 0)
        AS corner_free_kick_penalty_goals_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(away_sp.team_corner_free_kick_penalty_goals, 0)
            / nullIf(toFloat64(coalesce(m.away_score, 0)), 0),
        1
    ), 0.0)) AS triggered_team_corner_free_kick_penalty_goal_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(home_sp.team_corner_free_kick_penalty_goals, 0)
            / nullIf(toFloat64(coalesce(m.home_score, 0)), 0),
        1
    ), 0.0)) AS opponent_corner_free_kick_penalty_goal_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(away_sp.team_corner_free_kick_penalty_goals, 0)
                / nullIf(toFloat64(coalesce(m.away_score, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(home_sp.team_corner_free_kick_penalty_goals, 0)
                / nullIf(toFloat64(coalesce(m.home_score, 0)), 0),
            1
        ), 0.0),
        1
    )) AS corner_free_kick_penalty_goal_share_delta_pct,

    coalesce(away_sp.team_corner_free_kick_penalty_shots, 0)
        AS triggered_team_corner_free_kick_penalty_shots,
    coalesce(home_sp.team_corner_free_kick_penalty_shots, 0)
        AS opponent_corner_free_kick_penalty_shots,
    toFloat32(coalesce(away_sp.team_corner_free_kick_penalty_expected_goals, 0.0))
        AS triggered_team_corner_free_kick_penalty_expected_goals,
    toFloat32(coalesce(home_sp.team_corner_free_kick_penalty_expected_goals, 0.0))
        AS opponent_corner_free_kick_penalty_expected_goals,
    toFloat32(round(
        coalesce(away_sp.team_corner_free_kick_penalty_expected_goals, 0.0)
        - coalesce(home_sp.team_corner_free_kick_penalty_expected_goals, 0.0),
        3
    )) AS corner_free_kick_penalty_expected_goals_delta,

    toFloat32(coalesce(round(
        coalesce(away_sp.team_corner_free_kick_penalty_goals, 0)
            / nullIf(toFloat64(coalesce(away_sp.team_corner_free_kick_penalty_shots, 0)), 0),
        3
    ), 0.0)) AS triggered_team_corner_free_kick_penalty_goals_per_shot,
    toFloat32(coalesce(round(
        coalesce(home_sp.team_corner_free_kick_penalty_goals, 0)
            / nullIf(toFloat64(coalesce(home_sp.team_corner_free_kick_penalty_shots, 0)), 0),
        3
    ), 0.0)) AS opponent_corner_free_kick_penalty_goals_per_shot,
    toFloat32(round(
        coalesce(round(
            coalesce(away_sp.team_corner_free_kick_penalty_goals, 0)
                / nullIf(toFloat64(coalesce(away_sp.team_corner_free_kick_penalty_shots, 0)), 0),
            3
        ), 0.0)
      - coalesce(round(
            coalesce(home_sp.team_corner_free_kick_penalty_goals, 0)
                / nullIf(toFloat64(coalesce(home_sp.team_corner_free_kick_penalty_shots, 0)), 0),
            3
        ), 0.0),
        3
    )) AS corner_free_kick_penalty_goals_per_shot_delta,

    coalesce(ps.total_shots_away, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_home, 0) AS opponent_total_shots,
    coalesce(ps.shots_on_target_away, 0) AS triggered_team_shots_on_target,
    coalesce(ps.shots_on_target_home, 0) AS opponent_shots_on_target,

    toFloat32(coalesce(ps.expected_goals_away, 0)) AS triggered_team_expected_goals,
    toFloat32(coalesce(ps.expected_goals_home, 0)) AS opponent_expected_goals,
    toFloat32(round(
        coalesce(ps.expected_goals_away, 0) - coalesce(ps.expected_goals_home, 0),
        3
    )) AS expected_goals_delta,

    toFloat32(coalesce(ps.expected_goals_set_play_away, 0)) AS triggered_team_set_play_expected_goals,
    toFloat32(coalesce(ps.expected_goals_set_play_home, 0)) AS opponent_set_play_expected_goals,
    toFloat32(round(
        coalesce(ps.expected_goals_set_play_away, 0) - coalesce(ps.expected_goals_set_play_home, 0),
        3
    )) AS set_play_expected_goals_delta,

    coalesce(ps.corners_away, 0) AS triggered_team_corners,
    coalesce(ps.corners_home, 0) AS opponent_corners,
    coalesce(ps.touches_opp_box_away, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_home, 0) AS opponent_touches_opposition_box,

    toFloat32(coalesce(ps.ball_possession_away, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS opponent_possession_pct,
    toFloat32(round(
        coalesce(ps.ball_possession_away, 0) - coalesce(ps.ball_possession_home, 0),
        1
    )) AS possession_delta_pct,

    coalesce(ps.pass_attempts_away, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_home, 0) AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0)
            / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0)
            / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0)
                / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0)
                / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN set_piece_team_stats AS home_sp
    ON home_sp.match_id = m.match_id
   AND home_sp.team_id = m.home_team_id
LEFT JOIN set_piece_team_stats AS away_sp
    ON away_sp.match_id = m.match_id
   AND away_sp.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(away_sp.team_corner_goals, 0) >= 1
  AND coalesce(away_sp.team_free_kick_goals, 0) >= 1
  AND coalesce(away_sp.team_penalty_goals, 0) >= 1

ORDER BY
    triggered_team_corner_free_kick_penalty_goals DESC,
    triggered_team_set_piece_components_hit DESC,
    corner_free_kick_penalty_goal_share_delta_pct DESC,
    m.match_date DESC,
    m.match_id DESC;
