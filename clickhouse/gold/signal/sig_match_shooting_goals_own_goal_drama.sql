INSERT INTO gold.sig_match_shooting_goals_own_goal_drama (
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
    trigger_threshold_min_match_own_goals,
    match_total_goals,
    match_total_own_goals,
    match_total_non_own_goals,
    own_goal_share_of_match_goals_pct,
    home_own_goals_benefited,
    away_own_goals_benefited,
    home_own_goals_conceded,
    away_own_goals_conceded,
    triggered_team_own_goals_benefited,
    opponent_own_goals_benefited,
    own_goals_benefited_delta,
    triggered_team_own_goals_conceded,
    opponent_own_goals_conceded,
    own_goals_conceded_delta,
    triggered_team_total_goals,
    opponent_total_goals,
    goal_gap,
    triggered_team_non_own_goals,
    opponent_non_own_goals,
    non_own_goals_delta,
    triggered_team_own_goal_dependency_pct,
    opponent_own_goal_dependency_pct,
    own_goal_dependency_delta_pct,
    triggered_team_total_shots,
    opponent_total_shots,
    shot_volume_delta,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    shot_on_target_delta,
    triggered_team_shot_accuracy_pct,
    opponent_shot_accuracy_pct,
    shot_accuracy_delta_pct,
    triggered_team_xg,
    opponent_xg,
    xg_gap,
    triggered_team_goals_minus_xg,
    opponent_goals_minus_xg,
    goals_minus_xg_gap,
    triggered_team_big_chances,
    opponent_big_chances,
    big_chance_delta,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    opposition_box_touch_delta,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct
)
-- Signal: sig_match_shooting_goals_own_goal_drama
-- Intent: detect finished matches with at least one own goal and expose bilateral scoring,
--         finishing, and control context at canonical match-team grain.
-- Trigger: match_total_own_goals >= 1 from silver.shot own-goal events.
WITH own_goal_events AS (
    SELECT
        s.match_id,
        toUInt8(coalesce(s.is_home_goal, 0)) AS is_home_goal_flag
    FROM silver.shot AS s
    WHERE s.match_id > 0
      AND coalesce(s.is_goal, 0) = 1
      AND coalesce(s.is_own_goal, 0) = 1
      AND isNotNull(s.is_home_goal)
),
own_goal_breakdown AS (
    SELECT
        oge.match_id,
        toInt32(count()) AS match_total_own_goals,
        toInt32(countIf(oge.is_home_goal_flag = 1)) AS home_own_goals_benefited,
        toInt32(countIf(oge.is_home_goal_flag = 0)) AS away_own_goals_benefited,
        toInt32(countIf(oge.is_home_goal_flag = 0)) AS home_own_goals_conceded,
        toInt32(countIf(oge.is_home_goal_flag = 1)) AS away_own_goals_conceded
    FROM own_goal_events AS oge
    GROUP BY oge.match_id
),
base_stats AS (
    SELECT
        m.match_id,
        m.match_date,
        m.home_team_id,
        m.home_team_name,
        m.away_team_id,
        m.away_team_name,
        m.home_score,
        m.away_score,
        coalesce(m.home_score, 0) AS home_goals,
        coalesce(m.away_score, 0) AS away_goals,
        coalesce(ogb.match_total_own_goals, 0) AS match_total_own_goals,
        coalesce(ogb.home_own_goals_benefited, 0) AS home_own_goals_benefited,
        coalesce(ogb.away_own_goals_benefited, 0) AS away_own_goals_benefited,
        coalesce(ogb.home_own_goals_conceded, 0) AS home_own_goals_conceded,
        coalesce(ogb.away_own_goals_conceded, 0) AS away_own_goals_conceded,
        toInt32(coalesce(m.home_score, 0) + coalesce(m.away_score, 0)) AS match_total_goals,
        toFloat32(coalesce(ps.expected_goals_home, 0)) AS expected_goals_home,
        toFloat32(coalesce(ps.expected_goals_away, 0)) AS expected_goals_away,
        toInt32(coalesce(ps.total_shots_home, 0)) AS total_shots_home,
        toInt32(coalesce(ps.total_shots_away, 0)) AS total_shots_away,
        toInt32(coalesce(ps.shots_on_target_home, 0)) AS shots_on_target_home,
        toInt32(coalesce(ps.shots_on_target_away, 0)) AS shots_on_target_away,
        toInt32(coalesce(ps.big_chances_home, 0)) AS big_chances_home,
        toInt32(coalesce(ps.big_chances_away, 0)) AS big_chances_away,
        toInt32(coalesce(ps.touches_opp_box_home, 0)) AS touches_opposition_box_home,
        toInt32(coalesce(ps.touches_opp_box_away, 0)) AS touches_opposition_box_away,
        toFloat32(coalesce(ps.ball_possession_home, 0)) AS possession_home_pct,
        toFloat32(coalesce(ps.ball_possession_away, 0)) AS possession_away_pct,
        toInt32(coalesce(ps.accurate_passes_home, 0)) AS accurate_passes_home,
        toInt32(coalesce(ps.accurate_passes_away, 0)) AS accurate_passes_away,
        toInt32(coalesce(ps.pass_attempts_home, 0)) AS pass_attempts_home,
        toInt32(coalesce(ps.pass_attempts_away, 0)) AS pass_attempts_away
    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.match_date = m.match_date
       AND ps.period = 'All'
    INNER JOIN own_goal_breakdown AS ogb
        ON ogb.match_id = m.match_id
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND coalesce(ogb.match_total_own_goals, 0) >= 1
)
SELECT
    match_id,
    bs.match_date,
    bs.home_team_id,
    bs.home_team_name,
    bs.away_team_id,
    bs.away_team_name,
    bs.home_score,
    bs.away_score,
    'home' AS triggered_side,
    bs.home_team_id AS triggered_team_id,
    bs.home_team_name AS triggered_team_name,
    bs.away_team_id AS opponent_team_id,
    bs.away_team_name AS opponent_team_name,
    toInt32(1) AS trigger_threshold_min_match_own_goals,
    bs.match_total_goals,
    bs.match_total_own_goals,
    toInt32(greatest(bs.match_total_goals - bs.match_total_own_goals, 0)) AS match_total_non_own_goals,
    toFloat32(coalesce(round(
        100.0 * bs.match_total_own_goals / nullIf(toFloat64(bs.match_total_goals), 0),
        1
    ), 0.0)) AS own_goal_share_of_match_goals_pct,
    bs.home_own_goals_benefited,
    bs.away_own_goals_benefited,
    bs.home_own_goals_conceded,
    bs.away_own_goals_conceded,
    bs.home_own_goals_benefited AS triggered_team_own_goals_benefited,
    bs.away_own_goals_benefited AS opponent_own_goals_benefited,
    bs.home_own_goals_benefited - bs.away_own_goals_benefited AS own_goals_benefited_delta,
    bs.home_own_goals_conceded AS triggered_team_own_goals_conceded,
    bs.away_own_goals_conceded AS opponent_own_goals_conceded,
    bs.home_own_goals_conceded - bs.away_own_goals_conceded AS own_goals_conceded_delta,
    bs.home_goals AS triggered_team_total_goals,
    bs.away_goals AS opponent_total_goals,
    bs.home_goals - bs.away_goals AS goal_gap,
    toInt32(greatest(bs.home_goals - bs.home_own_goals_benefited, 0)) AS triggered_team_non_own_goals,
    toInt32(greatest(bs.away_goals - bs.away_own_goals_benefited, 0)) AS opponent_non_own_goals,
    toInt32(
        greatest(bs.home_goals - bs.home_own_goals_benefited, 0)
        - greatest(bs.away_goals - bs.away_own_goals_benefited, 0)
    ) AS non_own_goals_delta,
    toFloat32(coalesce(round(
        100.0 * bs.home_own_goals_benefited / nullIf(toFloat64(bs.home_goals), 0),
        1
    ), 0.0)) AS triggered_team_own_goal_dependency_pct,
    toFloat32(coalesce(round(
        100.0 * bs.away_own_goals_benefited / nullIf(toFloat64(bs.away_goals), 0),
        1
    ), 0.0)) AS opponent_own_goal_dependency_pct,
    toFloat32(round(
        coalesce(round(100.0 * bs.home_own_goals_benefited / nullIf(toFloat64(bs.home_goals), 0), 1), 0.0)
        - coalesce(round(100.0 * bs.away_own_goals_benefited / nullIf(toFloat64(bs.away_goals), 0), 1), 0.0),
        1
    )) AS own_goal_dependency_delta_pct,
    bs.total_shots_home AS triggered_team_total_shots,
    bs.total_shots_away AS opponent_total_shots,
    bs.total_shots_home - bs.total_shots_away AS shot_volume_delta,
    bs.shots_on_target_home AS triggered_team_shots_on_target,
    bs.shots_on_target_away AS opponent_shots_on_target,
    bs.shots_on_target_home - bs.shots_on_target_away AS shot_on_target_delta,
    toFloat32(coalesce(round(
        100.0 * bs.shots_on_target_home / nullIf(toFloat64(bs.total_shots_home), 0),
        1
    ), 0.0)) AS triggered_team_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * bs.shots_on_target_away / nullIf(toFloat64(bs.total_shots_away), 0),
        1
    ), 0.0)) AS opponent_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * bs.shots_on_target_home / nullIf(toFloat64(bs.total_shots_home), 0), 1), 0.0)
        - coalesce(round(100.0 * bs.shots_on_target_away / nullIf(toFloat64(bs.total_shots_away), 0), 1), 0.0),
        1
    )) AS shot_accuracy_delta_pct,
    bs.expected_goals_home AS triggered_team_xg,
    bs.expected_goals_away AS opponent_xg,
    toFloat32(round(bs.expected_goals_home - bs.expected_goals_away, 3)) AS xg_gap,
    toFloat32(round(bs.home_goals - bs.expected_goals_home, 3)) AS triggered_team_goals_minus_xg,
    toFloat32(round(bs.away_goals - bs.expected_goals_away, 3)) AS opponent_goals_minus_xg,
    toFloat32(round(
        (bs.home_goals - bs.expected_goals_home) - (bs.away_goals - bs.expected_goals_away),
        3
    )) AS goals_minus_xg_gap,
    bs.big_chances_home AS triggered_team_big_chances,
    bs.big_chances_away AS opponent_big_chances,
    bs.big_chances_home - bs.big_chances_away AS big_chance_delta,
    bs.touches_opposition_box_home AS triggered_team_touches_opposition_box,
    bs.touches_opposition_box_away AS opponent_touches_opposition_box,
    bs.touches_opposition_box_home - bs.touches_opposition_box_away AS opposition_box_touch_delta,
    bs.possession_home_pct AS triggered_team_possession_pct,
    bs.possession_away_pct AS opponent_possession_pct,
    toFloat32(round(bs.possession_home_pct - bs.possession_away_pct, 1)) AS possession_delta_pct,
    toFloat32(coalesce(round(
        100.0 * bs.accurate_passes_home / nullIf(toFloat64(bs.pass_attempts_home), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * bs.accurate_passes_away / nullIf(toFloat64(bs.pass_attempts_away), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * bs.accurate_passes_home / nullIf(toFloat64(bs.pass_attempts_home), 0), 1), 0.0)
        - coalesce(round(100.0 * bs.accurate_passes_away / nullIf(toFloat64(bs.pass_attempts_away), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct
FROM base_stats AS bs

UNION ALL

SELECT
    match_id,
    bs.match_date,
    bs.home_team_id,
    bs.home_team_name,
    bs.away_team_id,
    bs.away_team_name,
    bs.home_score,
    bs.away_score,
    'away' AS triggered_side,
    bs.away_team_id AS triggered_team_id,
    bs.away_team_name AS triggered_team_name,
    bs.home_team_id AS opponent_team_id,
    bs.home_team_name AS opponent_team_name,
    toInt32(1) AS trigger_threshold_min_match_own_goals,
    bs.match_total_goals,
    bs.match_total_own_goals,
    toInt32(greatest(bs.match_total_goals - bs.match_total_own_goals, 0)) AS match_total_non_own_goals,
    toFloat32(coalesce(round(
        100.0 * bs.match_total_own_goals / nullIf(toFloat64(bs.match_total_goals), 0),
        1
    ), 0.0)) AS own_goal_share_of_match_goals_pct,
    bs.home_own_goals_benefited,
    bs.away_own_goals_benefited,
    bs.home_own_goals_conceded,
    bs.away_own_goals_conceded,
    bs.away_own_goals_benefited AS triggered_team_own_goals_benefited,
    bs.home_own_goals_benefited AS opponent_own_goals_benefited,
    bs.away_own_goals_benefited - bs.home_own_goals_benefited AS own_goals_benefited_delta,
    bs.away_own_goals_conceded AS triggered_team_own_goals_conceded,
    bs.home_own_goals_conceded AS opponent_own_goals_conceded,
    bs.away_own_goals_conceded - bs.home_own_goals_conceded AS own_goals_conceded_delta,
    bs.away_goals AS triggered_team_total_goals,
    bs.home_goals AS opponent_total_goals,
    bs.away_goals - bs.home_goals AS goal_gap,
    toInt32(greatest(bs.away_goals - bs.away_own_goals_benefited, 0)) AS triggered_team_non_own_goals,
    toInt32(greatest(bs.home_goals - bs.home_own_goals_benefited, 0)) AS opponent_non_own_goals,
    toInt32(
        greatest(bs.away_goals - bs.away_own_goals_benefited, 0)
        - greatest(bs.home_goals - bs.home_own_goals_benefited, 0)
    ) AS non_own_goals_delta,
    toFloat32(coalesce(round(
        100.0 * bs.away_own_goals_benefited / nullIf(toFloat64(bs.away_goals), 0),
        1
    ), 0.0)) AS triggered_team_own_goal_dependency_pct,
    toFloat32(coalesce(round(
        100.0 * bs.home_own_goals_benefited / nullIf(toFloat64(bs.home_goals), 0),
        1
    ), 0.0)) AS opponent_own_goal_dependency_pct,
    toFloat32(round(
        coalesce(round(100.0 * bs.away_own_goals_benefited / nullIf(toFloat64(bs.away_goals), 0), 1), 0.0)
        - coalesce(round(100.0 * bs.home_own_goals_benefited / nullIf(toFloat64(bs.home_goals), 0), 1), 0.0),
        1
    )) AS own_goal_dependency_delta_pct,
    bs.total_shots_away AS triggered_team_total_shots,
    bs.total_shots_home AS opponent_total_shots,
    bs.total_shots_away - bs.total_shots_home AS shot_volume_delta,
    bs.shots_on_target_away AS triggered_team_shots_on_target,
    bs.shots_on_target_home AS opponent_shots_on_target,
    bs.shots_on_target_away - bs.shots_on_target_home AS shot_on_target_delta,
    toFloat32(coalesce(round(
        100.0 * bs.shots_on_target_away / nullIf(toFloat64(bs.total_shots_away), 0),
        1
    ), 0.0)) AS triggered_team_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * bs.shots_on_target_home / nullIf(toFloat64(bs.total_shots_home), 0),
        1
    ), 0.0)) AS opponent_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * bs.shots_on_target_away / nullIf(toFloat64(bs.total_shots_away), 0), 1), 0.0)
        - coalesce(round(100.0 * bs.shots_on_target_home / nullIf(toFloat64(bs.total_shots_home), 0), 1), 0.0),
        1
    )) AS shot_accuracy_delta_pct,
    bs.expected_goals_away AS triggered_team_xg,
    bs.expected_goals_home AS opponent_xg,
    toFloat32(round(bs.expected_goals_away - bs.expected_goals_home, 3)) AS xg_gap,
    toFloat32(round(bs.away_goals - bs.expected_goals_away, 3)) AS triggered_team_goals_minus_xg,
    toFloat32(round(bs.home_goals - bs.expected_goals_home, 3)) AS opponent_goals_minus_xg,
    toFloat32(round(
        (bs.away_goals - bs.expected_goals_away) - (bs.home_goals - bs.expected_goals_home),
        3
    )) AS goals_minus_xg_gap,
    bs.big_chances_away AS triggered_team_big_chances,
    bs.big_chances_home AS opponent_big_chances,
    bs.big_chances_away - bs.big_chances_home AS big_chance_delta,
    bs.touches_opposition_box_away AS triggered_team_touches_opposition_box,
    bs.touches_opposition_box_home AS opponent_touches_opposition_box,
    bs.touches_opposition_box_away - bs.touches_opposition_box_home AS opposition_box_touch_delta,
    bs.possession_away_pct AS triggered_team_possession_pct,
    bs.possession_home_pct AS opponent_possession_pct,
    toFloat32(round(bs.possession_away_pct - bs.possession_home_pct, 1)) AS possession_delta_pct,
    toFloat32(coalesce(round(
        100.0 * bs.accurate_passes_away / nullIf(toFloat64(bs.pass_attempts_away), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * bs.accurate_passes_home / nullIf(toFloat64(bs.pass_attempts_home), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(100.0 * bs.accurate_passes_away / nullIf(toFloat64(bs.pass_attempts_away), 0), 1), 0.0)
        - coalesce(round(100.0 * bs.accurate_passes_home / nullIf(toFloat64(bs.pass_attempts_home), 0), 1), 0.0),
        1
    )) AS pass_accuracy_delta_pct
FROM base_stats AS bs;
