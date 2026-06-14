INSERT INTO gold.sig_match_goalkeeping_defense_physical_duels_peak (
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
    trigger_threshold_min_combined_total_duels_won,
    match_total_combined_duels_won,
    match_total_combined_duels_won_above_threshold,
    match_total_ground_duels_won,
    match_total_aerial_duels_won,
    match_physical_duels_balance_abs,
    triggered_team_combined_duels_won,
    opponent_combined_duels_won,
    combined_duels_won_delta,
    triggered_team_combined_duels_won_share_pct,
    opponent_combined_duels_won_share_pct,
    combined_duels_won_share_delta_pct,
    triggered_team_ground_duels_won,
    opponent_ground_duels_won,
    ground_duels_won_delta,
    triggered_team_aerial_duels_won,
    opponent_aerial_duels_won,
    aerial_duels_won_delta,
    triggered_team_tackles_won,
    opponent_tackles_won,
    tackles_won_delta,
    triggered_team_interceptions,
    opponent_interceptions,
    interceptions_delta,
    triggered_team_clearances,
    opponent_clearances,
    clearances_delta,
    triggered_team_total_shots_faced,
    opponent_total_shots_faced,
    total_shots_faced_delta,
    triggered_team_shots_on_target_faced,
    opponent_shots_on_target_faced,
    shots_on_target_faced_delta,
    triggered_team_keeper_saves,
    opponent_keeper_saves,
    keeper_saves_delta,
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
-- Signal: sig_match_goalkeeping_defense_physical_duels_peak
-- Intent: detect finished matches with extreme combined physical-duel volume (ground + aerial)
--         while preserving bilateral side-oriented defensive workload and control context.
-- Trigger: combined total duels won (ground + aerial, home + away) > 200 at period='All'.
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
        coalesce(ps.duels_won_home, 0) AS ground_duels_won_home,
        coalesce(ps.duels_won_away, 0) AS ground_duels_won_away,
        coalesce(ps.aerials_won_home, 0) AS aerial_duels_won_home,
        coalesce(ps.aerials_won_away, 0) AS aerial_duels_won_away,
        coalesce(ps.tackles_succeeded_home, 0) AS tackles_won_home,
        coalesce(ps.tackles_succeeded_away, 0) AS tackles_won_away,
        coalesce(ps.interceptions_home, 0) AS interceptions_home,
        coalesce(ps.interceptions_away, 0) AS interceptions_away,
        coalesce(ps.clearances_home, 0) AS clearances_home,
        coalesce(ps.clearances_away, 0) AS clearances_away,
        coalesce(ps.total_shots_home, 0) AS total_shots_home,
        coalesce(ps.total_shots_away, 0) AS total_shots_away,
        coalesce(ps.shots_on_target_home, 0) AS shots_on_target_home,
        coalesce(ps.shots_on_target_away, 0) AS shots_on_target_away,
        coalesce(ps.keeper_saves_home, 0) AS keeper_saves_home,
        coalesce(ps.keeper_saves_away, 0) AS keeper_saves_away,
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
        coalesce(ps.duels_won_home, 0) + coalesce(ps.duels_won_away, 0) AS match_total_ground_duels_won,
        coalesce(ps.aerials_won_home, 0) + coalesce(ps.aerials_won_away, 0) AS match_total_aerial_duels_won,
        coalesce(ps.duels_won_home, 0) + coalesce(ps.duels_won_away, 0)
            + coalesce(ps.aerials_won_home, 0) + coalesce(ps.aerials_won_away, 0)
            AS match_total_combined_duels_won,
        coalesce(ps.duels_won_home, 0) + coalesce(ps.aerials_won_home, 0)
            AS combined_duels_won_home,
        coalesce(ps.duels_won_away, 0) + coalesce(ps.aerials_won_away, 0)
            AS combined_duels_won_away
    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.match_date = m.match_date
       AND ps.period = 'All'
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND (
          coalesce(ps.duels_won_home, 0) + coalesce(ps.duels_won_away, 0)
          + coalesce(ps.aerials_won_home, 0) + coalesce(ps.aerials_won_away, 0)
      ) > 200
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
    toInt32(200) AS trigger_threshold_min_combined_total_duels_won,
    toInt32(b.match_total_combined_duels_won) AS match_total_combined_duels_won,
    toInt32(b.match_total_combined_duels_won - 200) AS match_total_combined_duels_won_above_threshold,
    toInt32(b.match_total_ground_duels_won) AS match_total_ground_duels_won,
    toInt32(b.match_total_aerial_duels_won) AS match_total_aerial_duels_won,
    toInt32(abs(b.combined_duels_won_home - b.combined_duels_won_away))
        AS match_physical_duels_balance_abs,
    toInt32(b.combined_duels_won_home) AS triggered_team_combined_duels_won,
    toInt32(b.combined_duels_won_away) AS opponent_combined_duels_won,
    toInt32(b.combined_duels_won_home - b.combined_duels_won_away) AS combined_duels_won_delta,
    toFloat32(round(
        100.0 * b.combined_duels_won_home / nullIf(toFloat64(b.match_total_combined_duels_won), 0),
        1
    )) AS triggered_team_combined_duels_won_share_pct,
    toFloat32(round(
        100.0 * b.combined_duels_won_away / nullIf(toFloat64(b.match_total_combined_duels_won), 0),
        1
    )) AS opponent_combined_duels_won_share_pct,
    toFloat32(round(
        (
            100.0 * b.combined_duels_won_home / nullIf(toFloat64(b.match_total_combined_duels_won), 0)
        ) - (
            100.0 * b.combined_duels_won_away / nullIf(toFloat64(b.match_total_combined_duels_won), 0)
        ),
        1
    )) AS combined_duels_won_share_delta_pct,
    toInt32(b.ground_duels_won_home) AS triggered_team_ground_duels_won,
    toInt32(b.ground_duels_won_away) AS opponent_ground_duels_won,
    toInt32(b.ground_duels_won_home - b.ground_duels_won_away) AS ground_duels_won_delta,
    toInt32(b.aerial_duels_won_home) AS triggered_team_aerial_duels_won,
    toInt32(b.aerial_duels_won_away) AS opponent_aerial_duels_won,
    toInt32(b.aerial_duels_won_home - b.aerial_duels_won_away) AS aerial_duels_won_delta,
    toInt32(b.tackles_won_home) AS triggered_team_tackles_won,
    toInt32(b.tackles_won_away) AS opponent_tackles_won,
    toInt32(b.tackles_won_home - b.tackles_won_away) AS tackles_won_delta,
    toInt32(b.interceptions_home) AS triggered_team_interceptions,
    toInt32(b.interceptions_away) AS opponent_interceptions,
    toInt32(b.interceptions_home - b.interceptions_away) AS interceptions_delta,
    toInt32(b.clearances_home) AS triggered_team_clearances,
    toInt32(b.clearances_away) AS opponent_clearances,
    toInt32(b.clearances_home - b.clearances_away) AS clearances_delta,
    toInt32(b.total_shots_away) AS triggered_team_total_shots_faced,
    toInt32(b.total_shots_home) AS opponent_total_shots_faced,
    toInt32(b.total_shots_away - b.total_shots_home) AS total_shots_faced_delta,
    toInt32(b.shots_on_target_away) AS triggered_team_shots_on_target_faced,
    toInt32(b.shots_on_target_home) AS opponent_shots_on_target_faced,
    toInt32(b.shots_on_target_away - b.shots_on_target_home) AS shots_on_target_faced_delta,
    toInt32(b.keeper_saves_home) AS triggered_team_keeper_saves,
    toInt32(b.keeper_saves_away) AS opponent_keeper_saves,
    toInt32(b.keeper_saves_home - b.keeper_saves_away) AS keeper_saves_delta,
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
    toInt32(200) AS trigger_threshold_min_combined_total_duels_won,
    toInt32(b.match_total_combined_duels_won) AS match_total_combined_duels_won,
    toInt32(b.match_total_combined_duels_won - 200) AS match_total_combined_duels_won_above_threshold,
    toInt32(b.match_total_ground_duels_won) AS match_total_ground_duels_won,
    toInt32(b.match_total_aerial_duels_won) AS match_total_aerial_duels_won,
    toInt32(abs(b.combined_duels_won_home - b.combined_duels_won_away))
        AS match_physical_duels_balance_abs,
    toInt32(b.combined_duels_won_away) AS triggered_team_combined_duels_won,
    toInt32(b.combined_duels_won_home) AS opponent_combined_duels_won,
    toInt32(b.combined_duels_won_away - b.combined_duels_won_home) AS combined_duels_won_delta,
    toFloat32(round(
        100.0 * b.combined_duels_won_away / nullIf(toFloat64(b.match_total_combined_duels_won), 0),
        1
    )) AS triggered_team_combined_duels_won_share_pct,
    toFloat32(round(
        100.0 * b.combined_duels_won_home / nullIf(toFloat64(b.match_total_combined_duels_won), 0),
        1
    )) AS opponent_combined_duels_won_share_pct,
    toFloat32(round(
        (
            100.0 * b.combined_duels_won_away / nullIf(toFloat64(b.match_total_combined_duels_won), 0)
        ) - (
            100.0 * b.combined_duels_won_home / nullIf(toFloat64(b.match_total_combined_duels_won), 0)
        ),
        1
    )) AS combined_duels_won_share_delta_pct,
    toInt32(b.ground_duels_won_away) AS triggered_team_ground_duels_won,
    toInt32(b.ground_duels_won_home) AS opponent_ground_duels_won,
    toInt32(b.ground_duels_won_away - b.ground_duels_won_home) AS ground_duels_won_delta,
    toInt32(b.aerial_duels_won_away) AS triggered_team_aerial_duels_won,
    toInt32(b.aerial_duels_won_home) AS opponent_aerial_duels_won,
    toInt32(b.aerial_duels_won_away - b.aerial_duels_won_home) AS aerial_duels_won_delta,
    toInt32(b.tackles_won_away) AS triggered_team_tackles_won,
    toInt32(b.tackles_won_home) AS opponent_tackles_won,
    toInt32(b.tackles_won_away - b.tackles_won_home) AS tackles_won_delta,
    toInt32(b.interceptions_away) AS triggered_team_interceptions,
    toInt32(b.interceptions_home) AS opponent_interceptions,
    toInt32(b.interceptions_away - b.interceptions_home) AS interceptions_delta,
    toInt32(b.clearances_away) AS triggered_team_clearances,
    toInt32(b.clearances_home) AS opponent_clearances,
    toInt32(b.clearances_away - b.clearances_home) AS clearances_delta,
    toInt32(b.total_shots_home) AS triggered_team_total_shots_faced,
    toInt32(b.total_shots_away) AS opponent_total_shots_faced,
    toInt32(b.total_shots_home - b.total_shots_away) AS total_shots_faced_delta,
    toInt32(b.shots_on_target_home) AS triggered_team_shots_on_target_faced,
    toInt32(b.shots_on_target_away) AS opponent_shots_on_target_faced,
    toInt32(b.shots_on_target_home - b.shots_on_target_away) AS shots_on_target_faced_delta,
    toInt32(b.keeper_saves_away) AS triggered_team_keeper_saves,
    toInt32(b.keeper_saves_home) AS opponent_keeper_saves,
    toInt32(b.keeper_saves_away - b.keeper_saves_home) AS keeper_saves_delta,
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
FROM base_stats AS b;
