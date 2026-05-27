INSERT INTO gold.sig_team_discipline_cards_card_heavy_defeat (
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
    trigger_threshold_min_loss_margin_goals,
    trigger_threshold_min_red_cards_match,
    triggered_team_loss_margin,
    triggered_team_first_red_card_minute,
    opponent_first_red_card_minute,
    triggered_team_score_at_first_red,
    opponent_score_at_first_red,
    score_margin_at_first_red,
    triggered_team_goals_after_first_red,
    opponent_goals_after_first_red,
    goals_after_first_red_delta,
    triggered_team_red_cards_match,
    opponent_red_cards_match,
    red_cards_match_delta,
    triggered_team_yellow_cards_match,
    opponent_yellow_cards_match,
    triggered_team_total_cards_match,
    opponent_total_cards_match,
    card_count_match_delta,
    triggered_team_fouls_committed,
    opponent_fouls_committed,
    fouls_committed_delta,
    triggered_team_fouls_per_card,
    opponent_fouls_per_card,
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
WITH red_events AS (
    SELECT
        c.match_id,
        lowerUTF8(coalesce(c.team_side, '')) AS triggered_side,
        toInt32(c.card_minute) AS card_minute,
        c.event_id,
        toInt32(coalesce(c.score_home_at_time, 0)) AS score_home_at_red,
        toInt32(coalesce(c.score_away_at_time, 0)) AS score_away_at_red
    FROM silver.card AS c
    WHERE c.match_id > 0
      AND lowerUTF8(coalesce(c.team_side, '')) IN ('home', 'away')
      AND positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'red') > 0
      AND toInt32(c.card_minute) > 0
),
red_rollup AS (
    SELECT
        re.match_id,
        re.triggered_side,
        count() AS red_cards_match,
        min(re.card_minute) AS first_red_card_minute,
        argMin(re.score_home_at_red, tuple(re.card_minute, re.event_id)) AS score_home_at_first_red,
        argMin(re.score_away_at_red, tuple(re.card_minute, re.event_id)) AS score_away_at_first_red
    FROM red_events AS re
    GROUP BY
        re.match_id,
        re.triggered_side
)
-- Signal: sig_team_discipline_cards_card_heavy_defeat
-- Trigger: team loses by >= 3 goals and receives at least one red card.
-- Intent: detect severe scoreline collapses where dismissal burden coexists with a heavy defeat.

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

    toInt32(3) AS trigger_threshold_min_loss_margin_goals,
    toInt32(1) AS trigger_threshold_min_red_cards_match,
    toInt32(coalesce(m.away_score, 0) - coalesce(m.home_score, 0)) AS triggered_team_loss_margin,
    toInt32(coalesce(home_rr.first_red_card_minute, 0)) AS triggered_team_first_red_card_minute,
    toInt32(coalesce(away_rr.first_red_card_minute, 0)) AS opponent_first_red_card_minute,
    toInt32(coalesce(home_rr.score_home_at_first_red, 0)) AS triggered_team_score_at_first_red,
    toInt32(coalesce(home_rr.score_away_at_first_red, 0)) AS opponent_score_at_first_red,
    toInt32(
        coalesce(home_rr.score_home_at_first_red, 0)
        - coalesce(home_rr.score_away_at_first_red, 0)
    ) AS score_margin_at_first_red,
    toInt32(coalesce(m.home_score, 0) - coalesce(home_rr.score_home_at_first_red, 0)) AS triggered_team_goals_after_first_red,
    toInt32(coalesce(m.away_score, 0) - coalesce(home_rr.score_away_at_first_red, 0)) AS opponent_goals_after_first_red,
    toInt32(
        (coalesce(m.home_score, 0) - coalesce(home_rr.score_home_at_first_red, 0))
        - (coalesce(m.away_score, 0) - coalesce(home_rr.score_away_at_first_red, 0))
    ) AS goals_after_first_red_delta,

    toInt32(coalesce(home_rr.red_cards_match, 0)) AS triggered_team_red_cards_match,
    toInt32(coalesce(away_rr.red_cards_match, 0)) AS opponent_red_cards_match,
    toInt32(coalesce(home_rr.red_cards_match, 0) - coalesce(away_rr.red_cards_match, 0)) AS red_cards_match_delta,
    toInt32(coalesce(ps.yellow_cards_home, 0)) AS triggered_team_yellow_cards_match,
    toInt32(coalesce(ps.yellow_cards_away, 0)) AS opponent_yellow_cards_match,
    toInt32(coalesce(ps.yellow_cards_home, 0) + coalesce(home_rr.red_cards_match, 0)) AS triggered_team_total_cards_match,
    toInt32(coalesce(ps.yellow_cards_away, 0) + coalesce(away_rr.red_cards_match, 0)) AS opponent_total_cards_match,
    toInt32(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(home_rr.red_cards_match, 0))
        - (coalesce(ps.yellow_cards_away, 0) + coalesce(away_rr.red_cards_match, 0))
    ) AS card_count_match_delta,
    toInt32(coalesce(ps.fouls_home, 0)) AS triggered_team_fouls_committed,
    toInt32(coalesce(ps.fouls_away, 0)) AS opponent_fouls_committed,
    toInt32(coalesce(ps.fouls_home, 0) - coalesce(ps.fouls_away, 0)) AS fouls_committed_delta,
    toNullable(toFloat32(round(
        coalesce(ps.fouls_home, 0) / nullIf(
            coalesce(ps.yellow_cards_home, 0) + coalesce(home_rr.red_cards_match, 0),
            0
        ),
        2
    ))) AS triggered_team_fouls_per_card,
    toNullable(toFloat32(round(
        coalesce(ps.fouls_away, 0) / nullIf(
            coalesce(ps.yellow_cards_away, 0) + coalesce(away_rr.red_cards_match, 0),
            0
        ),
        2
    ))) AS opponent_fouls_per_card,
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
INNER JOIN red_rollup AS home_rr
    ON home_rr.match_id = m.match_id
   AND home_rr.triggered_side = 'home'
