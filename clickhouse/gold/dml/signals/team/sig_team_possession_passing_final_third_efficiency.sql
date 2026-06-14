INSERT INTO gold.sig_team_possession_passing_final_third_efficiency (
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
    triggered_team_final_third_entries,
    opponent_final_third_entries,
    final_third_entries_delta,
    triggered_team_goals_per_final_third_entry,
    opponent_goals_per_final_third_entry,
    goals_per_entry_delta,
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
    opponent_opposition_half_passes
)
-- Signal: sig_team_possession_passing_final_third_efficiency
-- Trigger: team goals >= 2 with triggered_team_final_third_entries < 10 (entries proxied by touches_opp_box).
-- Intent: detect unusually clinical output where a side scores multiple goals from very few final-third entries.

-- Home-side triggers.
SELECT
    -- Match identifiers.
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    -- Triggered team and opponent identifiers.
    'home' AS triggered_side,
    m.home_team_id AS triggered_team_id,
    m.home_team_name AS triggered_team_name,
    m.away_team_id AS opponent_team_id,
    m.away_team_name AS opponent_team_name,

    -- Signal context: scoreline efficiency with final-third-entry proxy.
    coalesce(m.home_score, 0) AS triggered_team_goals,
    coalesce(m.away_score, 0) AS opponent_goals,
    coalesce(m.home_score, 0) - coalesce(m.away_score, 0) AS goal_delta,
    coalesce(ps.touches_opp_box_home, 0) AS triggered_team_final_third_entries,
    coalesce(ps.touches_opp_box_away, 0) AS opponent_final_third_entries,
    coalesce(ps.touches_opp_box_home, 0) - coalesce(ps.touches_opp_box_away, 0) AS final_third_entries_delta,
    toFloat32(coalesce(round(coalesce(m.home_score, 0) / greatest(toFloat32(coalesce(ps.touches_opp_box_home, 0)), 1.0), 3), 0.0))
        AS triggered_team_goals_per_final_third_entry,
    toFloat32(coalesce(round(coalesce(m.away_score, 0) / greatest(toFloat32(coalesce(ps.touches_opp_box_away, 0)), 1.0), 3), 0.0))
        AS opponent_goals_per_final_third_entry,
    round(
        coalesce(round(coalesce(m.home_score, 0) / greatest(toFloat32(coalesce(ps.touches_opp_box_home, 0)), 1.0), 3), 0.0)
      - coalesce(round(coalesce(m.away_score, 0) / greatest(toFloat32(coalesce(ps.touches_opp_box_away, 0)), 1.0), 3), 0.0),
        3
    ) AS goals_per_entry_delta,

    -- Shot profile context.
    coalesce(ps.total_shots_home, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_away, 0) AS opponent_total_shots,
    coalesce(ps.shots_on_target_home, 0) AS triggered_team_shots_on_target,
    coalesce(ps.shots_on_target_away, 0) AS opponent_shots_on_target,
    toFloat32(coalesce(round(100.0 * coalesce(ps.shots_on_target_home, 0) / nullIf(coalesce(ps.total_shots_home, 0), 0), 1), 0.0))
        AS triggered_team_on_target_ratio_pct,
    toFloat32(coalesce(round(100.0 * coalesce(ps.shots_on_target_away, 0) / nullIf(coalesce(ps.total_shots_away, 0), 0), 1), 0.0))
        AS opponent_on_target_ratio_pct,

    -- Chance-quality context.
    toFloat32(coalesce(ps.expected_goals_home, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_home, 0) - coalesce(ps.expected_goals_away, 0), 3)) AS xg_delta,
    toFloat32(coalesce(round(coalesce(ps.expected_goals_home, 0) / nullIf(coalesce(ps.total_shots_home, 0), 0), 3), 0.0))
        AS triggered_team_xg_per_shot,
    toFloat32(coalesce(round(coalesce(ps.expected_goals_away, 0) / nullIf(coalesce(ps.total_shots_away, 0), 0), 3), 0.0))
        AS opponent_xg_per_shot,

    -- Passing-control context.
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

    -- Territorial progression context.
    coalesce(ps.opposition_half_passes_home, 0) AS triggered_team_opposition_half_passes,
    coalesce(ps.opposition_half_passes_away, 0) AS opponent_opposition_half_passes

