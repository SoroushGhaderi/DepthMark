INSERT INTO gold.sig_match_goalkeeping_defense_coordinated_trap_match (
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
    trigger_threshold_min_combined_offsides,
    match_total_offsides,
    match_total_offsides_above_threshold,
    match_offside_balance_abs,
    triggered_team_offsides_committed,
    opponent_offsides_committed,
    offsides_committed_delta,
    triggered_team_offsides_share_pct,
    opponent_offsides_share_pct,
    offsides_share_delta_pct,
    triggered_team_offsides_caught,
    opponent_offsides_caught,
    offsides_caught_delta,
    triggered_team_total_shots_faced,
    opponent_total_shots_faced,
    total_shots_faced_delta,
    triggered_team_shots_on_target_faced,
    opponent_shots_on_target_faced,
    shots_on_target_faced_delta,
    triggered_team_keeper_saves,
    opponent_keeper_saves,
    keeper_saves_delta,
    triggered_team_clearances,
    opponent_clearances,
    clearances_delta,
    triggered_team_interceptions,
    opponent_interceptions,
    interceptions_delta,
    triggered_team_tackles_won,
    opponent_tackles_won,
    tackles_won_delta,
    triggered_team_duels_won,
    opponent_duels_won,
    duels_won_delta,
    triggered_team_aerials_won,
    opponent_aerials_won,
    aerials_won_delta,
    triggered_team_fouls_committed,
    opponent_fouls_committed,
    fouls_committed_delta,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_clean_sheet_flag
)
-- Signal: sig_match_goalkeeping_defense_coordinated_trap_match
-- Intent: detect finished matches with extreme combined offside volume and preserve bilateral
--         side-oriented defensive/control context for tactical interpretation.
-- Trigger: combined match offsides (home + away) >= 12 at period='All'.
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
        coalesce(ps.offsides_home, 0) AS offsides_home,
        coalesce(ps.offsides_away, 0) AS offsides_away,
        coalesce(ps.total_shots_home, 0) AS total_shots_home,
        coalesce(ps.total_shots_away, 0) AS total_shots_away,
        coalesce(ps.shots_on_target_home, 0) AS shots_on_target_home,
        coalesce(ps.shots_on_target_away, 0) AS shots_on_target_away,
        coalesce(ps.keeper_saves_home, 0) AS keeper_saves_home,
        coalesce(ps.keeper_saves_away, 0) AS keeper_saves_away,
        coalesce(ps.clearances_home, 0) AS clearances_home,
        coalesce(ps.clearances_away, 0) AS clearances_away,
        coalesce(ps.interceptions_home, 0) AS interceptions_home,
        coalesce(ps.interceptions_away, 0) AS interceptions_away,
        coalesce(ps.tackles_succeeded_home, 0) AS tackles_won_home,
        coalesce(ps.tackles_succeeded_away, 0) AS tackles_won_away,
        coalesce(ps.duels_won_home, 0) AS duels_won_home,
        coalesce(ps.duels_won_away, 0) AS duels_won_away,
        coalesce(ps.aerials_won_home, 0) AS aerials_won_home,
        coalesce(ps.aerials_won_away, 0) AS aerials_won_away,
        coalesce(ps.fouls_home, 0) AS fouls_home,
        coalesce(ps.fouls_away, 0) AS fouls_away,
        toFloat32(coalesce(ps.ball_possession_home, 0)) AS possession_home_pct,
        toFloat32(coalesce(ps.ball_possession_away, 0)) AS possession_away_pct,
        toFloat32(coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0)
            / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
            1
        ), 0.0)) AS pass_accuracy_home_pct,
        toFloat32(coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0)
            / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
            1
        ), 0.0)) AS pass_accuracy_away_pct,
        coalesce(ps.offsides_home, 0) + coalesce(ps.offsides_away, 0) AS match_total_offsides
    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.match_date = m.match_date
       AND ps.period = 'All'
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND coalesce(ps.offsides_home, 0) + coalesce(ps.offsides_away, 0) >= 12
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
    toInt32(12) AS trigger_threshold_min_combined_offsides,
    toInt32(b.match_total_offsides) AS match_total_offsides,
    toInt32(b.match_total_offsides - 12) AS match_total_offsides_above_threshold,
    toInt32(abs(b.offsides_home - b.offsides_away)) AS match_offside_balance_abs,
    toInt32(b.offsides_home) AS triggered_team_offsides_committed,
    toInt32(b.offsides_away) AS opponent_offsides_committed,
    toInt32(b.offsides_home - b.offsides_away) AS offsides_committed_delta,
    toFloat32(round(
        100.0 * b.offsides_home / nullIf(toFloat64(b.match_total_offsides), 0),
        1
    )) AS triggered_team_offsides_share_pct,
    toFloat32(round(
        100.0 * b.offsides_away / nullIf(toFloat64(b.match_total_offsides), 0),
        1
    )) AS opponent_offsides_share_pct,
    toFloat32(round(
        (
            100.0 * b.offsides_home / nullIf(toFloat64(b.match_total_offsides), 0)
        ) - (
            100.0 * b.offsides_away / nullIf(toFloat64(b.match_total_offsides), 0)
        ),
        1
    )) AS offsides_share_delta_pct,
    toInt32(b.offsides_away) AS triggered_team_offsides_caught,
    toInt32(b.offsides_home) AS opponent_offsides_caught,
    toInt32(b.offsides_away - b.offsides_home) AS offsides_caught_delta,
    toInt32(b.total_shots_away) AS triggered_team_total_shots_faced,
    toInt32(b.total_shots_home) AS opponent_total_shots_faced,
    toInt32(b.total_shots_away - b.total_shots_home) AS total_shots_faced_delta,
    toInt32(b.shots_on_target_away) AS triggered_team_shots_on_target_faced,
    toInt32(b.shots_on_target_home) AS opponent_shots_on_target_faced,
    toInt32(b.shots_on_target_away - b.shots_on_target_home) AS shots_on_target_faced_delta,
    toInt32(b.keeper_saves_home) AS triggered_team_keeper_saves,
    toInt32(b.keeper_saves_away) AS opponent_keeper_saves,
    toInt32(b.keeper_saves_home - b.keeper_saves_away) AS keeper_saves_delta,
    toInt32(b.clearances_home) AS triggered_team_clearances,
    toInt32(b.clearances_away) AS opponent_clearances,
    toInt32(b.clearances_home - b.clearances_away) AS clearances_delta,
    toInt32(b.interceptions_home) AS triggered_team_interceptions,
    toInt32(b.interceptions_away) AS opponent_interceptions,
    toInt32(b.interceptions_home - b.interceptions_away) AS interceptions_delta,
    toInt32(b.tackles_won_home) AS triggered_team_tackles_won,
    toInt32(b.tackles_won_away) AS opponent_tackles_won,
    toInt32(b.tackles_won_home - b.tackles_won_away) AS tackles_won_delta,
    toInt32(b.duels_won_home) AS triggered_team_duels_won,
    toInt32(b.duels_won_away) AS opponent_duels_won,
    toInt32(b.duels_won_home - b.duels_won_away) AS duels_won_delta,
    toInt32(b.aerials_won_home) AS triggered_team_aerials_won,
    toInt32(b.aerials_won_away) AS opponent_aerials_won,
    toInt32(b.aerials_won_home - b.aerials_won_away) AS aerials_won_delta,
    toInt32(b.fouls_home) AS triggered_team_fouls_committed,
    toInt32(b.fouls_away) AS opponent_fouls_committed,
    toInt32(b.fouls_home - b.fouls_away) AS fouls_committed_delta,
    b.possession_home_pct AS triggered_team_possession_pct,
    b.possession_away_pct AS opponent_possession_pct,
    toFloat32(round(b.possession_home_pct - b.possession_away_pct, 1)) AS possession_delta_pct,
    b.pass_accuracy_home_pct AS triggered_team_pass_accuracy_pct,
    b.pass_accuracy_away_pct AS opponent_pass_accuracy_pct,
    toFloat32(round(b.pass_accuracy_home_pct - b.pass_accuracy_away_pct, 1))
        AS pass_accuracy_delta_pct,
    toInt32(coalesce(b.home_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(b.away_score, 0)) AS opponent_goals,
    toInt32(coalesce(b.home_score, 0) - coalesce(b.away_score, 0)) AS goal_delta,
    toInt8(if(coalesce(b.away_score, 0) = 0, 1, 0)) AS triggered_team_clean_sheet_flag
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
    toInt32(12) AS trigger_threshold_min_combined_offsides,
    toInt32(b.match_total_offsides) AS match_total_offsides,
    toInt32(b.match_total_offsides - 12) AS match_total_offsides_above_threshold,
    toInt32(abs(b.offsides_home - b.offsides_away)) AS match_offside_balance_abs,
    toInt32(b.offsides_away) AS triggered_team_offsides_committed,
    toInt32(b.offsides_home) AS opponent_offsides_committed,
    toInt32(b.offsides_away - b.offsides_home) AS offsides_committed_delta,
    toFloat32(round(
        100.0 * b.offsides_away / nullIf(toFloat64(b.match_total_offsides), 0),
        1
    )) AS triggered_team_offsides_share_pct,
    toFloat32(round(
        100.0 * b.offsides_home / nullIf(toFloat64(b.match_total_offsides), 0),
        1
    )) AS opponent_offsides_share_pct,
    toFloat32(round(
        (
            100.0 * b.offsides_away / nullIf(toFloat64(b.match_total_offsides), 0)
        ) - (
            100.0 * b.offsides_home / nullIf(toFloat64(b.match_total_offsides), 0)
        ),
        1
    )) AS offsides_share_delta_pct,
    toInt32(b.offsides_home) AS triggered_team_offsides_caught,
    toInt32(b.offsides_away) AS opponent_offsides_caught,
    toInt32(b.offsides_home - b.offsides_away) AS offsides_caught_delta,
    toInt32(b.total_shots_home) AS triggered_team_total_shots_faced,
    toInt32(b.total_shots_away) AS opponent_total_shots_faced,
    toInt32(b.total_shots_home - b.total_shots_away) AS total_shots_faced_delta,
    toInt32(b.shots_on_target_home) AS triggered_team_shots_on_target_faced,
    toInt32(b.shots_on_target_away) AS opponent_shots_on_target_faced,
    toInt32(b.shots_on_target_home - b.shots_on_target_away) AS shots_on_target_faced_delta,
    toInt32(b.keeper_saves_away) AS triggered_team_keeper_saves,
    toInt32(b.keeper_saves_home) AS opponent_keeper_saves,
    toInt32(b.keeper_saves_away - b.keeper_saves_home) AS keeper_saves_delta,
    toInt32(b.clearances_away) AS triggered_team_clearances,
    toInt32(b.clearances_home) AS opponent_clearances,
    toInt32(b.clearances_away - b.clearances_home) AS clearances_delta,
    toInt32(b.interceptions_away) AS triggered_team_interceptions,
    toInt32(b.interceptions_home) AS opponent_interceptions,
    toInt32(b.interceptions_away - b.interceptions_home) AS interceptions_delta,
    toInt32(b.tackles_won_away) AS triggered_team_tackles_won,
    toInt32(b.tackles_won_home) AS opponent_tackles_won,
    toInt32(b.tackles_won_away - b.tackles_won_home) AS tackles_won_delta,
    toInt32(b.duels_won_away) AS triggered_team_duels_won,
    toInt32(b.duels_won_home) AS opponent_duels_won,
    toInt32(b.duels_won_away - b.duels_won_home) AS duels_won_delta,
    toInt32(b.aerials_won_away) AS triggered_team_aerials_won,
    toInt32(b.aerials_won_home) AS opponent_aerials_won,
    toInt32(b.aerials_won_away - b.aerials_won_home) AS aerials_won_delta,
    toInt32(b.fouls_away) AS triggered_team_fouls_committed,
    toInt32(b.fouls_home) AS opponent_fouls_committed,
    toInt32(b.fouls_away - b.fouls_home) AS fouls_committed_delta,
    b.possession_away_pct AS triggered_team_possession_pct,
    b.possession_home_pct AS opponent_possession_pct,
    toFloat32(round(b.possession_away_pct - b.possession_home_pct, 1)) AS possession_delta_pct,
    b.pass_accuracy_away_pct AS triggered_team_pass_accuracy_pct,
    b.pass_accuracy_home_pct AS opponent_pass_accuracy_pct,
    toFloat32(round(b.pass_accuracy_away_pct - b.pass_accuracy_home_pct, 1))
        AS pass_accuracy_delta_pct,
    toInt32(coalesce(b.away_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(b.home_score, 0)) AS opponent_goals,
    toInt32(coalesce(b.away_score, 0) - coalesce(b.home_score, 0)) AS goal_delta,
    toInt8(if(coalesce(b.home_score, 0) = 0, 1, 0)) AS triggered_team_clean_sheet_flag
FROM base_stats AS b

ORDER BY
    match_total_offsides DESC,
    match_offside_balance_abs ASC,
    match_date DESC,
    match_id DESC,
    triggered_side;
