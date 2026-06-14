INSERT INTO gold.sig_team_creativity_playmaking_set_piece_threat_volume (
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
    trigger_threshold_min_dead_ball_chances,
    triggered_team_dead_ball_chances,
    opponent_dead_ball_chances,
    dead_ball_chances_delta,
    triggered_team_dead_ball_expected_goals,
    opponent_dead_ball_expected_goals,
    dead_ball_expected_goals_delta,
    triggered_team_dead_ball_shots_on_target,
    opponent_dead_ball_shots_on_target,
    dead_ball_shots_on_target_delta,
    triggered_team_dead_ball_shot_accuracy_pct,
    opponent_dead_ball_shot_accuracy_pct,
    dead_ball_shot_accuracy_delta_pct,
    triggered_team_dead_ball_goals,
    opponent_dead_ball_goals,
    dead_ball_goals_delta,
    triggered_team_dead_ball_chance_conversion_pct,
    opponent_dead_ball_chance_conversion_pct,
    dead_ball_chance_conversion_delta_pct,
    triggered_team_set_play_expected_goals,
    opponent_set_play_expected_goals,
    set_play_expected_goals_delta,
    triggered_team_key_passes,
    opponent_key_passes,
    key_pass_delta,
    triggered_team_expected_assists,
    opponent_expected_assists,
    expected_assists_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_dead_ball_chance_share_of_total_shots_pct,
    opponent_dead_ball_chance_share_of_total_shots_pct,
    dead_ball_chance_share_of_total_shots_delta_pct,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    opposition_box_touches_delta,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_accurate_passes,
    opponent_accurate_passes,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct
)
WITH dead_ball_shot_stats AS (
    SELECT
        s.match_id,
        assumeNotNull(s.team_id) AS team_id,
        toInt32(count()) AS team_dead_ball_chances,
        toInt32(countIf(coalesce(s.is_on_target, 0) = 1)) AS team_dead_ball_shots_on_target,
        toInt32(countIf(
            coalesce(s.is_goal, 0) = 1
            AND coalesce(s.is_own_goal, 0) = 0
        )) AS team_dead_ball_goals,
        toFloat32(round(sum(coalesce(s.expected_goals, 0.0)), 3)) AS team_dead_ball_expected_goals
    FROM silver.shot AS s
    WHERE s.team_id IS NOT NULL
      AND coalesce(s.situation, '') IN ('FromCorner', 'FreeKick', 'SetPiece', 'ThrowInSetPiece')
    GROUP BY
        s.match_id,
        s.team_id
),
team_creation_stats AS (
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
)
-- Signal: sig_team_creativity_playmaking_set_piece_threat_volume
-- Trigger: Team creates >= 8 chances from dead-ball situations in a finished match.
-- Intent: identify team-level set-piece creation surges and profile whether dead-ball chance
--         volume translated into quality, conversion, and broader playmaking control.

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

    toInt32(8) AS trigger_threshold_min_dead_ball_chances,
    toInt32(coalesce(hs.team_dead_ball_chances, 0)) AS triggered_team_dead_ball_chances,
    toInt32(coalesce(aw.team_dead_ball_chances, 0)) AS opponent_dead_ball_chances,
    toInt32(coalesce(hs.team_dead_ball_chances, 0) - coalesce(aw.team_dead_ball_chances, 0))
        AS dead_ball_chances_delta,

    toFloat32(coalesce(hs.team_dead_ball_expected_goals, 0.0)) AS triggered_team_dead_ball_expected_goals,
    toFloat32(coalesce(aw.team_dead_ball_expected_goals, 0.0)) AS opponent_dead_ball_expected_goals,
    toFloat32(round(
        coalesce(hs.team_dead_ball_expected_goals, 0.0) - coalesce(aw.team_dead_ball_expected_goals, 0.0),
        3
    )) AS dead_ball_expected_goals_delta,

    toInt32(coalesce(hs.team_dead_ball_shots_on_target, 0)) AS triggered_team_dead_ball_shots_on_target,
    toInt32(coalesce(aw.team_dead_ball_shots_on_target, 0)) AS opponent_dead_ball_shots_on_target,
    toInt32(
        coalesce(hs.team_dead_ball_shots_on_target, 0) - coalesce(aw.team_dead_ball_shots_on_target, 0)
    ) AS dead_ball_shots_on_target_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(hs.team_dead_ball_shots_on_target, 0)
        / nullIf(toFloat64(coalesce(hs.team_dead_ball_chances, 0)), 0),
        1
    ), 0.0)) AS triggered_team_dead_ball_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(aw.team_dead_ball_shots_on_target, 0)
        / nullIf(toFloat64(coalesce(aw.team_dead_ball_chances, 0)), 0),
        1
    ), 0.0)) AS opponent_dead_ball_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(hs.team_dead_ball_shots_on_target, 0)
            / nullIf(toFloat64(coalesce(hs.team_dead_ball_chances, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(aw.team_dead_ball_shots_on_target, 0)
            / nullIf(toFloat64(coalesce(aw.team_dead_ball_chances, 0)), 0),
            1
        ), 0.0),
        1
    )) AS dead_ball_shot_accuracy_delta_pct,

    toInt32(coalesce(hs.team_dead_ball_goals, 0)) AS triggered_team_dead_ball_goals,
    toInt32(coalesce(aw.team_dead_ball_goals, 0)) AS opponent_dead_ball_goals,
    toInt32(coalesce(hs.team_dead_ball_goals, 0) - coalesce(aw.team_dead_ball_goals, 0))
        AS dead_ball_goals_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(hs.team_dead_ball_goals, 0)
        / nullIf(toFloat64(coalesce(hs.team_dead_ball_chances, 0)), 0),
        1
    ), 0.0)) AS triggered_team_dead_ball_chance_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(aw.team_dead_ball_goals, 0)
        / nullIf(toFloat64(coalesce(aw.team_dead_ball_chances, 0)), 0),
        1
    ), 0.0)) AS opponent_dead_ball_chance_conversion_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(hs.team_dead_ball_goals, 0)
            / nullIf(toFloat64(coalesce(hs.team_dead_ball_chances, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(aw.team_dead_ball_goals, 0)
            / nullIf(toFloat64(coalesce(aw.team_dead_ball_chances, 0)), 0),
            1
        ), 0.0),
        1
    )) AS dead_ball_chance_conversion_delta_pct,

    toFloat32(coalesce(ps.expected_goals_set_play_home, 0.0)) AS triggered_team_set_play_expected_goals,
    toFloat32(coalesce(ps.expected_goals_set_play_away, 0.0)) AS opponent_set_play_expected_goals,
    toFloat32(round(
        coalesce(ps.expected_goals_set_play_home, 0.0) - coalesce(ps.expected_goals_set_play_away, 0.0),
        3
    )) AS set_play_expected_goals_delta,

    toInt32(coalesce(hc.team_key_passes, 0)) AS triggered_team_key_passes,
    toInt32(coalesce(ac.team_key_passes, 0)) AS opponent_key_passes,
    toInt32(coalesce(hc.team_key_passes, 0) - coalesce(ac.team_key_passes, 0)) AS key_pass_delta,
    toFloat32(coalesce(hc.team_expected_assists, 0.0)) AS triggered_team_expected_assists,
    toFloat32(coalesce(ac.team_expected_assists, 0.0)) AS opponent_expected_assists,
    toFloat32(round(
        coalesce(hc.team_expected_assists, 0.0) - coalesce(ac.team_expected_assists, 0.0),
        3
    )) AS expected_assists_delta,

    toInt32(coalesce(ps.total_shots_home, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_away, 0)) AS opponent_total_shots,
    toFloat32(coalesce(round(
        100.0 * coalesce(hs.team_dead_ball_chances, 0)
        / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_dead_ball_chance_share_of_total_shots_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(aw.team_dead_ball_chances, 0)
        / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        1
    ), 0.0)) AS opponent_dead_ball_chance_share_of_total_shots_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(hs.team_dead_ball_chances, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(aw.team_dead_ball_chances, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
            1
        ), 0.0),
        1
    )) AS dead_ball_chance_share_of_total_shots_delta_pct,

    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS opponent_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_home, 0) - coalesce(ps.touches_opp_box_away, 0))
        AS opposition_box_touches_delta,

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
LEFT JOIN dead_ball_shot_stats AS hs
    ON hs.match_id = m.match_id
   AND hs.team_id = m.home_team_id
