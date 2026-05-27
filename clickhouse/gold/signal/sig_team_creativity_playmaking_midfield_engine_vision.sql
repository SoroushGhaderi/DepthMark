INSERT INTO gold.sig_team_creativity_playmaking_midfield_engine_vision (
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
    trigger_threshold_min_midfielder_expected_assists,
    trigger_threshold_required_usual_playing_position_id,
    triggered_team_midfielder_count,
    opponent_midfielder_count,
    midfielder_count_delta,
    triggered_team_midfielders_with_expected_assists,
    opponent_midfielders_with_expected_assists,
    midfielders_with_expected_assists_delta,
    triggered_team_midfielder_expected_assists,
    opponent_midfielder_expected_assists,
    midfielder_expected_assists_delta,
    triggered_team_midfielder_expected_assists_above_threshold,
    triggered_team_midfielder_expected_assists_share_of_team_expected_assists_pct,
    opponent_midfielder_expected_assists_share_of_team_expected_assists_pct,
    midfielder_expected_assists_share_of_team_expected_assists_delta_pct,
    triggered_team_midfielder_key_passes,
    opponent_midfielder_key_passes,
    midfielder_key_passes_delta,
    triggered_team_total_key_passes,
    opponent_total_key_passes,
    total_key_passes_delta,
    triggered_team_expected_assists,
    opponent_expected_assists,
    expected_assists_delta,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
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
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct
)
-- Signal: sig_team_creativity_playmaking_midfield_engine_vision
-- Trigger: Team midfielders combine for >= 1.5 expected assists (xA) in one finished match.
-- Intent: surface team-level chance creation directed by midfield units, then profile bilateral
--         passing quality, final-third penetration, and shot-output context.
WITH player_roles AS (
    SELECT
        mp.match_id,
        toInt32(mp.primary_team_id) AS team_id,
        toInt32(mp.person_id) AS player_id,
        argMax(coalesce(mp.usual_playing_position_id, 0), if(mp.role = 'starter', 2, 1))
            AS usual_playing_position_id
    FROM silver.match_personnel AS mp
    WHERE mp.match_id > 0
      AND mp.primary_team_id > 0
      AND mp.person_id > 0
      AND mp.role IN ('starter', 'substitute')
    GROUP BY
        mp.match_id,
        team_id,
        player_id
),
player_playmaking AS (
    SELECT
        p.match_id,
        toInt32(p.team_id) AS team_id,
        toInt32(p.player_id) AS player_id,
        toInt32(max(coalesce(p.chances_created, 0))) AS player_key_passes,
        toFloat32(max(coalesce(p.expected_assists, 0.0))) AS player_expected_assists
    FROM silver.player_match_stat AS p
    WHERE p.match_id > 0
      AND p.team_id > 0
      AND p.player_id > 0
    GROUP BY
        p.match_id,
        team_id,
        player_id
),
team_total_playmaking AS (
    SELECT
        pp.match_id,
        pp.team_id,
        toInt32(sum(coalesce(pp.player_key_passes, 0))) AS team_total_key_passes,
        toFloat32(round(sum(coalesce(pp.player_expected_assists, 0.0)), 3)) AS team_expected_assists
    FROM player_playmaking AS pp
    GROUP BY
        pp.match_id,
        pp.team_id
),
team_midfield_playmaking AS (
    SELECT
        pr.match_id,
        pr.team_id,
        toInt32(count()) AS team_midfielder_count,
        toInt32(countIf(coalesce(pp.player_expected_assists, 0.0) > 0.0))
            AS team_midfielders_with_expected_assists,
        toFloat32(round(sum(coalesce(pp.player_expected_assists, 0.0)), 3))
            AS team_midfielder_expected_assists,
        toInt32(sum(coalesce(pp.player_key_passes, 0))) AS team_midfielder_key_passes
    FROM player_roles AS pr
    LEFT JOIN player_playmaking AS pp
        ON pp.match_id = pr.match_id
       AND pp.team_id = pr.team_id
       AND pp.player_id = pr.player_id
    WHERE coalesce(pr.usual_playing_position_id, 0) = 2
    GROUP BY
        pr.match_id,
        pr.team_id
)

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

    toFloat32(1.5) AS trigger_threshold_min_midfielder_expected_assists,
    toInt32(2) AS trigger_threshold_required_usual_playing_position_id,

    toInt32(coalesce(hm.team_midfielder_count, 0)) AS triggered_team_midfielder_count,
    toInt32(coalesce(am.team_midfielder_count, 0)) AS opponent_midfielder_count,
    toInt32(coalesce(hm.team_midfielder_count, 0) - coalesce(am.team_midfielder_count, 0))
        AS midfielder_count_delta,

    toInt32(coalesce(hm.team_midfielders_with_expected_assists, 0))
        AS triggered_team_midfielders_with_expected_assists,
    toInt32(coalesce(am.team_midfielders_with_expected_assists, 0))
        AS opponent_midfielders_with_expected_assists,
    toInt32(
        coalesce(hm.team_midfielders_with_expected_assists, 0)
      - coalesce(am.team_midfielders_with_expected_assists, 0)
    ) AS midfielders_with_expected_assists_delta,

    toFloat32(coalesce(hm.team_midfielder_expected_assists, 0.0))
        AS triggered_team_midfielder_expected_assists,
    toFloat32(coalesce(am.team_midfielder_expected_assists, 0.0))
        AS opponent_midfielder_expected_assists,
    toFloat32(round(
        coalesce(hm.team_midfielder_expected_assists, 0.0)
      - coalesce(am.team_midfielder_expected_assists, 0.0),
        3
    )) AS midfielder_expected_assists_delta,
    toFloat32(round(
        coalesce(hm.team_midfielder_expected_assists, 0.0) - 1.5,
        3
    )) AS triggered_team_midfielder_expected_assists_above_threshold,
    toFloat32(coalesce(round(
        100.0 * coalesce(hm.team_midfielder_expected_assists, 0.0)
            / nullIf(toFloat64(coalesce(ht.team_expected_assists, 0.0)), 0.0),
        1
    ), 0.0)) AS triggered_team_midfielder_expected_assists_share_of_team_expected_assists_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(am.team_midfielder_expected_assists, 0.0)
            / nullIf(toFloat64(coalesce(at.team_expected_assists, 0.0)), 0.0),
        1
    ), 0.0)) AS opponent_midfielder_expected_assists_share_of_team_expected_assists_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(hm.team_midfielder_expected_assists, 0.0)
                / nullIf(toFloat64(coalesce(ht.team_expected_assists, 0.0)), 0.0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(am.team_midfielder_expected_assists, 0.0)
                / nullIf(toFloat64(coalesce(at.team_expected_assists, 0.0)), 0.0),
            1
        ), 0.0),
        1
    )) AS midfielder_expected_assists_share_of_team_expected_assists_delta_pct,

    toInt32(coalesce(hm.team_midfielder_key_passes, 0)) AS triggered_team_midfielder_key_passes,
    toInt32(coalesce(am.team_midfielder_key_passes, 0)) AS opponent_midfielder_key_passes,
    toInt32(coalesce(hm.team_midfielder_key_passes, 0) - coalesce(am.team_midfielder_key_passes, 0))
        AS midfielder_key_passes_delta,

    toInt32(coalesce(ht.team_total_key_passes, 0)) AS triggered_team_total_key_passes,
    toInt32(coalesce(at.team_total_key_passes, 0)) AS opponent_total_key_passes,
    toInt32(coalesce(ht.team_total_key_passes, 0) - coalesce(at.team_total_key_passes, 0))
        AS total_key_passes_delta,

    toFloat32(coalesce(ht.team_expected_assists, 0.0)) AS triggered_team_expected_assists,
    toFloat32(coalesce(at.team_expected_assists, 0.0)) AS opponent_expected_assists,
    toFloat32(round(coalesce(ht.team_expected_assists, 0.0) - coalesce(at.team_expected_assists, 0.0), 3))
        AS expected_assists_delta,

    toInt32(coalesce(m.home_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.away_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.home_score, 0) - coalesce(m.away_score, 0)) AS goal_delta,

    toInt32(coalesce(ps.pass_attempts_home, 0)) AS triggered_team_pass_attempts,
    toInt32(coalesce(ps.pass_attempts_away, 0)) AS opponent_pass_attempts,
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

    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_home, 0.0) - coalesce(ps.expected_goals_away, 0.0), 3))
        AS xg_delta,
    toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_home, 0.0) - coalesce(ps.ball_possession_away, 0.0), 1))
        AS possession_delta_pct

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN team_midfield_playmaking AS hm
    ON hm.match_id = m.match_id
   AND hm.team_id = m.home_team_id
