INSERT INTO gold.sig_match_discipline_cards_referee_strictness (
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
    trigger_threshold_first_yellow_card_minute_inclusive,
    match_first_yellow_card_minute,
    match_first_yellow_card_team_side,
    match_first_yellow_card_team_id,
    match_first_yellow_card_team_name,
    match_first_yellow_card_player_id,
    match_first_yellow_card_player_name,
    triggered_team_early_yellow_cards,
    opponent_early_yellow_cards,
    early_yellow_cards_delta,
    match_total_early_yellow_cards,
    triggered_team_yellow_cards,
    opponent_yellow_cards,
    triggered_team_red_cards,
    opponent_red_cards,
    triggered_team_total_cards,
    opponent_total_cards,
    card_count_delta,
    triggered_team_fouls_committed,
    opponent_fouls_committed,
    fouls_committed_delta,
    triggered_team_tackles_won,
    opponent_tackles_won,
    triggered_team_duels_won,
    opponent_duels_won,
    triggered_team_interceptions,
    opponent_interceptions,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct
)
-- Signal: sig_match_discipline_cards_referee_strictness
-- Trigger: first yellow card in the match is shown within the first 5 minutes.
-- Intent: identify matches with strict early officiating and preserve side-oriented discipline context.
WITH yellow_card_events AS (
    SELECT
        c.match_id,
        lowerUTF8(coalesce(c.team_side, '')) AS card_team_side,
        toInt32(coalesce(c.card_minute, 0)) AS card_minute,
        toInt32(coalesce(c.event_id, 0)) AS event_id,
        toInt32(coalesce(c.player_id, 0)) AS player_id,
        coalesce(c.player_name, 'Unknown') AS player_name
    FROM silver.card AS c
    WHERE c.match_id > 0
      AND lowerUTF8(coalesce(c.team_side, '')) IN ('home', 'away')
      AND toInt32(coalesce(c.card_minute, 0)) > 0
      AND (
          positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'yellow') > 0
          OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'yellow') > 0
          OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'booked') > 0
      )
),
first_yellow_per_match AS (
    SELECT
        yce.match_id,
        min(yce.card_minute) AS match_first_yellow_card_minute,
        argMin(yce.card_team_side, tuple(yce.card_minute, yce.event_id)) AS match_first_yellow_card_team_side,
        argMin(yce.player_id, tuple(yce.card_minute, yce.event_id)) AS match_first_yellow_card_player_id,
        argMin(yce.player_name, tuple(yce.card_minute, yce.event_id)) AS match_first_yellow_card_player_name
    FROM yellow_card_events AS yce
    GROUP BY yce.match_id
),
eligible_matches AS (
    SELECT
        fym.match_id,
        fym.match_first_yellow_card_minute,
        fym.match_first_yellow_card_team_side,
        fym.match_first_yellow_card_player_id,
        fym.match_first_yellow_card_player_name
    FROM first_yellow_per_match AS fym
    WHERE fym.match_first_yellow_card_minute BETWEEN 1 AND 5
),
early_yellow_counts AS (
    SELECT
        yce.match_id,
        yce.card_team_side,
        countIf(yce.card_minute BETWEEN 1 AND 5) AS early_yellow_cards
    FROM yellow_card_events AS yce
    GROUP BY
        yce.match_id,
        yce.card_team_side
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

    toInt32(5) AS trigger_threshold_first_yellow_card_minute_inclusive,
    toInt32(em.match_first_yellow_card_minute) AS match_first_yellow_card_minute,
    em.match_first_yellow_card_team_side,
    if(em.match_first_yellow_card_team_side = 'home', m.home_team_id, m.away_team_id) AS match_first_yellow_card_team_id,
    if(em.match_first_yellow_card_team_side = 'home', m.home_team_name, m.away_team_name) AS match_first_yellow_card_team_name,
    toNullable(nullIf(toInt32(em.match_first_yellow_card_player_id), 0)) AS match_first_yellow_card_player_id,
    em.match_first_yellow_card_player_name,

    toInt32(coalesce(home_eyc.early_yellow_cards, 0)) AS triggered_team_early_yellow_cards,
    toInt32(coalesce(away_eyc.early_yellow_cards, 0)) AS opponent_early_yellow_cards,
    toInt32(coalesce(home_eyc.early_yellow_cards, 0) - coalesce(away_eyc.early_yellow_cards, 0)) AS early_yellow_cards_delta,
    toInt32(coalesce(home_eyc.early_yellow_cards, 0) + coalesce(away_eyc.early_yellow_cards, 0)) AS match_total_early_yellow_cards,

    toInt32(coalesce(ps.yellow_cards_home, 0)) AS triggered_team_yellow_cards,
    toInt32(coalesce(ps.yellow_cards_away, 0)) AS opponent_yellow_cards,
    toInt32(coalesce(ps.red_cards_home, 0)) AS triggered_team_red_cards,
    toInt32(coalesce(ps.red_cards_away, 0)) AS opponent_red_cards,
    toInt32(coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) AS triggered_team_total_cards,
    toInt32(coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)) AS opponent_total_cards,
    toInt32(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0))
        - (coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0))
    ) AS card_count_delta,

    toInt32(coalesce(ps.fouls_home, 0)) AS triggered_team_fouls_committed,
    toInt32(coalesce(ps.fouls_away, 0)) AS opponent_fouls_committed,
    toInt32(coalesce(ps.fouls_home, 0) - coalesce(ps.fouls_away, 0)) AS fouls_committed_delta,
    toInt32(coalesce(ps.tackles_succeeded_home, 0)) AS triggered_team_tackles_won,
    toInt32(coalesce(ps.tackles_succeeded_away, 0)) AS opponent_tackles_won,
    toInt32(coalesce(ps.duels_won_home, 0)) AS triggered_team_duels_won,
    toInt32(coalesce(ps.duels_won_away, 0)) AS opponent_duels_won,
    toInt32(coalesce(ps.interceptions_home, 0)) AS triggered_team_interceptions,
    toInt32(coalesce(ps.interceptions_away, 0)) AS opponent_interceptions,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
            1
        ), 0.0)
        - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_home, 0) - coalesce(ps.ball_possession_away, 0), 1)) AS possession_delta_pct

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
INNER JOIN eligible_matches AS em
    ON em.match_id = m.match_id
