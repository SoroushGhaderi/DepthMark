INSERT INTO gold.sig_team_shooting_goals_dead_ball_specialists (
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
    trigger_threshold_min_dead_ball_goals,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_dead_ball_goals,
    opponent_dead_ball_goals,
    dead_ball_goals_delta,
    triggered_team_corner_goals,
    opponent_corner_goals,
    corner_goals_delta,
    triggered_team_free_kick_goals,
    opponent_free_kick_goals,
    free_kick_goals_delta,
    triggered_team_set_piece_goals,
    opponent_set_piece_goals,
    set_piece_goals_delta,
    triggered_team_dead_ball_goal_share_pct,
    opponent_dead_ball_goal_share_pct,
    dead_ball_goal_share_delta_pct,
    triggered_team_dead_ball_shots,
    opponent_dead_ball_shots,
    triggered_team_dead_ball_xg,
    opponent_dead_ball_xg,
    dead_ball_xg_delta,
    triggered_team_dead_ball_goals_per_shot,
    opponent_dead_ball_goals_per_shot,
    dead_ball_goals_per_shot_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_set_play_xg,
    opponent_set_play_xg,
    set_play_xg_delta,
    triggered_team_corners,
    opponent_corners,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct
)
-- Signal: sig_team_shooting_goals_dead_ball_specialists
-- Trigger: Team scores >= 2 goals from corner/free-kick dead-ball events in a finished match.
-- Intent: Detect teams that generate decisive goal output from dead-ball finishing sequences and preserve
--         bilateral context on shooting quality, set-play reliance, and match control.

