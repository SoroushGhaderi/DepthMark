INSERT INTO gold.sig_player_shooting_goals_rapid_brace (
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
    trigger_threshold_min_goals,
    trigger_threshold_max_goal_window_minutes,
    triggered_player_first_rapid_goal_minute,
    triggered_player_first_rapid_goal_added_time,
    triggered_player_first_rapid_goal_effective_minute,
    triggered_player_second_rapid_goal_minute,
    triggered_player_second_rapid_goal_added_time,
    triggered_player_second_rapid_goal_effective_minute,
    minutes_between_rapid_brace_goals,
    triggered_player_rapid_brace_pair_count,
    goals_above_threshold,
    rapid_brace_window_margin_minutes,
    triggered_player_goals,
    triggered_player_expected_goals,
    triggered_player_total_shots,
    triggered_player_shots_on_target,
    triggered_player_shot_accuracy_pct,
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
    player_share_of_team_total_shots_pct
)
-- Signal: sig_player_shooting_goals_rapid_brace
-- Trigger: player scores 2 non-own goals within a 10-minute effective-minute window.
-- Intent: isolate rapid brace eruptions driven by short-interval finishing bursts with bilateral
-- team shooting and possession context.
WITH goal_events_raw AS (
    SELECT
        s.match_id,
        toInt32(s.team_id) AS team_id,
        toInt32(s.player_id) AS player_id,
        coalesce(s.player_name, 'Unknown') AS player_name,
        toInt32(coalesce(s.goal_time, s.minute, 0)) AS goal_minute,
        toInt32(coalesce(s.goal_overload_time, s.minute_added, 0)) AS goal_added_time,
        toInt32(
            coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
        ) AS goal_effective_minute,
        toInt64(coalesce(s.shot_id, 0)) AS shot_id,
        toInt32(coalesce(s.home_score_after, 0)) AS home_score_after,
        toInt32(coalesce(s.away_score_after, 0)) AS away_score_after
    FROM silver.shot AS s
    WHERE s.match_id > 0
      AND coalesce(s.player_id, 0) > 0
      AND coalesce(s.team_id, 0) > 0
      AND coalesce(s.is_goal, 0) = 1
      AND coalesce(s.is_own_goal, 0) = 0
),
goal_events AS (
    SELECT
        r.match_id,
        r.team_id,
        r.player_id,
        r.player_name,
        r.goal_minute,
        r.goal_added_time,
        r.goal_effective_minute,
        r.shot_id,
        row_number() OVER (
            PARTITION BY r.match_id, r.team_id, r.player_id
            ORDER BY
                r.goal_effective_minute ASC,
                r.shot_id ASC,
                r.home_score_after ASC,
                r.away_score_after ASC
        ) AS goal_event_order
    FROM goal_events_raw AS r
),
rapid_brace_pairs AS (
    SELECT
        g1.match_id,
        g1.team_id,
        g1.player_id,
        g1.player_name,
        g1.goal_minute AS first_rapid_goal_minute,
        g1.goal_added_time AS first_rapid_goal_added_time,
        g1.goal_effective_minute AS first_rapid_goal_effective_minute,
        g1.shot_id AS first_rapid_goal_shot_id,
        g2.goal_minute AS second_rapid_goal_minute,
        g2.goal_added_time AS second_rapid_goal_added_time,
        g2.goal_effective_minute AS second_rapid_goal_effective_minute,
        g2.shot_id AS second_rapid_goal_shot_id,
        toInt32(g2.goal_effective_minute - g1.goal_effective_minute) AS minutes_between_rapid_brace_goals
    FROM goal_events AS g1
    INNER JOIN goal_events AS g2
        ON g2.match_id = g1.match_id
       AND g2.team_id = g1.team_id
       AND g2.player_id = g1.player_id
    WHERE g2.goal_event_order > g1.goal_event_order
      AND g2.goal_effective_minute - g1.goal_effective_minute <= 10
),
rapid_brace_triggered_players AS (
    SELECT
        rp.match_id,
        rp.team_id,
        rp.player_id,
        argMin(
            rp.player_name,
            tuple(
                rp.second_rapid_goal_effective_minute,
                rp.second_rapid_goal_shot_id,
                rp.first_rapid_goal_effective_minute,
                rp.first_rapid_goal_shot_id
            )
        ) AS triggered_player_name,
        toInt32(argMin(
            rp.first_rapid_goal_minute,
            tuple(
                rp.second_rapid_goal_effective_minute,
                rp.second_rapid_goal_shot_id,
                rp.first_rapid_goal_effective_minute,
                rp.first_rapid_goal_shot_id
            )
        )) AS triggered_player_first_rapid_goal_minute,
        toInt32(argMin(
            rp.first_rapid_goal_added_time,
            tuple(
                rp.second_rapid_goal_effective_minute,
                rp.second_rapid_goal_shot_id,
                rp.first_rapid_goal_effective_minute,
                rp.first_rapid_goal_shot_id
            )
        )) AS triggered_player_first_rapid_goal_added_time,
        toInt32(argMin(
            rp.first_rapid_goal_effective_minute,
            tuple(
                rp.second_rapid_goal_effective_minute,
                rp.second_rapid_goal_shot_id,
                rp.first_rapid_goal_effective_minute,
                rp.first_rapid_goal_shot_id
            )
        )) AS triggered_player_first_rapid_goal_effective_minute,
        toInt32(argMin(
            rp.second_rapid_goal_minute,
            tuple(
                rp.second_rapid_goal_effective_minute,
                rp.second_rapid_goal_shot_id,
                rp.first_rapid_goal_effective_minute,
                rp.first_rapid_goal_shot_id
            )
        )) AS triggered_player_second_rapid_goal_minute,
        toInt32(argMin(
            rp.second_rapid_goal_added_time,
            tuple(
                rp.second_rapid_goal_effective_minute,
                rp.second_rapid_goal_shot_id,
                rp.first_rapid_goal_effective_minute,
                rp.first_rapid_goal_shot_id
            )
        )) AS triggered_player_second_rapid_goal_added_time,
        toInt32(min(rp.second_rapid_goal_effective_minute))
            AS triggered_player_second_rapid_goal_effective_minute,
        toInt32(argMin(
            rp.minutes_between_rapid_brace_goals,
            tuple(
                rp.second_rapid_goal_effective_minute,
                rp.second_rapid_goal_shot_id,
                rp.first_rapid_goal_effective_minute,
                rp.first_rapid_goal_shot_id
            )
        )) AS minutes_between_rapid_brace_goals,
        toInt32(count()) AS triggered_player_rapid_brace_pair_count
    FROM rapid_brace_pairs AS rp
    GROUP BY
        rp.match_id,
        rp.team_id,
        rp.player_id
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
    rbtp.triggered_player_name,
    if(p.team_id = m.home_team_id, m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(p.team_id = m.home_team_id, m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(p.team_id = m.home_team_id, m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(p.team_id = m.home_team_id, m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(2) AS trigger_threshold_min_goals,
    toInt32(10) AS trigger_threshold_max_goal_window_minutes,
    rbtp.triggered_player_first_rapid_goal_minute,
    rbtp.triggered_player_first_rapid_goal_added_time,
    rbtp.triggered_player_first_rapid_goal_effective_minute,
    rbtp.triggered_player_second_rapid_goal_minute,
    rbtp.triggered_player_second_rapid_goal_added_time,
    rbtp.triggered_player_second_rapid_goal_effective_minute,
    rbtp.minutes_between_rapid_brace_goals,
    rbtp.triggered_player_rapid_brace_pair_count,
    toInt32(coalesce(p.goals, 0) - 2) AS goals_above_threshold,
    toInt32(10 - rbtp.minutes_between_rapid_brace_goals) AS rapid_brace_window_margin_minutes,

    toInt32(coalesce(p.goals, 0)) AS triggered_player_goals,
    toFloat32(coalesce(p.expected_goals, 0.0)) AS triggered_player_expected_goals,
    toInt32(coalesce(p.total_shots, 0)) AS triggered_player_total_shots,
    toInt32(coalesce(p.shots_on_target, 0)) AS triggered_player_shots_on_target,
    toFloat32(coalesce(
        round(
            100.0 * coalesce(p.shots_on_target, 0)
            / nullIf(coalesce(p.total_shots, 0), 0),
            1
        ),
        0.0
    )) AS triggered_player_shot_accuracy_pct,
    toFloat32(coalesce(
        round(
            coalesce(p.expected_goals, 0.0)
            / nullIf(toFloat64(coalesce(p.total_shots, 0)), 0),
            3
        ),
        0.0
    )) AS triggered_player_expected_goals_per_shot,
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
    ), 0.0)) AS player_share_of_team_total_shots_pct

FROM rapid_brace_triggered_players AS rbtp
INNER JOIN silver.player_match_stat AS p
    ON p.match_id = rbtp.match_id
   AND p.player_id = rbtp.player_id
   AND p.team_id = rbtp.team_id
INNER JOIN silver.match AS m
    ON m.match_id = p.match_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = p.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND p.player_id > 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)

ORDER BY
    minutes_between_rapid_brace_goals ASC,
    rbtp.triggered_player_second_rapid_goal_effective_minute ASC,
    triggered_player_goals DESC,
    m.match_date DESC,
    m.match_id DESC;
