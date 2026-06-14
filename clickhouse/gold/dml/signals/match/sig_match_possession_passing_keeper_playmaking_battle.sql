INSERT INTO gold.sig_match_possession_passing_keeper_playmaking_battle (
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
    triggered_goalkeeper_player_id,
    triggered_goalkeeper_player_name,
    opponent_goalkeeper_player_id,
    opponent_goalkeeper_player_name,
    triggered_goalkeeper_pass_attempts,
    opponent_goalkeeper_pass_attempts,
    triggered_goalkeeper_accurate_passes,
    opponent_goalkeeper_accurate_passes,
    triggered_goalkeeper_pass_accuracy_pct,
    opponent_goalkeeper_pass_accuracy_pct,
    triggered_goalkeeper_share_of_team_passes_pct,
    opponent_goalkeeper_share_of_team_passes_pct,
    match_total_goalkeeper_pass_attempts,
    match_total_goalkeeper_accurate_passes,
    match_goalkeeper_pass_accuracy_pct,
    goalkeeper_pass_attempt_delta,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_own_half_passes,
    opponent_own_half_passes,
    triggered_team_long_ball_attempts,
    opponent_long_ball_attempts,
    triggered_team_possession_pct,
    opponent_possession_pct
)
-- ============================================================
-- Signal: sig_match_possession_passing_keeper_playmaking_battle
-- Intent: Detect matches where both goalkeepers are heavily involved in
--         circulation and expose bilateral keeper/team passing context.
-- Trigger: Both goalkeepers record > 40 passes each in the same match.
-- ============================================================