LEFT JOIN dead_ball_shot_stats AS aw
    ON aw.match_id = m.match_id
   AND aw.team_id = m.away_team_id
LEFT JOIN team_creation_stats AS hc
    ON hc.match_id = m.match_id
   AND hc.team_id = m.home_team_id
LEFT JOIN team_creation_stats AS ac
    ON ac.match_id = m.match_id
   AND ac.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(hs.team_dead_ball_chances, 0) >= 8

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

    toInt32(8) AS trigger_threshold_min_dead_ball_chances,
    toInt32(coalesce(aw.team_dead_ball_chances, 0)) AS triggered_team_dead_ball_chances,
    toInt32(coalesce(hs.team_dead_ball_chances, 0)) AS opponent_dead_ball_chances,
    toInt32(coalesce(aw.team_dead_ball_chances, 0) - coalesce(hs.team_dead_ball_chances, 0))
        AS dead_ball_chances_delta,

    toFloat32(coalesce(aw.team_dead_ball_expected_goals, 0.0)) AS triggered_team_dead_ball_expected_goals,
    toFloat32(coalesce(hs.team_dead_ball_expected_goals, 0.0)) AS opponent_dead_ball_expected_goals,
    toFloat32(round(
        coalesce(aw.team_dead_ball_expected_goals, 0.0) - coalesce(hs.team_dead_ball_expected_goals, 0.0),
        3
    )) AS dead_ball_expected_goals_delta,

    toInt32(coalesce(aw.team_dead_ball_shots_on_target, 0)) AS triggered_team_dead_ball_shots_on_target,
    toInt32(coalesce(hs.team_dead_ball_shots_on_target, 0)) AS opponent_dead_ball_shots_on_target,
    toInt32(
        coalesce(aw.team_dead_ball_shots_on_target, 0) - coalesce(hs.team_dead_ball_shots_on_target, 0)
    ) AS dead_ball_shots_on_target_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(aw.team_dead_ball_shots_on_target, 0)
        / nullIf(toFloat64(coalesce(aw.team_dead_ball_chances, 0)), 0),
        1
    ), 0.0)) AS triggered_team_dead_ball_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(hs.team_dead_ball_shots_on_target, 0)
        / nullIf(toFloat64(coalesce(hs.team_dead_ball_chances, 0)), 0),
        1
    ), 0.0)) AS opponent_dead_ball_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(aw.team_dead_ball_shots_on_target, 0)
            / nullIf(toFloat64(coalesce(aw.team_dead_ball_chances, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(hs.team_dead_ball_shots_on_target, 0)
            / nullIf(toFloat64(coalesce(hs.team_dead_ball_chances, 0)), 0),
            1
        ), 0.0),
        1
    )) AS dead_ball_shot_accuracy_delta_pct,

    toInt32(coalesce(aw.team_dead_ball_goals, 0)) AS triggered_team_dead_ball_goals,
    toInt32(coalesce(hs.team_dead_ball_goals, 0)) AS opponent_dead_ball_goals,
    toInt32(coalesce(aw.team_dead_ball_goals, 0) - coalesce(hs.team_dead_ball_goals, 0))
        AS dead_ball_goals_delta,

    toFloat32(coalesce(round(
        100.0 * coalesce(aw.team_dead_ball_goals, 0)
        / nullIf(toFloat64(coalesce(aw.team_dead_ball_chances, 0)), 0),
        1
    ), 0.0)) AS triggered_team_dead_ball_chance_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(hs.team_dead_ball_goals, 0)
        / nullIf(toFloat64(coalesce(hs.team_dead_ball_chances, 0)), 0),
        1
    ), 0.0)) AS opponent_dead_ball_chance_conversion_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(aw.team_dead_ball_goals, 0)
            / nullIf(toFloat64(coalesce(aw.team_dead_ball_chances, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(hs.team_dead_ball_goals, 0)
            / nullIf(toFloat64(coalesce(hs.team_dead_ball_chances, 0)), 0),
            1
        ), 0.0),
        1
    )) AS dead_ball_chance_conversion_delta_pct,

    toFloat32(coalesce(ps.expected_goals_set_play_away, 0.0)) AS triggered_team_set_play_expected_goals,
    toFloat32(coalesce(ps.expected_goals_set_play_home, 0.0)) AS opponent_set_play_expected_goals,
    toFloat32(round(
        coalesce(ps.expected_goals_set_play_away, 0.0) - coalesce(ps.expected_goals_set_play_home, 0.0),
        3
    )) AS set_play_expected_goals_delta,

    toInt32(coalesce(ac.team_key_passes, 0)) AS triggered_team_key_passes,
    toInt32(coalesce(hc.team_key_passes, 0)) AS opponent_key_passes,
    toInt32(coalesce(ac.team_key_passes, 0) - coalesce(hc.team_key_passes, 0)) AS key_pass_delta,
    toFloat32(coalesce(ac.team_expected_assists, 0.0)) AS triggered_team_expected_assists,
    toFloat32(coalesce(hc.team_expected_assists, 0.0)) AS opponent_expected_assists,
    toFloat32(round(
        coalesce(ac.team_expected_assists, 0.0) - coalesce(hc.team_expected_assists, 0.0),
        3
    )) AS expected_assists_delta,

    toInt32(coalesce(ps.total_shots_away, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_home, 0)) AS opponent_total_shots,
    toFloat32(coalesce(round(
        100.0 * coalesce(aw.team_dead_ball_chances, 0)
        / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_dead_ball_chance_share_of_total_shots_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(hs.team_dead_ball_chances, 0)
        / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        1
    ), 0.0)) AS opponent_dead_ball_chance_share_of_total_shots_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(aw.team_dead_ball_chances, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(hs.team_dead_ball_chances, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
            1
        ), 0.0),
        1
    )) AS dead_ball_chance_share_of_total_shots_delta_pct,

    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS opponent_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_away, 0) - coalesce(ps.touches_opp_box_home, 0))
        AS opposition_box_touches_delta,

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
LEFT JOIN dead_ball_shot_stats AS hs
    ON hs.match_id = m.match_id
   AND hs.team_id = m.home_team_id
LEFT JOIN dead_ball_shot_stats AS aw
    ON aw.match_id = m.match_id
   AND aw.team_id = m.away_team_id
LEFT JOIN team_creation_stats AS hc
    ON hc.match_id = m.match_id
   AND hc.team_id = m.home_team_id
LEFT JOIN team_creation_stats AS ac
    ON ac.match_id = m.match_id
   AND ac.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(aw.team_dead_ball_chances, 0) >= 8
