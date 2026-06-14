INSERT INTO gold.sig_team_creativity_playmaking_final_third_siege (
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
    trigger_threshold_min_successful_final_third_passes,
    triggered_team_successful_final_third_passes,
    opponent_successful_final_third_passes,
    successful_final_third_passes_delta,
    triggered_team_final_third_pass_share_pct,
    opponent_final_third_pass_share_pct,
    triggered_team_key_passes,
    opponent_key_passes,
    key_pass_delta,
    triggered_team_expected_assists,
    opponent_expected_assists,
    expected_assists_delta,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_accurate_passes,
    opponent_accurate_passes,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    opposition_box_touches_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    triggered_team_expected_goals,
    opponent_expected_goals,
    expected_goals_delta
)
WITH team_creation_stats AS (
    SELECT
        p.match_id,
        p.team_id,
        toInt32(sum(coalesce(p.passes_final_third, 0))) AS team_successful_final_third_passes,
        toInt32(sum(coalesce(p.chances_created, 0))) AS team_key_passes,
        toFloat32(round(sum(coalesce(p.expected_assists, 0.0)), 3)) AS team_expected_assists
    FROM silver.player_match_stat AS p
    WHERE p.team_id IS NOT NULL
    GROUP BY
        p.match_id,
        p.team_id
)
-- Signal: sig_team_creativity_playmaking_final_third_siege
-- Trigger: team records >= 150 successful passes in the final third in a single finished match.
-- Intent: identify team-level final-third circulation sieges and retain bilateral chance-creation
--         and territorial context to classify whether passing dominance translated into threat.