WITH
    goalkeeper_team_stats AS (
        SELECT
            p.match_id,
            assumeNotNull(p.team_id) AS team_id,
            argMax(p.player_id, coalesce(p.total_passes, 0)) AS goalkeeper_player_id,
            argMax(p.player_name, coalesce(p.total_passes, 0)) AS goalkeeper_player_name,
            max(coalesce(p.total_passes, 0)) AS goalkeeper_pass_attempts,
            argMax(coalesce(p.accurate_passes, 0), coalesce(p.total_passes, 0)) AS goalkeeper_accurate_passes
        FROM silver.player_match_stat AS p
        WHERE p.is_goalkeeper = 1
        GROUP BY
            p.match_id,
            assumeNotNull(p.team_id)
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
            hgk.goalkeeper_player_id AS home_goalkeeper_player_id,
            hgk.goalkeeper_player_name AS home_goalkeeper_player_name,
            hgk.goalkeeper_pass_attempts AS home_goalkeeper_pass_attempts,
            hgk.goalkeeper_accurate_passes AS home_goalkeeper_accurate_passes,
            agk.goalkeeper_player_id AS away_goalkeeper_player_id,
            agk.goalkeeper_player_name AS away_goalkeeper_player_name,
            agk.goalkeeper_pass_attempts AS away_goalkeeper_pass_attempts,
            agk.goalkeeper_accurate_passes AS away_goalkeeper_accurate_passes,
            coalesce(ps.pass_attempts_home, 0) AS pass_attempts_home,
            coalesce(ps.pass_attempts_away, 0) AS pass_attempts_away,
            coalesce(ps.accurate_passes_home, 0) AS accurate_passes_home,
            coalesce(ps.accurate_passes_away, 0) AS accurate_passes_away,
            coalesce(ps.own_half_passes_home, 0) AS own_half_passes_home,
            coalesce(ps.own_half_passes_away, 0) AS own_half_passes_away,
            coalesce(ps.long_ball_attempts_home, 0) AS long_ball_attempts_home,
            coalesce(ps.long_ball_attempts_away, 0) AS long_ball_attempts_away,
            toFloat32(coalesce(ps.ball_possession_home, 0)) AS ball_possession_home,
            toFloat32(coalesce(ps.ball_possession_away, 0)) AS ball_possession_away,
            hgk.goalkeeper_pass_attempts + agk.goalkeeper_pass_attempts AS match_total_goalkeeper_pass_attempts,
            hgk.goalkeeper_accurate_passes + agk.goalkeeper_accurate_passes AS match_total_goalkeeper_accurate_passes,
            toFloat32(round(
                100.0 * (hgk.goalkeeper_accurate_passes + agk.goalkeeper_accurate_passes)
                / nullIf(toFloat64(hgk.goalkeeper_pass_attempts + agk.goalkeeper_pass_attempts), 0),
                1
            )) AS match_goalkeeper_pass_accuracy_pct
        FROM silver.match AS m FINAL
        INNER JOIN silver.period_stat AS ps FINAL
            ON  ps.match_id = m.match_id
            AND ps.period = 'All'
        INNER JOIN goalkeeper_team_stats AS hgk
            ON  hgk.match_id = m.match_id
            AND hgk.team_id = m.home_team_id
        INNER JOIN goalkeeper_team_stats AS agk
            ON  agk.match_id = m.match_id
            AND agk.team_id = m.away_team_id
        WHERE m.match_finished = 1
          AND m.match_id > 0
          AND hgk.goalkeeper_pass_attempts > 40
          AND agk.goalkeeper_pass_attempts > 40
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
    b.home_goalkeeper_player_id AS triggered_goalkeeper_player_id,
    b.home_goalkeeper_player_name AS triggered_goalkeeper_player_name,
    b.away_goalkeeper_player_id AS opponent_goalkeeper_player_id,
    b.away_goalkeeper_player_name AS opponent_goalkeeper_player_name,
    b.home_goalkeeper_pass_attempts AS triggered_goalkeeper_pass_attempts,
    b.away_goalkeeper_pass_attempts AS opponent_goalkeeper_pass_attempts,
    b.home_goalkeeper_accurate_passes AS triggered_goalkeeper_accurate_passes,
    b.away_goalkeeper_accurate_passes AS opponent_goalkeeper_accurate_passes,
    toFloat32(round(
        100.0 * b.home_goalkeeper_accurate_passes / nullIf(toFloat64(b.home_goalkeeper_pass_attempts), 0),
        1
    )) AS triggered_goalkeeper_pass_accuracy_pct,
    toFloat32(round(
        100.0 * b.away_goalkeeper_accurate_passes / nullIf(toFloat64(b.away_goalkeeper_pass_attempts), 0),
        1
    )) AS opponent_goalkeeper_pass_accuracy_pct,
    toFloat32(round(
        100.0 * b.home_goalkeeper_pass_attempts / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    )) AS triggered_goalkeeper_share_of_team_passes_pct,
    toFloat32(round(
        100.0 * b.away_goalkeeper_pass_attempts / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    )) AS opponent_goalkeeper_share_of_team_passes_pct,
    b.match_total_goalkeeper_pass_attempts,
    b.match_total_goalkeeper_accurate_passes,
    b.match_goalkeeper_pass_accuracy_pct,
    b.home_goalkeeper_pass_attempts - b.away_goalkeeper_pass_attempts AS goalkeeper_pass_attempt_delta,
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
    b.own_half_passes_home AS triggered_team_own_half_passes,
    b.own_half_passes_away AS opponent_own_half_passes,
    b.long_ball_attempts_home AS triggered_team_long_ball_attempts,
    b.long_ball_attempts_away AS opponent_long_ball_attempts,
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
    b.away_goalkeeper_player_id AS triggered_goalkeeper_player_id,
    b.away_goalkeeper_player_name AS triggered_goalkeeper_player_name,
    b.home_goalkeeper_player_id AS opponent_goalkeeper_player_id,
    b.home_goalkeeper_player_name AS opponent_goalkeeper_player_name,
    b.away_goalkeeper_pass_attempts AS triggered_goalkeeper_pass_attempts,
    b.home_goalkeeper_pass_attempts AS opponent_goalkeeper_pass_attempts,
    b.away_goalkeeper_accurate_passes AS triggered_goalkeeper_accurate_passes,
    b.home_goalkeeper_accurate_passes AS opponent_goalkeeper_accurate_passes,
    toFloat32(round(
        100.0 * b.away_goalkeeper_accurate_passes / nullIf(toFloat64(b.away_goalkeeper_pass_attempts), 0),
        1
    )) AS triggered_goalkeeper_pass_accuracy_pct,
    toFloat32(round(
        100.0 * b.home_goalkeeper_accurate_passes / nullIf(toFloat64(b.home_goalkeeper_pass_attempts), 0),
        1
    )) AS opponent_goalkeeper_pass_accuracy_pct,
    toFloat32(round(
        100.0 * b.away_goalkeeper_pass_attempts / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    )) AS triggered_goalkeeper_share_of_team_passes_pct,
    toFloat32(round(
        100.0 * b.home_goalkeeper_pass_attempts / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    )) AS opponent_goalkeeper_share_of_team_passes_pct,
    b.match_total_goalkeeper_pass_attempts,
    b.match_total_goalkeeper_accurate_passes,
    b.match_goalkeeper_pass_accuracy_pct,
    b.away_goalkeeper_pass_attempts - b.home_goalkeeper_pass_attempts AS goalkeeper_pass_attempt_delta,
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
    b.own_half_passes_away AS triggered_team_own_half_passes,
    b.own_half_passes_home AS opponent_own_half_passes,
    b.long_ball_attempts_away AS triggered_team_long_ball_attempts,
    b.long_ball_attempts_home AS opponent_long_ball_attempts,
    b.ball_possession_away AS triggered_team_possession_pct,
    b.ball_possession_home AS opponent_possession_pct
FROM base_stats AS b

ORDER BY match_id, triggered_side;
