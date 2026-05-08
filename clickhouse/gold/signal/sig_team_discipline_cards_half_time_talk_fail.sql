WITH yellow_card_events AS (
    SELECT
        c.match_id,
        lowerUTF8(coalesce(c.team_side, '')) AS triggered_side,
        toInt32OrZero(c.card_minute) AS card_minute,
        c.event_id,
        toInt32OrZero(c.score_home_at_time) AS score_home_at_card,
        toInt32OrZero(c.score_away_at_time) AS score_away_at_card
    FROM silver.card AS c
    WHERE c.match_id > 0
      AND lowerUTF8(coalesce(c.team_side, '')) IN ('home', 'away')
      AND toInt32OrZero(c.card_minute) BETWEEN 46 AND 60
      AND (
          positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'yellow') > 0
          OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'yellow') > 0
      )
),
yellow_window_ranked AS (
    SELECT
        yce.match_id,
        yce.triggered_side,
        yce.card_minute,
        yce.event_id,
        yce.score_home_at_card,
        yce.score_away_at_card,
        row_number() OVER (
            PARTITION BY yce.match_id, yce.triggered_side
            ORDER BY yce.card_minute ASC, yce.event_id ASC
        ) AS yellow_card_sequence_in_window
    FROM yellow_card_events AS yce
),
yellow_window_rollup AS (
    SELECT
        ywr.match_id,
        ywr.triggered_side,
        count() AS triggered_team_yellow_cards_window,
        min(ywr.card_minute) AS triggered_team_first_yellow_card_window_minute,
        minIf(ywr.card_minute, ywr.yellow_card_sequence_in_window = 3) AS triggered_team_third_yellow_card_window_minute,
        argMinIf(
            ywr.score_home_at_card,
            tuple(ywr.card_minute, ywr.event_id),
            ywr.yellow_card_sequence_in_window = 3
        ) AS score_home_at_third_yellow,
        argMinIf(
            ywr.score_away_at_card,
            tuple(ywr.card_minute, ywr.event_id),
            ywr.yellow_card_sequence_in_window = 3
        ) AS score_away_at_third_yellow
    FROM yellow_window_ranked AS ywr
    GROUP BY
        ywr.match_id,
        ywr.triggered_side
)
INSERT INTO gold.sig_team_discipline_cards_half_time_talk_fail (
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
    trigger_threshold_min_yellow_cards,
    trigger_window_start_minute,
    trigger_window_end_minute,
    triggered_team_yellow_cards_window,
    opponent_yellow_cards_window,
    yellow_cards_window_delta,
    triggered_team_first_yellow_card_window_minute,
    triggered_team_third_yellow_card_window_minute,
    minutes_from_second_half_start_to_third_yellow,
    triggered_team_score_at_third_yellow,
    opponent_score_at_third_yellow,
    score_margin_at_third_yellow,
    triggered_team_yellow_cards_match,
    opponent_yellow_cards_match,
    yellow_cards_match_delta,
    triggered_team_red_cards_match,
    opponent_red_cards_match,
    triggered_team_total_cards_match,
    opponent_total_cards_match,
    card_count_match_delta,
    triggered_team_fouls_committed,
    opponent_fouls_committed,
    fouls_committed_delta,
    triggered_team_duels_won,
    opponent_duels_won,
    triggered_team_tackles_won,
    opponent_tackles_won,
    triggered_team_interceptions,
    opponent_interceptions,
    triggered_team_clearances,
    opponent_clearances,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct
)
-- Signal: sig_team_discipline_cards_half_time_talk_fail
-- Trigger: team receives >= 3 yellow cards between minutes 46 and 60.
-- Intent: flag teams that restart the second half with immediate discipline collapse and preserve bilateral match context.

