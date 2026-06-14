INSERT INTO gold.sig_team_possession_passing_possession_efficiency (
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
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_goals_per_possession_pct,
    opponent_goals_per_possession_pct,
    goals_per_possession_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    triggered_team_on_target_ratio_pct,
    opponent_on_target_ratio_pct,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_xg_per_shot,
    opponent_xg_per_shot,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_accurate_passes,
    opponent_accurate_passes,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_opposition_half_passes,
    opponent_opposition_half_passes,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    triggered_team_big_chances,
    opponent_big_chances,
    triggered_team_big_chances_missed,
    opponent_big_chances_missed
)
-- Signal: sig_team_possession_passing_possession_efficiency
-- Trigger: Team scores >= 3 goals with <= 40% possession.
-- Intent: identify low-possession teams that convert limited control into high scoreline output.

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

    coalesce(m.home_score, 0) AS triggered_team_goals,
    coalesce(m.away_score, 0) AS opponent_goals,
    coalesce(m.home_score, 0) - coalesce(m.away_score, 0) AS goal_delta,

    toFloat32(assumeNotNull(ps.ball_possession_home)) AS triggered_team_possession_pct,
    toFloat32(assumeNotNull(ps.ball_possession_away)) AS opponent_possession_pct,
    toFloat32(round(assumeNotNull(ps.ball_possession_home) - assumeNotNull(ps.ball_possession_away), 1))
        AS possession_delta_pct,

    toFloat32(coalesce(round(coalesce(m.home_score, 0) / greatest(toFloat32(assumeNotNull(ps.ball_possession_home)), 1.0), 3), 0.0))
        AS triggered_team_goals_per_possession_pct,
    toFloat32(coalesce(round(coalesce(m.away_score, 0) / greatest(toFloat32(assumeNotNull(ps.ball_possession_away)), 1.0), 3), 0.0))
        AS opponent_goals_per_possession_pct,
    toFloat32(round(
        coalesce(round(coalesce(m.home_score, 0) / greatest(toFloat32(assumeNotNull(ps.ball_possession_home)), 1.0), 3), 0.0)
      - coalesce(round(coalesce(m.away_score, 0) / greatest(toFloat32(assumeNotNull(ps.ball_possession_away)), 1.0), 3), 0.0),
        3
    )) AS goals_per_possession_delta,

    coalesce(ps.total_shots_home, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_away, 0) AS opponent_total_shots,
    coalesce(ps.shots_on_target_home, 0) AS triggered_team_shots_on_target,
    coalesce(ps.shots_on_target_away, 0) AS opponent_shots_on_target,
    toFloat32(coalesce(round(100.0 * coalesce(ps.shots_on_target_home, 0) / nullIf(coalesce(ps.total_shots_home, 0), 0), 1), 0.0))
        AS triggered_team_on_target_ratio_pct,
    toFloat32(coalesce(round(100.0 * coalesce(ps.shots_on_target_away, 0) / nullIf(coalesce(ps.total_shots_away, 0), 0), 1), 0.0))
        AS opponent_on_target_ratio_pct,

    toFloat32(coalesce(ps.expected_goals_home, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_home, 0) - coalesce(ps.expected_goals_away, 0), 3)) AS xg_delta,
    toFloat32(coalesce(round(coalesce(ps.expected_goals_home, 0) / nullIf(coalesce(ps.total_shots_home, 0), 0), 3), 0.0))
        AS triggered_team_xg_per_shot,
    toFloat32(coalesce(round(coalesce(ps.expected_goals_away, 0) / nullIf(coalesce(ps.total_shots_away, 0), 0), 3), 0.0))
        AS opponent_xg_per_shot,

    coalesce(ps.pass_attempts_home, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_away, 0) AS opponent_pass_attempts,
    coalesce(ps.accurate_passes_home, 0) AS triggered_team_accurate_passes,
    coalesce(ps.accurate_passes_away, 0) AS opponent_accurate_passes,
    toFloat32(coalesce(round(100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0))
        AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0))
        AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0)
      - coalesce(round(100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    coalesce(ps.opposition_half_passes_home, 0) AS triggered_team_opposition_half_passes,
    coalesce(ps.opposition_half_passes_away, 0) AS opponent_opposition_half_passes,
    coalesce(ps.touches_opp_box_home, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_away, 0) AS opponent_touches_opposition_box,
    coalesce(ps.big_chances_home, 0) AS triggered_team_big_chances,
    coalesce(ps.big_chances_away, 0) AS opponent_big_chances,
    coalesce(ps.big_chances_missed_home, 0) AS triggered_team_big_chances_missed,
    coalesce(ps.big_chances_missed_away, 0) AS opponent_big_chances_missed

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND ps.ball_possession_home IS NOT NULL
  AND ps.ball_possession_away IS NOT NULL
  AND coalesce(m.home_score, 0) >= 3
  AND assumeNotNull(ps.ball_possession_home) <= 40

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

    coalesce(m.away_score, 0) AS triggered_team_goals,
    coalesce(m.home_score, 0) AS opponent_goals,
    coalesce(m.away_score, 0) - coalesce(m.home_score, 0) AS goal_delta,

    toFloat32(assumeNotNull(ps.ball_possession_away)) AS triggered_team_possession_pct,
    toFloat32(assumeNotNull(ps.ball_possession_home)) AS opponent_possession_pct,
    toFloat32(round(assumeNotNull(ps.ball_possession_away) - assumeNotNull(ps.ball_possession_home), 1))
        AS possession_delta_pct,

    toFloat32(coalesce(round(coalesce(m.away_score, 0) / greatest(toFloat32(assumeNotNull(ps.ball_possession_away)), 1.0), 3), 0.0))
        AS triggered_team_goals_per_possession_pct,
    toFloat32(coalesce(round(coalesce(m.home_score, 0) / greatest(toFloat32(assumeNotNull(ps.ball_possession_home)), 1.0), 3), 0.0))
        AS opponent_goals_per_possession_pct,
    toFloat32(round(
        coalesce(round(coalesce(m.away_score, 0) / greatest(toFloat32(assumeNotNull(ps.ball_possession_away)), 1.0), 3), 0.0)
      - coalesce(round(coalesce(m.home_score, 0) / greatest(toFloat32(assumeNotNull(ps.ball_possession_home)), 1.0), 3), 0.0),
        3
    )) AS goals_per_possession_delta,

    coalesce(ps.total_shots_away, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_home, 0) AS opponent_total_shots,
    coalesce(ps.shots_on_target_away, 0) AS triggered_team_shots_on_target,
    coalesce(ps.shots_on_target_home, 0) AS opponent_shots_on_target,
    toFloat32(coalesce(round(100.0 * coalesce(ps.shots_on_target_away, 0) / nullIf(coalesce(ps.total_shots_away, 0), 0), 1), 0.0))
        AS triggered_team_on_target_ratio_pct,
    toFloat32(coalesce(round(100.0 * coalesce(ps.shots_on_target_home, 0) / nullIf(coalesce(ps.total_shots_home, 0), 0), 1), 0.0))
        AS opponent_on_target_ratio_pct,

    toFloat32(coalesce(ps.expected_goals_away, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_away, 0) - coalesce(ps.expected_goals_home, 0), 3)) AS xg_delta,
    toFloat32(coalesce(round(coalesce(ps.expected_goals_away, 0) / nullIf(coalesce(ps.total_shots_away, 0), 0), 3), 0.0))
        AS triggered_team_xg_per_shot,
    toFloat32(coalesce(round(coalesce(ps.expected_goals_home, 0) / nullIf(coalesce(ps.total_shots_home, 0), 0), 3), 0.0))
        AS opponent_xg_per_shot,

    coalesce(ps.pass_attempts_away, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_home, 0) AS opponent_pass_attempts,
    coalesce(ps.accurate_passes_away, 0) AS triggered_team_accurate_passes,
    coalesce(ps.accurate_passes_home, 0) AS opponent_accurate_passes,
    toFloat32(coalesce(round(100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0))
        AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0))
        AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0)
      - coalesce(round(100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    coalesce(ps.opposition_half_passes_away, 0) AS triggered_team_opposition_half_passes,
    coalesce(ps.opposition_half_passes_home, 0) AS opponent_opposition_half_passes,
    coalesce(ps.touches_opp_box_away, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_home, 0) AS opponent_touches_opposition_box,
    coalesce(ps.big_chances_away, 0) AS triggered_team_big_chances,
    coalesce(ps.big_chances_home, 0) AS opponent_big_chances,
    coalesce(ps.big_chances_missed_away, 0) AS triggered_team_big_chances_missed,
    coalesce(ps.big_chances_missed_home, 0) AS opponent_big_chances_missed

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND ps.ball_possession_home IS NOT NULL
  AND ps.ball_possession_away IS NOT NULL
  AND coalesce(m.away_score, 0) >= 3
  AND assumeNotNull(ps.ball_possession_away) <= 40

ORDER BY
    assumeNotNull(triggered_team_goals_per_possession_pct) DESC,
    m.match_date DESC,
    m.match_id DESC;
