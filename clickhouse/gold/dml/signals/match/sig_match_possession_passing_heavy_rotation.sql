INSERT INTO gold.sig_match_possession_passing_heavy_rotation (
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
    trigger_threshold_match_total_player_touches,
    trigger_threshold_max_player_touches,
    match_total_player_touches,
    match_max_player_touches,
    match_players_recorded,
    match_average_player_touches,
    triggered_team_total_player_touches,
    opponent_total_player_touches,
    triggered_team_max_player_touches,
    opponent_max_player_touches,
    triggered_team_players_recorded,
    opponent_players_recorded,
    triggered_team_top_touch_player_id,
    triggered_team_top_touch_player_name,
    triggered_team_top_touch_player_touches,
    opponent_top_touch_player_id,
    opponent_top_touch_player_name,
    opponent_top_touch_player_touches,
    triggered_team_touch_share_pct,
    opponent_touch_share_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_opposition_half_passes,
    opponent_opposition_half_passes,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    triggered_team_xg,
    opponent_xg,
    xg_gap
)
-- ============================================================
-- Signal: sig_match_possession_passing_heavy_rotation
-- Intent: Detect matches where possession load is distributed widely
--         instead of concentrated in a single high-touch focal player.
-- Trigger: Match total player touches > 1000 and match max player
--          touches <= 80.
-- ============================================================