WITH dead_ball_team_stats AS (
    SELECT
        s.match_id,
        toInt32(s.team_id) AS team_id,
        toInt32(sum(if(
            coalesce(s.is_goal, 0) = 1
            AND coalesce(s.is_own_goal, 0) = 0
            AND coalesce(s.situation, '') IN ('FromCorner', 'FreeKick', 'SetPiece'),
            1,
            0
        ))) AS team_dead_ball_goals,
        toInt32(sum(if(
            coalesce(s.is_goal, 0) = 1
            AND coalesce(s.is_own_goal, 0) = 0
            AND coalesce(s.situation, '') = 'FromCorner',
            1,
            0
        ))) AS team_corner_goals,
        toInt32(sum(if(
            coalesce(s.is_goal, 0) = 1
            AND coalesce(s.is_own_goal, 0) = 0
            AND coalesce(s.situation, '') = 'FreeKick',
            1,
            0
        ))) AS team_free_kick_goals,
        toInt32(sum(if(
            coalesce(s.is_goal, 0) = 1
            AND coalesce(s.is_own_goal, 0) = 0
            AND coalesce(s.situation, '') = 'SetPiece',
            1,
            0
        ))) AS team_set_piece_goals,
        toInt32(sum(if(
            coalesce(s.is_own_goal, 0) = 0
            AND coalesce(s.situation, '') IN ('FromCorner', 'FreeKick', 'SetPiece'),
            1,
            0
        ))) AS team_dead_ball_shots,
        toFloat32(round(sum(if(
            coalesce(s.is_own_goal, 0) = 0
            AND coalesce(s.situation, '') IN ('FromCorner', 'FreeKick', 'SetPiece'),
            coalesce(s.expected_goals, 0.0),
            0.0
        )), 3)) AS team_dead_ball_xg
    FROM silver.shot AS s
    WHERE coalesce(s.team_id, 0) > 0
    GROUP BY
        s.match_id,
        toInt32(s.team_id)
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

    toInt32(2) AS trigger_threshold_min_dead_ball_goals,
    coalesce(m.home_score, 0) AS triggered_team_goals,
    coalesce(m.away_score, 0) AS opponent_goals,
    coalesce(m.home_score, 0) - coalesce(m.away_score, 0) AS goal_delta,

    coalesce(home_db.team_dead_ball_goals, 0) AS triggered_team_dead_ball_goals,
    coalesce(away_db.team_dead_ball_goals, 0) AS opponent_dead_ball_goals,
    coalesce(home_db.team_dead_ball_goals, 0) - coalesce(away_db.team_dead_ball_goals, 0)
        AS dead_ball_goals_delta,

    coalesce(home_db.team_corner_goals, 0) AS triggered_team_corner_goals,
    coalesce(away_db.team_corner_goals, 0) AS opponent_corner_goals,
    coalesce(home_db.team_corner_goals, 0) - coalesce(away_db.team_corner_goals, 0)
        AS corner_goals_delta,

    coalesce(home_db.team_free_kick_goals, 0) AS triggered_team_free_kick_goals,
    coalesce(away_db.team_free_kick_goals, 0) AS opponent_free_kick_goals,
    coalesce(home_db.team_free_kick_goals, 0) - coalesce(away_db.team_free_kick_goals, 0)
        AS free_kick_goals_delta,

    coalesce(home_db.team_set_piece_goals, 0) AS triggered_team_set_piece_goals,
    coalesce(away_db.team_set_piece_goals, 0) AS opponent_set_piece_goals,
    coalesce(home_db.team_set_piece_goals, 0) - coalesce(away_db.team_set_piece_goals, 0)
        AS set_piece_goals_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(home_db.team_dead_ball_goals, 0)
            / nullIf(toFloat64(coalesce(m.home_score, 0)), 0),
        1
    ), 0.0)) AS triggered_team_dead_ball_goal_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(away_db.team_dead_ball_goals, 0)
            / nullIf(toFloat64(coalesce(m.away_score, 0)), 0),
        1
    ), 0.0)) AS opponent_dead_ball_goal_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(home_db.team_dead_ball_goals, 0)
                / nullIf(toFloat64(coalesce(m.home_score, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(away_db.team_dead_ball_goals, 0)
                / nullIf(toFloat64(coalesce(m.away_score, 0)), 0),
            1
        ), 0.0),
        1
    )) AS dead_ball_goal_share_delta_pct,

    coalesce(home_db.team_dead_ball_shots, 0) AS triggered_team_dead_ball_shots,
    coalesce(away_db.team_dead_ball_shots, 0) AS opponent_dead_ball_shots,
    toFloat32(coalesce(home_db.team_dead_ball_xg, 0.0)) AS triggered_team_dead_ball_xg,
    toFloat32(coalesce(away_db.team_dead_ball_xg, 0.0)) AS opponent_dead_ball_xg,
    toFloat32(round(
        coalesce(home_db.team_dead_ball_xg, 0.0) - coalesce(away_db.team_dead_ball_xg, 0.0),
        3
    )) AS dead_ball_xg_delta,

    toFloat32(coalesce(round(
        coalesce(home_db.team_dead_ball_goals, 0)
            / nullIf(toFloat64(coalesce(home_db.team_dead_ball_shots, 0)), 0),
        3
    ), 0.0)) AS triggered_team_dead_ball_goals_per_shot,
    toFloat32(coalesce(round(
        coalesce(away_db.team_dead_ball_goals, 0)
            / nullIf(toFloat64(coalesce(away_db.team_dead_ball_shots, 0)), 0),
        3
    ), 0.0)) AS opponent_dead_ball_goals_per_shot,
    toFloat32(round(
        coalesce(round(
            coalesce(home_db.team_dead_ball_goals, 0)
                / nullIf(toFloat64(coalesce(home_db.team_dead_ball_shots, 0)), 0),
            3
        ), 0.0)
      - coalesce(round(
            coalesce(away_db.team_dead_ball_goals, 0)
                / nullIf(toFloat64(coalesce(away_db.team_dead_ball_shots, 0)), 0),
            3
        ), 0.0),
        3
    )) AS dead_ball_goals_per_shot_delta,

    coalesce(ps.total_shots_home, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_away, 0) AS opponent_total_shots,
    coalesce(ps.shots_on_target_home, 0) AS triggered_team_shots_on_target,
    coalesce(ps.shots_on_target_away, 0) AS opponent_shots_on_target,
    toFloat32(coalesce(ps.expected_goals_home, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_home, 0) - coalesce(ps.expected_goals_away, 0), 3)) AS xg_delta,

    toFloat32(coalesce(ps.expected_goals_set_play_home, 0)) AS triggered_team_set_play_xg,
    toFloat32(coalesce(ps.expected_goals_set_play_away, 0)) AS opponent_set_play_xg,
    toFloat32(round(
        coalesce(ps.expected_goals_set_play_home, 0) - coalesce(ps.expected_goals_set_play_away, 0),
        3
    )) AS set_play_xg_delta,

    coalesce(ps.corners_home, 0) AS triggered_team_corners,
    coalesce(ps.corners_away, 0) AS opponent_corners,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_home, 0) - coalesce(ps.ball_possession_away, 0), 1))
        AS possession_delta_pct,

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
LEFT JOIN dead_ball_team_stats AS home_db
    ON home_db.match_id = m.match_id
   AND home_db.team_id = m.home_team_id