LEFT JOIN red_rollup AS away_rr
    ON away_rr.match_id = m.match_id
   AND away_rr.triggered_side = 'away'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(m.home_score, 0) <= coalesce(m.away_score, 0) - 3

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

    toInt32(3) AS trigger_threshold_min_loss_margin_goals,
    toInt32(1) AS trigger_threshold_min_red_cards_match,
    toInt32(coalesce(m.home_score, 0) - coalesce(m.away_score, 0)) AS triggered_team_loss_margin,
    toInt32(coalesce(away_rr.first_red_card_minute, 0)) AS triggered_team_first_red_card_minute,
    toInt32(coalesce(home_rr.first_red_card_minute, 0)) AS opponent_first_red_card_minute,
    toInt32(coalesce(away_rr.score_away_at_first_red, 0)) AS triggered_team_score_at_first_red,
    toInt32(coalesce(away_rr.score_home_at_first_red, 0)) AS opponent_score_at_first_red,
    toInt32(
        coalesce(away_rr.score_away_at_first_red, 0)
        - coalesce(away_rr.score_home_at_first_red, 0)
    ) AS score_margin_at_first_red,
    toInt32(coalesce(m.away_score, 0) - coalesce(away_rr.score_away_at_first_red, 0)) AS triggered_team_goals_after_first_red,
    toInt32(coalesce(m.home_score, 0) - coalesce(away_rr.score_home_at_first_red, 0)) AS opponent_goals_after_first_red,
    toInt32(
        (coalesce(m.away_score, 0) - coalesce(away_rr.score_away_at_first_red, 0))
        - (coalesce(m.home_score, 0) - coalesce(away_rr.score_home_at_first_red, 0))
    ) AS goals_after_first_red_delta,

    toInt32(coalesce(away_rr.red_cards_match, 0)) AS triggered_team_red_cards_match,
    toInt32(coalesce(home_rr.red_cards_match, 0)) AS opponent_red_cards_match,
    toInt32(coalesce(away_rr.red_cards_match, 0) - coalesce(home_rr.red_cards_match, 0)) AS red_cards_match_delta,
    toInt32(coalesce(ps.yellow_cards_away, 0)) AS triggered_team_yellow_cards_match,
    toInt32(coalesce(ps.yellow_cards_home, 0)) AS opponent_yellow_cards_match,
    toInt32(coalesce(ps.yellow_cards_away, 0) + coalesce(away_rr.red_cards_match, 0)) AS triggered_team_total_cards_match,
    toInt32(coalesce(ps.yellow_cards_home, 0) + coalesce(home_rr.red_cards_match, 0)) AS opponent_total_cards_match,
    toInt32(
        (coalesce(ps.yellow_cards_away, 0) + coalesce(away_rr.red_cards_match, 0))
        - (coalesce(ps.yellow_cards_home, 0) + coalesce(home_rr.red_cards_match, 0))
    ) AS card_count_match_delta,
    toInt32(coalesce(ps.fouls_away, 0)) AS triggered_team_fouls_committed,
    toInt32(coalesce(ps.fouls_home, 0)) AS opponent_fouls_committed,
    toInt32(coalesce(ps.fouls_away, 0) - coalesce(ps.fouls_home, 0)) AS fouls_committed_delta,
    toNullable(toFloat32(round(
        coalesce(ps.fouls_away, 0) / nullIf(
            coalesce(ps.yellow_cards_away, 0) + coalesce(away_rr.red_cards_match, 0),
            0
        ),
        2
    ))) AS triggered_team_fouls_per_card,
    toNullable(toFloat32(round(
        coalesce(ps.fouls_home, 0) / nullIf(
            coalesce(ps.yellow_cards_home, 0) + coalesce(home_rr.red_cards_match, 0),
            0
        ),
        2
    ))) AS opponent_fouls_per_card,
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
INNER JOIN red_rollup AS away_rr
    ON away_rr.match_id = m.match_id
   AND away_rr.triggered_side = 'away'
LEFT JOIN red_rollup AS home_rr
    ON home_rr.match_id = m.match_id
   AND home_rr.triggered_side = 'home'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(m.away_score, 0) <= coalesce(m.home_score, 0) - 3

ORDER BY
    triggered_team_loss_margin DESC,
    goals_after_first_red_delta ASC,
    triggered_team_first_red_card_minute ASC,
    m.match_date DESC,
    m.match_id DESC;
