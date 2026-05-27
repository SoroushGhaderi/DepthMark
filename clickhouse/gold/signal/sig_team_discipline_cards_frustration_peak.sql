INSERT INTO gold.sig_team_discipline_cards_frustration_peak (
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
    trigger_threshold_min_cards_while_trailing_late,
    trigger_threshold_minute,
    triggered_team_cards_while_trailing_late,
    opponent_cards_while_trailing_late,
    cards_while_trailing_late_delta,
    triggered_team_first_trailing_card_minute,
    triggered_team_last_trailing_card_minute,
    triggered_team_score_at_first_trailing_card,
    opponent_score_at_first_trailing_card,
    score_margin_at_first_trailing_card,
    min_score_margin_during_trailing_cards,
    triggered_team_yellow_cards_while_trailing_late,
    opponent_yellow_cards_while_trailing_late,
    triggered_team_red_cards_while_trailing_late,
    opponent_red_cards_while_trailing_late,
    triggered_team_yellow_cards,
    opponent_yellow_cards,
    triggered_team_red_cards,
    opponent_red_cards,
    triggered_team_total_cards,
    opponent_total_cards,
    card_count_delta,
    triggered_team_late_trailing_cards_share_pct,
    opponent_late_trailing_cards_share_pct,
    late_trailing_cards_share_delta_pct,
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
-- Signal: sig_team_discipline_cards_frustration_peak
-- Trigger: team receives >= 3 yellow/red cards while trailing after minute 75.
-- Intent: detect late-match discipline spikes by chasing teams and preserve bilateral card/defensive context.
WITH card_events AS (
    SELECT
        c.match_id,
        lowerUTF8(coalesce(c.team_side, '')) AS card_team_side,
        toInt32OrZero(toString(c.card_minute)) AS card_minute,
        toInt32OrZero(toString(c.score_home_at_time)) AS score_home_at_card,
        toInt32OrZero(toString(c.score_away_at_time)) AS score_away_at_card,
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
      AND lowerUTF8(coalesce(c.team_side, '')) IN ('home', 'away')
),
late_trailing_card_events AS (
    SELECT
        ce.match_id,
        ce.card_team_side,
        ce.card_minute,
        ce.score_home_at_card,
        ce.score_away_at_card,
        ce.event_id,
        ce.is_yellow_card,
        ce.is_red_card,
        if(
            ce.card_team_side = 'home',
            ce.score_home_at_card - ce.score_away_at_card,
            ce.score_away_at_card - ce.score_home_at_card
        ) AS score_margin_at_card
    FROM card_events AS ce
    WHERE (ce.is_yellow_card OR ce.is_red_card)
      AND ce.card_minute > 75
      AND if(
          ce.card_team_side = 'home',
          ce.score_home_at_card - ce.score_away_at_card,
          ce.score_away_at_card - ce.score_home_at_card
      ) < 0
),
late_trailing_card_rollup AS (
    SELECT
        ltce.match_id,
        ltce.card_team_side,
        count() AS triggered_team_cards_while_trailing_late,
        min(ltce.card_minute) AS triggered_team_first_trailing_card_minute,
        max(ltce.card_minute) AS triggered_team_last_trailing_card_minute,
        argMin(
            ltce.score_home_at_card,
            tuple(ltce.card_minute, ltce.event_id)
        ) AS score_home_at_first_trailing_card,
        argMin(
            ltce.score_away_at_card,
            tuple(ltce.card_minute, ltce.event_id)
        ) AS score_away_at_first_trailing_card,
        argMin(
            ltce.score_margin_at_card,
            tuple(ltce.card_minute, ltce.event_id)
        ) AS score_margin_at_first_trailing_card,
        min(ltce.score_margin_at_card) AS min_score_margin_during_trailing_cards,
        countIf(ltce.is_yellow_card) AS triggered_team_yellow_cards_while_trailing_late,
        countIf(ltce.is_red_card) AS triggered_team_red_cards_while_trailing_late
    FROM late_trailing_card_events AS ltce
    GROUP BY
        ltce.match_id,
        ltce.card_team_side
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

    ltr.card_team_side AS triggered_side,
    if(ltr.card_team_side = 'home', m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(ltr.card_team_side = 'home', m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(ltr.card_team_side = 'home', m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(ltr.card_team_side = 'home', m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(3) AS trigger_threshold_min_cards_while_trailing_late,
    toInt32(75) AS trigger_threshold_minute,
    toInt32(ltr.triggered_team_cards_while_trailing_late) AS triggered_team_cards_while_trailing_late,
    toInt32(coalesce(ltr_opp.triggered_team_cards_while_trailing_late, 0)) AS opponent_cards_while_trailing_late,
    toInt32(
        ltr.triggered_team_cards_while_trailing_late
        - coalesce(ltr_opp.triggered_team_cards_while_trailing_late, 0)
    ) AS cards_while_trailing_late_delta,
    toInt32(ltr.triggered_team_first_trailing_card_minute) AS triggered_team_first_trailing_card_minute,
    toInt32(ltr.triggered_team_last_trailing_card_minute) AS triggered_team_last_trailing_card_minute,
    toInt32(if(
        ltr.card_team_side = 'home',
        ltr.score_home_at_first_trailing_card,
        ltr.score_away_at_first_trailing_card
    )) AS triggered_team_score_at_first_trailing_card,
    toInt32(if(
        ltr.card_team_side = 'home',
        ltr.score_away_at_first_trailing_card,
        ltr.score_home_at_first_trailing_card
    )) AS opponent_score_at_first_trailing_card,
    toInt32(ltr.score_margin_at_first_trailing_card) AS score_margin_at_first_trailing_card,
    toInt32(ltr.min_score_margin_during_trailing_cards) AS min_score_margin_during_trailing_cards,
    toInt32(ltr.triggered_team_yellow_cards_while_trailing_late) AS triggered_team_yellow_cards_while_trailing_late,
    toInt32(coalesce(ltr_opp.triggered_team_yellow_cards_while_trailing_late, 0)) AS opponent_yellow_cards_while_trailing_late,
    toInt32(ltr.triggered_team_red_cards_while_trailing_late) AS triggered_team_red_cards_while_trailing_late,
    toInt32(coalesce(ltr_opp.triggered_team_red_cards_while_trailing_late, 0)) AS opponent_red_cards_while_trailing_late,
    toInt32(if(
        ltr.card_team_side = 'home',
        coalesce(ps.yellow_cards_home, 0),
        coalesce(ps.yellow_cards_away, 0)
    )) AS triggered_team_yellow_cards,
    toInt32(if(
        ltr.card_team_side = 'home',
        coalesce(ps.yellow_cards_away, 0),
        coalesce(ps.yellow_cards_home, 0)
    )) AS opponent_yellow_cards,
    toInt32(if(
        ltr.card_team_side = 'home',
        coalesce(ps.red_cards_home, 0),
        coalesce(ps.red_cards_away, 0)
    )) AS triggered_team_red_cards,
    toInt32(if(
        ltr.card_team_side = 'home',
        coalesce(ps.red_cards_away, 0),
        coalesce(ps.red_cards_home, 0)
    )) AS opponent_red_cards,
    toInt32(if(
        ltr.card_team_side = 'home',
        coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)
    )) AS triggered_team_total_cards,
    toInt32(if(
        ltr.card_team_side = 'home',
        coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)
    )) AS opponent_total_cards,
    toInt32(
        if(
            ltr.card_team_side = 'home',
            coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
            coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)
        )
        - if(
            ltr.card_team_side = 'home',
            coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
            coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)
        )
    ) AS card_count_delta,
    toNullable(toFloat32(round(
        100.0 * ltr.triggered_team_cards_while_trailing_late
        / nullIf(
            if(
                ltr.card_team_side = 'home',
                coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
                coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)
            ),
            0
        ),
        1
    ))) AS triggered_team_late_trailing_cards_share_pct,
    toNullable(toFloat32(round(
        100.0 * coalesce(ltr_opp.triggered_team_cards_while_trailing_late, 0)
        / nullIf(
            if(
                ltr.card_team_side = 'home',
                coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
                coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)
            ),
            0
        ),
        1
    ))) AS opponent_late_trailing_cards_share_pct,
    toNullable(toFloat32(round(
        (
            100.0 * ltr.triggered_team_cards_while_trailing_late
            / nullIf(
                if(
                    ltr.card_team_side = 'home',
                    coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
                    coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)
                ),
                0
            )
        )
        - (
            100.0 * coalesce(ltr_opp.triggered_team_cards_while_trailing_late, 0)
            / nullIf(
                if(
                    ltr.card_team_side = 'home',
                    coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
                    coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)
                ),
                0
            )
        ),
        1
    ))) AS late_trailing_cards_share_delta_pct,
    toInt32(if(
        ltr.card_team_side = 'home',
        coalesce(ps.fouls_home, 0),
        coalesce(ps.fouls_away, 0)
    )) AS triggered_team_fouls_committed,
    toInt32(if(
        ltr.card_team_side = 'home',
        coalesce(ps.fouls_away, 0),
        coalesce(ps.fouls_home, 0)
    )) AS opponent_fouls_committed,
    toInt32(
        if(
            ltr.card_team_side = 'home',
            coalesce(ps.fouls_home, 0),
            coalesce(ps.fouls_away, 0)
        )
        - if(
            ltr.card_team_side = 'home',
            coalesce(ps.fouls_away, 0),
            coalesce(ps.fouls_home, 0)
        )
    ) AS fouls_committed_delta,
    toInt32(if(
        ltr.card_team_side = 'home',
        coalesce(ps.duels_won_home, 0),
        coalesce(ps.duels_won_away, 0)
    )) AS triggered_team_duels_won,
    toInt32(if(
        ltr.card_team_side = 'home',
        coalesce(ps.duels_won_away, 0),
        coalesce(ps.duels_won_home, 0)
    )) AS opponent_duels_won,
    toInt32(if(
        ltr.card_team_side = 'home',
        coalesce(ps.tackles_succeeded_home, 0),
        coalesce(ps.tackles_succeeded_away, 0)
    )) AS triggered_team_tackles_won,
    toInt32(if(
        ltr.card_team_side = 'home',
        coalesce(ps.tackles_succeeded_away, 0),
        coalesce(ps.tackles_succeeded_home, 0)
    )) AS opponent_tackles_won,
    toInt32(if(
        ltr.card_team_side = 'home',
        coalesce(ps.interceptions_home, 0),
        coalesce(ps.interceptions_away, 0)
    )) AS triggered_team_interceptions,
    toInt32(if(
        ltr.card_team_side = 'home',
        coalesce(ps.interceptions_away, 0),
        coalesce(ps.interceptions_home, 0)
    )) AS opponent_interceptions,
    toInt32(if(
        ltr.card_team_side = 'home',
        coalesce(ps.clearances_home, 0),
        coalesce(ps.clearances_away, 0)
    )) AS triggered_team_clearances,
    toInt32(if(
        ltr.card_team_side = 'home',
        coalesce(ps.clearances_away, 0),
        coalesce(ps.clearances_home, 0)
    )) AS opponent_clearances,
    toFloat32(if(
        ltr.card_team_side = 'home',
        coalesce(ps.ball_possession_home, 0),
        coalesce(ps.ball_possession_away, 0)
    )) AS triggered_team_possession_pct,
    toFloat32(if(
        ltr.card_team_side = 'home',
        coalesce(ps.ball_possession_away, 0),
        coalesce(ps.ball_possession_home, 0)
    )) AS opponent_possession_pct,
    toFloat32(round(
        if(
            ltr.card_team_side = 'home',
            coalesce(ps.ball_possession_home, 0),
            coalesce(ps.ball_possession_away, 0)
        )
        - if(
            ltr.card_team_side = 'home',
            coalesce(ps.ball_possession_away, 0),
            coalesce(ps.ball_possession_home, 0)
        ),
        1
    )) AS possession_delta_pct

FROM late_trailing_card_rollup AS ltr
INNER JOIN silver.match AS m
    ON m.match_id = ltr.match_id
LEFT JOIN late_trailing_card_rollup AS ltr_opp
    ON ltr_opp.match_id = ltr.match_id
   AND ltr_opp.card_team_side = if(ltr.card_team_side = 'home', 'away', 'home')
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = ltr.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND ltr.triggered_team_cards_while_trailing_late >= 3

ORDER BY
    triggered_team_cards_while_trailing_late DESC,
    cards_while_trailing_late_delta DESC,
    min_score_margin_during_trailing_cards ASC,
    m.match_date DESC,
    m.match_id DESC;