-- Home-side triggers.
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

    toInt32(150) AS trigger_threshold_min_successful_final_third_passes,
    toInt32(coalesce(hc.team_successful_final_third_passes, 0)) AS triggered_team_successful_final_third_passes,
    toInt32(coalesce(ac.team_successful_final_third_passes, 0)) AS opponent_successful_final_third_passes,
    toInt32(
        coalesce(hc.team_successful_final_third_passes, 0)
        - coalesce(ac.team_successful_final_third_passes, 0)
    ) AS successful_final_third_passes_delta,
    toFloat32(coalesce(round(
        100.0 * coalesce(hc.team_successful_final_third_passes, 0)
        / nullIf(
            toFloat64(
                coalesce(hc.team_successful_final_third_passes, 0)
              + coalesce(ac.team_successful_final_third_passes, 0)
            ),
            0
        ),
        1
    ), 0.0)) AS triggered_team_final_third_pass_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ac.team_successful_final_third_passes, 0)
        / nullIf(
            toFloat64(
                coalesce(hc.team_successful_final_third_passes, 0)
              + coalesce(ac.team_successful_final_third_passes, 0)
            ),
            0
        ),
        1
    ), 0.0)) AS opponent_final_third_pass_share_pct,
    toInt32(coalesce(hc.team_key_passes, 0)) AS triggered_team_key_passes,
    toInt32(coalesce(ac.team_key_passes, 0)) AS opponent_key_passes,
    toInt32(coalesce(hc.team_key_passes, 0) - coalesce(ac.team_key_passes, 0)) AS key_pass_delta,
    toFloat32(coalesce(hc.team_expected_assists, 0.0)) AS triggered_team_expected_assists,
    toFloat32(coalesce(ac.team_expected_assists, 0.0)) AS opponent_expected_assists,
    toFloat32(round(
        coalesce(hc.team_expected_assists, 0.0) - coalesce(ac.team_expected_assists, 0.0),
        3
    )) AS expected_assists_delta,

    toInt32(coalesce(ps.pass_attempts_home, 0)) AS triggered_team_pass_attempts,
    toInt32(coalesce(ps.pass_attempts_away, 0)) AS opponent_pass_attempts,
    toInt32(coalesce(ps.accurate_passes_home, 0)) AS triggered_team_accurate_passes,
    toInt32(coalesce(ps.accurate_passes_away, 0)) AS opponent_accurate_passes,
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
            100.0 * coalesce(ps.accurate_passes_home, 0)
            / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0)
            / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS opponent_possession_pct,
    toFloat32(round(
        coalesce(ps.ball_possession_home, 0.0) - coalesce(ps.ball_possession_away, 0.0),
        1
    )) AS possession_delta_pct,
    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS opponent_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_home, 0) - coalesce(ps.touches_opp_box_away, 0))
        AS opposition_box_touches_delta,
    toInt32(coalesce(ps.total_shots_home, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_away, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS opponent_shots_on_target,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS triggered_team_expected_goals,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS opponent_expected_goals,
    toFloat32(round(
        coalesce(ps.expected_goals_home, 0.0) - coalesce(ps.expected_goals_away, 0.0),
        3
    )) AS expected_goals_delta

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
LEFT JOIN team_creation_stats AS hc
    ON hc.match_id = m.match_id
   AND hc.team_id = m.home_team_id
LEFT JOIN team_creation_stats AS ac
    ON ac.match_id = m.match_id
   AND ac.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(hc.team_successful_final_third_passes, 0) >= 150

UNION ALL

-- Away-side triggers.
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

    toInt32(150) AS trigger_threshold_min_successful_final_third_passes,
    toInt32(coalesce(ac.team_successful_final_third_passes, 0)) AS triggered_team_successful_final_third_passes,
    toInt32(coalesce(hc.team_successful_final_third_passes, 0)) AS opponent_successful_final_third_passes,
    toInt32(
        coalesce(ac.team_successful_final_third_passes, 0)
        - coalesce(hc.team_successful_final_third_passes, 0)
    ) AS successful_final_third_passes_delta,
    toFloat32(coalesce(round(
        100.0 * coalesce(ac.team_successful_final_third_passes, 0)
        / nullIf(
            toFloat64(
                coalesce(ac.team_successful_final_third_passes, 0)
              + coalesce(hc.team_successful_final_third_passes, 0)
            ),
            0
        ),
        1
    ), 0.0)) AS triggered_team_final_third_pass_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(hc.team_successful_final_third_passes, 0)
        / nullIf(
            toFloat64(
                coalesce(ac.team_successful_final_third_passes, 0)
              + coalesce(hc.team_successful_final_third_passes, 0)
            ),
            0
        ),
        1
    ), 0.0)) AS opponent_final_third_pass_share_pct,
    toInt32(coalesce(ac.team_key_passes, 0)) AS triggered_team_key_passes,
    toInt32(coalesce(hc.team_key_passes, 0)) AS opponent_key_passes,
    toInt32(coalesce(ac.team_key_passes, 0) - coalesce(hc.team_key_passes, 0)) AS key_pass_delta,
    toFloat32(coalesce(ac.team_expected_assists, 0.0)) AS triggered_team_expected_assists,
    toFloat32(coalesce(hc.team_expected_assists, 0.0)) AS opponent_expected_assists,
    toFloat32(round(
        coalesce(ac.team_expected_assists, 0.0) - coalesce(hc.team_expected_assists, 0.0),
        3
    )) AS expected_assists_delta,

    toInt32(coalesce(ps.pass_attempts_away, 0)) AS triggered_team_pass_attempts,
    toInt32(coalesce(ps.pass_attempts_home, 0)) AS opponent_pass_attempts,
    toInt32(coalesce(ps.accurate_passes_away, 0)) AS triggered_team_accurate_passes,
    toInt32(coalesce(ps.accurate_passes_home, 0)) AS opponent_accurate_passes,
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
            100.0 * coalesce(ps.accurate_passes_away, 0)
            / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0)
            / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS opponent_possession_pct,
    toFloat32(round(
        coalesce(ps.ball_possession_away, 0.0) - coalesce(ps.ball_possession_home, 0.0),
        1
    )) AS possession_delta_pct,
    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS opponent_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_away, 0) - coalesce(ps.touches_opp_box_home, 0))
        AS opposition_box_touches_delta,
    toInt32(coalesce(ps.total_shots_away, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_home, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS opponent_shots_on_target,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS triggered_team_expected_goals,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS opponent_expected_goals,
    toFloat32(round(
        coalesce(ps.expected_goals_away, 0.0) - coalesce(ps.expected_goals_home, 0.0),
        3
    )) AS expected_goals_delta

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
LEFT JOIN team_creation_stats AS hc
    ON hc.match_id = m.match_id
   AND hc.team_id = m.home_team_id
LEFT JOIN team_creation_stats AS ac
    ON ac.match_id = m.match_id
   AND ac.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ac.team_successful_final_third_passes, 0) >= 150

ORDER BY
    triggered_team_successful_final_third_passes DESC,
    triggered_team_expected_assists DESC,
    m.match_date DESC,
    m.match_id DESC;
