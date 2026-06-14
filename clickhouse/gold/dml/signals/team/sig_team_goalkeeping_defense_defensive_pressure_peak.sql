INSERT INTO gold.sig_team_goalkeeping_defense_defensive_pressure_peak (
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
    trigger_threshold_min_opposition_turnovers_in_half,
    trigger_threshold_required_half_minutes,
    triggered_half_with_turnovers_forced_peak,
    has_first_half_period_row_flag,
    has_second_half_period_row_flag,
    triggered_team_turnovers_forced_first_half,
    triggered_team_turnovers_forced_second_half,
    opponent_turnovers_forced_first_half,
    opponent_turnovers_forced_second_half,
    turnovers_forced_first_half_delta,
    turnovers_forced_second_half_delta,
    triggered_team_peak_turnovers_forced_in_half,
    opponent_peak_turnovers_forced_in_half,
    peak_turnovers_forced_in_half_delta,
    triggered_team_turnovers_forced_above_threshold,
    triggered_team_turnovers_forced_full_match,
    opponent_turnovers_forced_full_match,
    turnovers_forced_full_match_delta,
    triggered_team_interceptions,
    opponent_interceptions,
    interceptions_delta,
    triggered_team_clearances,
    opponent_clearances,
    clearances_delta,
    triggered_team_tackles_won,
    opponent_tackles_won,
    tackles_won_delta,
    triggered_team_duels_won,
    opponent_duels_won,
    duels_won_delta,
    triggered_team_aerials_won,
    opponent_aerials_won,
    aerials_won_delta,
    triggered_team_total_shots_faced,
    opponent_total_shots_faced,
    total_shots_faced_delta,
    triggered_team_shots_on_target_faced,
    opponent_shots_on_target_faced,
    shots_on_target_faced_delta,
    triggered_team_keeper_saves,
    opponent_keeper_saves,
    keeper_saves_delta,
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
WITH half_turnover_stats AS (
    SELECT
        ps.match_id,
        maxIf(
            greatest(coalesce(ps.pass_attempts_home, 0) - coalesce(ps.accurate_passes_home, 0), 0),
            ps.period = 'FirstHalf'
        ) AS home_failed_passes_first_half,
        maxIf(
            greatest(coalesce(ps.pass_attempts_home, 0) - coalesce(ps.accurate_passes_home, 0), 0),
            ps.period = 'SecondHalf'
        ) AS home_failed_passes_second_half,
        maxIf(
            greatest(coalesce(ps.pass_attempts_away, 0) - coalesce(ps.accurate_passes_away, 0), 0),
            ps.period = 'FirstHalf'
        ) AS away_failed_passes_first_half,
        maxIf(
            greatest(coalesce(ps.pass_attempts_away, 0) - coalesce(ps.accurate_passes_away, 0), 0),
            ps.period = 'SecondHalf'
        ) AS away_failed_passes_second_half,

        maxIf(
            greatest(coalesce(ps.dribble_attempts_home, 0) - coalesce(ps.dribbles_succeeded_home, 0), 0),
            ps.period = 'FirstHalf'
        ) AS home_failed_dribbles_first_half,
        maxIf(
            greatest(coalesce(ps.dribble_attempts_home, 0) - coalesce(ps.dribbles_succeeded_home, 0), 0),
            ps.period = 'SecondHalf'
        ) AS home_failed_dribbles_second_half,
        maxIf(
            greatest(coalesce(ps.dribble_attempts_away, 0) - coalesce(ps.dribbles_succeeded_away, 0), 0),
            ps.period = 'FirstHalf'
        ) AS away_failed_dribbles_first_half,
        maxIf(
            greatest(coalesce(ps.dribble_attempts_away, 0) - coalesce(ps.dribbles_succeeded_away, 0), 0),
            ps.period = 'SecondHalf'
        ) AS away_failed_dribbles_second_half,

        toInt8(maxIf(1, ps.period = 'FirstHalf')) AS has_first_half_period_row_flag,
        toInt8(maxIf(1, ps.period = 'SecondHalf')) AS has_second_half_period_row_flag
    FROM silver.period_stat AS ps
    WHERE ps.period IN ('FirstHalf', 'SecondHalf')
    GROUP BY ps.match_id
)
-- Signal: sig_team_goalkeeping_defense_defensive_pressure_peak
-- Intent: detect team-level defensive pressure peaks where one side forces extreme opposition turnovers
--         in a single half, with bilateral defensive and match-context diagnostics.
-- Trigger: team forces >= 20 opposition turnovers in a full half (FirstHalf or SecondHalf).

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

    toInt32(20) AS trigger_threshold_min_opposition_turnovers_in_half,
    toInt32(45) AS trigger_threshold_required_half_minutes,
    if(
        (
            coalesce(hts.away_failed_passes_first_half, 0)
          + coalesce(hts.away_failed_dribbles_first_half, 0)
        ) >= 20
        AND (
            coalesce(hts.away_failed_passes_second_half, 0)
          + coalesce(hts.away_failed_dribbles_second_half, 0)
        ) >= 20,
        'BothHalves',
        if(
            (
                coalesce(hts.away_failed_passes_first_half, 0)
              + coalesce(hts.away_failed_dribbles_first_half, 0)
            ) >= 20,
            'FirstHalf',
            'SecondHalf'
        )
    ) AS triggered_half_with_turnovers_forced_peak,
    hts.has_first_half_period_row_flag,
    hts.has_second_half_period_row_flag,

    toInt32(coalesce(hts.away_failed_passes_first_half, 0) + coalesce(hts.away_failed_dribbles_first_half, 0))
        AS triggered_team_turnovers_forced_first_half,
    toInt32(coalesce(hts.away_failed_passes_second_half, 0) + coalesce(hts.away_failed_dribbles_second_half, 0))
        AS triggered_team_turnovers_forced_second_half,
    toInt32(coalesce(hts.home_failed_passes_first_half, 0) + coalesce(hts.home_failed_dribbles_first_half, 0))
        AS opponent_turnovers_forced_first_half,
    toInt32(coalesce(hts.home_failed_passes_second_half, 0) + coalesce(hts.home_failed_dribbles_second_half, 0))
        AS opponent_turnovers_forced_second_half,

    toInt32(
        (
            coalesce(hts.away_failed_passes_first_half, 0)
          + coalesce(hts.away_failed_dribbles_first_half, 0)
        )
      - (
            coalesce(hts.home_failed_passes_first_half, 0)
          + coalesce(hts.home_failed_dribbles_first_half, 0)
        )
    ) AS turnovers_forced_first_half_delta,
    toInt32(
        (
            coalesce(hts.away_failed_passes_second_half, 0)
          + coalesce(hts.away_failed_dribbles_second_half, 0)
        )
      - (
            coalesce(hts.home_failed_passes_second_half, 0)
          + coalesce(hts.home_failed_dribbles_second_half, 0)
        )
    ) AS turnovers_forced_second_half_delta,

    toInt32(greatest(
        coalesce(hts.away_failed_passes_first_half, 0) + coalesce(hts.away_failed_dribbles_first_half, 0),
        coalesce(hts.away_failed_passes_second_half, 0) + coalesce(hts.away_failed_dribbles_second_half, 0)
    )) AS triggered_team_peak_turnovers_forced_in_half,
    toInt32(greatest(
        coalesce(hts.home_failed_passes_first_half, 0) + coalesce(hts.home_failed_dribbles_first_half, 0),
        coalesce(hts.home_failed_passes_second_half, 0) + coalesce(hts.home_failed_dribbles_second_half, 0)
    )) AS opponent_peak_turnovers_forced_in_half,
    toInt32(
        greatest(
            coalesce(hts.away_failed_passes_first_half, 0) + coalesce(hts.away_failed_dribbles_first_half, 0),
            coalesce(hts.away_failed_passes_second_half, 0) + coalesce(hts.away_failed_dribbles_second_half, 0)
        )
      - greatest(
            coalesce(hts.home_failed_passes_first_half, 0) + coalesce(hts.home_failed_dribbles_first_half, 0),
            coalesce(hts.home_failed_passes_second_half, 0) + coalesce(hts.home_failed_dribbles_second_half, 0)
        )
    ) AS peak_turnovers_forced_in_half_delta,
    toInt32(greatest(
        coalesce(hts.away_failed_passes_first_half, 0) + coalesce(hts.away_failed_dribbles_first_half, 0),
        coalesce(hts.away_failed_passes_second_half, 0) + coalesce(hts.away_failed_dribbles_second_half, 0)
    ) - 20) AS triggered_team_turnovers_forced_above_threshold,

    toInt32(
        greatest(coalesce(ps.pass_attempts_away, 0) - coalesce(ps.accurate_passes_away, 0), 0)
      + greatest(coalesce(ps.dribble_attempts_away, 0) - coalesce(ps.dribbles_succeeded_away, 0), 0)
    ) AS triggered_team_turnovers_forced_full_match,
    toInt32(
        greatest(coalesce(ps.pass_attempts_home, 0) - coalesce(ps.accurate_passes_home, 0), 0)
      + greatest(coalesce(ps.dribble_attempts_home, 0) - coalesce(ps.dribbles_succeeded_home, 0), 0)
    ) AS opponent_turnovers_forced_full_match,
    toInt32(
        (
            greatest(coalesce(ps.pass_attempts_away, 0) - coalesce(ps.accurate_passes_away, 0), 0)
          + greatest(coalesce(ps.dribble_attempts_away, 0) - coalesce(ps.dribbles_succeeded_away, 0), 0)
        )
      - (
            greatest(coalesce(ps.pass_attempts_home, 0) - coalesce(ps.accurate_passes_home, 0), 0)
          + greatest(coalesce(ps.dribble_attempts_home, 0) - coalesce(ps.dribbles_succeeded_home, 0), 0)
        )
    ) AS turnovers_forced_full_match_delta,

    toInt32(coalesce(ps.interceptions_home, 0)) AS triggered_team_interceptions,
    toInt32(coalesce(ps.interceptions_away, 0)) AS opponent_interceptions,
    toInt32(coalesce(ps.interceptions_home, 0) - coalesce(ps.interceptions_away, 0)) AS interceptions_delta,

    toInt32(coalesce(ps.clearances_home, 0)) AS triggered_team_clearances,
    toInt32(coalesce(ps.clearances_away, 0)) AS opponent_clearances,
    toInt32(coalesce(ps.clearances_home, 0) - coalesce(ps.clearances_away, 0)) AS clearances_delta,

    toInt32(coalesce(ps.tackles_succeeded_home, 0)) AS triggered_team_tackles_won,
    toInt32(coalesce(ps.tackles_succeeded_away, 0)) AS opponent_tackles_won,
    toInt32(coalesce(ps.tackles_succeeded_home, 0) - coalesce(ps.tackles_succeeded_away, 0))
        AS tackles_won_delta,

    toInt32(coalesce(ps.duels_won_home, 0)) AS triggered_team_duels_won,
    toInt32(coalesce(ps.duels_won_away, 0)) AS opponent_duels_won,
    toInt32(coalesce(ps.duels_won_home, 0) - coalesce(ps.duels_won_away, 0)) AS duels_won_delta,

    toInt32(coalesce(ps.aerials_won_home, 0)) AS triggered_team_aerials_won,
    toInt32(coalesce(ps.aerials_won_away, 0)) AS opponent_aerials_won,
    toInt32(coalesce(ps.aerials_won_home, 0) - coalesce(ps.aerials_won_away, 0)) AS aerials_won_delta,

    toInt32(coalesce(ps.total_shots_away, 0)) AS triggered_team_total_shots_faced,
    toInt32(coalesce(ps.total_shots_home, 0)) AS opponent_total_shots_faced,
    toInt32(coalesce(ps.total_shots_away, 0) - coalesce(ps.total_shots_home, 0)) AS total_shots_faced_delta,

    toInt32(coalesce(ps.shots_on_target_away, 0)) AS triggered_team_shots_on_target_faced,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS opponent_shots_on_target_faced,
    toInt32(coalesce(ps.shots_on_target_away, 0) - coalesce(ps.shots_on_target_home, 0))
        AS shots_on_target_faced_delta,

    toInt32(coalesce(ps.keeper_saves_home, 0)) AS triggered_team_keeper_saves,
    toInt32(coalesce(ps.keeper_saves_away, 0)) AS opponent_keeper_saves,
    toInt32(coalesce(ps.keeper_saves_home, 0) - coalesce(ps.keeper_saves_away, 0)) AS keeper_saves_delta,

    toFloat32(coalesce(ps.ball_possession_home, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_home, 0) - coalesce(ps.ball_possession_away, 0), 1))
        AS possession_delta_pct,

    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
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
INNER JOIN half_turnover_stats AS hts
    ON hts.match_id = m.match_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND hts.has_first_half_period_row_flag = 1
  AND hts.has_second_half_period_row_flag = 1
  AND (
      coalesce(hts.away_failed_passes_first_half, 0) + coalesce(hts.away_failed_dribbles_first_half, 0) >= 20
      OR coalesce(hts.away_failed_passes_second_half, 0) + coalesce(hts.away_failed_dribbles_second_half, 0) >= 20
  )

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

    toInt32(20) AS trigger_threshold_min_opposition_turnovers_in_half,
    toInt32(45) AS trigger_threshold_required_half_minutes,
    if(
        (
            coalesce(hts.home_failed_passes_first_half, 0)
          + coalesce(hts.home_failed_dribbles_first_half, 0)
        ) >= 20
        AND (
            coalesce(hts.home_failed_passes_second_half, 0)
          + coalesce(hts.home_failed_dribbles_second_half, 0)
        ) >= 20,
        'BothHalves',
        if(
            (
                coalesce(hts.home_failed_passes_first_half, 0)
              + coalesce(hts.home_failed_dribbles_first_half, 0)
            ) >= 20,
            'FirstHalf',
            'SecondHalf'
        )
    ) AS triggered_half_with_turnovers_forced_peak,
    hts.has_first_half_period_row_flag,
    hts.has_second_half_period_row_flag,

    toInt32(coalesce(hts.home_failed_passes_first_half, 0) + coalesce(hts.home_failed_dribbles_first_half, 0))
        AS triggered_team_turnovers_forced_first_half,
    toInt32(coalesce(hts.home_failed_passes_second_half, 0) + coalesce(hts.home_failed_dribbles_second_half, 0))
        AS triggered_team_turnovers_forced_second_half,
    toInt32(coalesce(hts.away_failed_passes_first_half, 0) + coalesce(hts.away_failed_dribbles_first_half, 0))
        AS opponent_turnovers_forced_first_half,
    toInt32(coalesce(hts.away_failed_passes_second_half, 0) + coalesce(hts.away_failed_dribbles_second_half, 0))
        AS opponent_turnovers_forced_second_half,

    toInt32(
        (
            coalesce(hts.home_failed_passes_first_half, 0)
          + coalesce(hts.home_failed_dribbles_first_half, 0)
        )
      - (
            coalesce(hts.away_failed_passes_first_half, 0)
          + coalesce(hts.away_failed_dribbles_first_half, 0)
        )
    ) AS turnovers_forced_first_half_delta,
    toInt32(
        (
            coalesce(hts.home_failed_passes_second_half, 0)
          + coalesce(hts.home_failed_dribbles_second_half, 0)
        )
      - (
            coalesce(hts.away_failed_passes_second_half, 0)
          + coalesce(hts.away_failed_dribbles_second_half, 0)
        )
    ) AS turnovers_forced_second_half_delta,

    toInt32(greatest(
        coalesce(hts.home_failed_passes_first_half, 0) + coalesce(hts.home_failed_dribbles_first_half, 0),
        coalesce(hts.home_failed_passes_second_half, 0) + coalesce(hts.home_failed_dribbles_second_half, 0)
    )) AS triggered_team_peak_turnovers_forced_in_half,
    toInt32(greatest(
        coalesce(hts.away_failed_passes_first_half, 0) + coalesce(hts.away_failed_dribbles_first_half, 0),
        coalesce(hts.away_failed_passes_second_half, 0) + coalesce(hts.away_failed_dribbles_second_half, 0)
    )) AS opponent_peak_turnovers_forced_in_half,
    toInt32(
        greatest(
            coalesce(hts.home_failed_passes_first_half, 0) + coalesce(hts.home_failed_dribbles_first_half, 0),
            coalesce(hts.home_failed_passes_second_half, 0) + coalesce(hts.home_failed_dribbles_second_half, 0)
        )
      - greatest(
            coalesce(hts.away_failed_passes_first_half, 0) + coalesce(hts.away_failed_dribbles_first_half, 0),
            coalesce(hts.away_failed_passes_second_half, 0) + coalesce(hts.away_failed_dribbles_second_half, 0)
        )
    ) AS peak_turnovers_forced_in_half_delta,
    toInt32(greatest(
        coalesce(hts.home_failed_passes_first_half, 0) + coalesce(hts.home_failed_dribbles_first_half, 0),
        coalesce(hts.home_failed_passes_second_half, 0) + coalesce(hts.home_failed_dribbles_second_half, 0)
    ) - 20) AS triggered_team_turnovers_forced_above_threshold,

    toInt32(
        greatest(coalesce(ps.pass_attempts_home, 0) - coalesce(ps.accurate_passes_home, 0), 0)
      + greatest(coalesce(ps.dribble_attempts_home, 0) - coalesce(ps.dribbles_succeeded_home, 0), 0)
    ) AS triggered_team_turnovers_forced_full_match,
    toInt32(
        greatest(coalesce(ps.pass_attempts_away, 0) - coalesce(ps.accurate_passes_away, 0), 0)
      + greatest(coalesce(ps.dribble_attempts_away, 0) - coalesce(ps.dribbles_succeeded_away, 0), 0)
    ) AS opponent_turnovers_forced_full_match,
    toInt32(
        (
            greatest(coalesce(ps.pass_attempts_home, 0) - coalesce(ps.accurate_passes_home, 0), 0)
          + greatest(coalesce(ps.dribble_attempts_home, 0) - coalesce(ps.dribbles_succeeded_home, 0), 0)
        )
      - (
            greatest(coalesce(ps.pass_attempts_away, 0) - coalesce(ps.accurate_passes_away, 0), 0)
          + greatest(coalesce(ps.dribble_attempts_away, 0) - coalesce(ps.dribbles_succeeded_away, 0), 0)
        )
    ) AS turnovers_forced_full_match_delta,

    toInt32(coalesce(ps.interceptions_away, 0)) AS triggered_team_interceptions,
    toInt32(coalesce(ps.interceptions_home, 0)) AS opponent_interceptions,
    toInt32(coalesce(ps.interceptions_away, 0) - coalesce(ps.interceptions_home, 0)) AS interceptions_delta,

    toInt32(coalesce(ps.clearances_away, 0)) AS triggered_team_clearances,
    toInt32(coalesce(ps.clearances_home, 0)) AS opponent_clearances,
    toInt32(coalesce(ps.clearances_away, 0) - coalesce(ps.clearances_home, 0)) AS clearances_delta,

    toInt32(coalesce(ps.tackles_succeeded_away, 0)) AS triggered_team_tackles_won,
    toInt32(coalesce(ps.tackles_succeeded_home, 0)) AS opponent_tackles_won,
    toInt32(coalesce(ps.tackles_succeeded_away, 0) - coalesce(ps.tackles_succeeded_home, 0))
        AS tackles_won_delta,

    toInt32(coalesce(ps.duels_won_away, 0)) AS triggered_team_duels_won,
    toInt32(coalesce(ps.duels_won_home, 0)) AS opponent_duels_won,
    toInt32(coalesce(ps.duels_won_away, 0) - coalesce(ps.duels_won_home, 0)) AS duels_won_delta,

    toInt32(coalesce(ps.aerials_won_away, 0)) AS triggered_team_aerials_won,
    toInt32(coalesce(ps.aerials_won_home, 0)) AS opponent_aerials_won,
    toInt32(coalesce(ps.aerials_won_away, 0) - coalesce(ps.aerials_won_home, 0)) AS aerials_won_delta,

    toInt32(coalesce(ps.total_shots_home, 0)) AS triggered_team_total_shots_faced,
    toInt32(coalesce(ps.total_shots_away, 0)) AS opponent_total_shots_faced,
    toInt32(coalesce(ps.total_shots_home, 0) - coalesce(ps.total_shots_away, 0)) AS total_shots_faced_delta,

    toInt32(coalesce(ps.shots_on_target_home, 0)) AS triggered_team_shots_on_target_faced,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS opponent_shots_on_target_faced,
    toInt32(coalesce(ps.shots_on_target_home, 0) - coalesce(ps.shots_on_target_away, 0))
        AS shots_on_target_faced_delta,

    toInt32(coalesce(ps.keeper_saves_away, 0)) AS triggered_team_keeper_saves,
    toInt32(coalesce(ps.keeper_saves_home, 0)) AS opponent_keeper_saves,
    toInt32(coalesce(ps.keeper_saves_away, 0) - coalesce(ps.keeper_saves_home, 0)) AS keeper_saves_delta,

    toFloat32(coalesce(ps.ball_possession_away, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_away, 0) - coalesce(ps.ball_possession_home, 0), 1))
        AS possession_delta_pct,

    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
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
INNER JOIN half_turnover_stats AS hts
    ON hts.match_id = m.match_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND hts.has_first_half_period_row_flag = 1
  AND hts.has_second_half_period_row_flag = 1
  AND (
      coalesce(hts.home_failed_passes_first_half, 0) + coalesce(hts.home_failed_dribbles_first_half, 0) >= 20
      OR coalesce(hts.home_failed_passes_second_half, 0) + coalesce(hts.home_failed_dribbles_second_half, 0) >= 20
  )
