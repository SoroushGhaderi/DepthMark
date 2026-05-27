INSERT INTO gold.sig_team_creativity_playmaking_unlikely_creative_source (
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
    trigger_threshold_min_center_back_assists,
    trigger_threshold_required_usual_playing_position_id,
    trigger_center_back_position_ids,
    triggered_team_center_back_count,
    opponent_center_back_count,
    center_back_count_delta,
    triggered_team_center_backs_with_assists,
    opponent_center_backs_with_assists,
    center_backs_with_assists_delta,
    triggered_team_center_back_assists,
    opponent_center_back_assists,
    center_back_assists_delta,
    triggered_team_top_center_back_assists,
    opponent_top_center_back_assists,
    top_center_back_assists_delta,
    triggered_team_center_back_key_passes,
    opponent_center_back_key_passes,
    center_back_key_passes_delta,
    triggered_team_center_back_expected_assists,
    opponent_center_back_expected_assists,
    center_back_expected_assists_delta,
    triggered_team_total_assists,
    opponent_total_assists,
    total_assists_delta,
    triggered_team_total_key_passes,
    opponent_total_key_passes,
    total_key_passes_delta,
    triggered_team_total_expected_assists,
    opponent_total_expected_assists,
    total_expected_assists_delta,
    triggered_team_center_back_assist_share_pct,
    opponent_center_back_assist_share_pct,
    center_back_assist_share_delta_pct,
    triggered_team_center_back_key_pass_share_pct,
    opponent_center_back_key_pass_share_pct,
    center_back_key_pass_share_delta_pct,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_accurate_passes,
    opponent_accurate_passes,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    opposition_box_touches_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    total_shots_delta,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    shots_on_target_delta,
    triggered_team_expected_goals,
    opponent_expected_goals,
    expected_goals_delta,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct
)
WITH player_roles AS (
    SELECT
        mp.match_id,
        toInt32(mp.primary_team_id) AS team_id,
        toInt32(mp.person_id) AS player_id,
        argMax(coalesce(mp.position_id, 0), if(mp.role = 'starter', 2, 1)) AS position_id,
        argMax(coalesce(mp.usual_playing_position_id, 0), if(mp.role = 'starter', 2, 1))
            AS usual_playing_position_id
    FROM silver.match_personnel AS mp
    WHERE mp.match_id > 0
      AND coalesce(mp.primary_team_id, 0) > 0
      AND coalesce(mp.person_id, 0) > 0
      AND mp.role IN ('starter', 'substitute')
    GROUP BY
        mp.match_id,
        team_id,
        player_id
),
center_back_playmaking AS (
    SELECT
        p.match_id,
        toInt32(p.team_id) AS team_id,
        toInt32(count()) AS team_center_back_count,
        toInt32(countIf(coalesce(p.assists, 0) > 0)) AS team_center_backs_with_assists,
        toInt32(sum(coalesce(p.assists, 0))) AS team_center_back_assists,
        toInt32(sum(coalesce(p.chances_created, 0))) AS team_center_back_key_passes,
        toFloat32(round(sum(coalesce(p.expected_assists, 0.0)), 3)) AS team_center_back_expected_assists,
        toInt32(max(coalesce(p.assists, 0))) AS team_top_center_back_assists
    FROM silver.player_match_stat AS p
    INNER JOIN player_roles AS pr
        ON pr.match_id = p.match_id
       AND pr.team_id = toInt32(p.team_id)
       AND pr.player_id = toInt32(p.player_id)
    WHERE p.match_id > 0
      AND coalesce(p.team_id, 0) > 0
      AND coalesce(pr.usual_playing_position_id, 0) = 1
      AND coalesce(pr.position_id, 0) IN (3, 4)
    GROUP BY
        p.match_id,
        team_id
),
team_total_playmaking AS (
    SELECT
        p.match_id,
        toInt32(p.team_id) AS team_id,
        toInt32(sum(coalesce(p.assists, 0))) AS team_total_assists,
        toInt32(sum(coalesce(p.chances_created, 0))) AS team_total_key_passes,
        toFloat32(round(sum(coalesce(p.expected_assists, 0.0)), 3)) AS team_total_expected_assists
    FROM silver.player_match_stat AS p
    WHERE p.match_id > 0
      AND coalesce(p.team_id, 0) > 0
    GROUP BY
        p.match_id,
        team_id
)
-- Signal: sig_team_creativity_playmaking_unlikely_creative_source
-- Trigger: Center backs provide >= 2 assists in one finished match.
-- Intent: detect rare team-level playmaking surges where center backs drive direct goal creation,
--         then retain bilateral context for creativity share, passing control, and attacking output.

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

    toInt32(2) AS trigger_threshold_min_center_back_assists,
    toInt32(1) AS trigger_threshold_required_usual_playing_position_id,
    '3,4' AS trigger_center_back_position_ids,

    toInt32(coalesce(hc.team_center_back_count, 0)) AS triggered_team_center_back_count,
    toInt32(coalesce(ac.team_center_back_count, 0)) AS opponent_center_back_count,
    toInt32(coalesce(hc.team_center_back_count, 0) - coalesce(ac.team_center_back_count, 0))
        AS center_back_count_delta,

    toInt32(coalesce(hc.team_center_backs_with_assists, 0)) AS triggered_team_center_backs_with_assists,
    toInt32(coalesce(ac.team_center_backs_with_assists, 0)) AS opponent_center_backs_with_assists,
    toInt32(
        coalesce(hc.team_center_backs_with_assists, 0) - coalesce(ac.team_center_backs_with_assists, 0)
    ) AS center_backs_with_assists_delta,

    toInt32(coalesce(hc.team_center_back_assists, 0)) AS triggered_team_center_back_assists,
    toInt32(coalesce(ac.team_center_back_assists, 0)) AS opponent_center_back_assists,
    toInt32(coalesce(hc.team_center_back_assists, 0) - coalesce(ac.team_center_back_assists, 0))
        AS center_back_assists_delta,

    toInt32(coalesce(hc.team_top_center_back_assists, 0)) AS triggered_team_top_center_back_assists,
    toInt32(coalesce(ac.team_top_center_back_assists, 0)) AS opponent_top_center_back_assists,
    toInt32(
        coalesce(hc.team_top_center_back_assists, 0) - coalesce(ac.team_top_center_back_assists, 0)
    ) AS top_center_back_assists_delta,

    toInt32(coalesce(hc.team_center_back_key_passes, 0)) AS triggered_team_center_back_key_passes,
    toInt32(coalesce(ac.team_center_back_key_passes, 0)) AS opponent_center_back_key_passes,
    toInt32(coalesce(hc.team_center_back_key_passes, 0) - coalesce(ac.team_center_back_key_passes, 0))
        AS center_back_key_passes_delta,

    toFloat32(coalesce(hc.team_center_back_expected_assists, 0.0)) AS triggered_team_center_back_expected_assists,
    toFloat32(coalesce(ac.team_center_back_expected_assists, 0.0)) AS opponent_center_back_expected_assists,
    toFloat32(round(
        coalesce(hc.team_center_back_expected_assists, 0.0)
      - coalesce(ac.team_center_back_expected_assists, 0.0),
        3
    )) AS center_back_expected_assists_delta,

    toInt32(coalesce(ht.team_total_assists, 0)) AS triggered_team_total_assists,
    toInt32(coalesce(at.team_total_assists, 0)) AS opponent_total_assists,
    toInt32(coalesce(ht.team_total_assists, 0) - coalesce(at.team_total_assists, 0)) AS total_assists_delta,

    toInt32(coalesce(ht.team_total_key_passes, 0)) AS triggered_team_total_key_passes,
    toInt32(coalesce(at.team_total_key_passes, 0)) AS opponent_total_key_passes,
    toInt32(coalesce(ht.team_total_key_passes, 0) - coalesce(at.team_total_key_passes, 0))
        AS total_key_passes_delta,

    toFloat32(coalesce(ht.team_total_expected_assists, 0.0)) AS triggered_team_total_expected_assists,
    toFloat32(coalesce(at.team_total_expected_assists, 0.0)) AS opponent_total_expected_assists,
    toFloat32(round(
        coalesce(ht.team_total_expected_assists, 0.0)
      - coalesce(at.team_total_expected_assists, 0.0),
        3
    )) AS total_expected_assists_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(hc.team_center_back_assists, 0)
        / nullIf(toFloat64(coalesce(ht.team_total_assists, 0)), 0),
        1
    ), 0.0)) AS triggered_team_center_back_assist_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ac.team_center_back_assists, 0)
        / nullIf(toFloat64(coalesce(at.team_total_assists, 0)), 0),
        1
    ), 0.0)) AS opponent_center_back_assist_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(hc.team_center_back_assists, 0)
            / nullIf(toFloat64(coalesce(ht.team_total_assists, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ac.team_center_back_assists, 0)
            / nullIf(toFloat64(coalesce(at.team_total_assists, 0)), 0),
            1
        ), 0.0),
        1
    )) AS center_back_assist_share_delta_pct,

    toFloat32(coalesce(round(
        100.0 * coalesce(hc.team_center_back_key_passes, 0)
        / nullIf(toFloat64(coalesce(ht.team_total_key_passes, 0)), 0),
        1
    ), 0.0)) AS triggered_team_center_back_key_pass_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ac.team_center_back_key_passes, 0)
        / nullIf(toFloat64(coalesce(at.team_total_key_passes, 0)), 0),
        1
    ), 0.0)) AS opponent_center_back_key_pass_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(hc.team_center_back_key_passes, 0)
            / nullIf(toFloat64(coalesce(ht.team_total_key_passes, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ac.team_center_back_key_passes, 0)
            / nullIf(toFloat64(coalesce(at.team_total_key_passes, 0)), 0),
            1
        ), 0.0),
        1
    )) AS center_back_key_pass_share_delta_pct,

    toInt32(coalesce(m.home_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.away_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.home_score, 0) - coalesce(m.away_score, 0)) AS goal_delta,

    toInt32(coalesce(ps.pass_attempts_home, 0)) AS triggered_team_pass_attempts,
    toInt32(coalesce(ps.pass_attempts_away, 0)) AS opponent_pass_attempts,
    toInt32(coalesce(ps.accurate_passes_home, 0)) AS triggered_team_accurate_passes,
    toInt32(coalesce(ps.accurate_passes_away, 0)) AS opponent_accurate_passes,
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

    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS opponent_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_home, 0) - coalesce(ps.touches_opp_box_away, 0))
        AS opposition_box_touches_delta,

    toInt32(coalesce(ps.total_shots_home, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_away, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.total_shots_home, 0) - coalesce(ps.total_shots_away, 0)) AS total_shots_delta,

    toInt32(coalesce(ps.shots_on_target_home, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS opponent_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_home, 0) - coalesce(ps.shots_on_target_away, 0))
        AS shots_on_target_delta,

    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS triggered_team_expected_goals,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS opponent_expected_goals,
    toFloat32(round(
        coalesce(ps.expected_goals_home, 0.0) - coalesce(ps.expected_goals_away, 0.0),
        3
    )) AS expected_goals_delta,

    toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS opponent_possession_pct,
    toFloat32(round(
        coalesce(ps.ball_possession_home, 0.0) - coalesce(ps.ball_possession_away, 0.0),
        1
    )) AS possession_delta_pct

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN center_back_playmaking AS hc
    ON hc.match_id = m.match_id
   AND hc.team_id = toInt32(m.home_team_id)
