INSERT INTO gold.sig_team_creativity_playmaking_bench_creative_impact (
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
    trigger_threshold_min_substitute_key_passes,
    trigger_threshold_min_substitute_assists,
    triggered_team_substitute_key_passes,
    opponent_substitute_key_passes,
    substitute_key_passes_delta,
    triggered_team_substitute_assists,
    opponent_substitute_assists,
    substitute_assists_delta,
    triggered_team_substitute_expected_assists,
    opponent_substitute_expected_assists,
    substitute_expected_assists_delta,
    triggered_team_distinct_substitute_key_pass_creators,
    opponent_distinct_substitute_key_pass_creators,
    distinct_substitute_key_pass_creators_delta,
    triggered_team_distinct_substitute_assist_providers,
    opponent_distinct_substitute_assist_providers,
    distinct_substitute_assist_providers_delta,
    triggered_team_top_substitute_key_passes,
    opponent_top_substitute_key_passes,
    top_substitute_key_passes_delta,
    triggered_team_total_key_passes,
    opponent_total_key_passes,
    total_key_passes_delta,
    triggered_team_total_assists,
    opponent_total_assists,
    total_assists_delta,
    triggered_team_total_expected_assists,
    opponent_total_expected_assists,
    total_expected_assists_delta,
    triggered_team_substitute_key_pass_share_pct,
    opponent_substitute_key_pass_share_pct,
    substitute_key_pass_share_delta_pct,
    triggered_team_substitute_assist_share_pct,
    opponent_substitute_assist_share_pct,
    substitute_assist_share_delta_pct,
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
    expected_goals_delta,
    triggered_team_goals,
    opponent_goals,
    goal_delta
)
WITH substitute_entries AS (
    SELECT
        mp.match_id,
        toInt32(assumeNotNull(mp.person_id)) AS player_id,
        toInt32(max(coalesce(mp.substitution_time, 0))) AS substitution_time
    FROM silver.match_personnel AS mp
    WHERE mp.match_id > 0
      AND mp.person_id IS NOT NULL
      AND lowerUTF8(coalesce(mp.role, '')) = 'substitute'
      AND coalesce(mp.substitution_time, 0) > 0
    GROUP BY
        mp.match_id,
        player_id
),
substitute_playmaking_stats AS (
    SELECT
        p.match_id,
        toInt32(p.team_id) AS team_id,
        toInt32(p.player_id) AS player_id,
        toInt32(sum(coalesce(p.chances_created, 0))) AS substitute_key_passes,
        toInt32(sum(coalesce(p.assists, 0))) AS substitute_assists,
        toFloat32(round(sum(coalesce(p.expected_assists, 0.0)), 3)) AS substitute_expected_assists
    FROM silver.player_match_stat AS p
    INNER JOIN substitute_entries AS se
        ON se.match_id = p.match_id
       AND se.player_id = p.player_id
    WHERE p.match_id > 0
      AND coalesce(p.team_id, 0) > 0
    GROUP BY
        p.match_id,
        team_id,
        player_id
),
team_substitute_playmaking_rollup AS (
    SELECT
        sps.match_id,
        sps.team_id,
        toInt32(sum(sps.substitute_key_passes)) AS team_substitute_key_passes,
        toInt32(sum(sps.substitute_assists)) AS team_substitute_assists,
        toFloat32(round(sum(sps.substitute_expected_assists), 3)) AS team_substitute_expected_assists,
        toInt32(countIf(sps.substitute_key_passes > 0)) AS team_distinct_substitute_key_pass_creators,
        toInt32(countIf(sps.substitute_assists > 0)) AS team_distinct_substitute_assist_providers,
        toInt32(max(sps.substitute_key_passes)) AS team_top_substitute_key_passes
    FROM substitute_playmaking_stats AS sps
    GROUP BY
        sps.match_id,
        sps.team_id
),
team_total_playmaking_rollup AS (
    SELECT
        p.match_id,
        toInt32(p.team_id) AS team_id,
        toInt32(sum(coalesce(p.chances_created, 0))) AS team_total_key_passes,
        toInt32(sum(coalesce(p.assists, 0))) AS team_total_assists,
        toFloat32(round(sum(coalesce(p.expected_assists, 0.0)), 3)) AS team_total_expected_assists
    FROM silver.player_match_stat AS p
    WHERE p.match_id > 0
      AND coalesce(p.team_id, 0) > 0
    GROUP BY
        p.match_id,
        team_id
)
-- Signal: sig_team_creativity_playmaking_bench_creative_impact
-- Trigger: Substitutes provide >= 2 key passes and >= 1 assist in one finished match.
-- Intent: Capture team-level bench playmaking impact where substitute creators materially
--         contribute both chance volume and direct goal creation, with bilateral context.

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

    toInt32(2) AS trigger_threshold_min_substitute_key_passes,
    toInt32(1) AS trigger_threshold_min_substitute_assists,

    toInt32(coalesce(home_sub.team_substitute_key_passes, 0)) AS triggered_team_substitute_key_passes,
    toInt32(coalesce(away_sub.team_substitute_key_passes, 0)) AS opponent_substitute_key_passes,
    toInt32(
        coalesce(home_sub.team_substitute_key_passes, 0)
      - coalesce(away_sub.team_substitute_key_passes, 0)
    ) AS substitute_key_passes_delta,

    toInt32(coalesce(home_sub.team_substitute_assists, 0)) AS triggered_team_substitute_assists,
    toInt32(coalesce(away_sub.team_substitute_assists, 0)) AS opponent_substitute_assists,
    toInt32(
        coalesce(home_sub.team_substitute_assists, 0)
      - coalesce(away_sub.team_substitute_assists, 0)
    ) AS substitute_assists_delta,

    toFloat32(coalesce(home_sub.team_substitute_expected_assists, 0.0))
        AS triggered_team_substitute_expected_assists,
    toFloat32(coalesce(away_sub.team_substitute_expected_assists, 0.0))
        AS opponent_substitute_expected_assists,
    toFloat32(round(
        coalesce(home_sub.team_substitute_expected_assists, 0.0)
      - coalesce(away_sub.team_substitute_expected_assists, 0.0),
        3
    )) AS substitute_expected_assists_delta,

    toInt32(coalesce(home_sub.team_distinct_substitute_key_pass_creators, 0))
        AS triggered_team_distinct_substitute_key_pass_creators,
    toInt32(coalesce(away_sub.team_distinct_substitute_key_pass_creators, 0))
        AS opponent_distinct_substitute_key_pass_creators,
    toInt32(
        coalesce(home_sub.team_distinct_substitute_key_pass_creators, 0)
      - coalesce(away_sub.team_distinct_substitute_key_pass_creators, 0)
    ) AS distinct_substitute_key_pass_creators_delta,

    toInt32(coalesce(home_sub.team_distinct_substitute_assist_providers, 0))
        AS triggered_team_distinct_substitute_assist_providers,
    toInt32(coalesce(away_sub.team_distinct_substitute_assist_providers, 0))
        AS opponent_distinct_substitute_assist_providers,
    toInt32(
        coalesce(home_sub.team_distinct_substitute_assist_providers, 0)
      - coalesce(away_sub.team_distinct_substitute_assist_providers, 0)
    ) AS distinct_substitute_assist_providers_delta,

    toInt32(coalesce(home_sub.team_top_substitute_key_passes, 0))
        AS triggered_team_top_substitute_key_passes,
    toInt32(coalesce(away_sub.team_top_substitute_key_passes, 0))
        AS opponent_top_substitute_key_passes,
    toInt32(
        coalesce(home_sub.team_top_substitute_key_passes, 0)
      - coalesce(away_sub.team_top_substitute_key_passes, 0)
    ) AS top_substitute_key_passes_delta,

    toInt32(coalesce(home_tot.team_total_key_passes, 0)) AS triggered_team_total_key_passes,
    toInt32(coalesce(away_tot.team_total_key_passes, 0)) AS opponent_total_key_passes,
    toInt32(
        coalesce(home_tot.team_total_key_passes, 0)
      - coalesce(away_tot.team_total_key_passes, 0)
    ) AS total_key_passes_delta,

    toInt32(coalesce(home_tot.team_total_assists, 0)) AS triggered_team_total_assists,
    toInt32(coalesce(away_tot.team_total_assists, 0)) AS opponent_total_assists,
    toInt32(
        coalesce(home_tot.team_total_assists, 0)
      - coalesce(away_tot.team_total_assists, 0)
    ) AS total_assists_delta,

    toFloat32(coalesce(home_tot.team_total_expected_assists, 0.0)) AS triggered_team_total_expected_assists,
    toFloat32(coalesce(away_tot.team_total_expected_assists, 0.0)) AS opponent_total_expected_assists,
    toFloat32(round(
        coalesce(home_tot.team_total_expected_assists, 0.0)
      - coalesce(away_tot.team_total_expected_assists, 0.0),
        3
    )) AS total_expected_assists_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(home_sub.team_substitute_key_passes, 0)
        / nullIf(toFloat64(coalesce(home_tot.team_total_key_passes, 0)), 0),
        1
    ), 0.0)) AS triggered_team_substitute_key_pass_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(away_sub.team_substitute_key_passes, 0)
        / nullIf(toFloat64(coalesce(away_tot.team_total_key_passes, 0)), 0),
        1
    ), 0.0)) AS opponent_substitute_key_pass_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(home_sub.team_substitute_key_passes, 0)
            / nullIf(toFloat64(coalesce(home_tot.team_total_key_passes, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(away_sub.team_substitute_key_passes, 0)
            / nullIf(toFloat64(coalesce(away_tot.team_total_key_passes, 0)), 0),
            1
        ), 0.0),
        1
    )) AS substitute_key_pass_share_delta_pct,

    toFloat32(coalesce(round(
        100.0 * coalesce(home_sub.team_substitute_assists, 0)
        / nullIf(toFloat64(coalesce(home_tot.team_total_assists, 0)), 0),
        1
    ), 0.0)) AS triggered_team_substitute_assist_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(away_sub.team_substitute_assists, 0)
        / nullIf(toFloat64(coalesce(away_tot.team_total_assists, 0)), 0),
        1
    ), 0.0)) AS opponent_substitute_assist_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(home_sub.team_substitute_assists, 0)
            / nullIf(toFloat64(coalesce(home_tot.team_total_assists, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(away_sub.team_substitute_assists, 0)
            / nullIf(toFloat64(coalesce(away_tot.team_total_assists, 0)), 0),
            1
        ), 0.0),
        1
    )) AS substitute_assist_share_delta_pct,

    toInt32(coalesce(ps.pass_attempts_home, 0)) AS triggered_team_pass_attempts,
    toInt32(coalesce(ps.pass_attempts_away, 0)) AS opponent_pass_attempts,
    toInt32(coalesce(ps.accurate_passes_home, 0)) AS triggered_team_accurate_passes,
    toInt32(coalesce(ps.accurate_passes_away, 0)) AS opponent_accurate_passes,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0)
        / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0)
        / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
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
    toInt32(
        coalesce(ps.touches_opp_box_home, 0)
      - coalesce(ps.touches_opp_box_away, 0)
    ) AS opposition_box_touches_delta,

    toInt32(coalesce(ps.total_shots_home, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_away, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS opponent_shots_on_target,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS triggered_team_expected_goals,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS opponent_expected_goals,
    toFloat32(round(
        coalesce(ps.expected_goals_home, 0.0) - coalesce(ps.expected_goals_away, 0.0),
        3
    )) AS expected_goals_delta,

    toInt32(coalesce(m.home_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.away_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.home_score, 0) - coalesce(m.away_score, 0)) AS goal_delta

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN team_substitute_playmaking_rollup AS home_sub
    ON home_sub.match_id = m.match_id
   AND home_sub.team_id = m.home_team_id
LEFT JOIN team_substitute_playmaking_rollup AS away_sub
    ON away_sub.match_id = m.match_id
   AND away_sub.team_id = m.away_team_id
LEFT JOIN team_total_playmaking_rollup AS home_tot
    ON home_tot.match_id = m.match_id
   AND home_tot.team_id = m.home_team_id
LEFT JOIN team_total_playmaking_rollup AS away_tot
    ON away_tot.match_id = m.match_id
   AND away_tot.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(home_sub.team_substitute_key_passes, 0) >= 2
  AND coalesce(home_sub.team_substitute_assists, 0) >= 1

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

    toInt32(2) AS trigger_threshold_min_substitute_key_passes,
    toInt32(1) AS trigger_threshold_min_substitute_assists,

    toInt32(coalesce(away_sub.team_substitute_key_passes, 0)) AS triggered_team_substitute_key_passes,
    toInt32(coalesce(home_sub.team_substitute_key_passes, 0)) AS opponent_substitute_key_passes,
    toInt32(
        coalesce(away_sub.team_substitute_key_passes, 0)
      - coalesce(home_sub.team_substitute_key_passes, 0)
    ) AS substitute_key_passes_delta,

    toInt32(coalesce(away_sub.team_substitute_assists, 0)) AS triggered_team_substitute_assists,
    toInt32(coalesce(home_sub.team_substitute_assists, 0)) AS opponent_substitute_assists,
    toInt32(
        coalesce(away_sub.team_substitute_assists, 0)
      - coalesce(home_sub.team_substitute_assists, 0)
    ) AS substitute_assists_delta,

    toFloat32(coalesce(away_sub.team_substitute_expected_assists, 0.0))
        AS triggered_team_substitute_expected_assists,
    toFloat32(coalesce(home_sub.team_substitute_expected_assists, 0.0))
        AS opponent_substitute_expected_assists,
    toFloat32(round(
        coalesce(away_sub.team_substitute_expected_assists, 0.0)
      - coalesce(home_sub.team_substitute_expected_assists, 0.0),
        3
    )) AS substitute_expected_assists_delta,

    toInt32(coalesce(away_sub.team_distinct_substitute_key_pass_creators, 0))
        AS triggered_team_distinct_substitute_key_pass_creators,
    toInt32(coalesce(home_sub.team_distinct_substitute_key_pass_creators, 0))
        AS opponent_distinct_substitute_key_pass_creators,
    toInt32(
        coalesce(away_sub.team_distinct_substitute_key_pass_creators, 0)
      - coalesce(home_sub.team_distinct_substitute_key_pass_creators, 0)
    ) AS distinct_substitute_key_pass_creators_delta,

    toInt32(coalesce(away_sub.team_distinct_substitute_assist_providers, 0))
        AS triggered_team_distinct_substitute_assist_providers,
    toInt32(coalesce(home_sub.team_distinct_substitute_assist_providers, 0))
        AS opponent_distinct_substitute_assist_providers,
    toInt32(
        coalesce(away_sub.team_distinct_substitute_assist_providers, 0)
      - coalesce(home_sub.team_distinct_substitute_assist_providers, 0)
    ) AS distinct_substitute_assist_providers_delta,

    toInt32(coalesce(away_sub.team_top_substitute_key_passes, 0))
        AS triggered_team_top_substitute_key_passes,
    toInt32(coalesce(home_sub.team_top_substitute_key_passes, 0))
        AS opponent_top_substitute_key_passes,
    toInt32(
        coalesce(away_sub.team_top_substitute_key_passes, 0)
      - coalesce(home_sub.team_top_substitute_key_passes, 0)
    ) AS top_substitute_key_passes_delta,

    toInt32(coalesce(away_tot.team_total_key_passes, 0)) AS triggered_team_total_key_passes,
    toInt32(coalesce(home_tot.team_total_key_passes, 0)) AS opponent_total_key_passes,
    toInt32(
        coalesce(away_tot.team_total_key_passes, 0)
      - coalesce(home_tot.team_total_key_passes, 0)
    ) AS total_key_passes_delta,

    toInt32(coalesce(away_tot.team_total_assists, 0)) AS triggered_team_total_assists,
    toInt32(coalesce(home_tot.team_total_assists, 0)) AS opponent_total_assists,
    toInt32(
        coalesce(away_tot.team_total_assists, 0)
      - coalesce(home_tot.team_total_assists, 0)
    ) AS total_assists_delta,

    toFloat32(coalesce(away_tot.team_total_expected_assists, 0.0)) AS triggered_team_total_expected_assists,
    toFloat32(coalesce(home_tot.team_total_expected_assists, 0.0)) AS opponent_total_expected_assists,
    toFloat32(round(
        coalesce(away_tot.team_total_expected_assists, 0.0)
      - coalesce(home_tot.team_total_expected_assists, 0.0),
        3
    )) AS total_expected_assists_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(away_sub.team_substitute_key_passes, 0)
        / nullIf(toFloat64(coalesce(away_tot.team_total_key_passes, 0)), 0),
        1
    ), 0.0)) AS triggered_team_substitute_key_pass_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(home_sub.team_substitute_key_passes, 0)
        / nullIf(toFloat64(coalesce(home_tot.team_total_key_passes, 0)), 0),
        1
    ), 0.0)) AS opponent_substitute_key_pass_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(away_sub.team_substitute_key_passes, 0)
            / nullIf(toFloat64(coalesce(away_tot.team_total_key_passes, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(home_sub.team_substitute_key_passes, 0)
            / nullIf(toFloat64(coalesce(home_tot.team_total_key_passes, 0)), 0),
            1
        ), 0.0),
        1
    )) AS substitute_key_pass_share_delta_pct,

    toFloat32(coalesce(round(
        100.0 * coalesce(away_sub.team_substitute_assists, 0)
        / nullIf(toFloat64(coalesce(away_tot.team_total_assists, 0)), 0),
        1
    ), 0.0)) AS triggered_team_substitute_assist_share_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(home_sub.team_substitute_assists, 0)
        / nullIf(toFloat64(coalesce(home_tot.team_total_assists, 0)), 0),
        1
    ), 0.0)) AS opponent_substitute_assist_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(away_sub.team_substitute_assists, 0)
            / nullIf(toFloat64(coalesce(away_tot.team_total_assists, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(home_sub.team_substitute_assists, 0)
            / nullIf(toFloat64(coalesce(home_tot.team_total_assists, 0)), 0),
            1
        ), 0.0),
        1
    )) AS substitute_assist_share_delta_pct,

    toInt32(coalesce(ps.pass_attempts_away, 0)) AS triggered_team_pass_attempts,
    toInt32(coalesce(ps.pass_attempts_home, 0)) AS opponent_pass_attempts,
    toInt32(coalesce(ps.accurate_passes_away, 0)) AS triggered_team_accurate_passes,
    toInt32(coalesce(ps.accurate_passes_home, 0)) AS opponent_accurate_passes,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0)
        / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0)
        / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
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
    toInt32(
        coalesce(ps.touches_opp_box_away, 0)
      - coalesce(ps.touches_opp_box_home, 0)
    ) AS opposition_box_touches_delta,

    toInt32(coalesce(ps.total_shots_away, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_home, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS opponent_shots_on_target,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS triggered_team_expected_goals,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS opponent_expected_goals,
    toFloat32(round(
        coalesce(ps.expected_goals_away, 0.0) - coalesce(ps.expected_goals_home, 0.0),
        3
    )) AS expected_goals_delta,

    toInt32(coalesce(m.away_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.home_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.away_score, 0) - coalesce(m.home_score, 0)) AS goal_delta

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN team_substitute_playmaking_rollup AS home_sub
    ON home_sub.match_id = m.match_id
   AND home_sub.team_id = m.home_team_id
LEFT JOIN team_substitute_playmaking_rollup AS away_sub
    ON away_sub.match_id = m.match_id
   AND away_sub.team_id = m.away_team_id
LEFT JOIN team_total_playmaking_rollup AS home_tot
    ON home_tot.match_id = m.match_id
   AND home_tot.team_id = m.home_team_id
LEFT JOIN team_total_playmaking_rollup AS away_tot
    ON away_tot.match_id = m.match_id
   AND away_tot.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(away_sub.team_substitute_key_passes, 0) >= 2
  AND coalesce(away_sub.team_substitute_assists, 0) >= 1;