LEFT JOIN early_yellow_counts AS home_eyc
    ON home_eyc.match_id = m.match_id
   AND home_eyc.card_team_side = 'home'
LEFT JOIN early_yellow_counts AS away_eyc
    ON away_eyc.match_id = m.match_id
   AND away_eyc.card_team_side = 'away'
WHERE m.match_finished = 1
  AND m.match_id > 0

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

    toInt32(5) AS trigger_threshold_first_yellow_card_minute_inclusive,
    toInt32(em.match_first_yellow_card_minute) AS match_first_yellow_card_minute,
    em.match_first_yellow_card_team_side,
    if(em.match_first_yellow_card_team_side = 'home', m.home_team_id, m.away_team_id) AS match_first_yellow_card_team_id,
    if(em.match_first_yellow_card_team_side = 'home', m.home_team_name, m.away_team_name) AS match_first_yellow_card_team_name,
    toNullable(nullIf(toInt32(em.match_first_yellow_card_player_id), 0)) AS match_first_yellow_card_player_id,
    em.match_first_yellow_card_player_name,

    toInt32(coalesce(away_eyc.early_yellow_cards, 0)) AS triggered_team_early_yellow_cards,
    toInt32(coalesce(home_eyc.early_yellow_cards, 0)) AS opponent_early_yellow_cards,
    toInt32(coalesce(away_eyc.early_yellow_cards, 0) - coalesce(home_eyc.early_yellow_cards, 0)) AS early_yellow_cards_delta,
    toInt32(coalesce(home_eyc.early_yellow_cards, 0) + coalesce(away_eyc.early_yellow_cards, 0)) AS match_total_early_yellow_cards,

    toInt32(coalesce(ps.yellow_cards_away, 0)) AS triggered_team_yellow_cards,
    toInt32(coalesce(ps.yellow_cards_home, 0)) AS opponent_yellow_cards,
    toInt32(coalesce(ps.red_cards_away, 0)) AS triggered_team_red_cards,
    toInt32(coalesce(ps.red_cards_home, 0)) AS opponent_red_cards,
    toInt32(coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)) AS triggered_team_total_cards,
    toInt32(coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) AS opponent_total_cards,
    toInt32(
        (coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0))
        - (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0))
    ) AS card_count_delta,

    toInt32(coalesce(ps.fouls_away, 0)) AS triggered_team_fouls_committed,
    toInt32(coalesce(ps.fouls_home, 0)) AS opponent_fouls_committed,
    toInt32(coalesce(ps.fouls_away, 0) - coalesce(ps.fouls_home, 0)) AS fouls_committed_delta,
    toInt32(coalesce(ps.tackles_succeeded_away, 0)) AS triggered_team_tackles_won,
    toInt32(coalesce(ps.tackles_succeeded_home, 0)) AS opponent_tackles_won,
    toInt32(coalesce(ps.duels_won_away, 0)) AS triggered_team_duels_won,
    toInt32(coalesce(ps.duels_won_home, 0)) AS opponent_duels_won,
    toInt32(coalesce(ps.interceptions_away, 0)) AS triggered_team_interceptions,
    toInt32(coalesce(ps.interceptions_home, 0)) AS opponent_interceptions,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
            1
        ), 0.0)
        - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_away, 0) - coalesce(ps.ball_possession_home, 0), 1)) AS possession_delta_pct

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
INNER JOIN eligible_matches AS em
    ON em.match_id = m.match_id
LEFT JOIN early_yellow_counts AS home_eyc
    ON home_eyc.match_id = m.match_id
   AND home_eyc.card_team_side = 'home'
LEFT JOIN early_yellow_counts AS away_eyc
    ON away_eyc.match_id = m.match_id
   AND away_eyc.card_team_side = 'away'
WHERE m.match_finished = 1
  AND m.match_id > 0

ORDER BY m.match_id, triggered_side;