LEFT JOIN center_back_playmaking AS ac
    ON ac.match_id = m.match_id
   AND ac.team_id = toInt32(m.away_team_id)
LEFT JOIN team_total_playmaking AS ht
    ON ht.match_id = m.match_id
   AND ht.team_id = toInt32(m.home_team_id)
LEFT JOIN team_total_playmaking AS at
    ON at.match_id = m.match_id
   AND at.team_id = toInt32(m.away_team_id)
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(hc.team_center_back_assists, 0) >= 2

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

    toInt32(2) AS trigger_threshold_min_center_back_assists,
    toInt32(1) AS trigger_threshold_required_usual_playing_position_id,
    '3,4' AS trigger_center_back_position_ids,

    toInt32(coalesce(ac.team_center_back_count, 0)) AS triggered_team_center_back_count,
    toInt32(coalesce(hc.team_center_back_count, 0)) AS opponent_center_back_count,
    toInt32(coalesce(ac.team_center_back_count, 0) - coalesce(hc.team_center_back_count, 0))
        AS center_back_count_delta,

    toInt32(coalesce(ac.team_center_backs_with_assists, 0)) AS triggered_team_center_backs_with_assists,
    toInt32(coalesce(hc.team_center_backs_with_assists, 0)) AS opponent_center_backs_with_assists,
    toInt32(
        coalesce(ac.team_center_backs_with_assists, 0) - coalesce(hc.team_center_backs_with_assists, 0)
    ) AS center_backs_with_assists_delta,

    toInt32(coalesce(ac.team_center_back_assists, 0)) AS triggered_team_center_back_assists,
    toInt32(coalesce(hc.team_center_back_assists, 0)) AS opponent_center_back_assists,
    toInt32(coalesce(ac.team_center_back_assists, 0) - coalesce(hc.team_center_back_assists, 0))
        AS center_back_assists_delta,

    toInt32(coalesce(ac.team_top_center_back_assists, 0)) AS triggered_team_top_center_back_assists,
    toInt32(coalesce(hc.team_top_center_back_assists, 0)) AS opponent_top_center_back_assists,
    toInt32(
        coalesce(ac.team_top_center_back_assists, 0) - coalesce(hc.team_top_center_back_assists, 0)
    ) AS top_center_back_assists_delta,

    toInt32(coalesce(ac.team_center_back_key_passes, 0)) AS triggered_team_center_back_key_passes,
    toInt32(coalesce(hc.team_center_back_key_passes, 0)) AS opponent_center_back_key_passes,
    toInt32(coalesce(ac.team_center_back_key_passes, 0) - coalesce(hc.team_center_back_key_passes, 0))
        AS center_back_key_passes_delta,

    toFloat32(coalesce(ac.team_center_back_expected_assists, 0.0)) AS triggered_team_center_back_expected_assists,
    toFloat32(coalesce(hc.team_center_back_expected_assists, 0.0)) AS opponent_center_back_expected_assists,
    toFloat32(round(
        coalesce(ac.team_center_back_expected_assists, 0.0)
      - coalesce(hc.team_center_back_expected_assists, 0.0),
        3
    )) AS center_back_expected_assists_delta,

    toInt32(coalesce(at.team_total_assists, 0)) AS triggered_team_total_assists,
    toInt32(coalesce(ht.team_total_assists, 0)) AS opponent_total_assists,
    toInt32(coalesce(at.team_total_assists, 0) - coalesce(ht.team_total_assists, 0)) AS total_assists_delta,

    toInt32(coalesce(at.team_total_key_passes, 0)) AS triggered_team_total_key_passes,
    toInt32(coalesce(ht.team_total_key_passes, 0)) AS opponent_total_key_passes,
    toInt32(coalesce(at.team_total_key_passes, 0) - coalesce(ht.team_total_key_passes, 0))
        AS total_key_passes_delta,

    toFloat32(coalesce(at.team_total_expected_assists, 0.0)) AS triggered_team_total_expected_assists,
    toFloat32(coalesce(ht.team_total_expected_assists, 0.0)) AS opponent_total_expected_assists,
    toFloat32(round(
        coalesce(at.team_total_expected_assists, 0.0)
      - coalesce(ht.team_total_expected_assists, 0.0),
        3
    )) AS total_expected_assists_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(ac.team_center_back_assists, 0)
        / nullIf(toFloat64(coalesce(at.team_total_assists, 0)), 0),
        1
    ), 0.0)) AS triggered_team_center_back_assist_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(hc.team_center_back_assists, 0)
        / nullIf(toFloat64(coalesce(ht.team_total_assists, 0)), 0),
        1
    ), 0.0)) AS opponent_center_back_assist_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ac.team_center_back_assists, 0)
            / nullIf(toFloat64(coalesce(at.team_total_assists, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(hc.team_center_back_assists, 0)
            / nullIf(toFloat64(coalesce(ht.team_total_assists, 0)), 0),
            1
        ), 0.0),
        1
    )) AS center_back_assist_share_delta_pct,

    toFloat32(coalesce(round(
        100.0 * coalesce(ac.team_center_back_key_passes, 0)
        / nullIf(toFloat64(coalesce(at.team_total_key_passes, 0)), 0),
        1
    ), 0.0)) AS triggered_team_center_back_key_pass_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(hc.team_center_back_key_passes, 0)
        / nullIf(toFloat64(coalesce(ht.team_total_key_passes, 0)), 0),
        1
    ), 0.0)) AS opponent_center_back_key_pass_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ac.team_center_back_key_passes, 0)
            / nullIf(toFloat64(coalesce(at.team_total_key_passes, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(hc.team_center_back_key_passes, 0)
            / nullIf(toFloat64(coalesce(ht.team_total_key_passes, 0)), 0),
            1
        ), 0.0),
        1
    )) AS center_back_key_pass_share_delta_pct,

    toInt32(coalesce(m.away_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.home_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.away_score, 0) - coalesce(m.home_score, 0)) AS goal_delta,

    toInt32(coalesce(ps.pass_attempts_away, 0)) AS triggered_team_pass_attempts,
    toInt32(coalesce(ps.pass_attempts_home, 0)) AS opponent_pass_attempts,
    toInt32(coalesce(ps.accurate_passes_away, 0)) AS triggered_team_accurate_passes,
    toInt32(coalesce(ps.accurate_passes_home, 0)) AS opponent_accurate_passes,
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

    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS opponent_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_away, 0) - coalesce(ps.touches_opp_box_home, 0))
        AS opposition_box_touches_delta,

    toInt32(coalesce(ps.total_shots_away, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_home, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.total_shots_away, 0) - coalesce(ps.total_shots_home, 0)) AS total_shots_delta,

    toInt32(coalesce(ps.shots_on_target_away, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS opponent_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_away, 0) - coalesce(ps.shots_on_target_home, 0))
        AS shots_on_target_delta,

    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS triggered_team_expected_goals,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS opponent_expected_goals,
    toFloat32(round(
        coalesce(ps.expected_goals_away, 0.0) - coalesce(ps.expected_goals_home, 0.0),
        3
    )) AS expected_goals_delta,

    toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS opponent_possession_pct,
    toFloat32(round(
        coalesce(ps.ball_possession_away, 0.0) - coalesce(ps.ball_possession_home, 0.0),
        1
    )) AS possession_delta_pct

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN center_back_playmaking AS hc
    ON hc.match_id = m.match_id
   AND hc.team_id = toInt32(m.home_team_id)
LEFT JOIN center_back_playmaking AS ac
    ON ac.match_id = m.match_id
   AND ac.team_id = toInt32(m.away_team_id)
LEFT JOIN team_total_playmaking AS ht
    ON ht.match_id = m.match_id
   AND ht.team_id = toInt32(m.home_team_id)
LEFT JOIN team_total_playmaking AS at
    ON at.match_id = m.match_id
   AND at.team_id = toInt32(m.away_team_id)
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ac.team_center_back_assists, 0) >= 2
