INSERT INTO gold.sig_match_possession_passing_set_piece_dominance (
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
    match_total_pass_attempts,
    match_total_dead_ball_restart_passes_proxy,
    match_dead_ball_restart_pass_share_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_dead_ball_restart_passes_proxy,
    opponent_dead_ball_restart_passes_proxy,
    triggered_team_dead_ball_restart_pass_share_pct,
    opponent_dead_ball_restart_pass_share_pct,
    triggered_team_dead_ball_share_of_match_passes_pct,
    opponent_dead_ball_share_of_match_passes_pct,
    triggered_team_dead_ball_share_of_match_dead_ball_restart_passes_pct,
    opponent_dead_ball_share_of_match_dead_ball_restart_passes_pct,
    triggered_team_player_throws,
    opponent_player_throws,
    triggered_team_corners,
    opponent_corners,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_set_piece_shots,
    opponent_set_piece_shots,
    triggered_team_set_play_xg,
    opponent_set_play_xg,
    set_play_xg_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_possession_pct,
    opponent_possession_pct
)
-- ============================================================
-- Signal: sig_match_possession_passing_set_piece_dominance
-- Intent: Detect matches where restart-led circulation dominates total
--         passing volume, then orient output per side for bilateral analysis.
-- Trigger: match_dead_ball_restart_pass_share_pct > 15 (proxy-calibrated).
-- Notes: Dead-ball restart pass volume is proxied with
--        (player_throws + corners) because explicit free-kick pass counts
--        are not available in silver.period_stat. A 15% proxy threshold is
--        used as practical calibration for the intended 20% true restart share.
-- ============================================================

