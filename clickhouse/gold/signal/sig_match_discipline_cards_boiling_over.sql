INSERT INTO gold.sig_match_discipline_cards_boiling_over (
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
    trigger_threshold_min_late_window_cards,
    trigger_threshold_window_start_minute,
    trigger_threshold_window_end_minute,
    match_late_window_cards,
    match_late_window_cards_above_threshold,
    home_late_window_cards,
    away_late_window_cards,
    triggered_team_late_window_cards,
    opponent_late_window_cards,
    late_window_cards_delta,
    triggered_team_late_window_cards_share_pct,
    opponent_late_window_cards_share_pct,
    late_window_cards_share_delta_pct,
    match_total_cards,
    match_total_yellow_cards,
    match_total_red_cards,
    triggered_team_yellow_cards,
    opponent_yellow_cards,
    yellow_cards_delta,
    triggered_team_red_cards,
    opponent_red_cards,
    red_cards_delta,
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
-- Signal: sig_match_discipline_cards_boiling_over
-- Intent: detect late-match disciplinary spikes where cards pile up in the closing phase.
-- Trigger: combined yellow/red cards issued after minute 80 are >= 4.
WITH card_events AS (
    SELECT
        c.match_id,
        lowerUTF8(coalesce(c.team_side, '')) AS card_team_side,
        toInt32(coalesce(c.card_minute, 0)) AS card_minute
    FROM silver.card AS c
    WHERE c.match_id > 0
      AND lowerUTF8(coalesce(c.team_side, '')) IN ('home', 'away')
      AND toInt32(coalesce(c.card_minute, 0)) > 0
      AND (
          positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'yellow') > 0
          OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'yellow') > 0
          OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'booked') > 0
          OR positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'red') > 0
          OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'red') > 0
      )
),
late_window_counts AS (
    SELECT
        ce.match_id,
        countIf(ce.card_team_side = 'home' AND ce.card_minute > 80) AS home_late_window_cards,
        countIf(ce.card_team_side = 'away' AND ce.card_minute > 80) AS away_late_window_cards
    FROM card_events AS ce
    GROUP BY ce.match_id
),
eligible_matches AS (
    SELECT
        lwc.match_id,
        lwc.home_late_window_cards,
        lwc.away_late_window_cards,
        lwc.home_late_window_cards + lwc.away_late_window_cards AS match_late_window_cards
    FROM late_window_counts AS lwc
    WHERE (lwc.home_late_window_cards + lwc.away_late_window_cards) >= 4
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
        toInt32(em.home_late_window_cards) AS home_late_window_cards,
        toInt32(em.away_late_window_cards) AS away_late_window_cards,
        toInt32(em.match_late_window_cards) AS match_late_window_cards,
        coalesce(ps.yellow_cards_home, 0)
        + coalesce(ps.yellow_cards_away, 0)
        + coalesce(ps.red_cards_home, 0)
        + coalesce(ps.red_cards_away, 0) AS match_total_cards,
        coalesce(ps.yellow_cards_home, 0) + coalesce(ps.yellow_cards_away, 0) AS match_total_yellow_cards,
        coalesce(ps.red_cards_home, 0) + coalesce(ps.red_cards_away, 0) AS match_total_red_cards
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
    match_id,
    match_date,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,

    'home' AS triggered_side,
    home_team_id AS triggered_team_id,
    home_team_name AS triggered_team_name,
    away_team_id AS opponent_team_id,
    away_team_name AS opponent_team_name,

    toInt32(4) AS trigger_threshold_min_late_window_cards,
    toInt32(80) AS trigger_threshold_window_start_minute,
    CAST(NULL, 'Nullable(Int32)') AS trigger_threshold_window_end_minute,
    toInt32(match_late_window_cards) AS match_late_window_cards,
    toInt32(match_late_window_cards - 4) AS match_late_window_cards_above_threshold,
    toInt32(home_late_window_cards) AS home_late_window_cards,
    toInt32(away_late_window_cards) AS away_late_window_cards,
    toInt32(home_late_window_cards) AS triggered_team_late_window_cards,
    toInt32(away_late_window_cards) AS opponent_late_window_cards,
    toInt32(home_late_window_cards - away_late_window_cards) AS late_window_cards_delta,
    toFloat32(round(
        100.0 * home_late_window_cards / nullIf(toFloat64(match_late_window_cards), 0),
        1
    )) AS triggered_team_late_window_cards_share_pct,
    toFloat32(round(
        100.0 * away_late_window_cards / nullIf(toFloat64(match_late_window_cards), 0),
        1
    )) AS opponent_late_window_cards_share_pct,
    toFloat32(round(
        (
            100.0 * home_late_window_cards / nullIf(toFloat64(match_late_window_cards), 0)
        ) - (
            100.0 * away_late_window_cards / nullIf(toFloat64(match_late_window_cards), 0)
        ),
        1
    )) AS late_window_cards_share_delta_pct,

    toInt32(match_total_cards) AS match_total_cards,
    toInt32(match_total_yellow_cards) AS match_total_yellow_cards,
    toInt32(match_total_red_cards) AS match_total_red_cards,
    toInt32(yellow_cards_home) AS triggered_team_yellow_cards,
    toInt32(yellow_cards_away) AS opponent_yellow_cards,
    toInt32(yellow_cards_home - yellow_cards_away) AS yellow_cards_delta,
    toInt32(red_cards_home) AS triggered_team_red_cards,
    toInt32(red_cards_away) AS opponent_red_cards,
    toInt32(red_cards_home - red_cards_away) AS red_cards_delta,
    toInt32(yellow_cards_home + red_cards_home) AS triggered_team_total_cards,
    toInt32(yellow_cards_away + red_cards_away) AS opponent_total_cards,
    toInt32(
        (yellow_cards_home + red_cards_home)
        - (yellow_cards_away + red_cards_away)
    ) AS card_count_delta,

    toInt32(fouls_home) AS triggered_team_fouls_committed,
    toInt32(fouls_away) AS opponent_fouls_committed,
    toInt32(fouls_home - fouls_away) AS fouls_committed_delta,
    toNullable(toFloat32(round(
        100.0 * (yellow_cards_home + red_cards_home) / nullIf(toFloat64(fouls_home), 0),
        1
    ))) AS triggered_team_cards_per_foul_pct,
    toNullable(toFloat32(round(
        100.0 * (yellow_cards_away + red_cards_away) / nullIf(toFloat64(fouls_away), 0),
        1
    ))) AS opponent_cards_per_foul_pct,
    toNullable(toFloat32(round(
        (
            100.0 * (yellow_cards_home + red_cards_home) / nullIf(toFloat64(fouls_home), 0)
        ) - (
            100.0 * (yellow_cards_away + red_cards_away) / nullIf(toFloat64(fouls_away), 0)
        ),
        1
    ))) AS cards_per_foul_delta_pct,

    toInt32(duels_won_home) AS triggered_team_duels_won,
    toInt32(duels_won_away) AS opponent_duels_won,
    toInt32(tackles_won_home) AS triggered_team_tackles_won,
    toInt32(tackles_won_away) AS opponent_tackles_won,
    toInt32(interceptions_home) AS triggered_team_interceptions,
    toInt32(interceptions_away) AS opponent_interceptions,
    toInt32(clearances_home) AS triggered_team_clearances,
    toInt32(clearances_away) AS opponent_clearances,
    possession_home_pct AS triggered_team_possession_pct,
    possession_away_pct AS opponent_possession_pct,
    toFloat32(round(possession_home_pct - possession_away_pct, 1)) AS possession_delta_pct
FROM base_stats AS b

UNION ALL

SELECT
    match_id,
    match_date,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,

    'away' AS triggered_side,
    away_team_id AS triggered_team_id,
    away_team_name AS triggered_team_name,
    home_team_id AS opponent_team_id,
    home_team_name AS opponent_team_name,

    toInt32(4) AS trigger_threshold_min_late_window_cards,
    toInt32(80) AS trigger_threshold_window_start_minute,
    CAST(NULL, 'Nullable(Int32)') AS trigger_threshold_window_end_minute,
    toInt32(match_late_window_cards) AS match_late_window_cards,
    toInt32(match_late_window_cards - 4) AS match_late_window_cards_above_threshold,
    toInt32(home_late_window_cards) AS home_late_window_cards,
    toInt32(away_late_window_cards) AS away_late_window_cards,
    toInt32(away_late_window_cards) AS triggered_team_late_window_cards,
    toInt32(home_late_window_cards) AS opponent_late_window_cards,
    toInt32(away_late_window_cards - home_late_window_cards) AS late_window_cards_delta,
    toFloat32(round(
        100.0 * away_late_window_cards / nullIf(toFloat64(match_late_window_cards), 0),
        1
    )) AS triggered_team_late_window_cards_share_pct,
    toFloat32(round(
        100.0 * home_late_window_cards / nullIf(toFloat64(match_late_window_cards), 0),
        1
    )) AS opponent_late_window_cards_share_pct,
    toFloat32(round(
        (
            100.0 * away_late_window_cards / nullIf(toFloat64(match_late_window_cards), 0)
        ) - (
            100.0 * home_late_window_cards / nullIf(toFloat64(match_late_window_cards), 0)
        ),
        1
    )) AS late_window_cards_share_delta_pct,

    toInt32(match_total_cards) AS match_total_cards,
    toInt32(match_total_yellow_cards) AS match_total_yellow_cards,
    toInt32(match_total_red_cards) AS match_total_red_cards,
    toInt32(yellow_cards_away) AS triggered_team_yellow_cards,
    toInt32(yellow_cards_home) AS opponent_yellow_cards,
    toInt32(yellow_cards_away - yellow_cards_home) AS yellow_cards_delta,
    toInt32(red_cards_away) AS triggered_team_red_cards,
    toInt32(red_cards_home) AS opponent_red_cards,
    toInt32(red_cards_away - red_cards_home) AS red_cards_delta,
    toInt32(yellow_cards_away + red_cards_away) AS triggered_team_total_cards,
    toInt32(yellow_cards_home + red_cards_home) AS opponent_total_cards,
    toInt32(
        (yellow_cards_away + red_cards_away)
        - (yellow_cards_home + red_cards_home)
    ) AS card_count_delta,

    toInt32(fouls_away) AS triggered_team_fouls_committed,
    toInt32(fouls_home) AS opponent_fouls_committed,
    toInt32(fouls_away - fouls_home) AS fouls_committed_delta,
    toNullable(toFloat32(round(
        100.0 * (yellow_cards_away + red_cards_away) / nullIf(toFloat64(fouls_away), 0),
        1
    ))) AS triggered_team_cards_per_foul_pct,
    toNullable(toFloat32(round(
        100.0 * (yellow_cards_home + red_cards_home) / nullIf(toFloat64(fouls_home), 0),
        1
    ))) AS opponent_cards_per_foul_pct,
    toNullable(toFloat32(round(
        (
            100.0 * (yellow_cards_away + red_cards_away) / nullIf(toFloat64(fouls_away), 0)
        ) - (
            100.0 * (yellow_cards_home + red_cards_home) / nullIf(toFloat64(fouls_home), 0)
        ),
        1
    ))) AS cards_per_foul_delta_pct,

    toInt32(duels_won_away) AS triggered_team_duels_won,
    toInt32(duels_won_home) AS opponent_duels_won,
    toInt32(tackles_won_away) AS triggered_team_tackles_won,
    toInt32(tackles_won_home) AS opponent_tackles_won,
    toInt32(interceptions_away) AS triggered_team_interceptions,
    toInt32(interceptions_home) AS opponent_interceptions,
    toInt32(clearances_away) AS triggered_team_clearances,
    toInt32(clearances_home) AS opponent_clearances,
    possession_away_pct AS triggered_team_possession_pct,
    possession_home_pct AS opponent_possession_pct,
    toFloat32(round(possession_away_pct - possession_home_pct, 1)) AS possession_delta_pct
FROM base_stats AS b

ORDER BY match_id, triggered_side;
