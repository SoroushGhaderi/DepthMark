INSERT INTO gold.sig_match_creativity_playmaking_the_cross_heavy_match (
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
    trigger_threshold_min_match_combined_successful_crosses,
    match_combined_successful_crosses,
    triggered_team_successful_crosses,
    opponent_successful_crosses,
    successful_crosses_delta,
    triggered_team_successful_cross_share_pct,
    opponent_successful_cross_share_pct,
    successful_cross_share_delta_pct,
    triggered_team_cross_attempts,
    opponent_cross_attempts,
    cross_attempts_delta,
    triggered_team_cross_accuracy_pct,
    opponent_cross_accuracy_pct,
    cross_accuracy_delta_pct,
    triggered_team_cross_share_of_passes_pct,
    opponent_cross_share_of_passes_pct,
    cross_share_of_passes_delta_pct,
    triggered_team_key_passes,
    opponent_key_passes,
    key_pass_delta,
    triggered_team_expected_assists,
    opponent_expected_assists,
    expected_assists_delta,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    total_shots_delta,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    shots_on_target_delta,
    triggered_team_expected_goals,
    opponent_expected_goals,
    expected_goals_delta,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_opposition_half_passes,
    opponent_opposition_half_passes,
    opposition_half_passes_delta,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    opposition_box_touches_delta
)
WITH team_creation_stats AS (
    SELECT
        p.match_id,
        p.team_id,
        toInt32(sum(coalesce(p.chances_created, 0))) AS team_key_passes,
        toFloat32(round(sum(coalesce(p.expected_assists, 0.0)), 3)) AS team_expected_assists
    FROM silver.player_match_stat AS p
    WHERE p.team_id IS NOT NULL
    GROUP BY
        p.match_id,
        p.team_id
),
base_stats AS (
    SELECT
        m.match_id AS match_id,
        m.match_date AS match_date,
        m.home_team_id AS home_team_id,
        m.home_team_name AS home_team_name,
        m.away_team_id AS away_team_id,
        m.away_team_name AS away_team_name,
        m.home_score AS home_score,
        m.away_score AS away_score,

        toInt32(coalesce(m.home_score, 0)) AS home_goals,
        toInt32(coalesce(m.away_score, 0)) AS away_goals,

        toInt32(coalesce(ps.accurate_crosses_home, 0)) AS successful_crosses_home,
        toInt32(coalesce(ps.accurate_crosses_away, 0)) AS successful_crosses_away,
        toInt32(coalesce(ps.cross_attempts_home, 0)) AS cross_attempts_home,
        toInt32(coalesce(ps.cross_attempts_away, 0)) AS cross_attempts_away,
        toInt32(
            coalesce(ps.accurate_crosses_home, 0)
          + coalesce(ps.accurate_crosses_away, 0)
        ) AS match_combined_successful_crosses,

        toInt32(coalesce(hc.team_key_passes, 0)) AS home_key_passes,
        toInt32(coalesce(ac.team_key_passes, 0)) AS away_key_passes,
        toFloat32(coalesce(hc.team_expected_assists, 0.0)) AS home_expected_assists,
        toFloat32(coalesce(ac.team_expected_assists, 0.0)) AS away_expected_assists,

        toInt32(coalesce(ps.total_shots_home, 0)) AS total_shots_home,
        toInt32(coalesce(ps.total_shots_away, 0)) AS total_shots_away,
        toInt32(coalesce(ps.shots_on_target_home, 0)) AS shots_on_target_home,
        toInt32(coalesce(ps.shots_on_target_away, 0)) AS shots_on_target_away,
        toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS expected_goals_home,
        toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS expected_goals_away,
        toInt32(coalesce(ps.pass_attempts_home, 0)) AS pass_attempts_home,
        toInt32(coalesce(ps.pass_attempts_away, 0)) AS pass_attempts_away,
        toInt32(coalesce(ps.accurate_passes_home, 0)) AS accurate_passes_home,
        toInt32(coalesce(ps.accurate_passes_away, 0)) AS accurate_passes_away,
        toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS possession_home_pct,
        toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS possession_away_pct,
        toInt32(coalesce(ps.opposition_half_passes_home, 0)) AS opposition_half_passes_home,
        toInt32(coalesce(ps.opposition_half_passes_away, 0)) AS opposition_half_passes_away,
        toInt32(coalesce(ps.touches_opp_box_home, 0)) AS touches_opposition_box_home,
        toInt32(coalesce(ps.touches_opp_box_away, 0)) AS touches_opposition_box_away
    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.match_date = m.match_date
       AND ps.period = 'All'
    LEFT JOIN team_creation_stats AS hc
        ON hc.match_id = m.match_id
       AND hc.team_id = m.home_team_id
    LEFT JOIN team_creation_stats AS ac
        ON ac.match_id = m.match_id
       AND ac.team_id = m.away_team_id
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND (
          coalesce(ps.accurate_crosses_home, 0)
        + coalesce(ps.accurate_crosses_away, 0)
      ) > 25
)
-- Signal: sig_match_creativity_playmaking_the_cross_heavy_match
-- Trigger: combined match successful crosses exceed 25 in a finished match.
-- Intent: capture bilateral cross-heavy creative matches with completion quality,
--         direct crossing load, and side-by-side playmaking context.
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

    toInt32(25) AS trigger_threshold_min_match_combined_successful_crosses,
    b.match_combined_successful_crosses,
    b.successful_crosses_home AS triggered_team_successful_crosses,
    b.successful_crosses_away AS opponent_successful_crosses,
    b.successful_crosses_home - b.successful_crosses_away AS successful_crosses_delta,

    toFloat32(coalesce(round(
        100.0 * b.successful_crosses_home
        / nullIf(toFloat64(b.match_combined_successful_crosses), 0),
        1
    ), 0.0)) AS triggered_team_successful_cross_share_pct,
    toFloat32(coalesce(round(
        100.0 * b.successful_crosses_away
        / nullIf(toFloat64(b.match_combined_successful_crosses), 0),
        1
    ), 0.0)) AS opponent_successful_cross_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.successful_crosses_home
            / nullIf(toFloat64(b.match_combined_successful_crosses), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * b.successful_crosses_away
            / nullIf(toFloat64(b.match_combined_successful_crosses), 0),
            1
        ), 0.0),
        1
    )) AS successful_cross_share_delta_pct,

    b.cross_attempts_home AS triggered_team_cross_attempts,
    b.cross_attempts_away AS opponent_cross_attempts,
    b.cross_attempts_home - b.cross_attempts_away AS cross_attempts_delta,

    toFloat32(coalesce(round(
        100.0 * b.successful_crosses_home / nullIf(toFloat64(b.cross_attempts_home), 0),
        1
    ), 0.0)) AS triggered_team_cross_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.successful_crosses_away / nullIf(toFloat64(b.cross_attempts_away), 0),
        1
    ), 0.0)) AS opponent_cross_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.successful_crosses_home / nullIf(toFloat64(b.cross_attempts_home), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * b.successful_crosses_away / nullIf(toFloat64(b.cross_attempts_away), 0),
            1
        ), 0.0),
        1
    )) AS cross_accuracy_delta_pct,

    toFloat32(coalesce(round(
        100.0 * b.cross_attempts_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS triggered_team_cross_share_of_passes_pct,
    toFloat32(coalesce(round(
        100.0 * b.cross_attempts_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS opponent_cross_share_of_passes_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.cross_attempts_home / nullIf(toFloat64(b.pass_attempts_home), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * b.cross_attempts_away / nullIf(toFloat64(b.pass_attempts_away), 0),
            1
        ), 0.0),
        1
    )) AS cross_share_of_passes_delta_pct,

    b.home_key_passes AS triggered_team_key_passes,
    b.away_key_passes AS opponent_key_passes,
    b.home_key_passes - b.away_key_passes AS key_pass_delta,
    b.home_expected_assists AS triggered_team_expected_assists,
    b.away_expected_assists AS opponent_expected_assists,
    toFloat32(round(b.home_expected_assists - b.away_expected_assists, 3)) AS expected_assists_delta,

    b.home_goals AS triggered_team_goals,
    b.away_goals AS opponent_goals,
    b.home_goals - b.away_goals AS goal_delta,

    b.total_shots_home AS triggered_team_total_shots,
    b.total_shots_away AS opponent_total_shots,
    b.total_shots_home - b.total_shots_away AS total_shots_delta,
    b.shots_on_target_home AS triggered_team_shots_on_target,
    b.shots_on_target_away AS opponent_shots_on_target,
    b.shots_on_target_home - b.shots_on_target_away AS shots_on_target_delta,
    b.expected_goals_home AS triggered_team_expected_goals,
    b.expected_goals_away AS opponent_expected_goals,
    toFloat32(round(b.expected_goals_home - b.expected_goals_away, 3)) AS expected_goals_delta,

    b.pass_attempts_home AS triggered_team_pass_attempts,
    b.pass_attempts_away AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0), 1), 0.0)
      - coalesce(round(100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    b.possession_home_pct AS triggered_team_possession_pct,
    b.possession_away_pct AS opponent_possession_pct,
    toFloat32(round(b.possession_home_pct - b.possession_away_pct, 1)) AS possession_delta_pct,

    b.opposition_half_passes_home AS triggered_team_opposition_half_passes,
    b.opposition_half_passes_away AS opponent_opposition_half_passes,
    b.opposition_half_passes_home - b.opposition_half_passes_away AS opposition_half_passes_delta,

    b.touches_opposition_box_home AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_away AS opponent_touches_opposition_box,
    b.touches_opposition_box_home - b.touches_opposition_box_away AS opposition_box_touches_delta
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

    toInt32(25) AS trigger_threshold_min_match_combined_successful_crosses,
    b.match_combined_successful_crosses,
    b.successful_crosses_away AS triggered_team_successful_crosses,
    b.successful_crosses_home AS opponent_successful_crosses,
    b.successful_crosses_away - b.successful_crosses_home AS successful_crosses_delta,

    toFloat32(coalesce(round(
        100.0 * b.successful_crosses_away
        / nullIf(toFloat64(b.match_combined_successful_crosses), 0),
        1
    ), 0.0)) AS triggered_team_successful_cross_share_pct,
    toFloat32(coalesce(round(
        100.0 * b.successful_crosses_home
        / nullIf(toFloat64(b.match_combined_successful_crosses), 0),
        1
    ), 0.0)) AS opponent_successful_cross_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.successful_crosses_away
            / nullIf(toFloat64(b.match_combined_successful_crosses), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * b.successful_crosses_home
            / nullIf(toFloat64(b.match_combined_successful_crosses), 0),
            1
        ), 0.0),
        1
    )) AS successful_cross_share_delta_pct,

    b.cross_attempts_away AS triggered_team_cross_attempts,
    b.cross_attempts_home AS opponent_cross_attempts,
    b.cross_attempts_away - b.cross_attempts_home AS cross_attempts_delta,

    toFloat32(coalesce(round(
        100.0 * b.successful_crosses_away / nullIf(toFloat64(b.cross_attempts_away), 0),
        1
    ), 0.0)) AS triggered_team_cross_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.successful_crosses_home / nullIf(toFloat64(b.cross_attempts_home), 0),
        1
    ), 0.0)) AS opponent_cross_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.successful_crosses_away / nullIf(toFloat64(b.cross_attempts_away), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * b.successful_crosses_home / nullIf(toFloat64(b.cross_attempts_home), 0),
            1
        ), 0.0),
        1
    )) AS cross_accuracy_delta_pct,

    toFloat32(coalesce(round(
        100.0 * b.cross_attempts_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS triggered_team_cross_share_of_passes_pct,
    toFloat32(coalesce(round(
        100.0 * b.cross_attempts_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS opponent_cross_share_of_passes_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.cross_attempts_away / nullIf(toFloat64(b.pass_attempts_away), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * b.cross_attempts_home / nullIf(toFloat64(b.pass_attempts_home), 0),
            1
        ), 0.0),
        1
    )) AS cross_share_of_passes_delta_pct,

    b.away_key_passes AS triggered_team_key_passes,
    b.home_key_passes AS opponent_key_passes,
    b.away_key_passes - b.home_key_passes AS key_pass_delta,
    b.away_expected_assists AS triggered_team_expected_assists,
    b.home_expected_assists AS opponent_expected_assists,
    toFloat32(round(b.away_expected_assists - b.home_expected_assists, 3)) AS expected_assists_delta,

    b.away_goals AS triggered_team_goals,
    b.home_goals AS opponent_goals,
    b.away_goals - b.home_goals AS goal_delta,

    b.total_shots_away AS triggered_team_total_shots,
    b.total_shots_home AS opponent_total_shots,
    b.total_shots_away - b.total_shots_home AS total_shots_delta,
    b.shots_on_target_away AS triggered_team_shots_on_target,
    b.shots_on_target_home AS opponent_shots_on_target,
    b.shots_on_target_away - b.shots_on_target_home AS shots_on_target_delta,
    b.expected_goals_away AS triggered_team_expected_goals,
    b.expected_goals_home AS opponent_expected_goals,
    toFloat32(round(b.expected_goals_away - b.expected_goals_home, 3)) AS expected_goals_delta,

    b.pass_attempts_away AS triggered_team_pass_attempts,
    b.pass_attempts_home AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.accurate_passes_away / nullIf(toFloat64(b.pass_attempts_away), 0), 1), 0.0)
      - coalesce(round(100.0 * b.accurate_passes_home / nullIf(toFloat64(b.pass_attempts_home), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    b.possession_away_pct AS triggered_team_possession_pct,
    b.possession_home_pct AS opponent_possession_pct,
    toFloat32(round(b.possession_away_pct - b.possession_home_pct, 1)) AS possession_delta_pct,

    b.opposition_half_passes_away AS triggered_team_opposition_half_passes,
    b.opposition_half_passes_home AS opponent_opposition_half_passes,
    b.opposition_half_passes_away - b.opposition_half_passes_home AS opposition_half_passes_delta,

    b.touches_opposition_box_away AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_home AS opponent_touches_opposition_box,
    b.touches_opposition_box_away - b.touches_opposition_box_home AS opposition_box_touches_delta
FROM base_stats AS b