-- Home side triggers the signal
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

    toInt32(3) AS trigger_threshold_min_yellow_cards,
    toInt32(46) AS trigger_window_start_minute,
    toInt32(60) AS trigger_window_end_minute,
    toInt32(coalesce(home_ywr.triggered_team_yellow_cards_window, 0)) AS triggered_team_yellow_cards_window,
    toInt32(coalesce(away_ywr.triggered_team_yellow_cards_window, 0)) AS opponent_yellow_cards_window,
    toInt32(
        coalesce(home_ywr.triggered_team_yellow_cards_window, 0)
        - coalesce(away_ywr.triggered_team_yellow_cards_window, 0)
    ) AS yellow_cards_window_delta,
    toInt32(coalesce(home_ywr.triggered_team_first_yellow_card_window_minute, 0)) AS triggered_team_first_yellow_card_window_minute,
    toInt32(coalesce(home_ywr.triggered_team_third_yellow_card_window_minute, 0)) AS triggered_team_third_yellow_card_window_minute,
    toInt32(coalesce(home_ywr.triggered_team_third_yellow_card_window_minute, 0) - 45) AS minutes_from_second_half_start_to_third_yellow,
    toInt32(coalesce(home_ywr.score_home_at_third_yellow, 0)) AS triggered_team_score_at_third_yellow,
    toInt32(coalesce(home_ywr.score_away_at_third_yellow, 0)) AS opponent_score_at_third_yellow,
    toInt32(coalesce(home_ywr.score_home_at_third_yellow, 0) - coalesce(home_ywr.score_away_at_third_yellow, 0)) AS score_margin_at_third_yellow,

    toInt32(coalesce(ps.yellow_cards_home, 0)) AS triggered_team_yellow_cards_match,
    toInt32(coalesce(ps.yellow_cards_away, 0)) AS opponent_yellow_cards_match,
    toInt32(coalesce(ps.yellow_cards_home, 0) - coalesce(ps.yellow_cards_away, 0)) AS yellow_cards_match_delta,
    toInt32(coalesce(ps.red_cards_home, 0)) AS triggered_team_red_cards_match,
    toInt32(coalesce(ps.red_cards_away, 0)) AS opponent_red_cards_match,
    toInt32(coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) AS triggered_team_total_cards_match,
    toInt32(coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)) AS opponent_total_cards_match,
    toInt32(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0))
        - (coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0))
    ) AS card_count_match_delta,
    toInt32(coalesce(ps.fouls_home, 0)) AS triggered_team_fouls_committed,
    toInt32(coalesce(ps.fouls_away, 0)) AS opponent_fouls_committed,
    toInt32(coalesce(ps.fouls_home, 0) - coalesce(ps.fouls_away, 0)) AS fouls_committed_delta,
    toInt32(coalesce(ps.duels_won_home, 0)) AS triggered_team_duels_won,
    toInt32(coalesce(ps.duels_won_away, 0)) AS opponent_duels_won,
    toInt32(coalesce(ps.tackles_succeeded_home, 0)) AS triggered_team_tackles_won,
    toInt32(coalesce(ps.tackles_succeeded_away, 0)) AS opponent_tackles_won,
    toInt32(coalesce(ps.interceptions_home, 0)) AS triggered_team_interceptions,
    toInt32(coalesce(ps.interceptions_away, 0)) AS opponent_interceptions,
    toInt32(coalesce(ps.clearances_home, 0)) AS triggered_team_clearances,
    toInt32(coalesce(ps.clearances_away, 0)) AS opponent_clearances,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_home, 0) - coalesce(ps.ball_possession_away, 0), 1)) AS possession_delta_pct

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
INNER JOIN yellow_window_rollup AS home_ywr
    ON home_ywr.match_id = m.match_id
   AND home_ywr.triggered_side = 'home'
LEFT JOIN yellow_window_rollup AS away_ywr
    ON away_ywr.match_id = m.match_id
   AND away_ywr.triggered_side = 'away'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND home_ywr.triggered_team_yellow_cards_window >= 3

UNION ALL