LEFT JOIN dead_ball_team_stats AS away_db
    ON away_db.match_id = m.match_id
   AND away_db.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(home_db.team_dead_ball_goals, 0) >= 2

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

    toInt32(2) AS trigger_threshold_min_dead_ball_goals,
    coalesce(m.away_score, 0) AS triggered_team_goals,
    coalesce(m.home_score, 0) AS opponent_goals,
    coalesce(m.away_score, 0) - coalesce(m.home_score, 0) AS goal_delta,

    coalesce(away_db.team_dead_ball_goals, 0) AS triggered_team_dead_ball_goals,
    coalesce(home_db.team_dead_ball_goals, 0) AS opponent_dead_ball_goals,
    coalesce(away_db.team_dead_ball_goals, 0) - coalesce(home_db.team_dead_ball_goals, 0)
        AS dead_ball_goals_delta,

    coalesce(away_db.team_corner_goals, 0) AS triggered_team_corner_goals,
    coalesce(home_db.team_corner_goals, 0) AS opponent_corner_goals,
    coalesce(away_db.team_corner_goals, 0) - coalesce(home_db.team_corner_goals, 0)
        AS corner_goals_delta,

    coalesce(away_db.team_free_kick_goals, 0) AS triggered_team_free_kick_goals,
    coalesce(home_db.team_free_kick_goals, 0) AS opponent_free_kick_goals,
    coalesce(away_db.team_free_kick_goals, 0) - coalesce(home_db.team_free_kick_goals, 0)
        AS free_kick_goals_delta,

    coalesce(away_db.team_set_piece_goals, 0) AS triggered_team_set_piece_goals,
    coalesce(home_db.team_set_piece_goals, 0) AS opponent_set_piece_goals,
    coalesce(away_db.team_set_piece_goals, 0) - coalesce(home_db.team_set_piece_goals, 0)
        AS set_piece_goals_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(away_db.team_dead_ball_goals, 0)
            / nullIf(toFloat64(coalesce(m.away_score, 0)), 0),
        1
    ), 0.0)) AS triggered_team_dead_ball_goal_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(home_db.team_dead_ball_goals, 0)
            / nullIf(toFloat64(coalesce(m.home_score, 0)), 0),
        1
    ), 0.0)) AS opponent_dead_ball_goal_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(away_db.team_dead_ball_goals, 0)
                / nullIf(toFloat64(coalesce(m.away_score, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(home_db.team_dead_ball_goals, 0)
                / nullIf(toFloat64(coalesce(m.home_score, 0)), 0),
            1
        ), 0.0),
        1
    )) AS dead_ball_goal_share_delta_pct,

    coalesce(away_db.team_dead_ball_shots, 0) AS triggered_team_dead_ball_shots,
    coalesce(home_db.team_dead_ball_shots, 0) AS opponent_dead_ball_shots,
    toFloat32(coalesce(away_db.team_dead_ball_xg, 0.0)) AS triggered_team_dead_ball_xg,
    toFloat32(coalesce(home_db.team_dead_ball_xg, 0.0)) AS opponent_dead_ball_xg,
    toFloat32(round(
        coalesce(away_db.team_dead_ball_xg, 0.0) - coalesce(home_db.team_dead_ball_xg, 0.0),
        3
    )) AS dead_ball_xg_delta,

    toFloat32(coalesce(round(
        coalesce(away_db.team_dead_ball_goals, 0)
            / nullIf(toFloat64(coalesce(away_db.team_dead_ball_shots, 0)), 0),
        3
    ), 0.0)) AS triggered_team_dead_ball_goals_per_shot,
    toFloat32(coalesce(round(
        coalesce(home_db.team_dead_ball_goals, 0)
            / nullIf(toFloat64(coalesce(home_db.team_dead_ball_shots, 0)), 0),
        3
    ), 0.0)) AS opponent_dead_ball_goals_per_shot,
    toFloat32(round(
        coalesce(round(
            coalesce(away_db.team_dead_ball_goals, 0)
                / nullIf(toFloat64(coalesce(away_db.team_dead_ball_shots, 0)), 0),
            3
        ), 0.0)
      - coalesce(round(
            coalesce(home_db.team_dead_ball_goals, 0)
                / nullIf(toFloat64(coalesce(home_db.team_dead_ball_shots, 0)), 0),
            3
        ), 0.0),
        3
    )) AS dead_ball_goals_per_shot_delta,

    coalesce(ps.total_shots_away, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_home, 0) AS opponent_total_shots,
    coalesce(ps.shots_on_target_away, 0) AS triggered_team_shots_on_target,
    coalesce(ps.shots_on_target_home, 0) AS opponent_shots_on_target,
    toFloat32(coalesce(ps.expected_goals_away, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_away, 0) - coalesce(ps.expected_goals_home, 0), 3)) AS xg_delta,

    toFloat32(coalesce(ps.expected_goals_set_play_away, 0)) AS triggered_team_set_play_xg,
    toFloat32(coalesce(ps.expected_goals_set_play_home, 0)) AS opponent_set_play_xg,
    toFloat32(round(
        coalesce(ps.expected_goals_set_play_away, 0) - coalesce(ps.expected_goals_set_play_home, 0),
        3
    )) AS set_play_xg_delta,

    coalesce(ps.corners_away, 0) AS triggered_team_corners,
    coalesce(ps.corners_home, 0) AS opponent_corners,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_away, 0) - coalesce(ps.ball_possession_home, 0), 1))
        AS possession_delta_pct,

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
LEFT JOIN dead_ball_team_stats AS home_db
    ON home_db.match_id = m.match_id
   AND home_db.team_id = m.home_team_id
LEFT JOIN dead_ball_team_stats AS away_db
    ON away_db.match_id = m.match_id
   AND away_db.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(away_db.team_dead_ball_goals, 0) >= 2

ORDER BY
    triggered_team_dead_ball_goals DESC,
    triggered_team_dead_ball_goal_share_pct DESC,
    m.match_date DESC,
    m.match_id DESC;