-- Join full-match period stats for finished matches.
FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'

-- Apply home-side trigger.
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(m.home_score, 0) >= 2
  AND coalesce(ps.touches_opp_box_home, 0) < 10

UNION ALL

-- Away-side triggers.
SELECT
    -- Match identifiers.
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    -- Triggered team and opponent identifiers.
    'away' AS triggered_side,
    m.away_team_id AS triggered_team_id,
    m.away_team_name AS triggered_team_name,
    m.home_team_id AS opponent_team_id,
    m.home_team_name AS opponent_team_name,

    -- Signal context: scoreline efficiency with final-third-entry proxy.
    coalesce(m.away_score, 0) AS triggered_team_goals,
    coalesce(m.home_score, 0) AS opponent_goals,
    coalesce(m.away_score, 0) - coalesce(m.home_score, 0) AS goal_delta,
    coalesce(ps.touches_opp_box_away, 0) AS triggered_team_final_third_entries,
    coalesce(ps.touches_opp_box_home, 0) AS opponent_final_third_entries,
    coalesce(ps.touches_opp_box_away, 0) - coalesce(ps.touches_opp_box_home, 0) AS final_third_entries_delta,
    toFloat32(coalesce(round(coalesce(m.away_score, 0) / greatest(toFloat32(coalesce(ps.touches_opp_box_away, 0)), 1.0), 3), 0.0))
        AS triggered_team_goals_per_final_third_entry,
    toFloat32(coalesce(round(coalesce(m.home_score, 0) / greatest(toFloat32(coalesce(ps.touches_opp_box_home, 0)), 1.0), 3), 0.0))
        AS opponent_goals_per_final_third_entry,
    round(
        coalesce(round(coalesce(m.away_score, 0) / greatest(toFloat32(coalesce(ps.touches_opp_box_away, 0)), 1.0), 3), 0.0)
      - coalesce(round(coalesce(m.home_score, 0) / greatest(toFloat32(coalesce(ps.touches_opp_box_home, 0)), 1.0), 3), 0.0),
        3
    ) AS goals_per_entry_delta,

    -- Shot profile context.
    coalesce(ps.total_shots_away, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_home, 0) AS opponent_total_shots,
    coalesce(ps.shots_on_target_away, 0) AS triggered_team_shots_on_target,
    coalesce(ps.shots_on_target_home, 0) AS opponent_shots_on_target,
    toFloat32(coalesce(round(100.0 * coalesce(ps.shots_on_target_away, 0) / nullIf(coalesce(ps.total_shots_away, 0), 0), 1), 0.0))
        AS triggered_team_on_target_ratio_pct,
    toFloat32(coalesce(round(100.0 * coalesce(ps.shots_on_target_home, 0) / nullIf(coalesce(ps.total_shots_home, 0), 0), 1), 0.0))
        AS opponent_on_target_ratio_pct,

    -- Chance-quality context.
    toFloat32(coalesce(ps.expected_goals_away, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_away, 0) - coalesce(ps.expected_goals_home, 0), 3)) AS xg_delta,
    toFloat32(coalesce(round(coalesce(ps.expected_goals_away, 0) / nullIf(coalesce(ps.total_shots_away, 0), 0), 3), 0.0))
        AS triggered_team_xg_per_shot,
    toFloat32(coalesce(round(coalesce(ps.expected_goals_home, 0) / nullIf(coalesce(ps.total_shots_home, 0), 0), 3), 0.0))
        AS opponent_xg_per_shot,

    -- Passing-control context.
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

    -- Territorial progression context.
    coalesce(ps.opposition_half_passes_away, 0) AS triggered_team_opposition_half_passes,
    coalesce(ps.opposition_half_passes_home, 0) AS opponent_opposition_half_passes

-- Join full-match period stats for finished matches.
FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'

-- Apply away-side trigger.
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(m.away_score, 0) >= 2
  AND coalesce(ps.touches_opp_box_away, 0) < 10

-- Prioritize highest scoring efficiency.
ORDER BY
    assumeNotNull(triggered_team_goals_per_final_third_entry) DESC,
    m.match_date DESC,
    m.match_id DESC;
