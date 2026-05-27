INSERT INTO gold.sig_match_creativity_playmaking_set_piece_creative_duel (
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
    trigger_threshold_min_team_set_piece_assists,
    match_total_set_piece_assists,
    triggered_team_set_piece_assists,
    opponent_set_piece_assists,
    set_piece_assists_delta,
    triggered_team_set_piece_assist_share_pct,
    opponent_set_piece_assist_share_pct,
    set_piece_assist_share_delta_pct,
    triggered_team_set_piece_assisted_shots,
    opponent_set_piece_assisted_shots,
    set_piece_assisted_shots_delta,
    triggered_team_set_piece_assisted_shots_on_target,
    opponent_set_piece_assisted_shots_on_target,
    set_piece_assisted_shots_on_target_delta,
    triggered_team_set_piece_assisted_shot_accuracy_pct,
    opponent_set_piece_assisted_shot_accuracy_pct,
    set_piece_assisted_shot_accuracy_delta_pct,
    triggered_team_set_piece_assisted_shot_expected_goals,
    opponent_set_piece_assisted_shot_expected_goals,
    set_piece_assisted_shot_expected_goals_delta,
    match_total_expected_assists,
    triggered_team_expected_assists,
    opponent_expected_assists,
    expected_assists_delta,
    triggered_team_key_passes,
    opponent_key_passes,
    key_pass_delta,
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
    triggered_team_big_chances,
    opponent_big_chances,
    big_chances_delta,
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
WITH set_piece_assist_stats AS (
    SELECT
        s.match_id,
        assumeNotNull(s.team_id) AS team_id,
        toInt32(countIf(
            coalesce(s.assist_player_id, 0) > 0
            AND coalesce(s.is_goal, 0) = 1
            AND coalesce(s.is_own_goal, 0) = 0
        )) AS team_set_piece_assists,
        toInt32(countIf(coalesce(s.assist_player_id, 0) > 0)) AS team_set_piece_assisted_shots,
        toInt32(countIf(
            coalesce(s.assist_player_id, 0) > 0
            AND coalesce(s.is_on_target, 0) = 1
        )) AS team_set_piece_assisted_shots_on_target,
        toFloat32(round(sumIf(
            coalesce(s.expected_goals, 0.0),
            coalesce(s.assist_player_id, 0) > 0
        ), 3)) AS team_set_piece_assisted_shot_expected_goals
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
        toInt32(coalesce(sa_home.team_set_piece_assists, 0)) AS home_set_piece_assists,
        toInt32(coalesce(sa_away.team_set_piece_assists, 0)) AS away_set_piece_assists,
        toInt32(coalesce(sa_home.team_set_piece_assisted_shots, 0)) AS home_set_piece_assisted_shots,
        toInt32(coalesce(sa_away.team_set_piece_assisted_shots, 0)) AS away_set_piece_assisted_shots,
        toInt32(coalesce(sa_home.team_set_piece_assisted_shots_on_target, 0))
            AS home_set_piece_assisted_shots_on_target,
        toInt32(coalesce(sa_away.team_set_piece_assisted_shots_on_target, 0))
            AS away_set_piece_assisted_shots_on_target,
        toFloat32(coalesce(sa_home.team_set_piece_assisted_shot_expected_goals, 0.0))
            AS home_set_piece_assisted_shot_expected_goals,
        toFloat32(coalesce(sa_away.team_set_piece_assisted_shot_expected_goals, 0.0))
            AS away_set_piece_assisted_shot_expected_goals,
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
        toInt32(coalesce(ps.big_chances_home, 0)) AS big_chances_home,
        toInt32(coalesce(ps.big_chances_away, 0)) AS big_chances_away,
        toInt32(coalesce(ps.pass_attempts_home, 0)) AS pass_attempts_home,
        toInt32(coalesce(ps.pass_attempts_away, 0)) AS pass_attempts_away,
        toInt32(coalesce(ps.accurate_passes_home, 0)) AS accurate_passes_home,
        toInt32(coalesce(ps.accurate_passes_away, 0)) AS accurate_passes_away,
        toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS possession_home_pct,
        toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS possession_away_pct,
        toInt32(coalesce(ps.opposition_half_passes_home, 0)) AS opposition_half_passes_home,
        toInt32(coalesce(ps.opposition_half_passes_away, 0)) AS opposition_half_passes_away,
        toInt32(coalesce(ps.touches_opp_box_home, 0)) AS touches_opposition_box_home,
        toInt32(coalesce(ps.touches_opp_box_away, 0)) AS touches_opposition_box_away,
        toInt32(coalesce(sa_home.team_set_piece_assists, 0) + coalesce(sa_away.team_set_piece_assists, 0))
            AS match_total_set_piece_assists,
        toFloat32(round(
            coalesce(hc.team_expected_assists, 0.0) + coalesce(ac.team_expected_assists, 0.0),
            3
        )) AS match_total_expected_assists
    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.match_date = m.match_date
       AND ps.period = 'All'
    LEFT JOIN set_piece_assist_stats AS sa_home
        ON sa_home.match_id = m.match_id
       AND sa_home.team_id = m.home_team_id
    LEFT JOIN set_piece_assist_stats AS sa_away
        ON sa_away.match_id = m.match_id
       AND sa_away.team_id = m.away_team_id
    LEFT JOIN team_creation_stats AS hc
        ON hc.match_id = m.match_id
       AND hc.team_id = m.home_team_id
    LEFT JOIN team_creation_stats AS ac
        ON ac.match_id = m.match_id
       AND ac.team_id = m.away_team_id
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND coalesce(sa_home.team_set_piece_assists, 0) >= 1
      AND coalesce(sa_away.team_set_piece_assists, 0) >= 1
)
-- Signal: sig_match_creativity_playmaking_set_piece_creative_duel
-- Trigger: Both teams record at least one goal assist from set-piece situations in a finished match.
-- Intent: capture bilateral dead-ball creative exchanges where each side converts set-piece delivery
--         into direct goal creation, with playmaking and territorial context.
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
    toInt32(1) AS trigger_threshold_min_team_set_piece_assists,
    b.match_total_set_piece_assists,
    b.home_set_piece_assists AS triggered_team_set_piece_assists,
    b.away_set_piece_assists AS opponent_set_piece_assists,
    b.home_set_piece_assists - b.away_set_piece_assists AS set_piece_assists_delta,
    toFloat32(coalesce(round(
        100.0 * b.home_set_piece_assists / nullIf(toFloat64(b.match_total_set_piece_assists), 0),
        1
    ), 0.0)) AS triggered_team_set_piece_assist_share_pct,
    toFloat32(coalesce(round(
        100.0 * b.away_set_piece_assists / nullIf(toFloat64(b.match_total_set_piece_assists), 0),
        1
    ), 0.0)) AS opponent_set_piece_assist_share_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.home_set_piece_assists / nullIf(toFloat64(b.match_total_set_piece_assists), 0), 1), 0.0)
        - coalesce(round(100.0 * b.away_set_piece_assists / nullIf(toFloat64(b.match_total_set_piece_assists), 0), 1), 0.0),
        1
    )) AS set_piece_assist_share_delta_pct,
    b.home_set_piece_assisted_shots AS triggered_team_set_piece_assisted_shots,
    b.away_set_piece_assisted_shots AS opponent_set_piece_assisted_shots,
    b.home_set_piece_assisted_shots - b.away_set_piece_assisted_shots AS set_piece_assisted_shots_delta,
    b.home_set_piece_assisted_shots_on_target AS triggered_team_set_piece_assisted_shots_on_target,
    b.away_set_piece_assisted_shots_on_target AS opponent_set_piece_assisted_shots_on_target,
    b.home_set_piece_assisted_shots_on_target - b.away_set_piece_assisted_shots_on_target
        AS set_piece_assisted_shots_on_target_delta,
    toFloat32(coalesce(round(
        100.0 * b.home_set_piece_assisted_shots_on_target
        / nullIf(toFloat64(b.home_set_piece_assisted_shots), 0),
        1
    ), 0.0)) AS triggered_team_set_piece_assisted_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.away_set_piece_assisted_shots_on_target
        / nullIf(toFloat64(b.away_set_piece_assisted_shots), 0),
        1
    ), 0.0)) AS opponent_set_piece_assisted_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.home_set_piece_assisted_shots_on_target
            / nullIf(toFloat64(b.home_set_piece_assisted_shots), 0),
            1
        ), 0.0)
        - coalesce(round(
            100.0 * b.away_set_piece_assisted_shots_on_target
            / nullIf(toFloat64(b.away_set_piece_assisted_shots), 0),
            1
        ), 0.0),
        1
    )) AS set_piece_assisted_shot_accuracy_delta_pct,
    b.home_set_piece_assisted_shot_expected_goals AS triggered_team_set_piece_assisted_shot_expected_goals,
    b.away_set_piece_assisted_shot_expected_goals AS opponent_set_piece_assisted_shot_expected_goals,
    toFloat32(round(
        b.home_set_piece_assisted_shot_expected_goals - b.away_set_piece_assisted_shot_expected_goals,
        3
    )) AS set_piece_assisted_shot_expected_goals_delta,
    b.match_total_expected_assists,
    b.home_expected_assists AS triggered_team_expected_assists,
    b.away_expected_assists AS opponent_expected_assists,
    toFloat32(round(b.home_expected_assists - b.away_expected_assists, 3)) AS expected_assists_delta,
    b.home_key_passes AS triggered_team_key_passes,
    b.away_key_passes AS opponent_key_passes,
    b.home_key_passes - b.away_key_passes AS key_pass_delta,
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
    b.big_chances_home AS triggered_team_big_chances,
    b.big_chances_away AS opponent_big_chances,
    b.big_chances_home - b.big_chances_away AS big_chances_delta,
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
    toInt32(1) AS trigger_threshold_min_team_set_piece_assists,
    b.match_total_set_piece_assists,
    b.away_set_piece_assists AS triggered_team_set_piece_assists,
    b.home_set_piece_assists AS opponent_set_piece_assists,
    b.away_set_piece_assists - b.home_set_piece_assists AS set_piece_assists_delta,
    toFloat32(coalesce(round(
        100.0 * b.away_set_piece_assists / nullIf(toFloat64(b.match_total_set_piece_assists), 0),
        1
    ), 0.0)) AS triggered_team_set_piece_assist_share_pct,
    toFloat32(coalesce(round(
        100.0 * b.home_set_piece_assists / nullIf(toFloat64(b.match_total_set_piece_assists), 0),
        1
    ), 0.0)) AS opponent_set_piece_assist_share_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.away_set_piece_assists / nullIf(toFloat64(b.match_total_set_piece_assists), 0), 1), 0.0)
        - coalesce(round(100.0 * b.home_set_piece_assists / nullIf(toFloat64(b.match_total_set_piece_assists), 0), 1), 0.0),
        1
    )) AS set_piece_assist_share_delta_pct,
    b.away_set_piece_assisted_shots AS triggered_team_set_piece_assisted_shots,
    b.home_set_piece_assisted_shots AS opponent_set_piece_assisted_shots,
    b.away_set_piece_assisted_shots - b.home_set_piece_assisted_shots AS set_piece_assisted_shots_delta,
    b.away_set_piece_assisted_shots_on_target AS triggered_team_set_piece_assisted_shots_on_target,
    b.home_set_piece_assisted_shots_on_target AS opponent_set_piece_assisted_shots_on_target,
    b.away_set_piece_assisted_shots_on_target - b.home_set_piece_assisted_shots_on_target
        AS set_piece_assisted_shots_on_target_delta,
    toFloat32(coalesce(round(
        100.0 * b.away_set_piece_assisted_shots_on_target
        / nullIf(toFloat64(b.away_set_piece_assisted_shots), 0),
        1
    ), 0.0)) AS triggered_team_set_piece_assisted_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * b.home_set_piece_assisted_shots_on_target
        / nullIf(toFloat64(b.home_set_piece_assisted_shots), 0),
        1
    ), 0.0)) AS opponent_set_piece_assisted_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.away_set_piece_assisted_shots_on_target
            / nullIf(toFloat64(b.away_set_piece_assisted_shots), 0),
            1
        ), 0.0)
        - coalesce(round(
            100.0 * b.home_set_piece_assisted_shots_on_target
            / nullIf(toFloat64(b.home_set_piece_assisted_shots), 0),
            1
        ), 0.0),
        1
    )) AS set_piece_assisted_shot_accuracy_delta_pct,
    b.away_set_piece_assisted_shot_expected_goals AS triggered_team_set_piece_assisted_shot_expected_goals,
    b.home_set_piece_assisted_shot_expected_goals AS opponent_set_piece_assisted_shot_expected_goals,
    toFloat32(round(
        b.away_set_piece_assisted_shot_expected_goals - b.home_set_piece_assisted_shot_expected_goals,
        3
    )) AS set_piece_assisted_shot_expected_goals_delta,
    b.match_total_expected_assists,
    b.away_expected_assists AS triggered_team_expected_assists,
    b.home_expected_assists AS opponent_expected_assists,
    toFloat32(round(b.away_expected_assists - b.home_expected_assists, 3)) AS expected_assists_delta,
    b.away_key_passes AS triggered_team_key_passes,
    b.home_key_passes AS opponent_key_passes,
    b.away_key_passes - b.home_key_passes AS key_pass_delta,
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
    b.big_chances_away AS triggered_team_big_chances,
    b.big_chances_home AS opponent_big_chances,
    b.big_chances_away - b.big_chances_home AS big_chances_delta,
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
FROM base_stats AS b;
