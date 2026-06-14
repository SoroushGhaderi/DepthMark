INSERT INTO gold.sig_match_discipline_cards_asymmetric_aggression (
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
    trigger_threshold_min_fouls_multiplier,
    trigger_threshold_max_card_count_delta,
    triggered_team_fouls_committed,
    opponent_fouls_committed,
    match_total_fouls_committed,
    fouls_committed_delta,
    triggered_team_fouls_share_pct,
    opponent_fouls_share_pct,
    fouls_share_delta_pct,
    triggered_team_fouls_multiplier,
    fouls_multiplier_above_threshold,
    triggered_team_total_cards,
    opponent_total_cards,
    card_count_delta,
    match_total_cards,
    match_total_yellow_cards,
    match_total_red_cards,
    triggered_team_yellow_cards,
    opponent_yellow_cards,
    yellow_cards_delta,
    triggered_team_red_cards,
    opponent_red_cards,
    red_cards_delta,
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
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct
)
-- Signal: sig_match_discipline_cards_asymmetric_aggression
-- Intent: detect matches where one side commits far more fouls but is carded less than the opponent.
-- Trigger: triggered-side fouls >= 3x opponent fouls AND triggered-side total cards < opponent total cards.
WITH base_stats AS (
    SELECT
        m.match_id,
        m.match_date,
        m.home_team_id,
        m.home_team_name,
        m.away_team_id,
        m.away_team_name,
        m.home_score,
        m.away_score,
        coalesce(ps.fouls_home, 0) AS fouls_home,
        coalesce(ps.fouls_away, 0) AS fouls_away,
        coalesce(ps.yellow_cards_home, 0) AS yellow_cards_home,
        coalesce(ps.yellow_cards_away, 0) AS yellow_cards_away,
        coalesce(ps.red_cards_home, 0) AS red_cards_home,
        coalesce(ps.red_cards_away, 0) AS red_cards_away,
        coalesce(ps.duels_won_home, 0) AS duels_won_home,
        coalesce(ps.duels_won_away, 0) AS duels_won_away,
        coalesce(ps.tackles_succeeded_home, 0) AS tackles_won_home,
        coalesce(ps.tackles_succeeded_away, 0) AS tackles_won_away,
        coalesce(ps.interceptions_home, 0) AS interceptions_home,
        coalesce(ps.interceptions_away, 0) AS interceptions_away,
        coalesce(ps.clearances_home, 0) AS clearances_home,
        coalesce(ps.clearances_away, 0) AS clearances_away,
        coalesce(ps.accurate_passes_home, 0) AS accurate_passes_home,
        coalesce(ps.accurate_passes_away, 0) AS accurate_passes_away,
        coalesce(ps.pass_attempts_home, 0) AS pass_attempts_home,
        coalesce(ps.pass_attempts_away, 0) AS pass_attempts_away,
        toFloat32(coalesce(ps.ball_possession_home, 0)) AS possession_home_pct,
        toFloat32(coalesce(ps.ball_possession_away, 0)) AS possession_away_pct,
        coalesce(ps.fouls_home, 0) + coalesce(ps.fouls_away, 0) AS match_total_fouls_committed
    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.period = 'All'
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND (coalesce(ps.fouls_home, 0) + coalesce(ps.fouls_away, 0)) > 0
),
oriented AS (
    SELECT
        b.match_id,
        b.match_date,
        b.home_team_id,
        b.home_team_name,
        b.away_team_id,
        b.away_team_name,
        b.home_score,
        b.away_score,
        if(b.fouls_home >= b.fouls_away, 'home', 'away') AS triggered_side,
        if(b.fouls_home >= b.fouls_away, b.home_team_id, b.away_team_id) AS triggered_team_id,
        if(b.fouls_home >= b.fouls_away, b.home_team_name, b.away_team_name) AS triggered_team_name,
        if(b.fouls_home >= b.fouls_away, b.away_team_id, b.home_team_id) AS opponent_team_id,
        if(b.fouls_home >= b.fouls_away, b.away_team_name, b.home_team_name) AS opponent_team_name,
        if(b.fouls_home >= b.fouls_away, b.fouls_home, b.fouls_away) AS triggered_team_fouls_committed,
        if(b.fouls_home >= b.fouls_away, b.fouls_away, b.fouls_home) AS opponent_fouls_committed,
        if(
            b.fouls_home >= b.fouls_away,
            b.yellow_cards_home + b.red_cards_home,
            b.yellow_cards_away + b.red_cards_away
        ) AS triggered_team_total_cards,
        if(
            b.fouls_home >= b.fouls_away,
            b.yellow_cards_away + b.red_cards_away,
            b.yellow_cards_home + b.red_cards_home
        ) AS opponent_total_cards,
        if(b.fouls_home >= b.fouls_away, b.yellow_cards_home, b.yellow_cards_away) AS triggered_team_yellow_cards,
        if(b.fouls_home >= b.fouls_away, b.yellow_cards_away, b.yellow_cards_home) AS opponent_yellow_cards,
        if(b.fouls_home >= b.fouls_away, b.red_cards_home, b.red_cards_away) AS triggered_team_red_cards,
        if(b.fouls_home >= b.fouls_away, b.red_cards_away, b.red_cards_home) AS opponent_red_cards,
        if(b.fouls_home >= b.fouls_away, b.duels_won_home, b.duels_won_away) AS triggered_team_duels_won,
        if(b.fouls_home >= b.fouls_away, b.duels_won_away, b.duels_won_home) AS opponent_duels_won,
        if(b.fouls_home >= b.fouls_away, b.tackles_won_home, b.tackles_won_away) AS triggered_team_tackles_won,
        if(b.fouls_home >= b.fouls_away, b.tackles_won_away, b.tackles_won_home) AS opponent_tackles_won,
        if(b.fouls_home >= b.fouls_away, b.interceptions_home, b.interceptions_away) AS triggered_team_interceptions,
        if(b.fouls_home >= b.fouls_away, b.interceptions_away, b.interceptions_home) AS opponent_interceptions,
        if(b.fouls_home >= b.fouls_away, b.clearances_home, b.clearances_away) AS triggered_team_clearances,
        if(b.fouls_home >= b.fouls_away, b.clearances_away, b.clearances_home) AS opponent_clearances,
        if(b.fouls_home >= b.fouls_away, b.accurate_passes_home, b.accurate_passes_away) AS triggered_team_accurate_passes,
        if(b.fouls_home >= b.fouls_away, b.accurate_passes_away, b.accurate_passes_home) AS opponent_accurate_passes,
        if(b.fouls_home >= b.fouls_away, b.pass_attempts_home, b.pass_attempts_away) AS triggered_team_pass_attempts,
        if(b.fouls_home >= b.fouls_away, b.pass_attempts_away, b.pass_attempts_home) AS opponent_pass_attempts,
        if(b.fouls_home >= b.fouls_away, b.possession_home_pct, b.possession_away_pct) AS triggered_team_possession_pct,
        if(b.fouls_home >= b.fouls_away, b.possession_away_pct, b.possession_home_pct) AS opponent_possession_pct,
        b.match_total_fouls_committed,
        b.yellow_cards_home + b.yellow_cards_away AS match_total_yellow_cards,
        b.red_cards_home + b.red_cards_away AS match_total_red_cards
    FROM base_stats AS b
)
SELECT
    o.match_id,
    o.match_date,
    o.home_team_id,
    o.home_team_name,
    o.away_team_id,
    o.away_team_name,
    o.home_score,
    o.away_score,
    o.triggered_side,
    o.triggered_team_id,
    o.triggered_team_name,
    o.opponent_team_id,
    o.opponent_team_name,
    toFloat32(3.0) AS trigger_threshold_min_fouls_multiplier,
    toInt32(-1) AS trigger_threshold_max_card_count_delta,
    toInt32(o.triggered_team_fouls_committed) AS triggered_team_fouls_committed,
    toInt32(o.opponent_fouls_committed) AS opponent_fouls_committed,
    toInt32(o.match_total_fouls_committed) AS match_total_fouls_committed,
    toInt32(o.triggered_team_fouls_committed - o.opponent_fouls_committed) AS fouls_committed_delta,
    toFloat32(round(
        100.0 * o.triggered_team_fouls_committed / nullIf(toFloat64(o.match_total_fouls_committed), 0),
        1
    )) AS triggered_team_fouls_share_pct,
    toFloat32(round(
        100.0 * o.opponent_fouls_committed / nullIf(toFloat64(o.match_total_fouls_committed), 0),
        1
    )) AS opponent_fouls_share_pct,
    toFloat32(round(
        (
            100.0 * o.triggered_team_fouls_committed / nullIf(toFloat64(o.match_total_fouls_committed), 0)
        ) - (
            100.0 * o.opponent_fouls_committed / nullIf(toFloat64(o.match_total_fouls_committed), 0)
        ),
        1
    )) AS fouls_share_delta_pct,
    toFloat32(round(
        o.triggered_team_fouls_committed / nullIf(toFloat64(o.opponent_fouls_committed), 0),
        2
    )) AS triggered_team_fouls_multiplier,
    toFloat32(round(
        (o.triggered_team_fouls_committed / nullIf(toFloat64(o.opponent_fouls_committed), 0)) - 3.0,
        2
    )) AS fouls_multiplier_above_threshold,
    toInt32(o.triggered_team_total_cards) AS triggered_team_total_cards,
    toInt32(o.opponent_total_cards) AS opponent_total_cards,
    toInt32(o.triggered_team_total_cards - o.opponent_total_cards) AS card_count_delta,
    toInt32(o.match_total_yellow_cards + o.match_total_red_cards) AS match_total_cards,
    toInt32(o.match_total_yellow_cards) AS match_total_yellow_cards,
    toInt32(o.match_total_red_cards) AS match_total_red_cards,
    toInt32(o.triggered_team_yellow_cards) AS triggered_team_yellow_cards,
    toInt32(o.opponent_yellow_cards) AS opponent_yellow_cards,
    toInt32(o.triggered_team_yellow_cards - o.opponent_yellow_cards) AS yellow_cards_delta,
    toInt32(o.triggered_team_red_cards) AS triggered_team_red_cards,
    toInt32(o.opponent_red_cards) AS opponent_red_cards,
    toInt32(o.triggered_team_red_cards - o.opponent_red_cards) AS red_cards_delta,
    toNullable(toFloat32(round(
        100.0 * o.triggered_team_total_cards / nullIf(toFloat64(o.triggered_team_fouls_committed), 0),
        2
    ))) AS triggered_team_cards_per_foul_pct,
    toNullable(toFloat32(round(
        100.0 * o.opponent_total_cards / nullIf(toFloat64(o.opponent_fouls_committed), 0),
        2
    ))) AS opponent_cards_per_foul_pct,
    toNullable(toFloat32(round(
        (
            100.0 * o.triggered_team_total_cards / nullIf(toFloat64(o.triggered_team_fouls_committed), 0)
        ) - (
            100.0 * o.opponent_total_cards / nullIf(toFloat64(o.opponent_fouls_committed), 0)
        ),
        2
    ))) AS cards_per_foul_delta_pct,
    toInt32(o.triggered_team_duels_won) AS triggered_team_duels_won,
    toInt32(o.opponent_duels_won) AS opponent_duels_won,
    toInt32(o.triggered_team_tackles_won) AS triggered_team_tackles_won,
    toInt32(o.opponent_tackles_won) AS opponent_tackles_won,
    toInt32(o.triggered_team_interceptions) AS triggered_team_interceptions,
    toInt32(o.opponent_interceptions) AS opponent_interceptions,
    toInt32(o.triggered_team_clearances) AS triggered_team_clearances,
    toInt32(o.opponent_clearances) AS opponent_clearances,
    toFloat32(coalesce(round(
        100.0 * o.triggered_team_accurate_passes / nullIf(toFloat64(o.triggered_team_pass_attempts), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * o.opponent_accurate_passes / nullIf(toFloat64(o.opponent_pass_attempts), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * o.triggered_team_accurate_passes / nullIf(toFloat64(o.triggered_team_pass_attempts), 0),
            1
        ), 0.0) - coalesce(round(
            100.0 * o.opponent_accurate_passes / nullIf(toFloat64(o.opponent_pass_attempts), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,
    toFloat32(o.triggered_team_possession_pct) AS triggered_team_possession_pct,
    toFloat32(o.opponent_possession_pct) AS opponent_possession_pct,
    toFloat32(round(o.triggered_team_possession_pct - o.opponent_possession_pct, 1)) AS possession_delta_pct
FROM oriented AS o
WHERE o.opponent_fouls_committed > 0
  AND o.triggered_team_fouls_committed >= (3 * o.opponent_fouls_committed)
  AND o.triggered_team_total_cards < o.opponent_total_cards
ORDER BY
    triggered_team_fouls_multiplier DESC,
    card_count_delta ASC,
    o.match_date DESC,
    o.match_id DESC;