WITH
    player_touches AS (
        SELECT
            p.match_id,
            p.team_id,
            p.player_id,
            argMax(p.player_name, coalesce(p.touches, 0)) AS player_name,
            max(coalesce(p.touches, 0)) AS player_touches
        FROM silver.player_match_stat AS p
        GROUP BY
            p.match_id,
            p.team_id,
            p.player_id
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
            toFloat32(coalesce(ps.ball_possession_home, 0)) AS ball_possession_home,
            toFloat32(coalesce(ps.ball_possession_away, 0)) AS ball_possession_away,
            coalesce(ps.opposition_half_passes_home, 0) AS opposition_half_passes_home,
            coalesce(ps.opposition_half_passes_away, 0) AS opposition_half_passes_away,
            coalesce(ps.touches_opp_box_home, 0) AS touches_opposition_box_home,
            coalesce(ps.touches_opp_box_away, 0) AS touches_opposition_box_away,
            toFloat32(coalesce(ps.expected_goals_home, 0)) AS expected_goals_home,
            toFloat32(coalesce(ps.expected_goals_away, 0)) AS expected_goals_away,
            toInt32(sumIf(pt.player_touches, pt.team_id = m.home_team_id)) AS home_team_total_player_touches,
            toInt32(sumIf(pt.player_touches, pt.team_id = m.away_team_id)) AS away_team_total_player_touches,
            toInt32(maxIf(pt.player_touches, pt.team_id = m.home_team_id)) AS home_team_max_player_touches,
            toInt32(maxIf(pt.player_touches, pt.team_id = m.away_team_id)) AS away_team_max_player_touches,
            toInt32(countIf(pt.team_id = m.home_team_id)) AS home_team_players_recorded,
            toInt32(countIf(pt.team_id = m.away_team_id)) AS away_team_players_recorded,
            nullIf(
                argMaxIf(pt.player_id, tuple(pt.player_touches, pt.player_id), pt.team_id = m.home_team_id),
                0
            ) AS home_team_top_touch_player_id,
            argMaxIf(
                pt.player_name,
                tuple(pt.player_touches, pt.player_id),
                pt.team_id = m.home_team_id
            ) AS home_team_top_touch_player_name,
            toInt32(maxIf(pt.player_touches, pt.team_id = m.home_team_id)) AS home_team_top_touch_player_touches,
            nullIf(
                argMaxIf(pt.player_id, tuple(pt.player_touches, pt.player_id), pt.team_id = m.away_team_id),
                0
            ) AS away_team_top_touch_player_id,
            argMaxIf(
                pt.player_name,
                tuple(pt.player_touches, pt.player_id),
                pt.team_id = m.away_team_id
            ) AS away_team_top_touch_player_name,
            toInt32(maxIf(pt.player_touches, pt.team_id = m.away_team_id)) AS away_team_top_touch_player_touches
        FROM silver.match AS m FINAL
        INNER JOIN silver.period_stat AS ps FINAL
            ON  ps.match_id = m.match_id
            AND ps.period = 'All'
        LEFT JOIN player_touches AS pt
            ON pt.match_id = m.match_id
        WHERE m.match_finished = 1
          AND m.match_id > 0
        GROUP BY
            m.match_id,
            m.match_date,
            m.home_team_id,
            m.home_team_name,
            m.away_team_id,
            m.away_team_name,
            m.home_score,
            m.away_score,
            ps.pass_attempts_home,
            ps.pass_attempts_away,
            ps.accurate_passes_home,
            ps.accurate_passes_away,
            ps.ball_possession_home,
            ps.ball_possession_away,
            ps.opposition_half_passes_home,
            ps.opposition_half_passes_away,
            ps.touches_opp_box_home,
            ps.touches_opp_box_away,
            ps.expected_goals_home,
            ps.expected_goals_away
        HAVING
            (home_team_total_player_touches + away_team_total_player_touches) > 1000
            AND greatest(home_team_max_player_touches, away_team_max_player_touches) <= 80
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
    toInt32(1000) AS trigger_threshold_match_total_player_touches,
    toInt32(80) AS trigger_threshold_max_player_touches,
    b.home_team_total_player_touches + b.away_team_total_player_touches AS match_total_player_touches,
    greatest(b.home_team_max_player_touches, b.away_team_max_player_touches) AS match_max_player_touches,
    b.home_team_players_recorded + b.away_team_players_recorded AS match_players_recorded,
    toFloat32(round(
        (b.home_team_total_player_touches + b.away_team_total_player_touches)
        / nullIf(toFloat64(b.home_team_players_recorded + b.away_team_players_recorded), 0),
        1
    )) AS match_average_player_touches,
    b.home_team_total_player_touches AS triggered_team_total_player_touches,
    b.away_team_total_player_touches AS opponent_total_player_touches,
    b.home_team_max_player_touches AS triggered_team_max_player_touches,
    b.away_team_max_player_touches AS opponent_max_player_touches,
    b.home_team_players_recorded AS triggered_team_players_recorded,
    b.away_team_players_recorded AS opponent_players_recorded,
    b.home_team_top_touch_player_id AS triggered_team_top_touch_player_id,
    b.home_team_top_touch_player_name AS triggered_team_top_touch_player_name,
    b.home_team_top_touch_player_touches AS triggered_team_top_touch_player_touches,
    b.away_team_top_touch_player_id AS opponent_top_touch_player_id,
    b.away_team_top_touch_player_name AS opponent_top_touch_player_name,
    b.away_team_top_touch_player_touches AS opponent_top_touch_player_touches,
    toFloat32(round(
        100.0 * b.home_team_total_player_touches
        / nullIf(toFloat64(b.home_team_total_player_touches + b.away_team_total_player_touches), 0),
        1
    )) AS triggered_team_touch_share_pct,
    toFloat32(round(
        100.0 * b.away_team_total_player_touches
        / nullIf(toFloat64(b.home_team_total_player_touches + b.away_team_total_player_touches), 0),
        1
    )) AS opponent_touch_share_pct,
    b.pass_attempts_home AS triggered_team_pass_attempts,
    b.pass_attempts_away AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    b.ball_possession_home AS triggered_team_possession_pct,
    b.ball_possession_away AS opponent_possession_pct,
    b.opposition_half_passes_home AS triggered_team_opposition_half_passes,
    b.opposition_half_passes_away AS opponent_opposition_half_passes,
    b.touches_opposition_box_home AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_away AS opponent_touches_opposition_box,
    b.expected_goals_home AS triggered_team_xg,
    b.expected_goals_away AS opponent_xg,
    toFloat32(round(b.expected_goals_home - b.expected_goals_away, 3)) AS xg_gap
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
    toInt32(1000) AS trigger_threshold_match_total_player_touches,
    toInt32(80) AS trigger_threshold_max_player_touches,
    b.home_team_total_player_touches + b.away_team_total_player_touches AS match_total_player_touches,
    greatest(b.home_team_max_player_touches, b.away_team_max_player_touches) AS match_max_player_touches,
    b.home_team_players_recorded + b.away_team_players_recorded AS match_players_recorded,
    toFloat32(round(
        (b.home_team_total_player_touches + b.away_team_total_player_touches)
        / nullIf(toFloat64(b.home_team_players_recorded + b.away_team_players_recorded), 0),
        1
    )) AS match_average_player_touches,
    b.away_team_total_player_touches AS triggered_team_total_player_touches,
    b.home_team_total_player_touches AS opponent_total_player_touches,
    b.away_team_max_player_touches AS triggered_team_max_player_touches,
    b.home_team_max_player_touches AS opponent_max_player_touches,
    b.away_team_players_recorded AS triggered_team_players_recorded,
    b.home_team_players_recorded AS opponent_players_recorded,
    b.away_team_top_touch_player_id AS triggered_team_top_touch_player_id,
    b.away_team_top_touch_player_name AS triggered_team_top_touch_player_name,
    b.away_team_top_touch_player_touches AS triggered_team_top_touch_player_touches,
    b.home_team_top_touch_player_id AS opponent_top_touch_player_id,
    b.home_team_top_touch_player_name AS opponent_top_touch_player_name,
    b.home_team_top_touch_player_touches AS opponent_top_touch_player_touches,
    toFloat32(round(
        100.0 * b.away_team_total_player_touches
        / nullIf(toFloat64(b.home_team_total_player_touches + b.away_team_total_player_touches), 0),
        1
    )) AS triggered_team_touch_share_pct,
    toFloat32(round(
        100.0 * b.home_team_total_player_touches
        / nullIf(toFloat64(b.home_team_total_player_touches + b.away_team_total_player_touches), 0),
        1
    )) AS opponent_touch_share_pct,
    b.pass_attempts_away AS triggered_team_pass_attempts,
    b.pass_attempts_home AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    b.ball_possession_away AS triggered_team_possession_pct,
    b.ball_possession_home AS opponent_possession_pct,
    b.opposition_half_passes_away AS triggered_team_opposition_half_passes,
    b.opposition_half_passes_home AS opponent_opposition_half_passes,
    b.touches_opposition_box_away AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_home AS opponent_touches_opposition_box,
    b.expected_goals_away AS triggered_team_xg,
    b.expected_goals_home AS opponent_xg,
    toFloat32(round(b.expected_goals_away - b.expected_goals_home, 3)) AS xg_gap
FROM base_stats AS b

ORDER BY match_id, triggered_side;
