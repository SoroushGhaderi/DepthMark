INSERT INTO gold.sig_match_possession_passing_passing_clinic (
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
    trigger_threshold_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_gap_pct,
    match_min_half_pass_accuracy_pct,
    triggered_team_pass_accuracy_first_half_pct,
    triggered_team_pass_accuracy_second_half_pct,
    opponent_pass_accuracy_first_half_pct,
    opponent_pass_accuracy_second_half_pct,
    triggered_team_pass_accuracy_floor_pct,
    opponent_pass_accuracy_floor_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_pass_attempts_first_half,
    triggered_team_pass_attempts_second_half,
    opponent_pass_attempts_first_half,
    opponent_pass_attempts_second_half,
    triggered_team_opposition_half_passes,
    opponent_opposition_half_passes,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_xg,
    opponent_xg,
    xg_gap
)
-- ============================================================
-- Signal: sig_match_possession_passing_passing_clinic
-- Intent: Detect matches where both teams sustain elite pass completion
--         levels across the full match and both halves.
-- Trigger: Home and away pass accuracy > 88% in period='All',
--          period='FirstHalf', and period='SecondHalf'.
-- ============================================================

WITH
    all_stats AS (
        SELECT
            ps.match_id,
            coalesce(ps.pass_attempts_home, 0) AS pass_attempts_home,
            coalesce(ps.pass_attempts_away, 0) AS pass_attempts_away,
            coalesce(ps.accurate_passes_home, 0) AS accurate_passes_home,
            coalesce(ps.accurate_passes_away, 0) AS accurate_passes_away,
            coalesce(ps.opposition_half_passes_home, 0) AS opposition_half_passes_home,
            coalesce(ps.opposition_half_passes_away, 0) AS opposition_half_passes_away,
            coalesce(ps.touches_opp_box_home, 0) AS touches_opposition_box_home,
            coalesce(ps.touches_opp_box_away, 0) AS touches_opposition_box_away,
            coalesce(ps.total_shots_home, 0) AS total_shots_home,
            coalesce(ps.total_shots_away, 0) AS total_shots_away,
            toFloat32(coalesce(ps.expected_goals_home, 0)) AS expected_goals_home,
            toFloat32(coalesce(ps.expected_goals_away, 0)) AS expected_goals_away
        FROM silver.period_stat AS ps FINAL
        WHERE ps.period = 'All'
    ),
    half_stats AS (
        SELECT
            ps.match_id,
            maxIf(coalesce(ps.pass_attempts_home, 0), ps.period = 'FirstHalf') AS pass_attempts_home_first_half,
            maxIf(coalesce(ps.pass_attempts_home, 0), ps.period = 'SecondHalf') AS pass_attempts_home_second_half,
            maxIf(coalesce(ps.pass_attempts_away, 0), ps.period = 'FirstHalf') AS pass_attempts_away_first_half,
            maxIf(coalesce(ps.pass_attempts_away, 0), ps.period = 'SecondHalf') AS pass_attempts_away_second_half,
            maxIf(coalesce(ps.accurate_passes_home, 0), ps.period = 'FirstHalf') AS accurate_passes_home_first_half,
            maxIf(coalesce(ps.accurate_passes_home, 0), ps.period = 'SecondHalf') AS accurate_passes_home_second_half,
            maxIf(coalesce(ps.accurate_passes_away, 0), ps.period = 'FirstHalf') AS accurate_passes_away_first_half,
            maxIf(coalesce(ps.accurate_passes_away, 0), ps.period = 'SecondHalf') AS accurate_passes_away_second_half
        FROM silver.period_stat AS ps FINAL
        WHERE ps.period IN ('FirstHalf', 'SecondHalf')
        GROUP BY ps.match_id
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
            a.pass_attempts_home AS pass_attempts_home,
            a.pass_attempts_away AS pass_attempts_away,
            h.pass_attempts_home_first_half AS pass_attempts_home_first_half,
            h.pass_attempts_home_second_half AS pass_attempts_home_second_half,
            h.pass_attempts_away_first_half AS pass_attempts_away_first_half,
            h.pass_attempts_away_second_half AS pass_attempts_away_second_half,
            a.opposition_half_passes_home AS opposition_half_passes_home,
            a.opposition_half_passes_away AS opposition_half_passes_away,
            a.touches_opposition_box_home AS touches_opposition_box_home,
            a.touches_opposition_box_away AS touches_opposition_box_away,
            a.total_shots_home AS total_shots_home,
            a.total_shots_away AS total_shots_away,
            a.expected_goals_home AS expected_goals_home,
            a.expected_goals_away AS expected_goals_away,
            toFloat32(round(100.0 * a.accurate_passes_home / nullIf(toFloat64(a.pass_attempts_home), 0), 1)) AS pass_accuracy_home_pct,
            toFloat32(round(100.0 * a.accurate_passes_away / nullIf(toFloat64(a.pass_attempts_away), 0), 1)) AS pass_accuracy_away_pct,
            toFloat32(round(100.0 * h.accurate_passes_home_first_half / nullIf(toFloat64(h.pass_attempts_home_first_half), 0), 1)) AS pass_accuracy_home_first_half_pct,
            toFloat32(round(100.0 * h.accurate_passes_home_second_half / nullIf(toFloat64(h.pass_attempts_home_second_half), 0), 1)) AS pass_accuracy_home_second_half_pct,
            toFloat32(round(100.0 * h.accurate_passes_away_first_half / nullIf(toFloat64(h.pass_attempts_away_first_half), 0), 1)) AS pass_accuracy_away_first_half_pct,
            toFloat32(round(100.0 * h.accurate_passes_away_second_half / nullIf(toFloat64(h.pass_attempts_away_second_half), 0), 1)) AS pass_accuracy_away_second_half_pct
        FROM silver.match AS m FINAL
        INNER JOIN all_stats AS a
            ON a.match_id = m.match_id
        INNER JOIN half_stats AS h
            ON h.match_id = m.match_id
        WHERE m.match_finished = 1
          AND m.match_id > 0
          AND a.pass_attempts_home > 0
          AND a.pass_attempts_away > 0
          AND h.pass_attempts_home_first_half > 0
          AND h.pass_attempts_home_second_half > 0
          AND h.pass_attempts_away_first_half > 0
          AND h.pass_attempts_away_second_half > 0
          AND (100.0 * a.accurate_passes_home / toFloat64(a.pass_attempts_home)) > 88
          AND (100.0 * a.accurate_passes_away / toFloat64(a.pass_attempts_away)) > 88
          AND (100.0 * h.accurate_passes_home_first_half / toFloat64(h.pass_attempts_home_first_half)) > 88
          AND (100.0 * h.accurate_passes_home_second_half / toFloat64(h.pass_attempts_home_second_half)) > 88
          AND (100.0 * h.accurate_passes_away_first_half / toFloat64(h.pass_attempts_away_first_half)) > 88
          AND (100.0 * h.accurate_passes_away_second_half / toFloat64(h.pass_attempts_away_second_half)) > 88
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
    toFloat32(88.0) AS trigger_threshold_pct,
    b.pass_accuracy_home_pct AS triggered_team_pass_accuracy_pct,
    b.pass_accuracy_away_pct AS opponent_pass_accuracy_pct,
    toFloat32(round(b.pass_accuracy_home_pct - b.pass_accuracy_away_pct, 1)) AS pass_accuracy_gap_pct,
    least(
        b.pass_accuracy_home_first_half_pct,
        b.pass_accuracy_home_second_half_pct,
        b.pass_accuracy_away_first_half_pct,
        b.pass_accuracy_away_second_half_pct
    ) AS match_min_half_pass_accuracy_pct,
    b.pass_accuracy_home_first_half_pct AS triggered_team_pass_accuracy_first_half_pct,
    b.pass_accuracy_home_second_half_pct AS triggered_team_pass_accuracy_second_half_pct,
    b.pass_accuracy_away_first_half_pct AS opponent_pass_accuracy_first_half_pct,
    b.pass_accuracy_away_second_half_pct AS opponent_pass_accuracy_second_half_pct,
    least(
        b.pass_accuracy_home_pct,
        b.pass_accuracy_home_first_half_pct,
        b.pass_accuracy_home_second_half_pct
    ) AS triggered_team_pass_accuracy_floor_pct,
    least(
        b.pass_accuracy_away_pct,
        b.pass_accuracy_away_first_half_pct,
        b.pass_accuracy_away_second_half_pct
    ) AS opponent_pass_accuracy_floor_pct,
    b.pass_attempts_home AS triggered_team_pass_attempts,
    b.pass_attempts_away AS opponent_pass_attempts,
    b.pass_attempts_home_first_half AS triggered_team_pass_attempts_first_half,
    b.pass_attempts_home_second_half AS triggered_team_pass_attempts_second_half,
    b.pass_attempts_away_first_half AS opponent_pass_attempts_first_half,
    b.pass_attempts_away_second_half AS opponent_pass_attempts_second_half,
    b.opposition_half_passes_home AS triggered_team_opposition_half_passes,
    b.opposition_half_passes_away AS opponent_opposition_half_passes,
    b.touches_opposition_box_home AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_away AS opponent_touches_opposition_box,
    b.total_shots_home AS triggered_team_total_shots,
    b.total_shots_away AS opponent_total_shots,
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
    toFloat32(88.0) AS trigger_threshold_pct,
    b.pass_accuracy_away_pct AS triggered_team_pass_accuracy_pct,
    b.pass_accuracy_home_pct AS opponent_pass_accuracy_pct,
    toFloat32(round(b.pass_accuracy_away_pct - b.pass_accuracy_home_pct, 1)) AS pass_accuracy_gap_pct,
    least(
        b.pass_accuracy_home_first_half_pct,
        b.pass_accuracy_home_second_half_pct,
        b.pass_accuracy_away_first_half_pct,
        b.pass_accuracy_away_second_half_pct
    ) AS match_min_half_pass_accuracy_pct,
    b.pass_accuracy_away_first_half_pct AS triggered_team_pass_accuracy_first_half_pct,
    b.pass_accuracy_away_second_half_pct AS triggered_team_pass_accuracy_second_half_pct,
    b.pass_accuracy_home_first_half_pct AS opponent_pass_accuracy_first_half_pct,
    b.pass_accuracy_home_second_half_pct AS opponent_pass_accuracy_second_half_pct,
    least(
        b.pass_accuracy_away_pct,
        b.pass_accuracy_away_first_half_pct,
        b.pass_accuracy_away_second_half_pct
    ) AS triggered_team_pass_accuracy_floor_pct,
    least(
        b.pass_accuracy_home_pct,
        b.pass_accuracy_home_first_half_pct,
        b.pass_accuracy_home_second_half_pct
    ) AS opponent_pass_accuracy_floor_pct,
    b.pass_attempts_away AS triggered_team_pass_attempts,
    b.pass_attempts_home AS opponent_pass_attempts,
    b.pass_attempts_away_first_half AS triggered_team_pass_attempts_first_half,
    b.pass_attempts_away_second_half AS triggered_team_pass_attempts_second_half,
    b.pass_attempts_home_first_half AS opponent_pass_attempts_first_half,
    b.pass_attempts_home_second_half AS opponent_pass_attempts_second_half,
    b.opposition_half_passes_away AS triggered_team_opposition_half_passes,
    b.opposition_half_passes_home AS opponent_opposition_half_passes,
    b.touches_opposition_box_away AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_home AS opponent_touches_opposition_box,
    b.total_shots_away AS triggered_team_total_shots,
    b.total_shots_home AS opponent_total_shots,
    b.expected_goals_away AS triggered_team_xg,
    b.expected_goals_home AS opponent_xg,
    toFloat32(round(b.expected_goals_away - b.expected_goals_home, 3)) AS xg_gap
FROM base_stats AS b

ORDER BY match_id, triggered_side;
