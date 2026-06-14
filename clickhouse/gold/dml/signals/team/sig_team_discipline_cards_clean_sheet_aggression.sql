INSERT INTO gold.sig_team_discipline_cards_clean_sheet_aggression (
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
    trigger_threshold_max_opponent_goals,
    triggered_team_yellow_cards,
    opponent_yellow_cards,
    yellow_cards_delta,
    yellow_cards_above_threshold,
    triggered_team_red_cards,
    opponent_red_cards,
    red_cards_delta,
    triggered_team_total_cards,
    opponent_total_cards,
    card_count_delta,
    triggered_team_fouls_committed,
    opponent_fouls_committed,
    fouls_committed_delta,
    triggered_team_fouls_share_pct,
    opponent_fouls_share_pct,
    triggered_team_win_margin,
    triggered_team_goals,
    opponent_goals,
    triggered_team_clean_sheet_flag,
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
-- Signal: sig_team_discipline_cards_clean_sheet_aggression
-- Trigger: team wins with a clean sheet and receives >= 5 yellow cards.
-- Intent: identify high-discipline-load wins that still end in defensive shutouts.

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

    toInt32(5) AS trigger_threshold_min_yellow_cards,
    toInt32(0) AS trigger_threshold_max_opponent_goals,
    toInt32(coalesce(ps.yellow_cards_home, 0)) AS triggered_team_yellow_cards,
    toInt32(coalesce(ps.yellow_cards_away, 0)) AS opponent_yellow_cards,
    toInt32(coalesce(ps.yellow_cards_home, 0) - coalesce(ps.yellow_cards_away, 0)) AS yellow_cards_delta,
    toInt32(coalesce(ps.yellow_cards_home, 0) - 5) AS yellow_cards_above_threshold,
    toInt32(coalesce(ps.red_cards_home, 0)) AS triggered_team_red_cards,
    toInt32(coalesce(ps.red_cards_away, 0)) AS opponent_red_cards,
    toInt32(coalesce(ps.red_cards_home, 0) - coalesce(ps.red_cards_away, 0)) AS red_cards_delta,
    toInt32(coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) AS triggered_team_total_cards,
    toInt32(coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)) AS opponent_total_cards,
    toInt32(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0))
        - (coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0))
    ) AS card_count_delta,
    toInt32(coalesce(ps.fouls_home, 0)) AS triggered_team_fouls_committed,
    toInt32(coalesce(ps.fouls_away, 0)) AS opponent_fouls_committed,
    toInt32(coalesce(ps.fouls_home, 0) - coalesce(ps.fouls_away, 0)) AS fouls_committed_delta,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.fouls_home, 0)
        / nullIf(coalesce(ps.fouls_home, 0) + coalesce(ps.fouls_away, 0), 0),
        1
    ), 0.0)) AS triggered_team_fouls_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.fouls_away, 0)
        / nullIf(coalesce(ps.fouls_home, 0) + coalesce(ps.fouls_away, 0), 0),
        1
    ), 0.0)) AS opponent_fouls_share_pct,
    toInt32(coalesce(m.home_score, 0) - coalesce(m.away_score, 0)) AS triggered_team_win_margin,
    toInt32(coalesce(m.home_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.away_score, 0)) AS opponent_goals,
    toUInt8(1) AS triggered_team_clean_sheet_flag,
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
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(m.home_score, 0) > coalesce(m.away_score, 0)
  AND coalesce(m.away_score, 0) = 0
  AND coalesce(ps.yellow_cards_home, 0) >= 5

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

    toInt32(5) AS trigger_threshold_min_yellow_cards,
    toInt32(0) AS trigger_threshold_max_opponent_goals,
    toInt32(coalesce(ps.yellow_cards_away, 0)) AS triggered_team_yellow_cards,
    toInt32(coalesce(ps.yellow_cards_home, 0)) AS opponent_yellow_cards,
    toInt32(coalesce(ps.yellow_cards_away, 0) - coalesce(ps.yellow_cards_home, 0)) AS yellow_cards_delta,
    toInt32(coalesce(ps.yellow_cards_away, 0) - 5) AS yellow_cards_above_threshold,
    toInt32(coalesce(ps.red_cards_away, 0)) AS triggered_team_red_cards,
    toInt32(coalesce(ps.red_cards_home, 0)) AS opponent_red_cards,
    toInt32(coalesce(ps.red_cards_away, 0) - coalesce(ps.red_cards_home, 0)) AS red_cards_delta,
    toInt32(coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)) AS triggered_team_total_cards,
    toInt32(coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) AS opponent_total_cards,
    toInt32(
        (coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0))
        - (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0))
    ) AS card_count_delta,
    toInt32(coalesce(ps.fouls_away, 0)) AS triggered_team_fouls_committed,
    toInt32(coalesce(ps.fouls_home, 0)) AS opponent_fouls_committed,
    toInt32(coalesce(ps.fouls_away, 0) - coalesce(ps.fouls_home, 0)) AS fouls_committed_delta,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.fouls_away, 0)
        / nullIf(coalesce(ps.fouls_away, 0) + coalesce(ps.fouls_home, 0), 0),
        1
    ), 0.0)) AS triggered_team_fouls_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.fouls_home, 0)
        / nullIf(coalesce(ps.fouls_away, 0) + coalesce(ps.fouls_home, 0), 0),
        1
    ), 0.0)) AS opponent_fouls_share_pct,
    toInt32(coalesce(m.away_score, 0) - coalesce(m.home_score, 0)) AS triggered_team_win_margin,
    toInt32(coalesce(m.away_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.home_score, 0)) AS opponent_goals,
    toUInt8(1) AS triggered_team_clean_sheet_flag,
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
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(m.away_score, 0) > coalesce(m.home_score, 0)
  AND coalesce(m.home_score, 0) = 0
  AND coalesce(ps.yellow_cards_away, 0) >= 5

ORDER BY
    yellow_cards_above_threshold DESC,
    triggered_team_yellow_cards DESC,
    card_count_delta DESC,
    m.match_date DESC,
    m.match_id DESC;
