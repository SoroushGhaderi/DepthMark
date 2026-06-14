INSERT INTO gold.sig_player_creativity_playmaking_clutch_vision (
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
    trigger_threshold_min_goal_effective_minute,
    triggered_player_late_winning_goal_assists,
    triggered_player_first_late_winning_goal_assist_minute,
    triggered_player_first_late_winning_goal_assist_added_time,
    triggered_player_first_late_winning_goal_assist_effective_minute,
    triggered_team_score_before_first_late_winning_goal_assist,
    opponent_score_before_first_late_winning_goal_assist,
    triggered_team_score_after_first_late_winning_goal_assist,
    opponent_score_after_first_late_winning_goal_assist,
    final_goal_margin,
    late_winning_goal_assists_above_threshold,
    triggered_player_assists,
    triggered_player_chances_created,
    triggered_player_expected_assists,
    triggered_player_assist_minus_expected_assists,
    triggered_player_passes_final_third,
    triggered_player_touches_opposition_box,
    triggered_player_accurate_passes,
    triggered_player_total_passes,
    triggered_player_pass_accuracy_pct,
    triggered_player_minutes_played,
    triggered_player_touches,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_expected_goals,
    opponent_expected_goals,
    expected_goals_delta,
    triggered_team_big_chances,
    opponent_big_chances,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_accurate_passes,
    opponent_accurate_passes,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    player_share_of_team_assists_pct,
    player_share_of_team_chances_created_pct,
    player_share_of_team_passes_pct
)
-- Signal: sig_player_creativity_playmaking_clutch_vision
-- Trigger: player provides the assisted pass for a decisive non-own winning goal after the 85th minute.
-- Intent: isolate late-match decisive playmaking contributions with explicit score-state evidence,
--         while preserving bilateral passing, chance-quality, and control context.
WITH late_lead_assist_candidates AS (
    SELECT
        s.match_id,
        toInt32(s.team_id) AS team_id,
        toInt32(assumeNotNull(s.assist_player_id)) AS assist_player_id,
        toInt32(coalesce(s.is_home_goal, 0)) AS is_home_goal,
        toInt32(coalesce(s.goal_time, s.minute, 0)) AS goal_minute,
        toInt32(coalesce(s.goal_overload_time, s.minute_added, 0)) AS goal_added_time,
        toInt32(
            coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
        ) AS goal_effective_minute,
        toInt32(if(
            coalesce(s.is_home_goal, 0) = 1,
            coalesce(s.home_score_after, 0) - 1,
            coalesce(s.away_score_after, 0) - 1
        )) AS triggered_team_score_before,
        toInt32(if(
            coalesce(s.is_home_goal, 0) = 1,
            coalesce(s.away_score_after, 0),
            coalesce(s.home_score_after, 0)
        )) AS opponent_score_before,
        toInt32(if(
            coalesce(s.is_home_goal, 0) = 1,
            coalesce(s.home_score_after, 0),
            coalesce(s.away_score_after, 0)
        )) AS triggered_team_score_after,
        toInt32(if(
            coalesce(s.is_home_goal, 0) = 1,
            coalesce(s.away_score_after, 0),
            coalesce(s.home_score_after, 0)
        )) AS opponent_score_after,
        toInt32(if(
            coalesce(s.is_home_goal, 0) = 1,
            coalesce(m.home_score, 0) - coalesce(m.away_score, 0),
            coalesce(m.away_score, 0) - coalesce(m.home_score, 0)
        )) AS final_goal_margin,
        toString(coalesce(s.shot_id, '')) AS shot_id_key
    FROM silver.shot AS s
    INNER JOIN silver.match AS m
        ON m.match_id = s.match_id
    WHERE s.match_id > 0
      AND m.match_id > 0
      AND m.match_finished = 1
      AND coalesce(m.home_score, -1) != coalesce(m.away_score, -1)
      AND coalesce(s.assist_player_id, 0) > 0
      AND coalesce(s.team_id, 0) > 0
      AND coalesce(s.is_goal, 0) = 1
      AND coalesce(s.is_own_goal, 0) = 0
      AND toInt32(
            coalesce(s.goal_time, s.minute, 0) + coalesce(s.goal_overload_time, s.minute_added, 0)
        ) >= 86
      AND if(
            coalesce(s.is_home_goal, 0) = 1,
            coalesce(m.home_score, 0) > coalesce(m.away_score, 0),
            coalesce(m.away_score, 0) > coalesce(m.home_score, 0)
        )
      AND if(
            coalesce(s.is_home_goal, 0) = 1,
            coalesce(s.home_score_after, 0) > coalesce(s.away_score_after, 0),
            coalesce(s.away_score_after, 0) > coalesce(s.home_score_after, 0)
        )
      AND if(
            coalesce(s.is_home_goal, 0) = 1,
            coalesce(s.home_score_after, 0) - 1 <= coalesce(s.away_score_after, 0),
            coalesce(s.away_score_after, 0) - 1 <= coalesce(s.home_score_after, 0)
        )
),
late_winning_assist_events AS (
    SELECT
        c.match_id,
        c.team_id,
        c.assist_player_id,
        c.is_home_goal,
        c.goal_minute,
        c.goal_added_time,
        c.goal_effective_minute,
        c.triggered_team_score_before,
        c.opponent_score_before,
        c.triggered_team_score_after,
        c.opponent_score_after,
        c.final_goal_margin,
        c.shot_id_key
    FROM late_lead_assist_candidates AS c
    LEFT JOIN silver.shot AS s2
        ON s2.match_id = c.match_id
       AND coalesce(s2.is_goal, 0) = 1
       AND coalesce(s2.is_own_goal, 0) = 0
    GROUP BY
        c.match_id,
        c.team_id,
        c.assist_player_id,
        c.is_home_goal,
        c.goal_minute,
        c.goal_added_time,
        c.goal_effective_minute,
        c.triggered_team_score_before,
        c.opponent_score_before,
        c.triggered_team_score_after,
        c.opponent_score_after,
        c.final_goal_margin,
        c.shot_id_key
    HAVING countIf(
        tuple(
            toInt32(coalesce(s2.goal_time, s2.minute, 0)),
            toInt32(coalesce(s2.goal_overload_time, s2.minute_added, 0)),
            toString(coalesce(s2.shot_id, ''))
        ) > tuple(c.goal_minute, c.goal_added_time, c.shot_id_key)
        AND if(
            c.is_home_goal = 1,
            coalesce(s2.is_home_goal, 0) = 0
                AND coalesce(s2.away_score_after, 0) >= coalesce(s2.home_score_after, 0),
            coalesce(s2.is_home_goal, 0) = 1
                AND coalesce(s2.home_score_after, 0) >= coalesce(s2.away_score_after, 0)
        )
    ) = 0
),
player_late_winning_assists AS (
    SELECT
        e.match_id,
        e.team_id,
        e.assist_player_id,
        count() AS triggered_player_late_winning_goal_assists,
        toInt32(min(e.goal_minute)) AS triggered_player_first_late_winning_goal_assist_minute,
        toInt32(argMin(
            e.goal_added_time,
            tuple(e.goal_minute, e.goal_added_time, e.shot_id_key)
        )) AS triggered_player_first_late_winning_goal_assist_added_time,
        toInt32(min(e.goal_effective_minute))
            AS triggered_player_first_late_winning_goal_assist_effective_minute,
        toInt32(argMin(
            e.triggered_team_score_before,
            tuple(e.goal_minute, e.goal_added_time, e.shot_id_key)
        )) AS triggered_team_score_before_first_late_winning_goal_assist,
        toInt32(argMin(
            e.opponent_score_before,
            tuple(e.goal_minute, e.goal_added_time, e.shot_id_key)
        )) AS opponent_score_before_first_late_winning_goal_assist,
        toInt32(argMin(
            e.triggered_team_score_after,
            tuple(e.goal_minute, e.goal_added_time, e.shot_id_key)
        )) AS triggered_team_score_after_first_late_winning_goal_assist,
        toInt32(argMin(
            e.opponent_score_after,
            tuple(e.goal_minute, e.goal_added_time, e.shot_id_key)
        )) AS opponent_score_after_first_late_winning_goal_assist,
        toInt32(argMin(
            e.final_goal_margin,
            tuple(e.goal_minute, e.goal_added_time, e.shot_id_key)
        )) AS final_goal_margin
    FROM late_winning_assist_events AS e
    GROUP BY
        e.match_id,
        e.team_id,
        e.assist_player_id
),
team_chances_created AS (
    SELECT
        p.match_id,
        p.team_id,
        toInt32(sum(coalesce(p.chances_created, 0))) AS triggered_team_total_chances_created
    FROM silver.player_match_stat AS p
    WHERE p.team_id IS NOT NULL
    GROUP BY
        p.match_id,
        p.team_id
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
    toInt32(p.player_id) AS triggered_player_id,
    p.player_name AS triggered_player_name,
    if(p.team_id = m.home_team_id, m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(p.team_id = m.home_team_id, m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(p.team_id = m.home_team_id, m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(p.team_id = m.home_team_id, m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(86) AS trigger_threshold_min_goal_effective_minute,
    toInt32(plwa.triggered_player_late_winning_goal_assists) AS triggered_player_late_winning_goal_assists,
    toInt32(plwa.triggered_player_first_late_winning_goal_assist_minute)
        AS triggered_player_first_late_winning_goal_assist_minute,
    toInt32(plwa.triggered_player_first_late_winning_goal_assist_added_time)
        AS triggered_player_first_late_winning_goal_assist_added_time,
    toInt32(plwa.triggered_player_first_late_winning_goal_assist_effective_minute)
        AS triggered_player_first_late_winning_goal_assist_effective_minute,
    toInt32(plwa.triggered_team_score_before_first_late_winning_goal_assist)
        AS triggered_team_score_before_first_late_winning_goal_assist,
    toInt32(plwa.opponent_score_before_first_late_winning_goal_assist)
        AS opponent_score_before_first_late_winning_goal_assist,
    toInt32(plwa.triggered_team_score_after_first_late_winning_goal_assist)
        AS triggered_team_score_after_first_late_winning_goal_assist,
    toInt32(plwa.opponent_score_after_first_late_winning_goal_assist)
        AS opponent_score_after_first_late_winning_goal_assist,
    toInt32(plwa.final_goal_margin) AS final_goal_margin,
    toInt32(plwa.triggered_player_late_winning_goal_assists - 1) AS late_winning_goal_assists_above_threshold,

    toInt32(coalesce(p.assists, 0)) AS triggered_player_assists,
    toInt32(coalesce(p.chances_created, 0)) AS triggered_player_chances_created,
    toFloat32(coalesce(p.expected_assists, 0.0)) AS triggered_player_expected_assists,
    toFloat32(round(coalesce(p.assists, 0) - coalesce(p.expected_assists, 0.0), 3))
        AS triggered_player_assist_minus_expected_assists,
    toInt32(coalesce(p.passes_final_third, 0)) AS triggered_player_passes_final_third,
    toInt32(coalesce(p.touches_opp_box, 0)) AS triggered_player_touches_opposition_box,
    toInt32(coalesce(p.accurate_passes, 0)) AS triggered_player_accurate_passes,
    toInt32(coalesce(p.total_passes, 0)) AS triggered_player_total_passes,
    toFloat32(coalesce(
        p.pass_accuracy,
        round(
            100.0 * coalesce(p.accurate_passes, 0)
            / nullIf(coalesce(p.total_passes, 0), 0),
            1
        ),
        0.0
    )) AS triggered_player_pass_accuracy_pct,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,
    toInt32(coalesce(p.touches, 0)) AS triggered_player_touches,

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
        p.team_id = m.home_team_id, coalesce(ps.big_chances_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.big_chances_away, 0),
        0
    )) AS triggered_team_big_chances,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.big_chances_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.big_chances_home, 0),
        0
    )) AS opponent_big_chances,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.pass_attempts_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.pass_attempts_away, 0),
        0
    )) AS triggered_team_pass_attempts,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.pass_attempts_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.pass_attempts_home, 0),
        0
    )) AS opponent_pass_attempts,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.accurate_passes_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.accurate_passes_away, 0),
        0
    )) AS triggered_team_accurate_passes,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.accurate_passes_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.accurate_passes_home, 0),
        0
    )) AS opponent_accurate_passes,
    toFloat32(coalesce(
        round(
            100.0 * multiIf(
                p.team_id = m.home_team_id, coalesce(ps.accurate_passes_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.accurate_passes_away, 0),
                0
            ) / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.pass_attempts_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.pass_attempts_away, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    )) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(
        round(
            100.0 * multiIf(
                p.team_id = m.home_team_id, coalesce(ps.accurate_passes_away, 0),
                p.team_id = m.away_team_id, coalesce(ps.accurate_passes_home, 0),
                0
            ) / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.pass_attempts_away, 0),
                    p.team_id = m.away_team_id, coalesce(ps.pass_attempts_home, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    )) AS opponent_pass_accuracy_pct,
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
        100.0 * coalesce(p.assists, 0)
        / nullIf(
            toFloat64(multiIf(
                p.team_id = m.home_team_id, coalesce(m.home_score, 0),
                p.team_id = m.away_team_id, coalesce(m.away_score, 0),
                0
            )),
            0
        ),
        1
    ), 0.0)) AS player_share_of_team_assists_pct,
    toFloat32(coalesce(
        round(
            100.0 * coalesce(p.chances_created, 0)
            / nullIf(toFloat64(coalesce(tc.triggered_team_total_chances_created, 0)), 0),
            1
        ),
        0.0
    )) AS player_share_of_team_chances_created_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(p.total_passes, 0)
        / nullIf(
            toFloat64(multiIf(
                p.team_id = m.home_team_id, coalesce(ps.pass_attempts_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.pass_attempts_away, 0),
                0
            )),
            0
        ),
        1
    ), 0.0)) AS player_share_of_team_passes_pct

FROM player_late_winning_assists AS plwa
INNER JOIN silver.player_match_stat AS p
    ON p.match_id = plwa.match_id
   AND p.team_id = plwa.team_id
   AND p.player_id = plwa.assist_player_id
INNER JOIN silver.match AS m
    ON m.match_id = plwa.match_id
LEFT JOIN team_chances_created AS tc
    ON tc.match_id = p.match_id
   AND tc.team_id = p.team_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = plwa.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND p.player_id > 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)

ORDER BY
    triggered_player_first_late_winning_goal_assist_effective_minute DESC,
    triggered_player_late_winning_goal_assists DESC,
    triggered_player_assists DESC,
    m.match_date DESC,
    m.match_id DESC;