WITH
    set_piece_team_shots AS (
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
            m.match_id AS match_id,
            m.match_date AS match_date,
            m.home_team_id AS home_team_id,
            m.home_team_name AS home_team_name,
            m.away_team_id AS away_team_id,
            m.away_team_name AS away_team_name,
            m.home_score AS home_score,
            m.away_score AS away_score,
            coalesce(ps.pass_attempts_home, 0) AS pass_attempts_home,
            coalesce(ps.pass_attempts_away, 0) AS pass_attempts_away,
            coalesce(ps.accurate_passes_home, 0) AS accurate_passes_home,
            coalesce(ps.accurate_passes_away, 0) AS accurate_passes_away,
            coalesce(ps.player_throws_home, 0) AS player_throws_home,
            coalesce(ps.player_throws_away, 0) AS player_throws_away,
            coalesce(ps.corners_home, 0) AS corners_home,
            coalesce(ps.corners_away, 0) AS corners_away,
            coalesce(ps.total_shots_home, 0) AS total_shots_home,
            coalesce(ps.total_shots_away, 0) AS total_shots_away,
            toFloat32(coalesce(ps.ball_possession_home, 0)) AS ball_possession_home,
            toFloat32(coalesce(ps.ball_possession_away, 0)) AS ball_possession_away,
            toFloat32(coalesce(ps.expected_goals_set_play_home, 0)) AS expected_goals_set_play_home,
            toFloat32(coalesce(ps.expected_goals_set_play_away, 0)) AS expected_goals_set_play_away,
            coalesce(hs.team_set_piece_shots, 0) AS set_piece_shots_home,
            coalesce(away_sp.team_set_piece_shots, 0) AS set_piece_shots_away,
            coalesce(ps.player_throws_home, 0) + coalesce(ps.corners_home, 0) AS dead_ball_restart_passes_proxy_home,
            coalesce(ps.player_throws_away, 0) + coalesce(ps.corners_away, 0) AS dead_ball_restart_passes_proxy_away,
            coalesce(ps.pass_attempts_home, 0) + coalesce(ps.pass_attempts_away, 0) AS match_total_pass_attempts,
            coalesce(ps.player_throws_home, 0)
                + coalesce(ps.corners_home, 0)
                + coalesce(ps.player_throws_away, 0)
                + coalesce(ps.corners_away, 0) AS match_total_dead_ball_restart_passes_proxy,
            toFloat32(round(
                100.0
                * (
                    coalesce(ps.player_throws_home, 0)
                    + coalesce(ps.corners_home, 0)
                    + coalesce(ps.player_throws_away, 0)
                    + coalesce(ps.corners_away, 0)
                )
                / nullIf(
                    toFloat64(coalesce(ps.pass_attempts_home, 0) + coalesce(ps.pass_attempts_away, 0)),
                    0
                ),
                1
            )) AS match_dead_ball_restart_pass_share_pct
        FROM silver.match AS m FINAL
        INNER JOIN silver.period_stat AS ps FINAL
            ON  ps.match_id = m.match_id
            AND ps.period   = 'All'
        LEFT JOIN set_piece_team_shots AS hs
            ON  hs.match_id = m.match_id
            AND hs.team_id  = m.home_team_id
        LEFT JOIN set_piece_team_shots AS away_sp
            ON  away_sp.match_id = m.match_id
            AND away_sp.team_id  = m.away_team_id
        WHERE m.match_finished = 1
          AND m.match_id > 0
          AND (coalesce(ps.pass_attempts_home, 0) + coalesce(ps.pass_attempts_away, 0)) > 0
          AND (
              toFloat64(
                  coalesce(ps.player_throws_home, 0)
                  + coalesce(ps.corners_home, 0)
                  + coalesce(ps.player_throws_away, 0)
                  + coalesce(ps.corners_away, 0)
              )
              / nullIf(
                  toFloat64(coalesce(ps.pass_attempts_home, 0) + coalesce(ps.pass_attempts_away, 0)),
                  0
              )
          ) > 0.15
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

    b.match_total_pass_attempts,
    b.match_total_dead_ball_restart_passes_proxy,
    b.match_dead_ball_restart_pass_share_pct,

    b.pass_attempts_home AS triggered_team_pass_attempts,
    b.pass_attempts_away AS opponent_pass_attempts,
    b.dead_ball_restart_passes_proxy_home AS triggered_team_dead_ball_restart_passes_proxy,
    b.dead_ball_restart_passes_proxy_away AS opponent_dead_ball_restart_passes_proxy,

    toFloat32(coalesce(round(
        100.0 * b.dead_ball_restart_passes_proxy_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS triggered_team_dead_ball_restart_pass_share_pct,
    toFloat32(coalesce(round(
        100.0 * b.dead_ball_restart_passes_proxy_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS opponent_dead_ball_restart_pass_share_pct,

    toFloat32(round(
        100.0 * b.dead_ball_restart_passes_proxy_home / nullIf(toFloat64(b.match_total_pass_attempts), 0),
        1
    )) AS triggered_team_dead_ball_share_of_match_passes_pct,
    toFloat32(round(
        100.0 * b.dead_ball_restart_passes_proxy_away / nullIf(toFloat64(b.match_total_pass_attempts), 0),
        1
    )) AS opponent_dead_ball_share_of_match_passes_pct,

    toFloat32(coalesce(round(
        100.0 * b.dead_ball_restart_passes_proxy_home / nullIf(toFloat64(b.match_total_dead_ball_restart_passes_proxy), 0),
        1
    ), 0.0)) AS triggered_team_dead_ball_share_of_match_dead_ball_restart_passes_pct,
    toFloat32(coalesce(round(
        100.0 * b.dead_ball_restart_passes_proxy_away / nullIf(toFloat64(b.match_total_dead_ball_restart_passes_proxy), 0),
        1
    ), 0.0)) AS opponent_dead_ball_share_of_match_dead_ball_restart_passes_pct,

    b.player_throws_home AS triggered_team_player_throws,
    b.player_throws_away AS opponent_player_throws,
    b.corners_home AS triggered_team_corners,
    b.corners_away AS opponent_corners,

    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,

    b.set_piece_shots_home AS triggered_team_set_piece_shots,
    b.set_piece_shots_away AS opponent_set_piece_shots,
    b.expected_goals_set_play_home AS triggered_team_set_play_xg,
    b.expected_goals_set_play_away AS opponent_set_play_xg,
    toFloat32(round(
        b.expected_goals_set_play_home - b.expected_goals_set_play_away,
        3
    )) AS set_play_xg_delta,

    b.total_shots_home AS triggered_team_total_shots,
    b.total_shots_away AS opponent_total_shots,
    b.ball_possession_home AS triggered_team_possession_pct,
    b.ball_possession_away AS opponent_possession_pct
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

    b.match_total_pass_attempts,
    b.match_total_dead_ball_restart_passes_proxy,
    b.match_dead_ball_restart_pass_share_pct,

    b.pass_attempts_away AS triggered_team_pass_attempts,
    b.pass_attempts_home AS opponent_pass_attempts,
    b.dead_ball_restart_passes_proxy_away AS triggered_team_dead_ball_restart_passes_proxy,
    b.dead_ball_restart_passes_proxy_home AS opponent_dead_ball_restart_passes_proxy,

    toFloat32(coalesce(round(
        100.0 * b.dead_ball_restart_passes_proxy_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS triggered_team_dead_ball_restart_pass_share_pct,
    toFloat32(coalesce(round(
        100.0 * b.dead_ball_restart_passes_proxy_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS opponent_dead_ball_restart_pass_share_pct,

    toFloat32(round(
        100.0 * b.dead_ball_restart_passes_proxy_away / nullIf(toFloat64(b.match_total_pass_attempts), 0),
        1
    )) AS triggered_team_dead_ball_share_of_match_passes_pct,
    toFloat32(round(
        100.0 * b.dead_ball_restart_passes_proxy_home / nullIf(toFloat64(b.match_total_pass_attempts), 0),
        1
    )) AS opponent_dead_ball_share_of_match_passes_pct,

    toFloat32(coalesce(round(
        100.0 * b.dead_ball_restart_passes_proxy_away / nullIf(toFloat64(b.match_total_dead_ball_restart_passes_proxy), 0),
        1
    ), 0.0)) AS triggered_team_dead_ball_share_of_match_dead_ball_restart_passes_pct,
    toFloat32(coalesce(round(
        100.0 * b.dead_ball_restart_passes_proxy_home / nullIf(toFloat64(b.match_total_dead_ball_restart_passes_proxy), 0),
        1
    ), 0.0)) AS opponent_dead_ball_share_of_match_dead_ball_restart_passes_pct,

    b.player_throws_away AS triggered_team_player_throws,
    b.player_throws_home AS opponent_player_throws,
    b.corners_away AS triggered_team_corners,
    b.corners_home AS opponent_corners,

    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,

    b.set_piece_shots_away AS triggered_team_set_piece_shots,
    b.set_piece_shots_home AS opponent_set_piece_shots,
    b.expected_goals_set_play_away AS triggered_team_set_play_xg,
    b.expected_goals_set_play_home AS opponent_set_play_xg,
    toFloat32(round(
        b.expected_goals_set_play_away - b.expected_goals_set_play_home,
        3
    )) AS set_play_xg_delta,

    b.total_shots_away AS triggered_team_total_shots,
    b.total_shots_home AS opponent_total_shots,
    b.ball_possession_away AS triggered_team_possession_pct,
    b.ball_possession_home AS opponent_possession_pct
FROM base_stats AS b

ORDER BY match_id, triggered_side;
