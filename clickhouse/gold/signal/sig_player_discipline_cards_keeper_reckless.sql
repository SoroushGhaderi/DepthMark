INSERT INTO gold.sig_player_discipline_cards_keeper_reckless (
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
    trigger_threshold_total_cards,
    triggered_player_first_card_minute,
    triggered_player_first_card_type,
    triggered_player_yellow_cards_match,
    triggered_player_red_cards_match,
    triggered_player_total_cards_match,
    triggered_player_fouls_committed,
    triggered_player_was_fouled,
    triggered_player_minutes_played,
    triggered_team_score_at_first_card,
    opponent_score_at_first_card,
    score_margin_at_first_card,
    triggered_team_total_fouls,
    opponent_total_fouls,
    triggered_team_yellow_cards_match,
    opponent_yellow_cards_match,
    triggered_team_red_cards_match,
    opponent_red_cards_match,
    triggered_team_total_cards_match,
    opponent_total_cards_match,
    triggered_team_keeper_saves,
    opponent_keeper_saves,
    triggered_team_possession_pct,
    opponent_possession_pct
)
-- Signal: sig_player_discipline_cards_keeper_reckless
-- Intent: isolate booked goalkeepers and preserve bilateral discipline plus match-control context.
-- Trigger: goalkeeper receives at least one yellow/red card in the match.
WITH card_events AS (
    SELECT
        c.match_id,
        toInt32(assumeNotNull(c.player_id)) AS triggered_player_id,
        coalesce(c.player_name, 'Unknown') AS triggered_player_name,
        lowerUTF8(coalesce(c.team_side, '')) AS card_team_side,
        toInt32OrZero(c.card_minute) AS card_minute,
        c.event_id,
        toInt32OrZero(c.score_home_at_time) AS score_home_at_card,
        toInt32OrZero(c.score_away_at_time) AS score_away_at_card,
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
keeper_card_rollup AS (
    SELECT
        ce.match_id,
        ce.triggered_player_id,
        argMin(
            ce.triggered_player_name,
            tuple(ce.card_minute, ce.event_id)
        ) AS triggered_player_name,
        argMin(
            ce.card_team_side,
            tuple(ce.card_minute, ce.event_id)
        ) AS card_team_side,
        min(ce.card_minute) AS triggered_player_first_card_minute,
        argMin(
            multiIf(
                ce.is_yellow_card AND ce.is_red_card, 'yellow_red',
                ce.is_red_card, 'red',
                'yellow'
            ),
            tuple(ce.card_minute, ce.event_id)
        ) AS triggered_player_first_card_type,
        argMin(
            ce.score_home_at_card,
            tuple(ce.card_minute, ce.event_id)
        ) AS score_home_at_first_card,
        argMin(
            ce.score_away_at_card,
            tuple(ce.card_minute, ce.event_id)
        ) AS score_away_at_first_card,
        countIf(ce.is_yellow_card) AS triggered_player_yellow_cards_match,
        countIf(ce.is_red_card) AS triggered_player_red_cards_match,
        count() AS triggered_player_total_cards_match
    FROM card_events AS ce
    WHERE ce.is_yellow_card OR ce.is_red_card
    GROUP BY
        ce.match_id,
        ce.triggered_player_id
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
    coalesce(p.player_name, kcr.triggered_player_name) AS triggered_player_name,

    if(p.team_id = m.home_team_id, m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(p.team_id = m.home_team_id, m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(p.team_id = m.home_team_id, m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(p.team_id = m.home_team_id, m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(1) AS trigger_threshold_total_cards,
    toInt32(coalesce(kcr.triggered_player_first_card_minute, 0)) AS triggered_player_first_card_minute,
    kcr.triggered_player_first_card_type,
    toInt32(coalesce(kcr.triggered_player_yellow_cards_match, 0)) AS triggered_player_yellow_cards_match,
    toInt32(coalesce(kcr.triggered_player_red_cards_match, 0)) AS triggered_player_red_cards_match,
    toInt32(coalesce(kcr.triggered_player_total_cards_match, 0)) AS triggered_player_total_cards_match,
    toInt32(coalesce(p.fouls_committed, 0)) AS triggered_player_fouls_committed,
    toInt32(coalesce(p.was_fouled, 0)) AS triggered_player_was_fouled,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,
    if(
        p.team_id = m.home_team_id,
        kcr.score_home_at_first_card,
        kcr.score_away_at_first_card
    ) AS triggered_team_score_at_first_card,
    if(
        p.team_id = m.home_team_id,
        kcr.score_away_at_first_card,
        kcr.score_home_at_first_card
    ) AS opponent_score_at_first_card,
    if(
        p.team_id = m.home_team_id,
        kcr.score_home_at_first_card - kcr.score_away_at_first_card,
        kcr.score_away_at_first_card - kcr.score_home_at_first_card
    ) AS score_margin_at_first_card,

    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.fouls_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.fouls_away, 0),
        0
    ) AS triggered_team_total_fouls,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.fouls_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.fouls_home, 0),
        0
    ) AS opponent_total_fouls,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.yellow_cards_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.yellow_cards_away, 0),
        0
    ) AS triggered_team_yellow_cards_match,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.yellow_cards_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.yellow_cards_home, 0),
        0
    ) AS opponent_yellow_cards_match,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.red_cards_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.red_cards_away, 0),
        0
    ) AS triggered_team_red_cards_match,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.red_cards_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.red_cards_home, 0),
        0
    ) AS opponent_red_cards_match,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        0
    ) AS triggered_team_total_cards_match,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        0
    ) AS opponent_total_cards_match,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.keeper_saves_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.keeper_saves_away, 0),
        0
    ) AS triggered_team_keeper_saves,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.keeper_saves_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.keeper_saves_home, 0),
        0
    ) AS opponent_keeper_saves,
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

FROM keeper_card_rollup AS kcr
INNER JOIN silver.player_match_stat AS p
    ON p.match_id = kcr.match_id
   AND p.player_id = kcr.triggered_player_id
INNER JOIN silver.match AS m
    ON m.match_id = kcr.match_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = kcr.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND p.player_id > 0
  AND p.is_goalkeeper = 1
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)
  AND (
        (kcr.card_team_side = 'home' AND p.team_id = m.home_team_id)
        OR
        (kcr.card_team_side = 'away' AND p.team_id = m.away_team_id)
      )
  AND coalesce(kcr.triggered_player_total_cards_match, 0) >= 1

ORDER BY
    triggered_player_total_cards_match DESC,
    triggered_player_red_cards_match DESC,
    triggered_player_first_card_minute ASC,
    m.match_date DESC,
    m.match_id DESC,
    p.player_id ASC;
