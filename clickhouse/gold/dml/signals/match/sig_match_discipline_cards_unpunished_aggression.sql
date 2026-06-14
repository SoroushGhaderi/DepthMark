INSERT INTO gold.sig_match_discipline_cards_unpunished_aggression (
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
    trigger_threshold_min_match_total_xg,
    trigger_threshold_min_combined_fouls,
    match_total_xg,
    match_total_xg_above_threshold,
    match_total_fouls_committed,
    match_total_fouls_above_threshold,
    match_total_cards,
    match_total_yellow_cards,
    match_total_red_cards,
    match_total_cards_per_foul_pct,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_fouls_committed,
    opponent_fouls_committed,
    fouls_committed_delta,
    triggered_team_fouls_share_pct,
    opponent_fouls_share_pct,
    fouls_share_delta_pct,
    triggered_team_total_cards,
    opponent_total_cards,
    card_count_delta,
    triggered_team_cards_per_foul_pct,
    opponent_cards_per_foul_pct,
    cards_per_foul_delta_pct,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
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
-- Signal: sig_match_discipline_cards_unpunished_aggression
-- Intent: Detect open matches with high chance quality and high foul pressure, where physicality coexists with attacking volume.
-- Trigger: combined match xG >= 3.0 AND combined match fouls (home + away) >= 28 at period='All'.
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
        toFloat32(coalesce(ps.expected_goals_home, 0)) AS expected_goals_home,
        toFloat32(coalesce(ps.expected_goals_away, 0)) AS expected_goals_away,
        coalesce(ps.fouls_home, 0) AS fouls_home,
        coalesce(ps.fouls_away, 0) AS fouls_away,
        coalesce(ps.yellow_cards_home, 0) AS yellow_cards_home,
        coalesce(ps.yellow_cards_away, 0) AS yellow_cards_away,
        coalesce(ps.red_cards_home, 0) AS red_cards_home,
        coalesce(ps.red_cards_away, 0) AS red_cards_away,
        coalesce(ps.total_shots_home, 0) AS total_shots_home,
        coalesce(ps.total_shots_away, 0) AS total_shots_away,
        coalesce(ps.shots_on_target_home, 0) AS shots_on_target_home,
        coalesce(ps.shots_on_target_away, 0) AS shots_on_target_away,
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
        toFloat32(round(
            coalesce(ps.expected_goals_home, 0) + coalesce(ps.expected_goals_away, 0),
            3
        )) AS match_total_xg,
        coalesce(ps.fouls_home, 0) + coalesce(ps.fouls_away, 0) AS match_total_fouls_committed,
        coalesce(ps.yellow_cards_home, 0) + coalesce(ps.yellow_cards_away, 0) AS match_total_yellow_cards,
        coalesce(ps.red_cards_home, 0) + coalesce(ps.red_cards_away, 0) AS match_total_red_cards
    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.period = 'All'
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND (coalesce(ps.expected_goals_home, 0) + coalesce(ps.expected_goals_away, 0)) >= 3.0
      AND (coalesce(ps.fouls_home, 0) + coalesce(ps.fouls_away, 0)) >= 28
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
    toFloat32(3.0) AS trigger_threshold_min_match_total_xg,
    toInt32(28) AS trigger_threshold_min_combined_fouls,
    b.match_total_xg AS match_total_xg,
    toFloat32(round(b.match_total_xg - 3.0, 3)) AS match_total_xg_above_threshold,
    toInt32(b.match_total_fouls_committed) AS match_total_fouls_committed,
    toInt32(b.match_total_fouls_committed - 28) AS match_total_fouls_above_threshold,
    toInt32(b.match_total_yellow_cards + b.match_total_red_cards) AS match_total_cards,
    toInt32(b.match_total_yellow_cards) AS match_total_yellow_cards,
    toInt32(b.match_total_red_cards) AS match_total_red_cards,
    toNullable(toFloat32(round(
        100.0 * (b.match_total_yellow_cards + b.match_total_red_cards)
        / nullIf(toFloat64(b.match_total_fouls_committed), 0),
        1
    ))) AS match_total_cards_per_foul_pct,
    b.expected_goals_home AS triggered_team_xg,
    b.expected_goals_away AS opponent_xg,
    toFloat32(round(b.expected_goals_home - b.expected_goals_away, 3)) AS xg_delta,
    toInt32(b.fouls_home) AS triggered_team_fouls_committed,
    toInt32(b.fouls_away) AS opponent_fouls_committed,
    toInt32(b.fouls_home - b.fouls_away) AS fouls_committed_delta,
    toFloat32(round(
        100.0 * b.fouls_home / nullIf(toFloat64(b.match_total_fouls_committed), 0),
        1
    )) AS triggered_team_fouls_share_pct,
    toFloat32(round(
        100.0 * b.fouls_away / nullIf(toFloat64(b.match_total_fouls_committed), 0),
        1
    )) AS opponent_fouls_share_pct,
    toFloat32(round(
        (
            100.0 * b.fouls_home / nullIf(toFloat64(b.match_total_fouls_committed), 0)
        ) - (
            100.0 * b.fouls_away / nullIf(toFloat64(b.match_total_fouls_committed), 0)
        ),
        1
    )) AS fouls_share_delta_pct,
    toInt32(b.yellow_cards_home + b.red_cards_home) AS triggered_team_total_cards,
    toInt32(b.yellow_cards_away + b.red_cards_away) AS opponent_total_cards,
    toInt32(
        (b.yellow_cards_home + b.red_cards_home) - (b.yellow_cards_away + b.red_cards_away)
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
    toInt32(b.total_shots_home) AS triggered_team_total_shots,
    toInt32(b.total_shots_away) AS opponent_total_shots,
    toInt32(b.shots_on_target_home) AS triggered_team_shots_on_target,
    toInt32(b.shots_on_target_away) AS opponent_shots_on_target,
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
    toFloat32(3.0) AS trigger_threshold_min_match_total_xg,
    toInt32(28) AS trigger_threshold_min_combined_fouls,
    b.match_total_xg AS match_total_xg,
    toFloat32(round(b.match_total_xg - 3.0, 3)) AS match_total_xg_above_threshold,
    toInt32(b.match_total_fouls_committed) AS match_total_fouls_committed,
    toInt32(b.match_total_fouls_committed - 28) AS match_total_fouls_above_threshold,
    toInt32(b.match_total_yellow_cards + b.match_total_red_cards) AS match_total_cards,
    toInt32(b.match_total_yellow_cards) AS match_total_yellow_cards,
    toInt32(b.match_total_red_cards) AS match_total_red_cards,
    toNullable(toFloat32(round(
        100.0 * (b.match_total_yellow_cards + b.match_total_red_cards)
        / nullIf(toFloat64(b.match_total_fouls_committed), 0),
        1
    ))) AS match_total_cards_per_foul_pct,
    b.expected_goals_away AS triggered_team_xg,
    b.expected_goals_home AS opponent_xg,
    toFloat32(round(b.expected_goals_away - b.expected_goals_home, 3)) AS xg_delta,
    toInt32(b.fouls_away) AS triggered_team_fouls_committed,
    toInt32(b.fouls_home) AS opponent_fouls_committed,
    toInt32(b.fouls_away - b.fouls_home) AS fouls_committed_delta,
    toFloat32(round(
        100.0 * b.fouls_away / nullIf(toFloat64(b.match_total_fouls_committed), 0),
        1
    )) AS triggered_team_fouls_share_pct,
    toFloat32(round(
        100.0 * b.fouls_home / nullIf(toFloat64(b.match_total_fouls_committed), 0),
        1
    )) AS opponent_fouls_share_pct,
    toFloat32(round(
        (
            100.0 * b.fouls_away / nullIf(toFloat64(b.match_total_fouls_committed), 0)
        ) - (
            100.0 * b.fouls_home / nullIf(toFloat64(b.match_total_fouls_committed), 0)
        ),
        1
    )) AS fouls_share_delta_pct,
    toInt32(b.yellow_cards_away + b.red_cards_away) AS triggered_team_total_cards,
    toInt32(b.yellow_cards_home + b.red_cards_home) AS opponent_total_cards,
    toInt32(
        (b.yellow_cards_away + b.red_cards_away) - (b.yellow_cards_home + b.red_cards_home)
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
    toInt32(b.total_shots_away) AS triggered_team_total_shots,
    toInt32(b.total_shots_home) AS opponent_total_shots,
    toInt32(b.shots_on_target_away) AS triggered_team_shots_on_target,
    toInt32(b.shots_on_target_home) AS opponent_shots_on_target,
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
