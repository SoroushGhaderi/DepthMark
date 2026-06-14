INSERT INTO gold.sig_match_possession_passing_counter_vs_bus (
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
    possession_dominant_side,
    possession_dominant_team_id,
    possession_dominant_team_name,
    counter_attacking_side,
    counter_attacking_team_id,
    counter_attacking_team_name,
    possession_dominant_team_possession_pct,
    counter_attacking_team_counter_attacks_proxy,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_counter_attacks_proxy,
    opponent_counter_attacks_proxy,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    triggered_team_clearances,
    opponent_clearances,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    possession_gap_pct,
    counter_attack_gap_proxy
)
-- ============================================================
-- Signal: sig_match_possession_passing_counter_vs_bus
-- Intent: Detect matches where one side dominates possession while
--         the other side generates frequent counter-attacking threat,
--         then emit bilateral side-oriented context.
-- Trigger: one team possession > 70 and opponent counter_attacks_proxy > 5.
-- Notes: counter_attacks_proxy is derived from silver.shot.situation
--        string patterns containing "counter" or "fast" because no
--        explicit counter-attack count exists in silver.period_stat.
-- ============================================================

WITH
    counter_attack_team_shots AS (
        SELECT
            s.match_id,
            assumeNotNull(s.team_id) AS team_id,
            countIf(
                match(lowerUTF8(coalesce(s.situation, '')), 'counter|fast')
            ) AS counter_attacks_proxy
        FROM silver.shot AS s
        WHERE s.team_id IS NOT NULL
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
            toFloat32(coalesce(ps.ball_possession_home, 0)) AS ball_possession_home,
            toFloat32(coalesce(ps.ball_possession_away, 0)) AS ball_possession_away,
            coalesce(ps.pass_attempts_home, 0) AS pass_attempts_home,
            coalesce(ps.pass_attempts_away, 0) AS pass_attempts_away,
            coalesce(ps.accurate_passes_home, 0) AS accurate_passes_home,
            coalesce(ps.accurate_passes_away, 0) AS accurate_passes_away,
            coalesce(ps.total_shots_home, 0) AS total_shots_home,
            coalesce(ps.total_shots_away, 0) AS total_shots_away,
            coalesce(ps.touches_opp_box_home, 0) AS touches_opposition_box_home,
            coalesce(ps.touches_opp_box_away, 0) AS touches_opposition_box_away,
            coalesce(ps.clearances_home, 0) AS clearances_home,
            coalesce(ps.clearances_away, 0) AS clearances_away,
            toFloat32(coalesce(ps.expected_goals_home, 0)) AS expected_goals_home,
            toFloat32(coalesce(ps.expected_goals_away, 0)) AS expected_goals_away,
            coalesce(ca_home.counter_attacks_proxy, 0) AS counter_attacks_proxy_home,
            coalesce(ca_away.counter_attacks_proxy, 0) AS counter_attacks_proxy_away,
            if(
                toFloat32(coalesce(ps.ball_possession_home, 0)) > 70
                AND coalesce(ca_away.counter_attacks_proxy, 0) > 5,
                'home',
                if(
                    toFloat32(coalesce(ps.ball_possession_away, 0)) > 70
                    AND coalesce(ca_home.counter_attacks_proxy, 0) > 5,
                    'away',
                    'none'
                )
            ) AS possession_dominant_side,
            if(
                toFloat32(coalesce(ps.ball_possession_home, 0)) > 70
                AND coalesce(ca_away.counter_attacks_proxy, 0) > 5,
                'away',
                if(
                    toFloat32(coalesce(ps.ball_possession_away, 0)) > 70
                    AND coalesce(ca_home.counter_attacks_proxy, 0) > 5,
                    'home',
                    'none'
                )
            ) AS counter_attacking_side
        FROM silver.match AS m FINAL
        INNER JOIN silver.period_stat AS ps FINAL
            ON  ps.match_id = m.match_id
            AND ps.period = 'All'
        LEFT JOIN counter_attack_team_shots AS ca_home
            ON  ca_home.match_id = m.match_id
            AND ca_home.team_id = m.home_team_id
        LEFT JOIN counter_attack_team_shots AS ca_away
            ON  ca_away.match_id = m.match_id
            AND ca_away.team_id = m.away_team_id
        WHERE m.match_finished = 1
          AND m.match_id > 0
          AND (
                (
                    toFloat32(coalesce(ps.ball_possession_home, 0)) > 70
                    AND coalesce(ca_away.counter_attacks_proxy, 0) > 5
                )
                OR
                (
                    toFloat32(coalesce(ps.ball_possession_away, 0)) > 70
                    AND coalesce(ca_home.counter_attacks_proxy, 0) > 5
                )
          )
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

    b.possession_dominant_side,
    if(b.possession_dominant_side = 'home', b.home_team_id, b.away_team_id) AS possession_dominant_team_id,
    if(b.possession_dominant_side = 'home', b.home_team_name, b.away_team_name) AS possession_dominant_team_name,
    b.counter_attacking_side,
    if(b.counter_attacking_side = 'home', b.home_team_id, b.away_team_id) AS counter_attacking_team_id,
    if(b.counter_attacking_side = 'home', b.home_team_name, b.away_team_name) AS counter_attacking_team_name,

    if(b.possession_dominant_side = 'home', b.ball_possession_home, b.ball_possession_away) AS possession_dominant_team_possession_pct,
    if(b.counter_attacking_side = 'home', b.counter_attacks_proxy_home, b.counter_attacks_proxy_away) AS counter_attacking_team_counter_attacks_proxy,

    b.ball_possession_home AS triggered_team_possession_pct,
    b.ball_possession_away AS opponent_possession_pct,
    b.counter_attacks_proxy_home AS triggered_team_counter_attacks_proxy,
    b.counter_attacks_proxy_away AS opponent_counter_attacks_proxy,

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

    b.total_shots_home AS triggered_team_total_shots,
    b.total_shots_away AS opponent_total_shots,
    b.touches_opposition_box_home AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_away AS opponent_touches_opposition_box,
    b.clearances_home AS triggered_team_clearances,
    b.clearances_away AS opponent_clearances,
    b.expected_goals_home AS triggered_team_xg,
    b.expected_goals_away AS opponent_xg,
    toFloat32(round(b.expected_goals_home - b.expected_goals_away, 3)) AS xg_delta,
    toFloat32(round(abs(b.ball_possession_home - b.ball_possession_away), 1)) AS possession_gap_pct,
    toInt32(abs(b.counter_attacks_proxy_home - b.counter_attacks_proxy_away)) AS counter_attack_gap_proxy
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

    b.possession_dominant_side,
    if(b.possession_dominant_side = 'home', b.home_team_id, b.away_team_id) AS possession_dominant_team_id,
    if(b.possession_dominant_side = 'home', b.home_team_name, b.away_team_name) AS possession_dominant_team_name,
    b.counter_attacking_side,
    if(b.counter_attacking_side = 'home', b.home_team_id, b.away_team_id) AS counter_attacking_team_id,
    if(b.counter_attacking_side = 'home', b.home_team_name, b.away_team_name) AS counter_attacking_team_name,

    if(b.possession_dominant_side = 'home', b.ball_possession_home, b.ball_possession_away) AS possession_dominant_team_possession_pct,
    if(b.counter_attacking_side = 'home', b.counter_attacks_proxy_home, b.counter_attacks_proxy_away) AS counter_attacking_team_counter_attacks_proxy,

    b.ball_possession_away AS triggered_team_possession_pct,
    b.ball_possession_home AS opponent_possession_pct,
    b.counter_attacks_proxy_away AS triggered_team_counter_attacks_proxy,
    b.counter_attacks_proxy_home AS opponent_counter_attacks_proxy,

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

    b.total_shots_away AS triggered_team_total_shots,
    b.total_shots_home AS opponent_total_shots,
    b.touches_opposition_box_away AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_home AS opponent_touches_opposition_box,
    b.clearances_away AS triggered_team_clearances,
    b.clearances_home AS opponent_clearances,
    b.expected_goals_away AS triggered_team_xg,
    b.expected_goals_home AS opponent_xg,
    toFloat32(round(b.expected_goals_away - b.expected_goals_home, 3)) AS xg_delta,
    toFloat32(round(abs(b.ball_possession_home - b.ball_possession_away), 1)) AS possession_gap_pct,
    toInt32(abs(b.counter_attacks_proxy_home - b.counter_attacks_proxy_away)) AS counter_attack_gap_proxy
FROM base_stats AS b

ORDER BY match_id, triggered_side;
