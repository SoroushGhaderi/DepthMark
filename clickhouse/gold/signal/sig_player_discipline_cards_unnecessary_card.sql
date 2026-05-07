INSERT INTO gold.sig_player_discipline_cards_unnecessary_card (
    match_id,
    match_date,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,
    triggered_side,
    triggered_player_id,
    triggered_player_name,
    triggered_team_id,
    triggered_team_name,
    opponent_team_id,
    opponent_team_name,
    trigger_threshold_min_score_margin_at_card,
    triggered_player_first_unnecessary_card_minute,
    triggered_player_first_unnecessary_card_type,
    triggered_player_unnecessary_cards_count,
    triggered_player_yellow_cards_match,
    triggered_player_red_cards_match,
    triggered_player_total_cards_match,
    triggered_player_fouls_committed,
    triggered_player_was_fouled,
    triggered_player_minutes_played,
    triggered_team_score_at_first_unnecessary_card,
    opponent_score_at_first_unnecessary_card,
    score_margin_at_first_unnecessary_card,
    max_score_margin_during_unnecessary_cards,
    triggered_team_total_fouls,
    opponent_total_fouls,
    triggered_team_yellow_cards_match,
    opponent_yellow_cards_match,
    triggered_team_red_cards_match,
    opponent_red_cards_match,
    triggered_team_total_cards_match,
    opponent_total_cards_match,
    triggered_team_possession_pct,
    opponent_possession_pct
)
-- Signal: sig_player_discipline_cards_unnecessary_card
-- Intent: isolate bookings taken while a player already has a comfortable lead, with bilateral discipline and control context.
-- Trigger: player receives a yellow/red card while their team is leading by at least 3 goals.
WITH card_events AS (
    SELECT
        c.match_id,
        toInt32(assumeNotNull(c.player_id)) AS triggered_player_id,
        coalesce(c.player_name, 'Unknown') AS triggered_player_name,
        lowerUTF8(coalesce(c.team_side, '')) AS card_team_side,
        toInt32OrZero(c.card_minute) AS card_minute,
        toInt32OrZero(c.score_home_at_time) AS score_home_at_card,
        toInt32OrZero(c.score_away_at_time) AS score_away_at_card,
        c.event_id,
        (
            positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'yellow') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'yellow') > 0
        ) AS is_yellow_card,
        (
            positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'red') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'red') > 0
        ) AS is_red_card
    FROM silver.card AS c
    WHERE c.match_id > 0
      AND c.player_id IS NOT NULL
      AND lowerUTF8(coalesce(c.team_side, '')) IN ('home', 'away')
),
player_card_rollup AS (
    SELECT
        ce.match_id,
        ce.triggered_player_id,
        countIf(ce.is_yellow_card) AS triggered_player_yellow_cards_match,
        countIf(ce.is_red_card) AS triggered_player_red_cards_match,
        countIf(ce.is_yellow_card OR ce.is_red_card) AS triggered_player_total_cards_match
    FROM card_events AS ce
    GROUP BY
        ce.match_id,
        ce.triggered_player_id
),
unnecessary_card_events AS (
    SELECT
        ce.match_id,
        ce.triggered_player_id,
        ce.triggered_player_name,
        ce.card_team_side,
        ce.card_minute,
        ce.score_home_at_card,
        ce.score_away_at_card,
        ce.event_id,
        multiIf(
            ce.is_yellow_card AND ce.is_red_card, 'yellow_red',
            ce.is_red_card, 'red',
            'yellow'
        ) AS triggered_player_card_event_type,
        if(
            ce.card_team_side = 'home',
            ce.score_home_at_card - ce.score_away_at_card,
            ce.score_away_at_card - ce.score_home_at_card
        ) AS score_margin_at_card
    FROM card_events AS ce
    WHERE (ce.is_yellow_card OR ce.is_red_card)
      AND ce.card_minute > 0
      AND if(
          ce.card_team_side = 'home',
          ce.score_home_at_card - ce.score_away_at_card,
          ce.score_away_at_card - ce.score_home_at_card
      ) >= 3
),
unnecessary_card_rollup AS (
    SELECT
        uce.match_id,
        uce.triggered_player_id,
        argMin(
            uce.triggered_player_name,
            tuple(uce.card_minute, uce.event_id)
        ) AS triggered_player_name,
        argMin(
            uce.card_team_side,
            tuple(uce.card_minute, uce.event_id)
        ) AS card_team_side,
        min(uce.card_minute) AS triggered_player_first_unnecessary_card_minute,
        argMin(
            uce.triggered_player_card_event_type,
            tuple(uce.card_minute, uce.event_id)
        ) AS triggered_player_first_unnecessary_card_type,
        argMin(
            uce.score_home_at_card,
            tuple(uce.card_minute, uce.event_id)
        ) AS score_home_at_first_unnecessary_card,
        argMin(
            uce.score_away_at_card,
            tuple(uce.card_minute, uce.event_id)
        ) AS score_away_at_first_unnecessary_card,
        argMin(
            uce.score_margin_at_card,
            tuple(uce.card_minute, uce.event_id)
        ) AS score_margin_at_first_unnecessary_card,
        max(uce.score_margin_at_card) AS max_score_margin_during_unnecessary_cards,
        count() AS triggered_player_unnecessary_cards_count
    FROM unnecessary_card_events AS uce
    GROUP BY
        uce.match_id,
        uce.triggered_player_id
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

    if(p.team_id = m.home_team_id, 'home', 'away') AS triggered_side,
    p.player_id AS triggered_player_id,
    coalesce(p.player_name, ucr.triggered_player_name) AS triggered_player_name,
    if(p.team_id = m.home_team_id, m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(p.team_id = m.home_team_id, m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(p.team_id = m.home_team_id, m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(p.team_id = m.home_team_id, m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(3) AS trigger_threshold_min_score_margin_at_card,
    toInt32(coalesce(ucr.triggered_player_first_unnecessary_card_minute, 0)) AS triggered_player_first_unnecessary_card_minute,
    ucr.triggered_player_first_unnecessary_card_type,
    toInt32(coalesce(ucr.triggered_player_unnecessary_cards_count, 0)) AS triggered_player_unnecessary_cards_count,
    toInt32(coalesce(pcr.triggered_player_yellow_cards_match, 0)) AS triggered_player_yellow_cards_match,
    toInt32(coalesce(pcr.triggered_player_red_cards_match, 0)) AS triggered_player_red_cards_match,
    toInt32(coalesce(pcr.triggered_player_total_cards_match, 0)) AS triggered_player_total_cards_match,
    toInt32(coalesce(p.fouls_committed, 0)) AS triggered_player_fouls_committed,
    toInt32(coalesce(p.was_fouled, 0)) AS triggered_player_was_fouled,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,
    toInt32(if(
        p.team_id = m.home_team_id,
        coalesce(ucr.score_home_at_first_unnecessary_card, 0),
        coalesce(ucr.score_away_at_first_unnecessary_card, 0)
    )) AS triggered_team_score_at_first_unnecessary_card,
    toInt32(if(
        p.team_id = m.home_team_id,
        coalesce(ucr.score_away_at_first_unnecessary_card, 0),
        coalesce(ucr.score_home_at_first_unnecessary_card, 0)
    )) AS opponent_score_at_first_unnecessary_card,
    toInt32(coalesce(ucr.score_margin_at_first_unnecessary_card, 0)) AS score_margin_at_first_unnecessary_card,
    toInt32(coalesce(ucr.max_score_margin_during_unnecessary_cards, 0)) AS max_score_margin_during_unnecessary_cards,

    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.fouls_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.fouls_away, 0),
        0
    )) AS triggered_team_total_fouls,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.fouls_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.fouls_home, 0),
        0
    )) AS opponent_total_fouls,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.yellow_cards_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.yellow_cards_away, 0),
        0
    )) AS triggered_team_yellow_cards_match,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.yellow_cards_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.yellow_cards_home, 0),
        0
    )) AS opponent_yellow_cards_match,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.red_cards_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.red_cards_away, 0),
        0
    )) AS triggered_team_red_cards_match,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.red_cards_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.red_cards_home, 0),
        0
    )) AS opponent_red_cards_match,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        0
    )) AS triggered_team_total_cards_match,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        0
    )) AS opponent_total_cards_match,
    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.ball_possession_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.ball_possession_away, 0),
        0
    )) AS triggered_team_possession_pct,
    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.ball_possession_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.ball_possession_home, 0),
        0
    )) AS opponent_possession_pct

FROM unnecessary_card_rollup AS ucr
INNER JOIN silver.player_match_stat AS p
    ON p.match_id = ucr.match_id
   AND p.player_id = ucr.triggered_player_id
INNER JOIN silver.match AS m
    ON m.match_id = ucr.match_id
LEFT JOIN player_card_rollup AS pcr
    ON pcr.match_id = ucr.match_id
   AND pcr.triggered_player_id = ucr.triggered_player_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = ucr.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND p.player_id > 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)
  AND (
        (ucr.card_team_side = 'home' AND p.team_id = m.home_team_id)
        OR
        (ucr.card_team_side = 'away' AND p.team_id = m.away_team_id)
      )
  AND coalesce(ucr.triggered_player_unnecessary_cards_count, 0) >= 1

ORDER BY
    triggered_player_unnecessary_cards_count DESC,
    triggered_player_first_unnecessary_card_minute ASC,
    score_margin_at_first_unnecessary_card DESC,
    m.match_date DESC,
    m.match_id DESC,
    p.player_id ASC;
