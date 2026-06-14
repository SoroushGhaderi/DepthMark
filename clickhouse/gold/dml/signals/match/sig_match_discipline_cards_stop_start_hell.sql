INSERT INTO gold.sig_match_discipline_cards_stop_start_hell (
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
    trigger_threshold_match_minutes,
    trigger_threshold_max_seconds_per_whistle,
    trigger_threshold_min_combined_whistle_events,
    match_total_whistle_events,
    match_total_whistle_events_above_threshold,
    match_seconds_per_whistle,
    match_total_fouls_committed,
    match_total_cards,
    match_total_yellow_cards,
    match_total_red_cards,
    match_total_offsides,
    triggered_team_whistle_events,
    opponent_whistle_events,
    whistle_events_delta,
    triggered_team_whistle_share_pct,
    opponent_whistle_share_pct,
    whistle_share_delta_pct,
    triggered_team_seconds_per_whistle,
    opponent_seconds_per_whistle,
    seconds_per_whistle_delta,
    triggered_team_fouls_committed,
    opponent_fouls_committed,
    fouls_committed_delta,
    triggered_team_offsides,
    opponent_offsides,
    offsides_delta,
    triggered_team_yellow_cards,
    opponent_yellow_cards,
    yellow_cards_delta,
    triggered_team_red_cards,
    opponent_red_cards,
    red_cards_delta,
    triggered_team_total_cards,
    opponent_total_cards,
    card_count_delta,
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
-- Signal: sig_match_discipline_cards_stop_start_hell
-- Intent: Detect matches with relentless stop-start rhythm from foul/card/offside whistles.
-- Trigger: combined whistle proxy events (fouls + yellow/red cards + offsides) >= 60.
WITH base_stats AS (
    SELECT
        m.match_id AS match_id,
        m.match_date AS match_date,
        m.home_team_id AS home_team_id,
        m.home_team_name AS home_team_name,
        m.away_team_id AS away_team_id,
        m.away_team_name AS away_team_name,
        m.home_score AS home_score,
        m.away_score AS away_score,
        coalesce(ps.fouls_home, 0) AS fouls_home,
        coalesce(ps.fouls_away, 0) AS fouls_away,
        coalesce(ps.yellow_cards_home, 0) AS yellow_cards_home,
        coalesce(ps.yellow_cards_away, 0) AS yellow_cards_away,
        coalesce(ps.red_cards_home, 0) AS red_cards_home,
        coalesce(ps.red_cards_away, 0) AS red_cards_away,
        coalesce(ps.offsides_home, 0) AS offsides_home,
        coalesce(ps.offsides_away, 0) AS offsides_away,
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
        coalesce(ps.fouls_home, 0)
        + coalesce(ps.fouls_away, 0)
        + coalesce(ps.yellow_cards_home, 0)
        + coalesce(ps.yellow_cards_away, 0)
        + coalesce(ps.red_cards_home, 0)
        + coalesce(ps.red_cards_away, 0)
        + coalesce(ps.offsides_home, 0)
        + coalesce(ps.offsides_away, 0) AS match_total_whistle_events,
        coalesce(ps.fouls_home, 0) + coalesce(ps.fouls_away, 0) AS match_total_fouls_committed,
        coalesce(ps.yellow_cards_home, 0)
        + coalesce(ps.yellow_cards_away, 0)
        + coalesce(ps.red_cards_home, 0)
        + coalesce(ps.red_cards_away, 0) AS match_total_cards,
        coalesce(ps.yellow_cards_home, 0) + coalesce(ps.yellow_cards_away, 0) AS match_total_yellow_cards,
        coalesce(ps.red_cards_home, 0) + coalesce(ps.red_cards_away, 0) AS match_total_red_cards,
        coalesce(ps.offsides_home, 0) + coalesce(ps.offsides_away, 0) AS match_total_offsides
    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.period = 'All'
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND (
            coalesce(ps.fouls_home, 0)
            + coalesce(ps.fouls_away, 0)
            + coalesce(ps.yellow_cards_home, 0)
            + coalesce(ps.yellow_cards_away, 0)
            + coalesce(ps.red_cards_home, 0)
            + coalesce(ps.red_cards_away, 0)
            + coalesce(ps.offsides_home, 0)
            + coalesce(ps.offsides_away, 0)
        ) >= 60
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
    toInt32(90) AS trigger_threshold_match_minutes,
    toFloat32(90.0) AS trigger_threshold_max_seconds_per_whistle,
    toInt32(60) AS trigger_threshold_min_combined_whistle_events,
    toInt32(b.match_total_whistle_events) AS match_total_whistle_events,
    toInt32(b.match_total_whistle_events - 60) AS match_total_whistle_events_above_threshold,
    toNullable(toFloat32(round(
        5400.0 / nullIf(toFloat64(b.match_total_whistle_events), 0),
        1
    ))) AS match_seconds_per_whistle,
    toInt32(b.match_total_fouls_committed) AS match_total_fouls_committed,
    toInt32(b.match_total_cards) AS match_total_cards,
    toInt32(b.match_total_yellow_cards) AS match_total_yellow_cards,
    toInt32(b.match_total_red_cards) AS match_total_red_cards,
    toInt32(b.match_total_offsides) AS match_total_offsides,
    toInt32(b.fouls_home + b.yellow_cards_home + b.red_cards_home + b.offsides_home) AS triggered_team_whistle_events,
    toInt32(b.fouls_away + b.yellow_cards_away + b.red_cards_away + b.offsides_away) AS opponent_whistle_events,
    toInt32(
        (b.fouls_home + b.yellow_cards_home + b.red_cards_home + b.offsides_home)
        - (b.fouls_away + b.yellow_cards_away + b.red_cards_away + b.offsides_away)
    ) AS whistle_events_delta,
    toFloat32(round(
        100.0
        * (b.fouls_home + b.yellow_cards_home + b.red_cards_home + b.offsides_home)
        / nullIf(toFloat64(b.match_total_whistle_events), 0),
        1
    )) AS triggered_team_whistle_share_pct,
    toFloat32(round(
        100.0
        * (b.fouls_away + b.yellow_cards_away + b.red_cards_away + b.offsides_away)
        / nullIf(toFloat64(b.match_total_whistle_events), 0),
        1
    )) AS opponent_whistle_share_pct,
    toFloat32(round(
        (
            100.0
            * (b.fouls_home + b.yellow_cards_home + b.red_cards_home + b.offsides_home)
            / nullIf(toFloat64(b.match_total_whistle_events), 0)
        ) - (
            100.0
            * (b.fouls_away + b.yellow_cards_away + b.red_cards_away + b.offsides_away)
            / nullIf(toFloat64(b.match_total_whistle_events), 0)
        ),
        1
    )) AS whistle_share_delta_pct,
    toNullable(toFloat32(round(
        5400.0
        / nullIf(toFloat64(b.fouls_home + b.yellow_cards_home + b.red_cards_home + b.offsides_home), 0),
        1
    ))) AS triggered_team_seconds_per_whistle,
    toNullable(toFloat32(round(
        5400.0
        / nullIf(toFloat64(b.fouls_away + b.yellow_cards_away + b.red_cards_away + b.offsides_away), 0),
        1
    ))) AS opponent_seconds_per_whistle,
    toNullable(toFloat32(round(
        (
            5400.0
            / nullIf(toFloat64(b.fouls_home + b.yellow_cards_home + b.red_cards_home + b.offsides_home), 0)
        ) - (
            5400.0
            / nullIf(toFloat64(b.fouls_away + b.yellow_cards_away + b.red_cards_away + b.offsides_away), 0)
        ),
        1
    ))) AS seconds_per_whistle_delta,
    toInt32(b.fouls_home) AS triggered_team_fouls_committed,
    toInt32(b.fouls_away) AS opponent_fouls_committed,
    toInt32(b.fouls_home - b.fouls_away) AS fouls_committed_delta,
    toInt32(b.offsides_home) AS triggered_team_offsides,
    toInt32(b.offsides_away) AS opponent_offsides,
    toInt32(b.offsides_home - b.offsides_away) AS offsides_delta,
    toInt32(b.yellow_cards_home) AS triggered_team_yellow_cards,
    toInt32(b.yellow_cards_away) AS opponent_yellow_cards,
    toInt32(b.yellow_cards_home - b.yellow_cards_away) AS yellow_cards_delta,
    toInt32(b.red_cards_home) AS triggered_team_red_cards,
    toInt32(b.red_cards_away) AS opponent_red_cards,
    toInt32(b.red_cards_home - b.red_cards_away) AS red_cards_delta,
    toInt32(b.yellow_cards_home + b.red_cards_home) AS triggered_team_total_cards,
    toInt32(b.yellow_cards_away + b.red_cards_away) AS opponent_total_cards,
    toInt32(
        (b.yellow_cards_home + b.red_cards_home)
        - (b.yellow_cards_away + b.red_cards_away)
    ) AS card_count_delta,
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
    toInt32(90) AS trigger_threshold_match_minutes,
    toFloat32(90.0) AS trigger_threshold_max_seconds_per_whistle,
    toInt32(60) AS trigger_threshold_min_combined_whistle_events,
    toInt32(b.match_total_whistle_events) AS match_total_whistle_events,
    toInt32(b.match_total_whistle_events - 60) AS match_total_whistle_events_above_threshold,
    toNullable(toFloat32(round(
        5400.0 / nullIf(toFloat64(b.match_total_whistle_events), 0),
        1
    ))) AS match_seconds_per_whistle,
    toInt32(b.match_total_fouls_committed) AS match_total_fouls_committed,
    toInt32(b.match_total_cards) AS match_total_cards,
    toInt32(b.match_total_yellow_cards) AS match_total_yellow_cards,
    toInt32(b.match_total_red_cards) AS match_total_red_cards,
    toInt32(b.match_total_offsides) AS match_total_offsides,
    toInt32(b.fouls_away + b.yellow_cards_away + b.red_cards_away + b.offsides_away) AS triggered_team_whistle_events,
    toInt32(b.fouls_home + b.yellow_cards_home + b.red_cards_home + b.offsides_home) AS opponent_whistle_events,
    toInt32(
        (b.fouls_away + b.yellow_cards_away + b.red_cards_away + b.offsides_away)
        - (b.fouls_home + b.yellow_cards_home + b.red_cards_home + b.offsides_home)
    ) AS whistle_events_delta,
    toFloat32(round(
        100.0
        * (b.fouls_away + b.yellow_cards_away + b.red_cards_away + b.offsides_away)
        / nullIf(toFloat64(b.match_total_whistle_events), 0),
        1
    )) AS triggered_team_whistle_share_pct,
    toFloat32(round(
        100.0
        * (b.fouls_home + b.yellow_cards_home + b.red_cards_home + b.offsides_home)
        / nullIf(toFloat64(b.match_total_whistle_events), 0),
        1
    )) AS opponent_whistle_share_pct,
    toFloat32(round(
        (
            100.0
            * (b.fouls_away + b.yellow_cards_away + b.red_cards_away + b.offsides_away)
            / nullIf(toFloat64(b.match_total_whistle_events), 0)
        ) - (
            100.0
            * (b.fouls_home + b.yellow_cards_home + b.red_cards_home + b.offsides_home)
            / nullIf(toFloat64(b.match_total_whistle_events), 0)
        ),
        1
    )) AS whistle_share_delta_pct,
    toNullable(toFloat32(round(
        5400.0
        / nullIf(toFloat64(b.fouls_away + b.yellow_cards_away + b.red_cards_away + b.offsides_away), 0),
        1
    ))) AS triggered_team_seconds_per_whistle,
    toNullable(toFloat32(round(
        5400.0
        / nullIf(toFloat64(b.fouls_home + b.yellow_cards_home + b.red_cards_home + b.offsides_home), 0),
        1
    ))) AS opponent_seconds_per_whistle,
    toNullable(toFloat32(round(
        (
            5400.0
            / nullIf(toFloat64(b.fouls_away + b.yellow_cards_away + b.red_cards_away + b.offsides_away), 0)
        ) - (
            5400.0
            / nullIf(toFloat64(b.fouls_home + b.yellow_cards_home + b.red_cards_home + b.offsides_home), 0)
        ),
        1
    ))) AS seconds_per_whistle_delta,
    toInt32(b.fouls_away) AS triggered_team_fouls_committed,
    toInt32(b.fouls_home) AS opponent_fouls_committed,
    toInt32(b.fouls_away - b.fouls_home) AS fouls_committed_delta,
    toInt32(b.offsides_away) AS triggered_team_offsides,
    toInt32(b.offsides_home) AS opponent_offsides,
    toInt32(b.offsides_away - b.offsides_home) AS offsides_delta,
    toInt32(b.yellow_cards_away) AS triggered_team_yellow_cards,
    toInt32(b.yellow_cards_home) AS opponent_yellow_cards,
    toInt32(b.yellow_cards_away - b.yellow_cards_home) AS yellow_cards_delta,
    toInt32(b.red_cards_away) AS triggered_team_red_cards,
    toInt32(b.red_cards_home) AS opponent_red_cards,
    toInt32(b.red_cards_away - b.red_cards_home) AS red_cards_delta,
    toInt32(b.yellow_cards_away + b.red_cards_away) AS triggered_team_total_cards,
    toInt32(b.yellow_cards_home + b.red_cards_home) AS opponent_total_cards,
    toInt32(
        (b.yellow_cards_away + b.red_cards_away)
        - (b.yellow_cards_home + b.red_cards_home)
    ) AS card_count_delta,
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
