INSERT INTO gold.sig_team_goalkeeping_defense_wide_blockade (
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
    trigger_threshold_max_successful_crosses_allowed,
    trigger_threshold_min_cross_attempts_allowed,
    triggered_team_cross_attempts_allowed,
    opponent_cross_attempts_allowed,
    cross_attempts_allowed_delta,
    triggered_team_successful_crosses_allowed,
    opponent_successful_crosses_allowed,
    successful_crosses_allowed_delta,
    triggered_team_crosses_prevented,
    opponent_crosses_prevented,
    crosses_prevented_delta,
    triggered_team_successful_crosses_allowed_below_threshold,
    triggered_team_cross_attempts_allowed_above_threshold,
    triggered_team_successful_crosses_allowed_pct,
    opponent_successful_crosses_allowed_pct,
    successful_crosses_allowed_pct_delta,
    triggered_team_total_shots_faced,
    opponent_total_shots_faced,
    total_shots_faced_delta,
    triggered_team_shots_on_target_faced,
    opponent_shots_on_target_faced,
    shots_on_target_faced_delta,
    triggered_team_keeper_saves,
    opponent_keeper_saves,
    keeper_saves_delta,
    triggered_team_expected_goals_faced,
    opponent_expected_goals_faced,
    expected_goals_faced_delta,
    triggered_team_clearances,
    opponent_clearances,
    clearances_delta,
    triggered_team_interceptions,
    opponent_interceptions,
    interceptions_delta,
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
-- Signal: sig_team_goalkeeping_defense_wide_blockade
-- Intent: detect teams that strongly suppress opponent cross completion despite high crossing volume faced.
-- Trigger: team allows at most 2 successful crosses while facing at least 20 cross attempts in a finished match.

-- Home-side trigger.
SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    'home' AS triggered_side,
    m.home_team_id AS triggered_team_id,
    m.home_team_name AS triggered_team_name,
    m.away_team_id AS opponent_team_id,
    m.away_team_name AS opponent_team_name,

    toInt32(2) AS trigger_threshold_max_successful_crosses_allowed,
    toInt32(20) AS trigger_threshold_min_cross_attempts_allowed,
    toInt32(coalesce(ps.cross_attempts_away, 0)) AS triggered_team_cross_attempts_allowed,
    toInt32(coalesce(ps.cross_attempts_home, 0)) AS opponent_cross_attempts_allowed,
    toInt32(coalesce(ps.cross_attempts_away, 0) - coalesce(ps.cross_attempts_home, 0))
        AS cross_attempts_allowed_delta,
    toInt32(coalesce(ps.accurate_crosses_away, 0)) AS triggered_team_successful_crosses_allowed,
    toInt32(coalesce(ps.accurate_crosses_home, 0)) AS opponent_successful_crosses_allowed,
    toInt32(coalesce(ps.accurate_crosses_away, 0) - coalesce(ps.accurate_crosses_home, 0))
        AS successful_crosses_allowed_delta,
    toInt32(coalesce(ps.cross_attempts_away, 0) - coalesce(ps.accurate_crosses_away, 0))
        AS triggered_team_crosses_prevented,
    toInt32(coalesce(ps.cross_attempts_home, 0) - coalesce(ps.accurate_crosses_home, 0))
        AS opponent_crosses_prevented,
    toInt32(
        (coalesce(ps.cross_attempts_away, 0) - coalesce(ps.accurate_crosses_away, 0))
      - (coalesce(ps.cross_attempts_home, 0) - coalesce(ps.accurate_crosses_home, 0))
    ) AS crosses_prevented_delta,
    toInt32(2 - coalesce(ps.accurate_crosses_away, 0))
        AS triggered_team_successful_crosses_allowed_below_threshold,
    toInt32(coalesce(ps.cross_attempts_away, 0) - 20)
        AS triggered_team_cross_attempts_allowed_above_threshold,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_crosses_away, 0)
        / nullIf(toFloat64(coalesce(ps.cross_attempts_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_successful_crosses_allowed_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_crosses_home, 0)
        / nullIf(toFloat64(coalesce(ps.cross_attempts_home, 0)), 0),
        1
    ), 0.0)) AS opponent_successful_crosses_allowed_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_crosses_away, 0)
            / nullIf(toFloat64(coalesce(ps.cross_attempts_away, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_crosses_home, 0)
            / nullIf(toFloat64(coalesce(ps.cross_attempts_home, 0)), 0),
            1
        ), 0.0),
        1
    )) AS successful_crosses_allowed_pct_delta,

    toInt32(coalesce(ps.total_shots_away, 0)) AS triggered_team_total_shots_faced,
    toInt32(coalesce(ps.total_shots_home, 0)) AS opponent_total_shots_faced,
    toInt32(coalesce(ps.total_shots_away, 0) - coalesce(ps.total_shots_home, 0))
        AS total_shots_faced_delta,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS triggered_team_shots_on_target_faced,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS opponent_shots_on_target_faced,
    toInt32(coalesce(ps.shots_on_target_away, 0) - coalesce(ps.shots_on_target_home, 0))
        AS shots_on_target_faced_delta,
    toInt32(coalesce(ps.keeper_saves_home, 0)) AS triggered_team_keeper_saves,
    toInt32(coalesce(ps.keeper_saves_away, 0)) AS opponent_keeper_saves,
    toInt32(coalesce(ps.keeper_saves_home, 0) - coalesce(ps.keeper_saves_away, 0)) AS keeper_saves_delta,
    toFloat32(coalesce(ps.expected_goals_away, 0)) AS triggered_team_expected_goals_faced,
    toFloat32(coalesce(ps.expected_goals_home, 0)) AS opponent_expected_goals_faced,
    toFloat32(round(
        coalesce(ps.expected_goals_away, 0) - coalesce(ps.expected_goals_home, 0),
        3
    )) AS expected_goals_faced_delta,
    toInt32(coalesce(ps.clearances_home, 0)) AS triggered_team_clearances,
    toInt32(coalesce(ps.clearances_away, 0)) AS opponent_clearances,
    toInt32(coalesce(ps.clearances_home, 0) - coalesce(ps.clearances_away, 0)) AS clearances_delta,
    toInt32(coalesce(ps.interceptions_home, 0)) AS triggered_team_interceptions,
    toInt32(coalesce(ps.interceptions_away, 0)) AS opponent_interceptions,
    toInt32(coalesce(ps.interceptions_home, 0) - coalesce(ps.interceptions_away, 0))
        AS interceptions_delta,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS opponent_possession_pct,
    toFloat32(round(
        coalesce(ps.ball_possession_home, 0) - coalesce(ps.ball_possession_away, 0),
        1
    )) AS possession_delta_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0)
        / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0)
        / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0)
            / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0)
            / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,
    toInt32(coalesce(m.home_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.away_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.home_score, 0) - coalesce(m.away_score, 0)) AS goal_delta,
    toInt8(if(coalesce(m.away_score, 0) = 0, 1, 0)) AS triggered_team_clean_sheet_flag
FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ps.cross_attempts_away, 0) >= 20
  AND coalesce(ps.accurate_crosses_away, 0) <= 2

UNION ALL

-- Away-side trigger.
SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    'away' AS triggered_side,
    m.away_team_id AS triggered_team_id,
    m.away_team_name AS triggered_team_name,
    m.home_team_id AS opponent_team_id,
    m.home_team_name AS opponent_team_name,

    toInt32(2) AS trigger_threshold_max_successful_crosses_allowed,
    toInt32(20) AS trigger_threshold_min_cross_attempts_allowed,
    toInt32(coalesce(ps.cross_attempts_home, 0)) AS triggered_team_cross_attempts_allowed,
    toInt32(coalesce(ps.cross_attempts_away, 0)) AS opponent_cross_attempts_allowed,
    toInt32(coalesce(ps.cross_attempts_home, 0) - coalesce(ps.cross_attempts_away, 0))
        AS cross_attempts_allowed_delta,
    toInt32(coalesce(ps.accurate_crosses_home, 0)) AS triggered_team_successful_crosses_allowed,
    toInt32(coalesce(ps.accurate_crosses_away, 0)) AS opponent_successful_crosses_allowed,
    toInt32(coalesce(ps.accurate_crosses_home, 0) - coalesce(ps.accurate_crosses_away, 0))
        AS successful_crosses_allowed_delta,
    toInt32(coalesce(ps.cross_attempts_home, 0) - coalesce(ps.accurate_crosses_home, 0))
        AS triggered_team_crosses_prevented,
    toInt32(coalesce(ps.cross_attempts_away, 0) - coalesce(ps.accurate_crosses_away, 0))
        AS opponent_crosses_prevented,
    toInt32(
        (coalesce(ps.cross_attempts_home, 0) - coalesce(ps.accurate_crosses_home, 0))
      - (coalesce(ps.cross_attempts_away, 0) - coalesce(ps.accurate_crosses_away, 0))
    ) AS crosses_prevented_delta,
    toInt32(2 - coalesce(ps.accurate_crosses_home, 0))
        AS triggered_team_successful_crosses_allowed_below_threshold,
    toInt32(coalesce(ps.cross_attempts_home, 0) - 20)
        AS triggered_team_cross_attempts_allowed_above_threshold,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_crosses_home, 0)
        / nullIf(toFloat64(coalesce(ps.cross_attempts_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_successful_crosses_allowed_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_crosses_away, 0)
        / nullIf(toFloat64(coalesce(ps.cross_attempts_away, 0)), 0),
        1
    ), 0.0)) AS opponent_successful_crosses_allowed_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_crosses_home, 0)
            / nullIf(toFloat64(coalesce(ps.cross_attempts_home, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_crosses_away, 0)
            / nullIf(toFloat64(coalesce(ps.cross_attempts_away, 0)), 0),
            1
        ), 0.0),
        1
    )) AS successful_crosses_allowed_pct_delta,

    toInt32(coalesce(ps.total_shots_home, 0)) AS triggered_team_total_shots_faced,
    toInt32(coalesce(ps.total_shots_away, 0)) AS opponent_total_shots_faced,
    toInt32(coalesce(ps.total_shots_home, 0) - coalesce(ps.total_shots_away, 0))
        AS total_shots_faced_delta,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS triggered_team_shots_on_target_faced,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS opponent_shots_on_target_faced,
    toInt32(coalesce(ps.shots_on_target_home, 0) - coalesce(ps.shots_on_target_away, 0))
        AS shots_on_target_faced_delta,
    toInt32(coalesce(ps.keeper_saves_away, 0)) AS triggered_team_keeper_saves,
    toInt32(coalesce(ps.keeper_saves_home, 0)) AS opponent_keeper_saves,
    toInt32(coalesce(ps.keeper_saves_away, 0) - coalesce(ps.keeper_saves_home, 0)) AS keeper_saves_delta,
    toFloat32(coalesce(ps.expected_goals_home, 0)) AS triggered_team_expected_goals_faced,
    toFloat32(coalesce(ps.expected_goals_away, 0)) AS opponent_expected_goals_faced,
    toFloat32(round(
        coalesce(ps.expected_goals_home, 0) - coalesce(ps.expected_goals_away, 0),
        3
    )) AS expected_goals_faced_delta,
    toInt32(coalesce(ps.clearances_away, 0)) AS triggered_team_clearances,
    toInt32(coalesce(ps.clearances_home, 0)) AS opponent_clearances,
    toInt32(coalesce(ps.clearances_away, 0) - coalesce(ps.clearances_home, 0)) AS clearances_delta,
    toInt32(coalesce(ps.interceptions_away, 0)) AS triggered_team_interceptions,
    toInt32(coalesce(ps.interceptions_home, 0)) AS opponent_interceptions,
    toInt32(coalesce(ps.interceptions_away, 0) - coalesce(ps.interceptions_home, 0))
        AS interceptions_delta,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS opponent_possession_pct,
    toFloat32(round(
        coalesce(ps.ball_possession_away, 0) - coalesce(ps.ball_possession_home, 0),
        1
    )) AS possession_delta_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0)
        / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0)
        / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0)
            / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0)
            / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,
    toInt32(coalesce(m.away_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.home_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.away_score, 0) - coalesce(m.home_score, 0)) AS goal_delta,
    toInt8(if(coalesce(m.home_score, 0) = 0, 1, 0)) AS triggered_team_clean_sheet_flag
FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ps.cross_attempts_home, 0) >= 20
  AND coalesce(ps.accurate_crosses_home, 0) <= 2

ORDER BY
    triggered_team_successful_crosses_allowed ASC,
    triggered_team_cross_attempts_allowed DESC,
    triggered_team_total_shots_faced DESC,
    m.match_date DESC,
    m.match_id DESC;