LEFT JOIN team_midfield_playmaking AS am
    ON am.match_id = m.match_id
   AND am.team_id = m.away_team_id
LEFT JOIN team_total_playmaking AS ht
    ON ht.match_id = m.match_id
   AND ht.team_id = m.home_team_id
LEFT JOIN team_total_playmaking AS at
    ON at.match_id = m.match_id
   AND at.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(hm.team_midfielder_expected_assists, 0.0) >= 1.5

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

    toFloat32(1.5) AS trigger_threshold_min_midfielder_expected_assists,
    toInt32(2) AS trigger_threshold_required_usual_playing_position_id,

    toInt32(coalesce(am.team_midfielder_count, 0)) AS triggered_team_midfielder_count,
    toInt32(coalesce(hm.team_midfielder_count, 0)) AS opponent_midfielder_count,
    toInt32(coalesce(am.team_midfielder_count, 0) - coalesce(hm.team_midfielder_count, 0))
        AS midfielder_count_delta,

    toInt32(coalesce(am.team_midfielders_with_expected_assists, 0))
        AS triggered_team_midfielders_with_expected_assists,
    toInt32(coalesce(hm.team_midfielders_with_expected_assists, 0))
        AS opponent_midfielders_with_expected_assists,
    toInt32(
        coalesce(am.team_midfielders_with_expected_assists, 0)
      - coalesce(hm.team_midfielders_with_expected_assists, 0)
    ) AS midfielders_with_expected_assists_delta,

    toFloat32(coalesce(am.team_midfielder_expected_assists, 0.0))
        AS triggered_team_midfielder_expected_assists,
    toFloat32(coalesce(hm.team_midfielder_expected_assists, 0.0))
        AS opponent_midfielder_expected_assists,
    toFloat32(round(
        coalesce(am.team_midfielder_expected_assists, 0.0)
      - coalesce(hm.team_midfielder_expected_assists, 0.0),
        3
    )) AS midfielder_expected_assists_delta,
    toFloat32(round(
        coalesce(am.team_midfielder_expected_assists, 0.0) - 1.5,
        3
    )) AS triggered_team_midfielder_expected_assists_above_threshold,
    toFloat32(coalesce(round(
        100.0 * coalesce(am.team_midfielder_expected_assists, 0.0)
            / nullIf(toFloat64(coalesce(at.team_expected_assists, 0.0)), 0.0),
        1
    ), 0.0)) AS triggered_team_midfielder_expected_assists_share_of_team_expected_assists_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(hm.team_midfielder_expected_assists, 0.0)
            / nullIf(toFloat64(coalesce(ht.team_expected_assists, 0.0)), 0.0),
        1
    ), 0.0)) AS opponent_midfielder_expected_assists_share_of_team_expected_assists_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(am.team_midfielder_expected_assists, 0.0)
                / nullIf(toFloat64(coalesce(at.team_expected_assists, 0.0)), 0.0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(hm.team_midfielder_expected_assists, 0.0)
                / nullIf(toFloat64(coalesce(ht.team_expected_assists, 0.0)), 0.0),
            1
        ), 0.0),
        1
    )) AS midfielder_expected_assists_share_of_team_expected_assists_delta_pct,

    toInt32(coalesce(am.team_midfielder_key_passes, 0)) AS triggered_team_midfielder_key_passes,
    toInt32(coalesce(hm.team_midfielder_key_passes, 0)) AS opponent_midfielder_key_passes,
    toInt32(coalesce(am.team_midfielder_key_passes, 0) - coalesce(hm.team_midfielder_key_passes, 0))
        AS midfielder_key_passes_delta,

    toInt32(coalesce(at.team_total_key_passes, 0)) AS triggered_team_total_key_passes,
    toInt32(coalesce(ht.team_total_key_passes, 0)) AS opponent_total_key_passes,
    toInt32(coalesce(at.team_total_key_passes, 0) - coalesce(ht.team_total_key_passes, 0))
        AS total_key_passes_delta,

    toFloat32(coalesce(at.team_expected_assists, 0.0)) AS triggered_team_expected_assists,
    toFloat32(coalesce(ht.team_expected_assists, 0.0)) AS opponent_expected_assists,
    toFloat32(round(coalesce(at.team_expected_assists, 0.0) - coalesce(ht.team_expected_assists, 0.0), 3))
        AS expected_assists_delta,

    toInt32(coalesce(m.away_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.home_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.away_score, 0) - coalesce(m.home_score, 0)) AS goal_delta,

    toInt32(coalesce(ps.pass_attempts_away, 0)) AS triggered_team_pass_attempts,
    toInt32(coalesce(ps.pass_attempts_home, 0)) AS opponent_pass_attempts,
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

    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_away, 0.0) - coalesce(ps.expected_goals_home, 0.0), 3))
        AS xg_delta,
    toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_away, 0.0) - coalesce(ps.ball_possession_home, 0.0), 1))
        AS possession_delta_pct

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN team_midfield_playmaking AS hm
    ON hm.match_id = m.match_id
   AND hm.team_id = m.home_team_id
LEFT JOIN team_midfield_playmaking AS am
    ON am.match_id = m.match_id
   AND am.team_id = m.away_team_id
LEFT JOIN team_total_playmaking AS ht
    ON ht.match_id = m.match_id
   AND ht.team_id = m.home_team_id
LEFT JOIN team_total_playmaking AS at
    ON at.match_id = m.match_id
   AND at.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(am.team_midfielder_expected_assists, 0.0) >= 1.5

ORDER BY
    assumeNotNull(triggered_team_midfielder_expected_assists) DESC,
    assumeNotNull(triggered_team_midfielder_expected_assists_share_of_team_expected_assists_pct) DESC,
    m.match_date DESC,
    m.match_id DESC;
