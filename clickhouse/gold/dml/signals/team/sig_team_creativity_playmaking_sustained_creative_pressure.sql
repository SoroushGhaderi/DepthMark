INSERT INTO gold.sig_team_creativity_playmaking_sustained_creative_pressure (
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
    trigger_threshold_min_key_passes_per_segment,
    trigger_threshold_segment_window_minutes,
    trigger_threshold_required_segment_count,
    triggered_team_key_pass_proxy_segment_00_09,
    triggered_team_key_pass_proxy_segment_10_19,
    triggered_team_key_pass_proxy_segment_20_29,
    triggered_team_key_pass_proxy_segment_30_39,
    triggered_team_key_pass_proxy_segment_40_49,
    triggered_team_key_pass_proxy_segment_50_59,
    triggered_team_key_pass_proxy_segment_60_69,
    triggered_team_key_pass_proxy_segment_70_79,
    triggered_team_key_pass_proxy_segment_80_90_plus,
    opponent_key_pass_proxy_segment_00_09,
    opponent_key_pass_proxy_segment_10_19,
    opponent_key_pass_proxy_segment_20_29,
    opponent_key_pass_proxy_segment_30_39,
    opponent_key_pass_proxy_segment_40_49,
    opponent_key_pass_proxy_segment_50_59,
    opponent_key_pass_proxy_segment_60_69,
    opponent_key_pass_proxy_segment_70_79,
    opponent_key_pass_proxy_segment_80_90_plus,
    triggered_team_key_pass_proxy_segments_hit_count,
    opponent_key_pass_proxy_segments_hit_count,
    key_pass_proxy_segments_hit_count_delta,
    triggered_team_key_pass_proxy_segment_coverage_pct,
    opponent_key_pass_proxy_segment_coverage_pct,
    key_pass_proxy_segment_coverage_delta_pct,
    triggered_team_key_pass_proxy_total,
    opponent_key_pass_proxy_total,
    key_pass_proxy_total_delta,
    triggered_team_total_key_passes,
    opponent_total_key_passes,
    total_key_passes_delta,
    triggered_team_expected_assists,
    opponent_expected_assists,
    expected_assists_delta,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
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
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct
)
WITH shot_events AS (
    SELECT
        s.match_id,
        toInt32(s.team_id) AS team_id,
        if(s.team_id = m.home_team_id, 'home', 'away') AS shot_side,
        toInt32(
            coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
        ) AS shot_effective_minute
    FROM silver.shot AS s
    INNER JOIN silver.match AS m
        ON m.match_id = s.match_id
    WHERE s.match_id > 0
      AND m.match_finished = 1
      AND (s.team_id = m.home_team_id OR s.team_id = m.away_team_id)
      AND coalesce(s.minute, s.goal_time, 0) >= 0
      AND coalesce(s.is_own_goal, 0) = 0
      AND coalesce(s.situation, '') != 'Penalty'
),
team_segment_key_pass_proxy AS (
    SELECT
        se.match_id,
        se.team_id,
        se.shot_side,
        toInt32(sum(if(se.shot_effective_minute BETWEEN 0 AND 9, 1, 0)))
            AS key_pass_proxy_segment_00_09,
        toInt32(sum(if(se.shot_effective_minute BETWEEN 10 AND 19, 1, 0)))
            AS key_pass_proxy_segment_10_19,
        toInt32(sum(if(se.shot_effective_minute BETWEEN 20 AND 29, 1, 0)))
            AS key_pass_proxy_segment_20_29,
        toInt32(sum(if(se.shot_effective_minute BETWEEN 30 AND 39, 1, 0)))
            AS key_pass_proxy_segment_30_39,
        toInt32(sum(if(se.shot_effective_minute BETWEEN 40 AND 49, 1, 0)))
            AS key_pass_proxy_segment_40_49,
        toInt32(sum(if(se.shot_effective_minute BETWEEN 50 AND 59, 1, 0)))
            AS key_pass_proxy_segment_50_59,
        toInt32(sum(if(se.shot_effective_minute BETWEEN 60 AND 69, 1, 0)))
            AS key_pass_proxy_segment_60_69,
        toInt32(sum(if(se.shot_effective_minute BETWEEN 70 AND 79, 1, 0)))
            AS key_pass_proxy_segment_70_79,
        toInt32(sum(if(se.shot_effective_minute >= 80, 1, 0)))
            AS key_pass_proxy_segment_80_90_plus,
        toInt32(count()) AS key_pass_proxy_total
    FROM shot_events AS se
    GROUP BY
        se.match_id,
        se.team_id,
        se.shot_side
),
team_segment_rollup AS (
    SELECT
        tsp.match_id,
        tsp.team_id,
        tsp.shot_side,
        tsp.key_pass_proxy_segment_00_09,
        tsp.key_pass_proxy_segment_10_19,
        tsp.key_pass_proxy_segment_20_29,
        tsp.key_pass_proxy_segment_30_39,
        tsp.key_pass_proxy_segment_40_49,
        tsp.key_pass_proxy_segment_50_59,
        tsp.key_pass_proxy_segment_60_69,
        tsp.key_pass_proxy_segment_70_79,
        tsp.key_pass_proxy_segment_80_90_plus,
        tsp.key_pass_proxy_total,
        toInt32(
            if(tsp.key_pass_proxy_segment_00_09 >= 1, 1, 0)
          + if(tsp.key_pass_proxy_segment_10_19 >= 1, 1, 0)
          + if(tsp.key_pass_proxy_segment_20_29 >= 1, 1, 0)
          + if(tsp.key_pass_proxy_segment_30_39 >= 1, 1, 0)
          + if(tsp.key_pass_proxy_segment_40_49 >= 1, 1, 0)
          + if(tsp.key_pass_proxy_segment_50_59 >= 1, 1, 0)
          + if(tsp.key_pass_proxy_segment_60_69 >= 1, 1, 0)
          + if(tsp.key_pass_proxy_segment_70_79 >= 1, 1, 0)
          + if(tsp.key_pass_proxy_segment_80_90_plus >= 1, 1, 0)
        ) AS key_pass_proxy_segments_hit_count,
        toFloat32(round(
            100.0 * (
                if(tsp.key_pass_proxy_segment_00_09 >= 1, 1, 0)
              + if(tsp.key_pass_proxy_segment_10_19 >= 1, 1, 0)
              + if(tsp.key_pass_proxy_segment_20_29 >= 1, 1, 0)
              + if(tsp.key_pass_proxy_segment_30_39 >= 1, 1, 0)
              + if(tsp.key_pass_proxy_segment_40_49 >= 1, 1, 0)
              + if(tsp.key_pass_proxy_segment_50_59 >= 1, 1, 0)
              + if(tsp.key_pass_proxy_segment_60_69 >= 1, 1, 0)
              + if(tsp.key_pass_proxy_segment_70_79 >= 1, 1, 0)
              + if(tsp.key_pass_proxy_segment_80_90_plus >= 1, 1, 0)
            ) / 9.0,
            1
        )) AS key_pass_proxy_segment_coverage_pct
    FROM team_segment_key_pass_proxy AS tsp
),
team_playmaking_totals AS (
    SELECT
        p.match_id,
        toInt32(p.team_id) AS team_id,
        toInt32(sum(coalesce(p.chances_created, 0))) AS team_total_key_passes,
        toFloat32(round(sum(coalesce(p.expected_assists, 0.0)), 3)) AS team_expected_assists
    FROM silver.player_match_stat AS p
    WHERE p.match_id > 0
      AND p.team_id > 0
    GROUP BY
        p.match_id,
        team_id
),
team_rows AS (
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
        m.away_team_name AS opponent_team_name
    FROM silver.match AS m
    WHERE m.match_finished = 1
      AND m.match_id > 0

    UNION ALL

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
        m.home_team_name AS opponent_team_name
    FROM silver.match AS m
    WHERE m.match_finished = 1
      AND m.match_id > 0
)
-- Signal: sig_team_creativity_playmaking_sustained_creative_pressure
-- Trigger: Team records >= 1 key-pass proxy event in each 10-minute segment (00-09 ... 80-90+) in a finished match.
-- Intent: detect sustained chance-creation pressure across the entire match timeline with bilateral quality and control context.
SELECT
    tr.match_id,
    tr.match_date,
    tr.home_team_id,
    tr.home_team_name,
    tr.away_team_id,
    tr.away_team_name,
    tr.home_score,
    tr.away_score,

    tr.triggered_side,
    tr.triggered_team_id,
    tr.triggered_team_name,
    tr.opponent_team_id,
    tr.opponent_team_name,

    toInt32(1) AS trigger_threshold_min_key_passes_per_segment,
    toInt32(10) AS trigger_threshold_segment_window_minutes,
    toInt32(9) AS trigger_threshold_required_segment_count,

    toInt32(coalesce(tsr.key_pass_proxy_segment_00_09, 0)) AS triggered_team_key_pass_proxy_segment_00_09,
    toInt32(coalesce(tsr.key_pass_proxy_segment_10_19, 0)) AS triggered_team_key_pass_proxy_segment_10_19,
    toInt32(coalesce(tsr.key_pass_proxy_segment_20_29, 0)) AS triggered_team_key_pass_proxy_segment_20_29,
    toInt32(coalesce(tsr.key_pass_proxy_segment_30_39, 0)) AS triggered_team_key_pass_proxy_segment_30_39,
    toInt32(coalesce(tsr.key_pass_proxy_segment_40_49, 0)) AS triggered_team_key_pass_proxy_segment_40_49,
    toInt32(coalesce(tsr.key_pass_proxy_segment_50_59, 0)) AS triggered_team_key_pass_proxy_segment_50_59,
    toInt32(coalesce(tsr.key_pass_proxy_segment_60_69, 0)) AS triggered_team_key_pass_proxy_segment_60_69,
    toInt32(coalesce(tsr.key_pass_proxy_segment_70_79, 0)) AS triggered_team_key_pass_proxy_segment_70_79,
    toInt32(coalesce(tsr.key_pass_proxy_segment_80_90_plus, 0)) AS triggered_team_key_pass_proxy_segment_80_90_plus,

    toInt32(coalesce(osr.key_pass_proxy_segment_00_09, 0)) AS opponent_key_pass_proxy_segment_00_09,
    toInt32(coalesce(osr.key_pass_proxy_segment_10_19, 0)) AS opponent_key_pass_proxy_segment_10_19,
    toInt32(coalesce(osr.key_pass_proxy_segment_20_29, 0)) AS opponent_key_pass_proxy_segment_20_29,
    toInt32(coalesce(osr.key_pass_proxy_segment_30_39, 0)) AS opponent_key_pass_proxy_segment_30_39,
    toInt32(coalesce(osr.key_pass_proxy_segment_40_49, 0)) AS opponent_key_pass_proxy_segment_40_49,
    toInt32(coalesce(osr.key_pass_proxy_segment_50_59, 0)) AS opponent_key_pass_proxy_segment_50_59,
    toInt32(coalesce(osr.key_pass_proxy_segment_60_69, 0)) AS opponent_key_pass_proxy_segment_60_69,
    toInt32(coalesce(osr.key_pass_proxy_segment_70_79, 0)) AS opponent_key_pass_proxy_segment_70_79,
    toInt32(coalesce(osr.key_pass_proxy_segment_80_90_plus, 0)) AS opponent_key_pass_proxy_segment_80_90_plus,

    toInt32(coalesce(tsr.key_pass_proxy_segments_hit_count, 0)) AS triggered_team_key_pass_proxy_segments_hit_count,
    toInt32(coalesce(osr.key_pass_proxy_segments_hit_count, 0)) AS opponent_key_pass_proxy_segments_hit_count,
    toInt32(
        coalesce(tsr.key_pass_proxy_segments_hit_count, 0)
      - coalesce(osr.key_pass_proxy_segments_hit_count, 0)
    ) AS key_pass_proxy_segments_hit_count_delta,

    toFloat32(coalesce(tsr.key_pass_proxy_segment_coverage_pct, 0.0))
        AS triggered_team_key_pass_proxy_segment_coverage_pct,
    toFloat32(coalesce(osr.key_pass_proxy_segment_coverage_pct, 0.0))
        AS opponent_key_pass_proxy_segment_coverage_pct,
    toFloat32(round(
        coalesce(tsr.key_pass_proxy_segment_coverage_pct, 0.0)
      - coalesce(osr.key_pass_proxy_segment_coverage_pct, 0.0),
        1
    )) AS key_pass_proxy_segment_coverage_delta_pct,

    toInt32(coalesce(tsr.key_pass_proxy_total, 0)) AS triggered_team_key_pass_proxy_total,
    toInt32(coalesce(osr.key_pass_proxy_total, 0)) AS opponent_key_pass_proxy_total,
    toInt32(coalesce(tsr.key_pass_proxy_total, 0) - coalesce(osr.key_pass_proxy_total, 0))
        AS key_pass_proxy_total_delta,

    toInt32(coalesce(tpt.team_total_key_passes, 0)) AS triggered_team_total_key_passes,
    toInt32(coalesce(opt.team_total_key_passes, 0)) AS opponent_total_key_passes,
    toInt32(coalesce(tpt.team_total_key_passes, 0) - coalesce(opt.team_total_key_passes, 0))
        AS total_key_passes_delta,

    toFloat32(coalesce(tpt.team_expected_assists, 0.0)) AS triggered_team_expected_assists,
    toFloat32(coalesce(opt.team_expected_assists, 0.0)) AS opponent_expected_assists,
    toFloat32(round(
        coalesce(tpt.team_expected_assists, 0.0) - coalesce(opt.team_expected_assists, 0.0),
        3
    )) AS expected_assists_delta,

    toInt32(multiIf(
        tr.triggered_side = 'home', coalesce(ps.pass_attempts_home, 0),
        tr.triggered_side = 'away', coalesce(ps.pass_attempts_away, 0),
        0
    )) AS triggered_team_pass_attempts,
    toInt32(multiIf(
        tr.triggered_side = 'home', coalesce(ps.pass_attempts_away, 0),
        tr.triggered_side = 'away', coalesce(ps.pass_attempts_home, 0),
        0
    )) AS opponent_pass_attempts,
    toFloat32(coalesce(round(
        100.0 * multiIf(
            tr.triggered_side = 'home', coalesce(ps.accurate_passes_home, 0),
            tr.triggered_side = 'away', coalesce(ps.accurate_passes_away, 0),
            0
        )
        / nullIf(toFloat64(multiIf(
            tr.triggered_side = 'home', coalesce(ps.pass_attempts_home, 0),
            tr.triggered_side = 'away', coalesce(ps.pass_attempts_away, 0),
            0
        )), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * multiIf(
            tr.triggered_side = 'home', coalesce(ps.accurate_passes_away, 0),
            tr.triggered_side = 'away', coalesce(ps.accurate_passes_home, 0),
            0
        )
        / nullIf(toFloat64(multiIf(
            tr.triggered_side = 'home', coalesce(ps.pass_attempts_away, 0),
            tr.triggered_side = 'away', coalesce(ps.pass_attempts_home, 0),
            0
        )), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * multiIf(
                tr.triggered_side = 'home', coalesce(ps.accurate_passes_home, 0),
                tr.triggered_side = 'away', coalesce(ps.accurate_passes_away, 0),
                0
            )
            / nullIf(toFloat64(multiIf(
                tr.triggered_side = 'home', coalesce(ps.pass_attempts_home, 0),
                tr.triggered_side = 'away', coalesce(ps.pass_attempts_away, 0),
                0
            )), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * multiIf(
                tr.triggered_side = 'home', coalesce(ps.accurate_passes_away, 0),
                tr.triggered_side = 'away', coalesce(ps.accurate_passes_home, 0),
                0
            )
            / nullIf(toFloat64(multiIf(
                tr.triggered_side = 'home', coalesce(ps.pass_attempts_away, 0),
                tr.triggered_side = 'away', coalesce(ps.pass_attempts_home, 0),
                0
            )), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    toInt32(multiIf(
        tr.triggered_side = 'home', coalesce(ps.touches_opp_box_home, 0),
        tr.triggered_side = 'away', coalesce(ps.touches_opp_box_away, 0),
        0
    )) AS triggered_team_touches_opposition_box,
    toInt32(multiIf(
        tr.triggered_side = 'home', coalesce(ps.touches_opp_box_away, 0),
        tr.triggered_side = 'away', coalesce(ps.touches_opp_box_home, 0),
        0
    )) AS opponent_touches_opposition_box,
    toInt32(
        multiIf(
            tr.triggered_side = 'home', coalesce(ps.touches_opp_box_home, 0),
            tr.triggered_side = 'away', coalesce(ps.touches_opp_box_away, 0),
            0
        ) - multiIf(
            tr.triggered_side = 'home', coalesce(ps.touches_opp_box_away, 0),
            tr.triggered_side = 'away', coalesce(ps.touches_opp_box_home, 0),
            0
        )
    ) AS opposition_box_touches_delta,

    toInt32(multiIf(
        tr.triggered_side = 'home', coalesce(ps.total_shots_home, 0),
        tr.triggered_side = 'away', coalesce(ps.total_shots_away, 0),
        0
    )) AS triggered_team_total_shots,
    toInt32(multiIf(
        tr.triggered_side = 'home', coalesce(ps.total_shots_away, 0),
        tr.triggered_side = 'away', coalesce(ps.total_shots_home, 0),
        0
    )) AS opponent_total_shots,
    toInt32(
        multiIf(
            tr.triggered_side = 'home', coalesce(ps.total_shots_home, 0),
            tr.triggered_side = 'away', coalesce(ps.total_shots_away, 0),
            0
        ) - multiIf(
            tr.triggered_side = 'home', coalesce(ps.total_shots_away, 0),
            tr.triggered_side = 'away', coalesce(ps.total_shots_home, 0),
            0
        )
    ) AS total_shots_delta,
    toInt32(multiIf(
        tr.triggered_side = 'home', coalesce(ps.shots_on_target_home, 0),
        tr.triggered_side = 'away', coalesce(ps.shots_on_target_away, 0),
        0
    )) AS triggered_team_shots_on_target,
    toInt32(multiIf(
        tr.triggered_side = 'home', coalesce(ps.shots_on_target_away, 0),
        tr.triggered_side = 'away', coalesce(ps.shots_on_target_home, 0),
        0
    )) AS opponent_shots_on_target,
    toInt32(
        multiIf(
            tr.triggered_side = 'home', coalesce(ps.shots_on_target_home, 0),
            tr.triggered_side = 'away', coalesce(ps.shots_on_target_away, 0),
            0
        ) - multiIf(
            tr.triggered_side = 'home', coalesce(ps.shots_on_target_away, 0),
            tr.triggered_side = 'away', coalesce(ps.shots_on_target_home, 0),
            0
        )
    ) AS shots_on_target_delta,

    toFloat32(multiIf(
        tr.triggered_side = 'home', coalesce(ps.expected_goals_home, 0.0),
        tr.triggered_side = 'away', coalesce(ps.expected_goals_away, 0.0),
        0.0
    )) AS triggered_team_xg,
    toFloat32(multiIf(
        tr.triggered_side = 'home', coalesce(ps.expected_goals_away, 0.0),
        tr.triggered_side = 'away', coalesce(ps.expected_goals_home, 0.0),
        0.0
    )) AS opponent_xg,
    toFloat32(round(
        multiIf(
            tr.triggered_side = 'home', coalesce(ps.expected_goals_home, 0.0),
            tr.triggered_side = 'away', coalesce(ps.expected_goals_away, 0.0),
            0.0
        ) - multiIf(
            tr.triggered_side = 'home', coalesce(ps.expected_goals_away, 0.0),
            tr.triggered_side = 'away', coalesce(ps.expected_goals_home, 0.0),
            0.0
        ),
        3
    )) AS xg_delta,

    toInt32(multiIf(
        tr.triggered_side = 'home', coalesce(tr.home_score, 0),
        tr.triggered_side = 'away', coalesce(tr.away_score, 0),
        0
    )) AS triggered_team_goals,
    toInt32(multiIf(
        tr.triggered_side = 'home', coalesce(tr.away_score, 0),
        tr.triggered_side = 'away', coalesce(tr.home_score, 0),
        0
    )) AS opponent_goals,
    toInt32(
        multiIf(
            tr.triggered_side = 'home', coalesce(tr.home_score, 0),
            tr.triggered_side = 'away', coalesce(tr.away_score, 0),
            0
        ) - multiIf(
            tr.triggered_side = 'home', coalesce(tr.away_score, 0),
            tr.triggered_side = 'away', coalesce(tr.home_score, 0),
            0
        )
    ) AS goal_delta,

    toFloat32(multiIf(
        tr.triggered_side = 'home', coalesce(ps.ball_possession_home, 0.0),
        tr.triggered_side = 'away', coalesce(ps.ball_possession_away, 0.0),
        0.0
    )) AS triggered_team_possession_pct,
    toFloat32(multiIf(
        tr.triggered_side = 'home', coalesce(ps.ball_possession_away, 0.0),
        tr.triggered_side = 'away', coalesce(ps.ball_possession_home, 0.0),
        0.0
    )) AS opponent_possession_pct,
    toFloat32(round(
        multiIf(
            tr.triggered_side = 'home', coalesce(ps.ball_possession_home, 0.0),
            tr.triggered_side = 'away', coalesce(ps.ball_possession_away, 0.0),
            0.0
        ) - multiIf(
            tr.triggered_side = 'home', coalesce(ps.ball_possession_away, 0.0),
            tr.triggered_side = 'away', coalesce(ps.ball_possession_home, 0.0),
            0.0
        ),
        1
    )) AS possession_delta_pct
FROM team_rows AS tr
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = tr.match_id
   AND ps.match_date = tr.match_date
   AND ps.period = 'All'
LEFT JOIN team_segment_rollup AS tsr
    ON tsr.match_id = tr.match_id
   AND tsr.team_id = tr.triggered_team_id
LEFT JOIN team_segment_rollup AS osr
    ON osr.match_id = tr.match_id
   AND osr.team_id = tr.opponent_team_id
LEFT JOIN team_playmaking_totals AS tpt
    ON tpt.match_id = tr.match_id
   AND tpt.team_id = tr.triggered_team_id
LEFT JOIN team_playmaking_totals AS opt
    ON opt.match_id = tr.match_id
   AND opt.team_id = tr.opponent_team_id
WHERE coalesce(tsr.key_pass_proxy_segments_hit_count, 0) >= 9
ORDER BY
    assumeNotNull(triggered_team_key_pass_proxy_segments_hit_count) DESC,
    assumeNotNull(triggered_team_key_pass_proxy_total) DESC,
    tr.match_date DESC,
    tr.match_id DESC;
