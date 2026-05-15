INSERT INTO gold.sig_team_discipline_cards_first_half_frenzy (
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
    trigger_threshold_min_cards_first_half,
    trigger_window_start_minute,
    trigger_window_end_minute,
    triggered_team_cards_first_half,
    opponent_cards_first_half,
    cards_first_half_delta,
    triggered_team_cards_first_half_above_threshold,
    triggered_team_yellow_cards_first_half,
    opponent_yellow_cards_first_half,
    yellow_cards_first_half_delta,
    triggered_team_red_cards_first_half,
    opponent_red_cards_first_half,
    red_cards_first_half_delta,
    triggered_team_first_card_first_half_minute,
    opponent_first_card_first_half_minute,
    triggered_team_fourth_card_first_half_minute,
    triggered_team_fourth_card_first_half_added_time,
    triggered_team_fourth_card_first_half_effective_minute,
    opponent_fourth_card_first_half_minute,
    opponent_fourth_card_first_half_added_time,
    opponent_fourth_card_first_half_effective_minute,
    triggered_team_score_at_fourth_card,
    opponent_score_at_fourth_card,
    score_margin_at_fourth_card,
    triggered_team_first_half_cards_share_pct,
    opponent_first_half_cards_share_pct,
    first_half_cards_share_delta_pct,
    triggered_team_yellow_cards_match,
    opponent_yellow_cards_match,
    yellow_cards_match_delta,
    triggered_team_red_cards_match,
    opponent_red_cards_match,
    red_cards_match_delta,
    triggered_team_total_cards_match,
    opponent_total_cards_match,
    card_count_match_delta,
    triggered_team_fouls_committed,
    opponent_fouls_committed,
    fouls_committed_delta,
    triggered_team_cards_per_foul_pct,
    opponent_cards_per_foul_pct,
    cards_per_foul_delta_pct,
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
-- Signal: sig_team_discipline_cards_first_half_frenzy
-- Intent: detect teams whose discipline breaks down before half-time and preserve bilateral match context.
-- Trigger: team receives >= 4 yellow/red card events before the half-time whistle (minutes 1-45, including added time).
WITH card_events AS (
    SELECT
        c.match_id,
        lowerUTF8(coalesce(c.team_side, '')) AS card_team_side,
        toInt32OrZero(c.card_minute) AS card_minute,
        toInt32(coalesce(c.added_time, 0)) AS card_added_time,
        toInt64(c.event_id) AS event_id,
        toInt32OrZero(c.score_home_at_time) AS score_home_at_card,
        toInt32OrZero(c.score_away_at_time) AS score_away_at_card,
        (
            positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'red') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'red') > 0
        ) AS is_red_card,
        (
            (
                positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'yellow') > 0
                OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'yellow') > 0
                OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'booked') > 0
            )
            AND NOT (
                positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'red') > 0
                OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'red') > 0
            )
        ) AS is_yellow_card
    FROM silver.card AS c
    WHERE c.match_id > 0
      AND lowerUTF8(coalesce(c.team_side, '')) IN ('home', 'away')
      AND toInt32OrZero(c.card_minute) BETWEEN 1 AND 45
      AND (
          positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'yellow') > 0
          OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'yellow') > 0
          OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'booked') > 0
          OR positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'red') > 0
          OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'red') > 0
      )
),
ranked_card_events AS (
    SELECT
        ce.match_id,
        ce.card_team_side,
        ce.card_minute,
        ce.card_added_time,
        ce.event_id,
        ce.score_home_at_card,
        ce.score_away_at_card,
        ce.is_yellow_card,
        ce.is_red_card,
        row_number() OVER (
            PARTITION BY ce.match_id, ce.card_team_side
            ORDER BY ce.card_minute ASC, ce.card_added_time ASC, ce.event_id ASC
        ) AS card_sequence_first_half
    FROM card_events AS ce
),
card_rollup AS (
    SELECT
        rce.match_id,
        rce.card_team_side,
        count() AS cards_first_half,
        countIf(rce.is_yellow_card) AS yellow_cards_first_half,
        countIf(rce.is_red_card) AS red_cards_first_half,
        min(rce.card_minute) AS first_card_first_half_minute,
        toNullable(if(count() >= 4, minIf(rce.card_minute, rce.card_sequence_first_half = 4), NULL)) AS fourth_card_first_half_minute,
        toNullable(if(count() >= 4, minIf(rce.card_added_time, rce.card_sequence_first_half = 4), NULL)) AS fourth_card_first_half_added_time,
        toNullable(if(count() >= 4, minIf(rce.card_minute + rce.card_added_time, rce.card_sequence_first_half = 4), NULL)) AS fourth_card_first_half_effective_minute,
        toNullable(if(
            count() >= 4,
            argMinIf(rce.score_home_at_card, tuple(rce.card_minute, rce.card_added_time, rce.event_id), rce.card_sequence_first_half = 4),
            NULL
        )) AS score_home_at_fourth_card,
        toNullable(if(
            count() >= 4,
            argMinIf(rce.score_away_at_card, tuple(rce.card_minute, rce.card_added_time, rce.event_id), rce.card_sequence_first_half = 4),
            NULL
        )) AS score_away_at_fourth_card
    FROM ranked_card_events AS rce
    GROUP BY
        rce.match_id,
        rce.card_team_side
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

    tcr.card_team_side AS triggered_side,
    if(tcr.card_team_side = 'home', m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(tcr.card_team_side = 'home', m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(tcr.card_team_side = 'home', m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(tcr.card_team_side = 'home', m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(4) AS trigger_threshold_min_cards_first_half,
    toInt32(1) AS trigger_window_start_minute,
    toInt32(45) AS trigger_window_end_minute,
    toInt32(tcr.cards_first_half) AS triggered_team_cards_first_half,
    toInt32(coalesce(ocr.cards_first_half, 0)) AS opponent_cards_first_half,
    toInt32(tcr.cards_first_half - coalesce(ocr.cards_first_half, 0)) AS cards_first_half_delta,
    toInt32(tcr.cards_first_half - 4) AS triggered_team_cards_first_half_above_threshold,
    toInt32(tcr.yellow_cards_first_half) AS triggered_team_yellow_cards_first_half,
    toInt32(coalesce(ocr.yellow_cards_first_half, 0)) AS opponent_yellow_cards_first_half,
    toInt32(tcr.yellow_cards_first_half - coalesce(ocr.yellow_cards_first_half, 0)) AS yellow_cards_first_half_delta,
    toInt32(tcr.red_cards_first_half) AS triggered_team_red_cards_first_half,
    toInt32(coalesce(ocr.red_cards_first_half, 0)) AS opponent_red_cards_first_half,
    toInt32(tcr.red_cards_first_half - coalesce(ocr.red_cards_first_half, 0)) AS red_cards_first_half_delta,
    toInt32(tcr.first_card_first_half_minute) AS triggered_team_first_card_first_half_minute,
    toNullable(toInt32(ocr.first_card_first_half_minute)) AS opponent_first_card_first_half_minute,
    toInt32(tcr.fourth_card_first_half_minute) AS triggered_team_fourth_card_first_half_minute,
    toInt32(tcr.fourth_card_first_half_added_time) AS triggered_team_fourth_card_first_half_added_time,
    toInt32(tcr.fourth_card_first_half_effective_minute) AS triggered_team_fourth_card_first_half_effective_minute,
    toNullable(toInt32(ocr.fourth_card_first_half_minute)) AS opponent_fourth_card_first_half_minute,
    toNullable(toInt32(ocr.fourth_card_first_half_added_time)) AS opponent_fourth_card_first_half_added_time,
    toNullable(toInt32(ocr.fourth_card_first_half_effective_minute)) AS opponent_fourth_card_first_half_effective_minute,
    toInt32(if(tcr.card_team_side = 'home', tcr.score_home_at_fourth_card, tcr.score_away_at_fourth_card)) AS triggered_team_score_at_fourth_card,
    toInt32(if(tcr.card_team_side = 'home', tcr.score_away_at_fourth_card, tcr.score_home_at_fourth_card)) AS opponent_score_at_fourth_card,
    toInt32(
        if(tcr.card_team_side = 'home', tcr.score_home_at_fourth_card, tcr.score_away_at_fourth_card)
        - if(tcr.card_team_side = 'home', tcr.score_away_at_fourth_card, tcr.score_home_at_fourth_card)
    ) AS score_margin_at_fourth_card,
    toNullable(toFloat32(round(
        100.0 * tcr.cards_first_half
        / nullIf(if(tcr.card_team_side = 'home', coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0), coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)), 0),
        1
    ))) AS triggered_team_first_half_cards_share_pct,
    toNullable(toFloat32(round(
        100.0 * coalesce(ocr.cards_first_half, 0)
        / nullIf(if(tcr.card_team_side = 'home', coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0), coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)), 0),
        1
    ))) AS opponent_first_half_cards_share_pct,
    toNullable(toFloat32(round(
        (
            100.0 * tcr.cards_first_half
            / nullIf(if(tcr.card_team_side = 'home', coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0), coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)), 0)
        )
        - (
            100.0 * coalesce(ocr.cards_first_half, 0)
            / nullIf(if(tcr.card_team_side = 'home', coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0), coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)), 0)
        ),
        1
    ))) AS first_half_cards_share_delta_pct,

    toInt32(if(tcr.card_team_side = 'home', coalesce(ps.yellow_cards_home, 0), coalesce(ps.yellow_cards_away, 0))) AS triggered_team_yellow_cards_match,
    toInt32(if(tcr.card_team_side = 'home', coalesce(ps.yellow_cards_away, 0), coalesce(ps.yellow_cards_home, 0))) AS opponent_yellow_cards_match,
    toInt32(
        if(tcr.card_team_side = 'home', coalesce(ps.yellow_cards_home, 0), coalesce(ps.yellow_cards_away, 0))
        - if(tcr.card_team_side = 'home', coalesce(ps.yellow_cards_away, 0), coalesce(ps.yellow_cards_home, 0))
    ) AS yellow_cards_match_delta,
    toInt32(if(tcr.card_team_side = 'home', coalesce(ps.red_cards_home, 0), coalesce(ps.red_cards_away, 0))) AS triggered_team_red_cards_match,
    toInt32(if(tcr.card_team_side = 'home', coalesce(ps.red_cards_away, 0), coalesce(ps.red_cards_home, 0))) AS opponent_red_cards_match,
    toInt32(
        if(tcr.card_team_side = 'home', coalesce(ps.red_cards_home, 0), coalesce(ps.red_cards_away, 0))
        - if(tcr.card_team_side = 'home', coalesce(ps.red_cards_away, 0), coalesce(ps.red_cards_home, 0))
    ) AS red_cards_match_delta,
    toInt32(if(
        tcr.card_team_side = 'home',
        coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)
    )) AS triggered_team_total_cards_match,
    toInt32(if(
        tcr.card_team_side = 'home',
        coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)
    )) AS opponent_total_cards_match,
    toInt32(
        if(tcr.card_team_side = 'home', coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0), coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0))
        - if(tcr.card_team_side = 'home', coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0), coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0))
    ) AS card_count_match_delta,
    toInt32(if(tcr.card_team_side = 'home', coalesce(ps.fouls_home, 0), coalesce(ps.fouls_away, 0))) AS triggered_team_fouls_committed,
    toInt32(if(tcr.card_team_side = 'home', coalesce(ps.fouls_away, 0), coalesce(ps.fouls_home, 0))) AS opponent_fouls_committed,
    toInt32(
        if(tcr.card_team_side = 'home', coalesce(ps.fouls_home, 0), coalesce(ps.fouls_away, 0))
        - if(tcr.card_team_side = 'home', coalesce(ps.fouls_away, 0), coalesce(ps.fouls_home, 0))
    ) AS fouls_committed_delta,
    toNullable(toFloat32(round(
        100.0 * tcr.cards_first_half
        / nullIf(if(tcr.card_team_side = 'home', coalesce(ps.fouls_home, 0), coalesce(ps.fouls_away, 0)), 0),
        1
    ))) AS triggered_team_cards_per_foul_pct,
    toNullable(toFloat32(round(
        100.0 * coalesce(ocr.cards_first_half, 0)
        / nullIf(if(tcr.card_team_side = 'home', coalesce(ps.fouls_away, 0), coalesce(ps.fouls_home, 0)), 0),
        1
    ))) AS opponent_cards_per_foul_pct,
    toNullable(toFloat32(round(
        (
            100.0 * tcr.cards_first_half
            / nullIf(if(tcr.card_team_side = 'home', coalesce(ps.fouls_home, 0), coalesce(ps.fouls_away, 0)), 0)
        )
        - (
            100.0 * coalesce(ocr.cards_first_half, 0)
            / nullIf(if(tcr.card_team_side = 'home', coalesce(ps.fouls_away, 0), coalesce(ps.fouls_home, 0)), 0)
        ),
        1
    ))) AS cards_per_foul_delta_pct,
    toInt32(if(tcr.card_team_side = 'home', coalesce(ps.duels_won_home, 0), coalesce(ps.duels_won_away, 0))) AS triggered_team_duels_won,
    toInt32(if(tcr.card_team_side = 'home', coalesce(ps.duels_won_away, 0), coalesce(ps.duels_won_home, 0))) AS opponent_duels_won,
    toInt32(if(tcr.card_team_side = 'home', coalesce(ps.tackles_succeeded_home, 0), coalesce(ps.tackles_succeeded_away, 0))) AS triggered_team_tackles_won,
    toInt32(if(tcr.card_team_side = 'home', coalesce(ps.tackles_succeeded_away, 0), coalesce(ps.tackles_succeeded_home, 0))) AS opponent_tackles_won,
    toInt32(if(tcr.card_team_side = 'home', coalesce(ps.interceptions_home, 0), coalesce(ps.interceptions_away, 0))) AS triggered_team_interceptions,
    toInt32(if(tcr.card_team_side = 'home', coalesce(ps.interceptions_away, 0), coalesce(ps.interceptions_home, 0))) AS opponent_interceptions,
    toInt32(if(tcr.card_team_side = 'home', coalesce(ps.clearances_home, 0), coalesce(ps.clearances_away, 0))) AS triggered_team_clearances,
    toInt32(if(tcr.card_team_side = 'home', coalesce(ps.clearances_away, 0), coalesce(ps.clearances_home, 0))) AS opponent_clearances,
    toFloat32(if(tcr.card_team_side = 'home', coalesce(ps.ball_possession_home, 0), coalesce(ps.ball_possession_away, 0))) AS triggered_team_possession_pct,
    toFloat32(if(tcr.card_team_side = 'home', coalesce(ps.ball_possession_away, 0), coalesce(ps.ball_possession_home, 0))) AS opponent_possession_pct,
    toFloat32(round(
        if(tcr.card_team_side = 'home', coalesce(ps.ball_possession_home, 0), coalesce(ps.ball_possession_away, 0))
        - if(tcr.card_team_side = 'home', coalesce(ps.ball_possession_away, 0), coalesce(ps.ball_possession_home, 0)),
        1
    )) AS possession_delta_pct

FROM card_rollup AS tcr
INNER JOIN silver.match AS m
    ON m.match_id = tcr.match_id
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = tcr.match_id
   AND ps.period = 'All'
LEFT JOIN card_rollup AS ocr
    ON ocr.match_id = tcr.match_id
   AND ocr.card_team_side = if(tcr.card_team_side = 'home', 'away', 'home')
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND tcr.cards_first_half >= 4

ORDER BY
    triggered_team_cards_first_half DESC,
    triggered_team_fourth_card_first_half_effective_minute ASC,
    cards_first_half_delta DESC,
    m.match_date DESC,
    m.match_id DESC;
