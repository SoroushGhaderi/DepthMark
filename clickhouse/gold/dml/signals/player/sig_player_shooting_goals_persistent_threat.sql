INSERT INTO gold.sig_player_shooting_goals_persistent_threat (
    match_id,
    match_date,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,
    triggered_side,
    triggered_player_id,
    triggered_player_name,
    triggered_team_id,
    triggered_team_name,
    opponent_team_id,
    opponent_team_name,
    trigger_threshold_min_shots_per_segment,
    trigger_threshold_segment_window_minutes,
    trigger_threshold_required_segment_count,
    triggered_player_shots_segment_00_15,
    triggered_player_shots_segment_16_30,
    triggered_player_shots_segment_31_45_plus,
    triggered_player_shots_segment_46_60,
    triggered_player_shots_segment_61_75,
    triggered_player_shots_segment_76_90_plus,
    triggered_player_shot_segments_hit_count,
    triggered_player_shot_segment_coverage_pct,
    triggered_player_goals,
    triggered_player_expected_goals,
    triggered_player_total_shots,
    triggered_player_shots_on_target,
    triggered_player_shot_accuracy_pct,
    triggered_player_shot_conversion_pct,
    triggered_player_expected_goals_per_shot,
    triggered_player_goal_minus_expected_goals,
    triggered_player_minutes_played,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_expected_goals,
    opponent_expected_goals,
    expected_goals_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    triggered_team_big_chances,
    opponent_big_chances,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    player_share_of_team_goals_pct,
    player_share_of_team_expected_goals_pct,
    player_share_of_team_total_shots_pct,
    player_share_of_team_shots_on_target_pct
)
-- Signal: sig_player_shooting_goals_persistent_threat
-- Trigger: player records >= 1 shot in each 15-minute segment (00-15, 16-30, 31-45+, 46-60, 61-75, 76-90+) in a finished match.
-- Intent: detect full-match shot-presence persistence and preserve player finishing with bilateral team context.
WITH player_segment_shots AS (
    SELECT
        s.match_id,
        toInt32(s.player_id) AS player_id,
        toInt32(s.team_id) AS team_id,
        toInt32(sum(if(toInt32(coalesce(s.goal_time, s.minute, 0)) BETWEEN 0 AND 15, 1, 0))) AS shots_segment_00_15,
        toInt32(sum(if(toInt32(coalesce(s.goal_time, s.minute, 0)) BETWEEN 16 AND 30, 1, 0))) AS shots_segment_16_30,
        toInt32(sum(if(toInt32(coalesce(s.goal_time, s.minute, 0)) BETWEEN 31 AND 45, 1, 0))) AS shots_segment_31_45_plus,
        toInt32(sum(if(toInt32(coalesce(s.goal_time, s.minute, 0)) BETWEEN 46 AND 60, 1, 0))) AS shots_segment_46_60,
        toInt32(sum(if(toInt32(coalesce(s.goal_time, s.minute, 0)) BETWEEN 61 AND 75, 1, 0))) AS shots_segment_61_75,
        toInt32(sum(if(toInt32(coalesce(s.goal_time, s.minute, 0)) >= 76, 1, 0))) AS shots_segment_76_90_plus
    FROM silver.shot AS s
    WHERE coalesce(s.player_id, 0) > 0
      AND coalesce(s.team_id, 0) > 0
      AND toInt32(coalesce(s.goal_time, s.minute, 0)) >= 0
      AND coalesce(s.is_own_goal, 0) = 0
    GROUP BY
        s.match_id,
        toInt32(s.player_id),
        toInt32(s.team_id)
),
triggered_players AS (
    SELECT
        pss.match_id,
        pss.player_id,
        pss.team_id,
        pss.shots_segment_00_15,
        pss.shots_segment_16_30,
        pss.shots_segment_31_45_plus,
        pss.shots_segment_46_60,
        pss.shots_segment_61_75,
        pss.shots_segment_76_90_plus,
        toInt32(
            if(pss.shots_segment_00_15 > 0, 1, 0)
          + if(pss.shots_segment_16_30 > 0, 1, 0)
          + if(pss.shots_segment_31_45_plus > 0, 1, 0)
          + if(pss.shots_segment_46_60 > 0, 1, 0)
          + if(pss.shots_segment_61_75 > 0, 1, 0)
          + if(pss.shots_segment_76_90_plus > 0, 1, 0)
        ) AS shot_segments_hit_count
    FROM player_segment_shots AS pss
)
SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    if(p.team_id = m.home_team_id, 'home', 'away') AS triggered_side,
    p.player_id AS triggered_player_id,
    coalesce(p.player_name, 'Unknown') AS triggered_player_name,
    if(p.team_id = m.home_team_id, m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(p.team_id = m.home_team_id, m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(p.team_id = m.home_team_id, m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(p.team_id = m.home_team_id, m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(1) AS trigger_threshold_min_shots_per_segment,
    toInt32(15) AS trigger_threshold_segment_window_minutes,
    toInt32(6) AS trigger_threshold_required_segment_count,

    toInt32(tp.shots_segment_00_15) AS triggered_player_shots_segment_00_15,
    toInt32(tp.shots_segment_16_30) AS triggered_player_shots_segment_16_30,
    toInt32(tp.shots_segment_31_45_plus) AS triggered_player_shots_segment_31_45_plus,
    toInt32(tp.shots_segment_46_60) AS triggered_player_shots_segment_46_60,
    toInt32(tp.shots_segment_61_75) AS triggered_player_shots_segment_61_75,
    toInt32(tp.shots_segment_76_90_plus) AS triggered_player_shots_segment_76_90_plus,
    toInt32(tp.shot_segments_hit_count) AS triggered_player_shot_segments_hit_count,
    toFloat32(round(100.0 * tp.shot_segments_hit_count / 6.0, 1)) AS triggered_player_shot_segment_coverage_pct,

    toInt32(coalesce(p.goals, 0)) AS triggered_player_goals,
    toFloat32(coalesce(p.expected_goals, 0.0)) AS triggered_player_expected_goals,
    toInt32(coalesce(p.total_shots, 0)) AS triggered_player_total_shots,
    toInt32(coalesce(p.shots_on_target, 0)) AS triggered_player_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * coalesce(p.shots_on_target, 0)
        / nullIf(toFloat64(coalesce(p.total_shots, 0)), 0),
        1
    ), 0.0)) AS triggered_player_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(p.goals, 0)
        / nullIf(toFloat64(coalesce(p.total_shots, 0)), 0),
        1
    ), 0.0)) AS triggered_player_shot_conversion_pct,
    toFloat32(coalesce(round(
        coalesce(p.expected_goals, 0.0)
        / nullIf(toFloat64(coalesce(p.total_shots, 0)), 0),
        3
    ), 0.0)) AS triggered_player_expected_goals_per_shot,
    toFloat32(round(
        coalesce(p.goals, 0) - coalesce(p.expected_goals, 0.0),
        3
    )) AS triggered_player_goal_minus_expected_goals,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,

    toInt32(if(
        p.team_id = m.home_team_id,
        coalesce(m.home_score, 0),
        coalesce(m.away_score, 0)
    )) AS triggered_team_goals,
    toInt32(if(
        p.team_id = m.home_team_id,
        coalesce(m.away_score, 0),
        coalesce(m.home_score, 0)
    )) AS opponent_goals,
    toInt32(if(
        p.team_id = m.home_team_id,
        coalesce(m.home_score, 0) - coalesce(m.away_score, 0),
        coalesce(m.away_score, 0) - coalesce(m.home_score, 0)
    )) AS goal_delta,

    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.expected_goals_home, 0.0),
        p.team_id = m.away_team_id, coalesce(ps.expected_goals_away, 0.0),
        0.0
    )) AS triggered_team_expected_goals,
    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.expected_goals_away, 0.0),
        p.team_id = m.away_team_id, coalesce(ps.expected_goals_home, 0.0),
        0.0
    )) AS opponent_expected_goals,
    toFloat32(round(
        multiIf(
            p.team_id = m.home_team_id,
                coalesce(ps.expected_goals_home, 0.0) - coalesce(ps.expected_goals_away, 0.0),
            p.team_id = m.away_team_id,
                coalesce(ps.expected_goals_away, 0.0) - coalesce(ps.expected_goals_home, 0.0),
            0.0
        ),
        3
    )) AS expected_goals_delta,

    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.total_shots_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.total_shots_away, 0),
        0
    )) AS triggered_team_total_shots,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.total_shots_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.total_shots_home, 0),
        0
    )) AS opponent_total_shots,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.shots_on_target_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.shots_on_target_away, 0),
        0
    )) AS triggered_team_shots_on_target,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.shots_on_target_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.shots_on_target_home, 0),
        0
    )) AS opponent_shots_on_target,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.big_chances_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.big_chances_away, 0),
        0
    )) AS triggered_team_big_chances,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.big_chances_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.big_chances_home, 0),
        0
    )) AS opponent_big_chances,
    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.ball_possession_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.ball_possession_away, 0),
        0
    )) AS triggered_team_possession_pct,
    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.ball_possession_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.ball_possession_home, 0),
        0
    )) AS opponent_possession_pct,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.touches_opp_box_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.touches_opp_box_away, 0),
        0
    )) AS triggered_team_touches_opposition_box,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.touches_opp_box_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.touches_opp_box_home, 0),
        0
    )) AS opponent_touches_opposition_box,

    toFloat32(coalesce(round(
        100.0 * coalesce(p.goals, 0)
        / nullIf(
            toFloat64(multiIf(
                p.team_id = m.home_team_id, coalesce(m.home_score, 0),
                p.team_id = m.away_team_id, coalesce(m.away_score, 0),
                0
            )),
            0
        ),
        1
    ), 0.0)) AS player_share_of_team_goals_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(p.expected_goals, 0.0)
        / nullIf(
            multiIf(
                p.team_id = m.home_team_id, coalesce(ps.expected_goals_home, 0.0),
                p.team_id = m.away_team_id, coalesce(ps.expected_goals_away, 0.0),
                0.0
            ),
            0.0
        ),
        1
    ), 0.0)) AS player_share_of_team_expected_goals_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(p.total_shots, 0)
        / nullIf(
            toFloat64(multiIf(
                p.team_id = m.home_team_id, coalesce(ps.total_shots_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.total_shots_away, 0),
                0
            )),
            0
        ),
        1
    ), 0.0)) AS player_share_of_team_total_shots_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(p.shots_on_target, 0)
        / nullIf(
            toFloat64(multiIf(
                p.team_id = m.home_team_id, coalesce(ps.shots_on_target_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.shots_on_target_away, 0),
                0
            )),
            0
        ),
        1
    ), 0.0)) AS player_share_of_team_shots_on_target_pct

FROM triggered_players AS tp
INNER JOIN silver.player_match_stat AS p
    ON p.match_id = tp.match_id
   AND p.player_id = tp.player_id
   AND p.team_id = tp.team_id
INNER JOIN silver.match AS m
    ON m.match_id = tp.match_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = tp.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND p.player_id > 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)
  AND tp.shot_segments_hit_count >= 6

ORDER BY
    triggered_player_shot_segments_hit_count DESC,
    triggered_player_total_shots DESC,
    triggered_player_expected_goals DESC,
    m.match_date DESC,
    m.match_id DESC;
