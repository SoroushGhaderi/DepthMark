INSERT INTO gold.sig_team_possession_passing_set_piece_focus (
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
    trigger_threshold_corners,
    triggered_team_corners,
    opponent_corners,
    corner_delta,
    triggered_team_set_piece_shots,
    opponent_set_piece_shots,
    triggered_team_set_play_xg,
    opponent_set_play_xg,
    set_play_xg_delta,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_accurate_passes,
    opponent_accurate_passes,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_cross_attempts,
    opponent_cross_attempts,
    cross_attempts_delta,
    triggered_team_opposition_half_passes,
    opponent_opposition_half_passes,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_player_throws,
    opponent_player_throws,
    triggered_team_dead_ball_restart_passes_proxy,
    opponent_dead_ball_restart_passes_proxy,
    triggered_team_dead_ball_restart_pass_share_pct,
    opponent_dead_ball_restart_pass_share_pct
)
-- Signal: sig_team_possession_passing_set_piece_focus
-- Trigger: Team wins >= 15 corners in a single match.
-- Intent: detect team-level set-piece-focused possession/passing profiles driven by extreme corner volume, with bilateral passing and attacking context.

WITH set_piece_team_shots AS (
    SELECT
        s.match_id,
        assumeNotNull(s.team_id) AS team_id,
        count() AS team_set_piece_shots
    FROM silver.shot AS s
    WHERE s.team_id IS NOT NULL
      AND s.situation IN ('FromCorner', 'FreeKick', 'SetPiece', 'ThrowInSetPiece')
    GROUP BY
        s.match_id,
        s.team_id
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
        coalesce(ps.pass_attempts_home, 0) AS pass_attempts_home,
        coalesce(ps.pass_attempts_away, 0) AS pass_attempts_away,
        coalesce(ps.accurate_passes_home, 0) AS accurate_passes_home,
        coalesce(ps.accurate_passes_away, 0) AS accurate_passes_away,
        coalesce(ps.cross_attempts_home, 0) AS cross_attempts_home,
        coalesce(ps.cross_attempts_away, 0) AS cross_attempts_away,
        coalesce(ps.opposition_half_passes_home, 0) AS opposition_half_passes_home,
        coalesce(ps.opposition_half_passes_away, 0) AS opposition_half_passes_away,
        coalesce(ps.touches_opp_box_home, 0) AS touches_opposition_box_home,
        coalesce(ps.touches_opp_box_away, 0) AS touches_opposition_box_away,
        coalesce(ps.total_shots_home, 0) AS total_shots_home,
        coalesce(ps.total_shots_away, 0) AS total_shots_away,
        toFloat32(coalesce(ps.ball_possession_home, 0)) AS possession_home_pct,
        toFloat32(coalesce(ps.ball_possession_away, 0)) AS possession_away_pct,
        coalesce(ps.corners_home, 0) AS corners_home,
        coalesce(ps.corners_away, 0) AS corners_away,
        coalesce(ps.player_throws_home, 0) AS player_throws_home,
        coalesce(ps.player_throws_away, 0) AS player_throws_away,
        toFloat32(coalesce(ps.expected_goals_set_play_home, 0)) AS expected_goals_set_play_home,
        toFloat32(coalesce(ps.expected_goals_set_play_away, 0)) AS expected_goals_set_play_away,
        coalesce(hs.team_set_piece_shots, 0) AS set_piece_shots_home,
        coalesce(away_sp.team_set_piece_shots, 0) AS set_piece_shots_away
    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.match_date = m.match_date
       AND ps.period = 'All'
    LEFT JOIN set_piece_team_shots AS hs
        ON hs.match_id = m.match_id
       AND hs.team_id = m.home_team_id
    LEFT JOIN set_piece_team_shots AS away_sp
        ON away_sp.match_id = m.match_id
       AND away_sp.team_id = m.away_team_id
    WHERE m.match_finished = 1
      AND m.match_id > 0
),
triggered_rows AS (
-- Home-side triggers.
SELECT
    match_id,
    match_date,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,

    'home' AS triggered_side,
    home_team_id AS triggered_team_id,
    home_team_name AS triggered_team_name,
    away_team_id AS opponent_team_id,
    away_team_name AS opponent_team_name,

    15 AS trigger_threshold_corners,
    corners_home AS triggered_team_corners,
    corners_away AS opponent_corners,
    corners_home - corners_away AS corner_delta,

    set_piece_shots_home AS triggered_team_set_piece_shots,
    set_piece_shots_away AS opponent_set_piece_shots,
    expected_goals_set_play_home AS triggered_team_set_play_xg,
    expected_goals_set_play_away AS opponent_set_play_xg,
    toFloat32(round(expected_goals_set_play_home - expected_goals_set_play_away, 3)) AS set_play_xg_delta,

    pass_attempts_home AS triggered_team_pass_attempts,
    pass_attempts_away AS opponent_pass_attempts,
    accurate_passes_home AS triggered_team_accurate_passes,
    accurate_passes_away AS opponent_accurate_passes,
    toFloat32(coalesce(round(
        100.0 * accurate_passes_home / nullIf(toFloat64(pass_attempts_home), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * accurate_passes_away / nullIf(toFloat64(pass_attempts_away), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * accurate_passes_home / nullIf(toFloat64(pass_attempts_home), 0), 1), 0.0)
      - coalesce(round(100.0 * accurate_passes_away / nullIf(toFloat64(pass_attempts_away), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    cross_attempts_home AS triggered_team_cross_attempts,
    cross_attempts_away AS opponent_cross_attempts,
    cross_attempts_home - cross_attempts_away AS cross_attempts_delta,

    opposition_half_passes_home AS triggered_team_opposition_half_passes,
    opposition_half_passes_away AS opponent_opposition_half_passes,
    touches_opposition_box_home AS triggered_team_touches_opposition_box,
    touches_opposition_box_away AS opponent_touches_opposition_box,
    total_shots_home AS triggered_team_total_shots,
    total_shots_away AS opponent_total_shots,
    possession_home_pct AS triggered_team_possession_pct,
    possession_away_pct AS opponent_possession_pct,

    player_throws_home AS triggered_team_player_throws,
    player_throws_away AS opponent_player_throws,
    player_throws_home + corners_home AS triggered_team_dead_ball_restart_passes_proxy,
    player_throws_away + corners_away AS opponent_dead_ball_restart_passes_proxy,
    toFloat32(coalesce(round(
        100.0 * (player_throws_home + corners_home) / nullIf(toFloat64(pass_attempts_home), 0),
        1
    ), 0.0)) AS triggered_team_dead_ball_restart_pass_share_pct,
    toFloat32(coalesce(round(
        100.0 * (player_throws_away + corners_away) / nullIf(toFloat64(pass_attempts_away), 0),
        1
    ), 0.0)) AS opponent_dead_ball_restart_pass_share_pct
FROM base_stats AS b
WHERE b.corners_home >= 15

UNION ALL

-- Away-side triggers.
SELECT
    match_id,
    match_date,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,

    'away' AS triggered_side,
    away_team_id AS triggered_team_id,
    away_team_name AS triggered_team_name,
    home_team_id AS opponent_team_id,
    home_team_name AS opponent_team_name,

    15 AS trigger_threshold_corners,
    corners_away AS triggered_team_corners,
    corners_home AS opponent_corners,
    corners_away - corners_home AS corner_delta,

    set_piece_shots_away AS triggered_team_set_piece_shots,
    set_piece_shots_home AS opponent_set_piece_shots,
    expected_goals_set_play_away AS triggered_team_set_play_xg,
    expected_goals_set_play_home AS opponent_set_play_xg,
    toFloat32(round(expected_goals_set_play_away - expected_goals_set_play_home, 3)) AS set_play_xg_delta,

    pass_attempts_away AS triggered_team_pass_attempts,
    pass_attempts_home AS opponent_pass_attempts,
    accurate_passes_away AS triggered_team_accurate_passes,
    accurate_passes_home AS opponent_accurate_passes,
    toFloat32(coalesce(round(
        100.0 * accurate_passes_away / nullIf(toFloat64(pass_attempts_away), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * accurate_passes_home / nullIf(toFloat64(pass_attempts_home), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * accurate_passes_away / nullIf(toFloat64(pass_attempts_away), 0), 1), 0.0)
      - coalesce(round(100.0 * accurate_passes_home / nullIf(toFloat64(pass_attempts_home), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    cross_attempts_away AS triggered_team_cross_attempts,
    cross_attempts_home AS opponent_cross_attempts,
    cross_attempts_away - cross_attempts_home AS cross_attempts_delta,

    opposition_half_passes_away AS triggered_team_opposition_half_passes,
    opposition_half_passes_home AS opponent_opposition_half_passes,
    touches_opposition_box_away AS triggered_team_touches_opposition_box,
    touches_opposition_box_home AS opponent_touches_opposition_box,
    total_shots_away AS triggered_team_total_shots,
    total_shots_home AS opponent_total_shots,
    possession_away_pct AS triggered_team_possession_pct,
    possession_home_pct AS opponent_possession_pct,

    player_throws_away AS triggered_team_player_throws,
    player_throws_home AS opponent_player_throws,
    player_throws_away + corners_away AS triggered_team_dead_ball_restart_passes_proxy,
    player_throws_home + corners_home AS opponent_dead_ball_restart_passes_proxy,
    toFloat32(coalesce(round(
        100.0 * (player_throws_away + corners_away) / nullIf(toFloat64(pass_attempts_away), 0),
        1
    ), 0.0)) AS triggered_team_dead_ball_restart_pass_share_pct,
    toFloat32(coalesce(round(
        100.0 * (player_throws_home + corners_home) / nullIf(toFloat64(pass_attempts_home), 0),
        1
    ), 0.0)) AS opponent_dead_ball_restart_pass_share_pct
FROM base_stats AS b
WHERE b.corners_away >= 15
)

SELECT
    t.match_id,
    t.match_date,
    t.home_team_id,
    t.home_team_name,
    t.away_team_id,
    t.away_team_name,
    t.home_score,
    t.away_score,
    t.triggered_side,
    t.triggered_team_id,
    t.triggered_team_name,
    t.opponent_team_id,
    t.opponent_team_name,
    t.trigger_threshold_corners,
    t.triggered_team_corners,
    t.opponent_corners,
    t.corner_delta,
    t.triggered_team_set_piece_shots,
    t.opponent_set_piece_shots,
    t.triggered_team_set_play_xg,
    t.opponent_set_play_xg,
    t.set_play_xg_delta,
    t.triggered_team_pass_attempts,
    t.opponent_pass_attempts,
    t.triggered_team_accurate_passes,
    t.opponent_accurate_passes,
    t.triggered_team_pass_accuracy_pct,
    t.opponent_pass_accuracy_pct,
    t.pass_accuracy_delta_pct,
    t.triggered_team_cross_attempts,
    t.opponent_cross_attempts,
    t.cross_attempts_delta,
    t.triggered_team_opposition_half_passes,
    t.opponent_opposition_half_passes,
    t.triggered_team_touches_opposition_box,
    t.opponent_touches_opposition_box,
    t.triggered_team_total_shots,
    t.opponent_total_shots,
    t.triggered_team_possession_pct,
    t.opponent_possession_pct,
    t.triggered_team_player_throws,
    t.opponent_player_throws,
    t.triggered_team_dead_ball_restart_passes_proxy,
    t.opponent_dead_ball_restart_passes_proxy,
    t.triggered_team_dead_ball_restart_pass_share_pct,
    t.opponent_dead_ball_restart_pass_share_pct
FROM triggered_rows AS t

ORDER BY
    triggered_team_corners DESC,
    match_date DESC,
    match_id DESC;
