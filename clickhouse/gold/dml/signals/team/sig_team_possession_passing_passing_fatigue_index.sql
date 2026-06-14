INSERT INTO gold.sig_team_possession_passing_passing_fatigue_index (
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
    trigger_threshold_second_half_pass_drop_pct,
    triggered_team_passes_first_half,
    triggered_team_passes_second_half,
    triggered_team_pass_drop_pct,
    opponent_passes_first_half,
    opponent_passes_second_half,
    opponent_pass_drop_pct,
    triggered_team_pass_attempts_first_half,
    triggered_team_pass_attempts_second_half,
    opponent_pass_attempts_first_half,
    opponent_pass_attempts_second_half,
    triggered_team_pass_accuracy_first_half_pct,
    triggered_team_pass_accuracy_second_half_pct,
    opponent_pass_accuracy_first_half_pct,
    opponent_pass_accuracy_second_half_pct,
    triggered_team_possession_first_half_pct,
    triggered_team_possession_second_half_pct,
    opponent_possession_first_half_pct,
    opponent_possession_second_half_pct,
    triggered_team_total_cards,
    opponent_total_cards,
    triggered_team_red_cards,
    opponent_red_cards,
    triggered_team_xg_first_half,
    triggered_team_xg_second_half,
    opponent_xg_first_half,
    opponent_xg_second_half,
    xg_swing_delta
)
-- Signal: sig_team_possession_passing_passing_fatigue_index
-- Intent: Detect teams whose passing volume drops sharply after halftime,
--         while excluding card-distorted cases to isolate potential fatigue effects.
-- Trigger: second_half_passes <= 70% of first_half_passes AND triggered team total cards = 0.
WITH half_stats AS (
    SELECT
        match_id,
        maxIf(coalesce(passes_home, 0), period = 'FirstHalf') AS fh_passes_home,
        maxIf(coalesce(passes_away, 0), period = 'FirstHalf') AS fh_passes_away,
        maxIf(coalesce(passes_home, 0), period = 'SecondHalf') AS sh_passes_home,
        maxIf(coalesce(passes_away, 0), period = 'SecondHalf') AS sh_passes_away,
        maxIf(coalesce(pass_attempts_home, 0), period = 'FirstHalf') AS fh_pass_attempts_home,
        maxIf(coalesce(pass_attempts_away, 0), period = 'FirstHalf') AS fh_pass_attempts_away,
        maxIf(coalesce(pass_attempts_home, 0), period = 'SecondHalf') AS sh_pass_attempts_home,
        maxIf(coalesce(pass_attempts_away, 0), period = 'SecondHalf') AS sh_pass_attempts_away,
        maxIf(coalesce(accurate_passes_home, 0), period = 'FirstHalf') AS fh_accurate_passes_home,
        maxIf(coalesce(accurate_passes_away, 0), period = 'FirstHalf') AS fh_accurate_passes_away,
        maxIf(coalesce(accurate_passes_home, 0), period = 'SecondHalf') AS sh_accurate_passes_home,
        maxIf(coalesce(accurate_passes_away, 0), period = 'SecondHalf') AS sh_accurate_passes_away,
        maxIf(coalesce(ball_possession_home, 0), period = 'FirstHalf') AS fh_possession_home,
        maxIf(coalesce(ball_possession_away, 0), period = 'FirstHalf') AS fh_possession_away,
        maxIf(coalesce(ball_possession_home, 0), period = 'SecondHalf') AS sh_possession_home,
        maxIf(coalesce(ball_possession_away, 0), period = 'SecondHalf') AS sh_possession_away,
        maxIf(coalesce(expected_goals_home, 0), period = 'FirstHalf') AS fh_xg_home,
        maxIf(coalesce(expected_goals_away, 0), period = 'FirstHalf') AS fh_xg_away,
        maxIf(coalesce(expected_goals_home, 0), period = 'SecondHalf') AS sh_xg_home,
        maxIf(coalesce(expected_goals_away, 0), period = 'SecondHalf') AS sh_xg_away,
        sumIf(coalesce(yellow_cards_home, 0), period IN ('FirstHalf', 'SecondHalf')) AS total_yellow_cards_home,
        sumIf(coalesce(yellow_cards_away, 0), period IN ('FirstHalf', 'SecondHalf')) AS total_yellow_cards_away,
        sumIf(coalesce(red_cards_home, 0), period IN ('FirstHalf', 'SecondHalf')) AS total_red_cards_home,
        sumIf(coalesce(red_cards_away, 0), period IN ('FirstHalf', 'SecondHalf')) AS total_red_cards_away
    FROM silver.period_stat
    WHERE period IN ('FirstHalf', 'SecondHalf')
    GROUP BY match_id
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
    'home' AS triggered_side,
    m.home_team_id AS triggered_team_id,
    m.home_team_name AS triggered_team_name,
    m.away_team_id AS opponent_team_id,
    m.away_team_name AS opponent_team_name,
    30.0 AS trigger_threshold_second_half_pass_drop_pct,
    h.fh_passes_home AS triggered_team_passes_first_half,
    h.sh_passes_home AS triggered_team_passes_second_half,
    round(100.0 * (h.fh_passes_home - h.sh_passes_home) / nullIf(h.fh_passes_home, 0), 1) AS triggered_team_pass_drop_pct,
    h.fh_passes_away AS opponent_passes_first_half,
    h.sh_passes_away AS opponent_passes_second_half,
    round(100.0 * (h.fh_passes_away - h.sh_passes_away) / nullIf(h.fh_passes_away, 0), 1) AS opponent_pass_drop_pct,
    h.fh_pass_attempts_home AS triggered_team_pass_attempts_first_half,
    h.sh_pass_attempts_home AS triggered_team_pass_attempts_second_half,
    h.fh_pass_attempts_away AS opponent_pass_attempts_first_half,
    h.sh_pass_attempts_away AS opponent_pass_attempts_second_half,
    round(100.0 * h.fh_accurate_passes_home / nullIf(h.fh_pass_attempts_home, 0), 1) AS triggered_team_pass_accuracy_first_half_pct,
    round(100.0 * h.sh_accurate_passes_home / nullIf(h.sh_pass_attempts_home, 0), 1) AS triggered_team_pass_accuracy_second_half_pct,
    round(100.0 * h.fh_accurate_passes_away / nullIf(h.fh_pass_attempts_away, 0), 1) AS opponent_pass_accuracy_first_half_pct,
    round(100.0 * h.sh_accurate_passes_away / nullIf(h.sh_pass_attempts_away, 0), 1) AS opponent_pass_accuracy_second_half_pct,
    h.fh_possession_home AS triggered_team_possession_first_half_pct,
    h.sh_possession_home AS triggered_team_possession_second_half_pct,
    h.fh_possession_away AS opponent_possession_first_half_pct,
    h.sh_possession_away AS opponent_possession_second_half_pct,
    h.total_yellow_cards_home + h.total_red_cards_home AS triggered_team_total_cards,
    h.total_yellow_cards_away + h.total_red_cards_away AS opponent_total_cards,
    h.total_red_cards_home AS triggered_team_red_cards,
    h.total_red_cards_away AS opponent_red_cards,
    h.fh_xg_home AS triggered_team_xg_first_half,
    h.sh_xg_home AS triggered_team_xg_second_half,
    h.fh_xg_away AS opponent_xg_first_half,
    h.sh_xg_away AS opponent_xg_second_half,
    (h.sh_xg_home - h.sh_xg_away) - (h.fh_xg_home - h.fh_xg_away) AS xg_swing_delta
FROM silver.match AS m
INNER JOIN half_stats AS h
    ON h.match_id = m.match_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND h.fh_passes_home > 0
  AND h.sh_passes_home <= h.fh_passes_home * 0.70
  AND (h.total_yellow_cards_home + h.total_red_cards_home) = 0

UNION ALL

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
    30.0 AS trigger_threshold_second_half_pass_drop_pct,
    h.fh_passes_away AS triggered_team_passes_first_half,
    h.sh_passes_away AS triggered_team_passes_second_half,
    round(100.0 * (h.fh_passes_away - h.sh_passes_away) / nullIf(h.fh_passes_away, 0), 1) AS triggered_team_pass_drop_pct,
    h.fh_passes_home AS opponent_passes_first_half,
    h.sh_passes_home AS opponent_passes_second_half,
    round(100.0 * (h.fh_passes_home - h.sh_passes_home) / nullIf(h.fh_passes_home, 0), 1) AS opponent_pass_drop_pct,
    h.fh_pass_attempts_away AS triggered_team_pass_attempts_first_half,
    h.sh_pass_attempts_away AS triggered_team_pass_attempts_second_half,
    h.fh_pass_attempts_home AS opponent_pass_attempts_first_half,
    h.sh_pass_attempts_home AS opponent_pass_attempts_second_half,
    round(100.0 * h.fh_accurate_passes_away / nullIf(h.fh_pass_attempts_away, 0), 1) AS triggered_team_pass_accuracy_first_half_pct,
    round(100.0 * h.sh_accurate_passes_away / nullIf(h.sh_pass_attempts_away, 0), 1) AS triggered_team_pass_accuracy_second_half_pct,
    round(100.0 * h.fh_accurate_passes_home / nullIf(h.fh_pass_attempts_home, 0), 1) AS opponent_pass_accuracy_first_half_pct,
    round(100.0 * h.sh_accurate_passes_home / nullIf(h.sh_pass_attempts_home, 0), 1) AS opponent_pass_accuracy_second_half_pct,
    h.fh_possession_away AS triggered_team_possession_first_half_pct,
    h.sh_possession_away AS triggered_team_possession_second_half_pct,
    h.fh_possession_home AS opponent_possession_first_half_pct,
    h.sh_possession_home AS opponent_possession_second_half_pct,
    h.total_yellow_cards_away + h.total_red_cards_away AS triggered_team_total_cards,
    h.total_yellow_cards_home + h.total_red_cards_home AS opponent_total_cards,
    h.total_red_cards_away AS triggered_team_red_cards,
    h.total_red_cards_home AS opponent_red_cards,
    h.fh_xg_away AS triggered_team_xg_first_half,
    h.sh_xg_away AS triggered_team_xg_second_half,
    h.fh_xg_home AS opponent_xg_first_half,
    h.sh_xg_home AS opponent_xg_second_half,
    (h.sh_xg_away - h.sh_xg_home) - (h.fh_xg_away - h.fh_xg_home) AS xg_swing_delta
FROM silver.match AS m
INNER JOIN half_stats AS h
    ON h.match_id = m.match_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND h.fh_passes_away > 0
  AND h.sh_passes_away <= h.fh_passes_away * 0.70
  AND (h.total_yellow_cards_away + h.total_red_cards_away) = 0

ORDER BY assumeNotNull(triggered_team_pass_drop_pct) DESC;