-- Away side triggers the signal
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

    toInt32(3) AS trigger_threshold_min_yellow_cards,
    toInt32(46) AS trigger_window_start_minute,
    toInt32(60) AS trigger_window_end_minute,
    toInt32(coalesce(away_ywr.triggered_team_yellow_cards_window, 0)) AS triggered_team_yellow_cards_window,
    toInt32(coalesce(home_ywr.triggered_team_yellow_cards_window, 0)) AS opponent_yellow_cards_window,
    toInt32(
        coalesce(away_ywr.triggered_team_yellow_cards_window, 0)
        - coalesce(home_ywr.triggered_team_yellow_cards_window, 0)
    ) AS yellow_cards_window_delta,
    toInt32(coalesce(away_ywr.triggered_team_first_yellow_card_window_minute, 0)) AS triggered_team_first_yellow_card_window_minute,
    toInt32(coalesce(away_ywr.triggered_team_third_yellow_card_window_minute, 0)) AS triggered_team_third_yellow_card_window_minute,
    toInt32(coalesce(away_ywr.triggered_team_third_yellow_card_window_minute, 0) - 45) AS minutes_from_second_half_start_to_third_yellow,
    toInt32(coalesce(away_ywr.score_away_at_third_yellow, 0)) AS triggered_team_score_at_third_yellow,
    toInt32(coalesce(away_ywr.score_home_at_third_yellow, 0)) AS opponent_score_at_third_yellow,
    toInt32(coalesce(away_ywr.score_away_at_third_yellow, 0) - coalesce(away_ywr.score_home_at_third_yellow, 0)) AS score_margin_at_third_yellow,

    toInt32(coalesce(ps.yellow_cards_away, 0)) AS triggered_team_yellow_cards_match,
    toInt32(coalesce(ps.yellow_cards_home, 0)) AS opponent_yellow_cards_match,
    toInt32(coalesce(ps.yellow_cards_away, 0) - coalesce(ps.yellow_cards_home, 0)) AS yellow_cards_match_delta,
    toInt32(coalesce(ps.red_cards_away, 0)) AS triggered_team_red_cards_match,
    toInt32(coalesce(ps.red_cards_home, 0)) AS opponent_red_cards_match,
    toInt32(coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)) AS triggered_team_total_cards_match,
    toInt32(coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) AS opponent_total_cards_match,
    toInt32(
        (coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0))
        - (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0))
    ) AS card_count_match_delta,
    toInt32(coalesce(ps.fouls_away, 0)) AS triggered_team_fouls_committed,
    toInt32(coalesce(ps.fouls_home, 0)) AS opponent_fouls_committed,
    toInt32(coalesce(ps.fouls_away, 0) - coalesce(ps.fouls_home, 0)) AS fouls_committed_delta,
    toInt32(coalesce(ps.duels_won_away, 0)) AS triggered_team_duels_won,
    toInt32(coalesce(ps.duels_won_home, 0)) AS opponent_duels_won,
    toInt32(coalesce(ps.tackles_succeeded_away, 0)) AS triggered_team_tackles_won,
    toInt32(coalesce(ps.tackles_succeeded_home, 0)) AS opponent_tackles_won,
    toInt32(coalesce(ps.interceptions_away, 0)) AS triggered_team_interceptions,
    toInt32(coalesce(ps.interceptions_home, 0)) AS opponent_interceptions,
    toInt32(coalesce(ps.clearances_away, 0)) AS triggered_team_clearances,
    toInt32(coalesce(ps.clearances_home, 0)) AS opponent_clearances,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_away, 0) - coalesce(ps.ball_possession_home, 0), 1)) AS possession_delta_pct

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
INNER JOIN yellow_window_rollup AS away_ywr
    ON away_ywr.match_id = m.match_id
   AND away_ywr.triggered_side = 'away'
LEFT JOIN yellow_window_rollup AS home_ywr
    ON home_ywr.match_id = m.match_id
   AND home_ywr.triggered_side = 'home'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND away_ywr.triggered_team_yellow_cards_window >= 3

ORDER BY
    triggered_team_yellow_cards_window DESC,
    triggered_team_third_yellow_card_window_minute ASC,
    yellow_cards_window_delta DESC,
    m.match_date DESC,
    m.match_id DESC;
