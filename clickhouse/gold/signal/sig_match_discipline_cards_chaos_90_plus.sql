INSERT INTO gold.sig_match_discipline_cards_chaos_90_plus (
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
    trigger_threshold_min_added_time_red_cards,
    trigger_threshold_window_base_minute,
    match_added_time_red_cards,
    match_added_time_red_cards_above_threshold,
    home_added_time_red_cards,
    away_added_time_red_cards,
    triggered_team_added_time_red_cards,
    opponent_added_time_red_cards,
    added_time_red_cards_delta,
    triggered_team_added_time_red_cards_share_pct,
    opponent_added_time_red_cards_share_pct,
    added_time_red_cards_share_delta_pct,
    triggered_team_first_added_time_red_minute,
    opponent_first_added_time_red_minute,
    triggered_team_first_added_time_red_added_time,
    opponent_first_added_time_red_added_time,
    triggered_team_first_added_time_red_effective_minute,
    opponent_first_added_time_red_effective_minute,
    match_total_red_cards,
    match_total_yellow_cards,
    match_total_cards,
    triggered_team_red_cards,
    opponent_red_cards,
    red_cards_delta,
    triggered_team_yellow_cards,
    opponent_yellow_cards,
    yellow_cards_delta,
    triggered_team_total_cards,
    opponent_total_cards,
    card_count_delta,
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
-- Signal: sig_match_discipline_cards_chaos_90_plus
-- Intent: detect extreme late-game chaos where multiple red cards are issued in 90+ added time.
-- Trigger: combined red cards with card_minute >= 90 and added_time > 0 are >= 2.
WITH red_card_events AS (
    SELECT
        c.match_id,
        lowerUTF8(coalesce(c.team_side, '')) AS card_team_side,
        toInt32OrZero(c.card_minute) AS card_minute,
        toInt32(coalesce(c.added_time, 0)) AS card_added_time,
        toInt32OrZero(c.card_minute) + toInt32(coalesce(c.added_time, 0)) AS card_effective_minute,
        toInt64(c.event_id) AS event_id
    FROM silver.card AS c
    WHERE c.match_id > 0
      AND lowerUTF8(coalesce(c.team_side, '')) IN ('home', 'away')
      AND toInt32OrZero(c.card_minute) >= 90
      AND toInt32(coalesce(c.added_time, 0)) > 0
      AND (
          positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'red') > 0
          OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'red') > 0
      )
),
added_time_red_rollup AS (
    SELECT
        rce.match_id,
        rce.card_team_side,
        count() AS added_time_red_cards,
        argMin(rce.card_minute, tuple(rce.card_effective_minute, rce.event_id)) AS first_added_time_red_minute,
        argMin(rce.card_added_time, tuple(rce.card_effective_minute, rce.event_id)) AS first_added_time_red_added_time,
        min(rce.card_effective_minute) AS first_added_time_red_effective_minute
    FROM red_card_events AS rce
    GROUP BY
        rce.match_id,
        rce.card_team_side
),
match_added_time_red_counts AS (
    SELECT
        atr.match_id,
        coalesce(maxIf(atr.added_time_red_cards, atr.card_team_side = 'home'), 0) AS home_added_time_red_cards,
        coalesce(maxIf(atr.added_time_red_cards, atr.card_team_side = 'away'), 0) AS away_added_time_red_cards,
        coalesce(maxIf(atr.first_added_time_red_minute, atr.card_team_side = 'home'), NULL) AS home_first_added_time_red_minute,
        coalesce(maxIf(atr.first_added_time_red_minute, atr.card_team_side = 'away'), NULL) AS away_first_added_time_red_minute,
        coalesce(maxIf(atr.first_added_time_red_added_time, atr.card_team_side = 'home'), NULL) AS home_first_added_time_red_added_time,
        coalesce(maxIf(atr.first_added_time_red_added_time, atr.card_team_side = 'away'), NULL) AS away_first_added_time_red_added_time,
        coalesce(maxIf(atr.first_added_time_red_effective_minute, atr.card_team_side = 'home'), NULL) AS home_first_added_time_red_effective_minute,
        coalesce(maxIf(atr.first_added_time_red_effective_minute, atr.card_team_side = 'away'), NULL) AS away_first_added_time_red_effective_minute
    FROM added_time_red_rollup AS atr
    GROUP BY atr.match_id
),
eligible_matches AS (
    SELECT
        mar.match_id,
        mar.home_added_time_red_cards,
        mar.away_added_time_red_cards,
        mar.home_first_added_time_red_minute,
        mar.away_first_added_time_red_minute,
        mar.home_first_added_time_red_added_time,
        mar.away_first_added_time_red_added_time,
        mar.home_first_added_time_red_effective_minute,
        mar.away_first_added_time_red_effective_minute,
        mar.home_added_time_red_cards + mar.away_added_time_red_cards AS match_added_time_red_cards
    FROM match_added_time_red_counts AS mar
    WHERE (mar.home_added_time_red_cards + mar.away_added_time_red_cards) >= 2
),
base_stats AS (
    SELECT
        m.match_id,
        m.match_date,
        m.home_team_id,
        m.home_team_name,
        m.away_team_id,
        m.away_team_name,
        m.home_score,
        m.away_score,
        coalesce(ps.yellow_cards_home, 0) AS yellow_cards_home,
        coalesce(ps.yellow_cards_away, 0) AS yellow_cards_away,
        coalesce(ps.red_cards_home, 0) AS red_cards_home,
        coalesce(ps.red_cards_away, 0) AS red_cards_away,
        coalesce(ps.fouls_home, 0) AS fouls_home,
        coalesce(ps.fouls_away, 0) AS fouls_away,
        coalesce(ps.duels_won_home, 0) AS duels_won_home,
        coalesce(ps.duels_won_away, 0) AS duels_won_away,
        coalesce(ps.tackles_succeeded_home, 0) AS tackles_won_home,
        coalesce(ps.tackles_succeeded_away, 0) AS tackles_won_away,
        coalesce(ps.interceptions_home, 0) AS interceptions_home,
        coalesce(ps.interceptions_away, 0) AS interceptions_away,
        coalesce(ps.clearances_home, 0) AS clearances_home,
        coalesce(ps.clearances_away, 0) AS clearances_away,
        toFloat32(coalesce(ps.ball_possession_home, 0)) AS possession_home_pct,
        toFloat32(coalesce(ps.ball_possession_away, 0)) AS possession_away_pct,
        toInt32(em.home_added_time_red_cards) AS home_added_time_red_cards,
        toInt32(em.away_added_time_red_cards) AS away_added_time_red_cards,
        toInt32(em.match_added_time_red_cards) AS match_added_time_red_cards,
        toNullable(toInt32(em.home_first_added_time_red_minute)) AS home_first_added_time_red_minute,
        toNullable(toInt32(em.away_first_added_time_red_minute)) AS away_first_added_time_red_minute,
        toNullable(toInt32(em.home_first_added_time_red_added_time)) AS home_first_added_time_red_added_time,
        toNullable(toInt32(em.away_first_added_time_red_added_time)) AS away_first_added_time_red_added_time,
        toNullable(toInt32(em.home_first_added_time_red_effective_minute)) AS home_first_added_time_red_effective_minute,
        toNullable(toInt32(em.away_first_added_time_red_effective_minute)) AS away_first_added_time_red_effective_minute,
        coalesce(ps.yellow_cards_home, 0) + coalesce(ps.yellow_cards_away, 0) AS match_total_yellow_cards,
        coalesce(ps.red_cards_home, 0) + coalesce(ps.red_cards_away, 0) AS match_total_red_cards,
        coalesce(ps.yellow_cards_home, 0)
        + coalesce(ps.yellow_cards_away, 0)
        + coalesce(ps.red_cards_home, 0)
        + coalesce(ps.red_cards_away, 0) AS match_total_cards
    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.period = 'All'
    INNER JOIN eligible_matches AS em
        ON em.match_id = m.match_id
    WHERE m.match_finished = 1
      AND m.match_id > 0
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

    toInt32(2) AS trigger_threshold_min_added_time_red_cards,
    toInt32(90) AS trigger_threshold_window_base_minute,
    toInt32(b.match_added_time_red_cards) AS match_added_time_red_cards,
    toInt32(b.match_added_time_red_cards - 2) AS match_added_time_red_cards_above_threshold,
    toInt32(b.home_added_time_red_cards) AS home_added_time_red_cards,
    toInt32(b.away_added_time_red_cards) AS away_added_time_red_cards,
    toInt32(b.home_added_time_red_cards) AS triggered_team_added_time_red_cards,
    toInt32(b.away_added_time_red_cards) AS opponent_added_time_red_cards,
    toInt32(b.home_added_time_red_cards - b.away_added_time_red_cards) AS added_time_red_cards_delta,
    toFloat32(round(
        100.0 * b.home_added_time_red_cards / nullIf(toFloat64(b.match_added_time_red_cards), 0),
        1
    )) AS triggered_team_added_time_red_cards_share_pct,
    toFloat32(round(
        100.0 * b.away_added_time_red_cards / nullIf(toFloat64(b.match_added_time_red_cards), 0),
        1
    )) AS opponent_added_time_red_cards_share_pct,
    toFloat32(round(
        (
            100.0 * b.home_added_time_red_cards / nullIf(toFloat64(b.match_added_time_red_cards), 0)
        ) - (
            100.0 * b.away_added_time_red_cards / nullIf(toFloat64(b.match_added_time_red_cards), 0)
        ),
        1
    )) AS added_time_red_cards_share_delta_pct,
    b.home_first_added_time_red_minute AS triggered_team_first_added_time_red_minute,
    b.away_first_added_time_red_minute AS opponent_first_added_time_red_minute,
    b.home_first_added_time_red_added_time AS triggered_team_first_added_time_red_added_time,
    b.away_first_added_time_red_added_time AS opponent_first_added_time_red_added_time,
    b.home_first_added_time_red_effective_minute AS triggered_team_first_added_time_red_effective_minute,
    b.away_first_added_time_red_effective_minute AS opponent_first_added_time_red_effective_minute,

    toInt32(b.match_total_red_cards) AS match_total_red_cards,
    toInt32(b.match_total_yellow_cards) AS match_total_yellow_cards,
    toInt32(b.match_total_cards) AS match_total_cards,
    toInt32(b.red_cards_home) AS triggered_team_red_cards,
    toInt32(b.red_cards_away) AS opponent_red_cards,
    toInt32(b.red_cards_home - b.red_cards_away) AS red_cards_delta,
    toInt32(b.yellow_cards_home) AS triggered_team_yellow_cards,
    toInt32(b.yellow_cards_away) AS opponent_yellow_cards,
    toInt32(b.yellow_cards_home - b.yellow_cards_away) AS yellow_cards_delta,
    toInt32(b.yellow_cards_home + b.red_cards_home) AS triggered_team_total_cards,
    toInt32(b.yellow_cards_away + b.red_cards_away) AS opponent_total_cards,
    toInt32(
        (b.yellow_cards_home + b.red_cards_home)
        - (b.yellow_cards_away + b.red_cards_away)
    ) AS card_count_delta,
    toInt32(b.fouls_home) AS triggered_team_fouls_committed,
    toInt32(b.fouls_away) AS opponent_fouls_committed,
    toInt32(b.fouls_home - b.fouls_away) AS fouls_committed_delta,
    toNullable(toFloat32(round(
        100.0 * (b.yellow_cards_home + b.red_cards_home) / nullIf(toFloat64(b.fouls_home), 0),
        1
    ))) AS triggered_team_cards_per_foul_pct,
    toNullable(toFloat32(round(
        100.0 * (b.yellow_cards_away + b.red_cards_away) / nullIf(toFloat64(b.fouls_away), 0),
        1
    ))) AS opponent_cards_per_foul_pct,
    toNullable(toFloat32(round(
        (
            100.0 * (b.yellow_cards_home + b.red_cards_home) / nullIf(toFloat64(b.fouls_home), 0)
        ) - (
            100.0 * (b.yellow_cards_away + b.red_cards_away) / nullIf(toFloat64(b.fouls_away), 0)
        ),
        1
    ))) AS cards_per_foul_delta_pct,
    toInt32(b.duels_won_home) AS triggered_team_duels_won,
    toInt32(b.duels_won_away) AS opponent_duels_won,
    toInt32(b.tackles_won_home) AS triggered_team_tackles_won,
    toInt32(b.tackles_won_away) AS opponent_tackles_won,
    toInt32(b.interceptions_home) AS triggered_team_interceptions,
    toInt32(b.interceptions_away) AS opponent_interceptions,
    toInt32(b.clearances_home) AS triggered_team_clearances,
    toInt32(b.clearances_away) AS opponent_clearances,
    b.possession_home_pct AS triggered_team_possession_pct,
    b.possession_away_pct AS opponent_possession_pct,
    toFloat32(round(b.possession_home_pct - b.possession_away_pct, 1)) AS possession_delta_pct
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

    toInt32(2) AS trigger_threshold_min_added_time_red_cards,
    toInt32(90) AS trigger_threshold_window_base_minute,
    toInt32(b.match_added_time_red_cards) AS match_added_time_red_cards,
    toInt32(b.match_added_time_red_cards - 2) AS match_added_time_red_cards_above_threshold,
    toInt32(b.home_added_time_red_cards) AS home_added_time_red_cards,
    toInt32(b.away_added_time_red_cards) AS away_added_time_red_cards,
    toInt32(b.away_added_time_red_cards) AS triggered_team_added_time_red_cards,
    toInt32(b.home_added_time_red_cards) AS opponent_added_time_red_cards,
    toInt32(b.away_added_time_red_cards - b.home_added_time_red_cards) AS added_time_red_cards_delta,
    toFloat32(round(
        100.0 * b.away_added_time_red_cards / nullIf(toFloat64(b.match_added_time_red_cards), 0),
        1
    )) AS triggered_team_added_time_red_cards_share_pct,
    toFloat32(round(
        100.0 * b.home_added_time_red_cards / nullIf(toFloat64(b.match_added_time_red_cards), 0),
        1
    )) AS opponent_added_time_red_cards_share_pct,
    toFloat32(round(
        (
            100.0 * b.away_added_time_red_cards / nullIf(toFloat64(b.match_added_time_red_cards), 0)
        ) - (
            100.0 * b.home_added_time_red_cards / nullIf(toFloat64(b.match_added_time_red_cards), 0)
        ),
        1
    )) AS added_time_red_cards_share_delta_pct,
    b.away_first_added_time_red_minute AS triggered_team_first_added_time_red_minute,
    b.home_first_added_time_red_minute AS opponent_first_added_time_red_minute,
    b.away_first_added_time_red_added_time AS triggered_team_first_added_time_red_added_time,
    b.home_first_added_time_red_added_time AS opponent_first_added_time_red_added_time,
    b.away_first_added_time_red_effective_minute AS triggered_team_first_added_time_red_effective_minute,
    b.home_first_added_time_red_effective_minute AS opponent_first_added_time_red_effective_minute,

    toInt32(b.match_total_red_cards) AS match_total_red_cards,
    toInt32(b.match_total_yellow_cards) AS match_total_yellow_cards,
    toInt32(b.match_total_cards) AS match_total_cards,
    toInt32(b.red_cards_away) AS triggered_team_red_cards,
    toInt32(b.red_cards_home) AS opponent_red_cards,
    toInt32(b.red_cards_away - b.red_cards_home) AS red_cards_delta,
    toInt32(b.yellow_cards_away) AS triggered_team_yellow_cards,
    toInt32(b.yellow_cards_home) AS opponent_yellow_cards,
    toInt32(b.yellow_cards_away - b.yellow_cards_home) AS yellow_cards_delta,
    toInt32(b.yellow_cards_away + b.red_cards_away) AS triggered_team_total_cards,
    toInt32(b.yellow_cards_home + b.red_cards_home) AS opponent_total_cards,
    toInt32(
        (b.yellow_cards_away + b.red_cards_away)
        - (b.yellow_cards_home + b.red_cards_home)
    ) AS card_count_delta,
    toInt32(b.fouls_away) AS triggered_team_fouls_committed,
    toInt32(b.fouls_home) AS opponent_fouls_committed,
    toInt32(b.fouls_away - b.fouls_home) AS fouls_committed_delta,
    toNullable(toFloat32(round(
        100.0 * (b.yellow_cards_away + b.red_cards_away) / nullIf(toFloat64(b.fouls_away), 0),
        1
    ))) AS triggered_team_cards_per_foul_pct,
    toNullable(toFloat32(round(
        100.0 * (b.yellow_cards_home + b.red_cards_home) / nullIf(toFloat64(b.fouls_home), 0),
        1
    ))) AS opponent_cards_per_foul_pct,
    toNullable(toFloat32(round(
        (
            100.0 * (b.yellow_cards_away + b.red_cards_away) / nullIf(toFloat64(b.fouls_away), 0)
        ) - (
            100.0 * (b.yellow_cards_home + b.red_cards_home) / nullIf(toFloat64(b.fouls_home), 0)
        ),
        1
    ))) AS cards_per_foul_delta_pct,
    toInt32(b.duels_won_away) AS triggered_team_duels_won,
    toInt32(b.duels_won_home) AS opponent_duels_won,
    toInt32(b.tackles_won_away) AS triggered_team_tackles_won,
    toInt32(b.tackles_won_home) AS opponent_tackles_won,
    toInt32(b.interceptions_away) AS triggered_team_interceptions,
    toInt32(b.interceptions_home) AS opponent_interceptions,
    toInt32(b.clearances_away) AS triggered_team_clearances,
    toInt32(b.clearances_home) AS opponent_clearances,
    b.possession_away_pct AS triggered_team_possession_pct,
    b.possession_home_pct AS opponent_possession_pct,
    toFloat32(round(b.possession_away_pct - b.possession_home_pct, 1)) AS possession_delta_pct
FROM base_stats AS b

ORDER BY match_id, triggered_side;
