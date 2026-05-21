INSERT INTO gold.sig_player_shooting_goals_clutch_brace_winning (
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
    trigger_threshold_min_equalizer_goals,
    trigger_threshold_min_decisive_winning_goals,
    triggered_player_equalizer_goals,
    triggered_player_decisive_winning_goals,
    triggered_player_first_equalizer_minute,
    triggered_player_first_equalizer_added_time,
    triggered_player_first_equalizer_effective_minute,
    triggered_player_first_decisive_winning_goal_minute,
    triggered_player_first_decisive_winning_goal_added_time,
    triggered_player_first_decisive_winning_goal_effective_minute,
    triggered_team_score_before_first_equalizer,
    opponent_score_before_first_equalizer,
    triggered_team_score_after_first_equalizer,
    opponent_score_after_first_equalizer,
    triggered_team_score_before_first_decisive_winning_goal,
    opponent_score_before_first_decisive_winning_goal,
    triggered_team_score_after_first_decisive_winning_goal,
    opponent_score_after_first_decisive_winning_goal,
    minutes_between_first_equalizer_and_first_decisive_winning_goal,
    final_goal_margin,
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
-- Signal: sig_player_shooting_goals_clutch_brace_winning
-- Trigger: player scores the equalizer and the decisive winner in the same finished match.
-- Intent: isolate clutch brace profiles where one player both restores parity and later scores the match winner.
WITH equalizer_goal_events AS (
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
        toString(coalesce(s.shot_id, '')) AS shot_id_key
    FROM silver.shot AS s
    WHERE s.match_id > 0
      AND coalesce(s.player_id, 0) > 0
      AND coalesce(s.team_id, 0) > 0
      AND coalesce(s.is_goal, 0) = 1
      AND coalesce(s.is_own_goal, 0) = 0
      AND coalesce(s.home_score_after, -1) = coalesce(s.away_score_after, -1)
),
decisive_winning_goal_candidates AS (
    SELECT
        s.match_id,
        toInt32(s.team_id) AS team_id,
        toInt32(s.player_id) AS player_id,
        coalesce(s.player_name, 'Unknown') AS player_name,
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
      AND coalesce(s.player_id, 0) > 0
      AND coalesce(s.team_id, 0) > 0
      AND coalesce(s.is_goal, 0) = 1
      AND coalesce(s.is_own_goal, 0) = 0
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
decisive_winning_goal_events AS (
    SELECT
        c.match_id,
        c.team_id,
        c.player_id,
        c.player_name,
        c.goal_minute,
        c.goal_added_time,
        c.goal_effective_minute,
        c.triggered_team_score_before,
        c.opponent_score_before,
        c.triggered_team_score_after,
        c.opponent_score_after,
        c.final_goal_margin,
        c.shot_id_key
    FROM decisive_winning_goal_candidates AS c
    LEFT JOIN silver.shot AS s2
        ON s2.match_id = c.match_id
       AND coalesce(s2.is_goal, 0) = 1
       AND coalesce(s2.is_own_goal, 0) = 0
       AND tuple(
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
    GROUP BY
        c.match_id,
        c.team_id,
        c.player_id,
        c.player_name,
        c.goal_minute,
        c.goal_added_time,
        c.goal_effective_minute,
        c.triggered_team_score_before,
        c.opponent_score_before,
        c.triggered_team_score_after,
        c.opponent_score_after,
        c.final_goal_margin,
        c.shot_id_key
    HAVING count(s2.match_id) = 0
),
player_equalizer_winner_events AS (
    SELECT
        d.match_id,
        d.team_id,
        d.player_id,
        argMin(
            d.player_name,
            tuple(d.goal_minute, d.goal_added_time, d.shot_id_key)
        ) AS triggered_player_name,
        countDistinct(tuple(e.goal_minute, e.goal_added_time, e.shot_id_key)) AS triggered_player_equalizer_goals,
        countDistinct(tuple(d.goal_minute, d.goal_added_time, d.shot_id_key))
            AS triggered_player_decisive_winning_goals,
        toInt32(min(e.goal_minute)) AS triggered_player_first_equalizer_minute,
        toInt32(argMin(
            e.goal_added_time,
            tuple(e.goal_minute, e.goal_added_time, e.shot_id_key)
        )) AS triggered_player_first_equalizer_added_time,
        toInt32(min(e.goal_effective_minute)) AS triggered_player_first_equalizer_effective_minute,
        toInt32(min(d.goal_minute)) AS triggered_player_first_decisive_winning_goal_minute,
        toInt32(argMin(
            d.goal_added_time,
            tuple(d.goal_minute, d.goal_added_time, d.shot_id_key)
        )) AS triggered_player_first_decisive_winning_goal_added_time,
        toInt32(min(d.goal_effective_minute))
            AS triggered_player_first_decisive_winning_goal_effective_minute,
        toInt32(argMin(
            e.triggered_team_score_before,
            tuple(e.goal_minute, e.goal_added_time, e.shot_id_key)
        )) AS triggered_team_score_before_first_equalizer,
        toInt32(argMin(
            e.opponent_score_before,
            tuple(e.goal_minute, e.goal_added_time, e.shot_id_key)
        )) AS opponent_score_before_first_equalizer,
        toInt32(argMin(
            e.triggered_team_score_after,
            tuple(e.goal_minute, e.goal_added_time, e.shot_id_key)
        )) AS triggered_team_score_after_first_equalizer,
        toInt32(argMin(
            e.opponent_score_after,
            tuple(e.goal_minute, e.goal_added_time, e.shot_id_key)
        )) AS opponent_score_after_first_equalizer,
        toInt32(argMin(
            d.triggered_team_score_before,
            tuple(d.goal_minute, d.goal_added_time, d.shot_id_key)
        )) AS triggered_team_score_before_first_decisive_winning_goal,
        toInt32(argMin(
            d.opponent_score_before,
            tuple(d.goal_minute, d.goal_added_time, d.shot_id_key)
        )) AS opponent_score_before_first_decisive_winning_goal,
        toInt32(argMin(
            d.triggered_team_score_after,
            tuple(d.goal_minute, d.goal_added_time, d.shot_id_key)
        )) AS triggered_team_score_after_first_decisive_winning_goal,
        toInt32(argMin(
            d.opponent_score_after,
            tuple(d.goal_minute, d.goal_added_time, d.shot_id_key)
        )) AS opponent_score_after_first_decisive_winning_goal,
        toInt32(argMin(
            d.final_goal_margin,
            tuple(d.goal_minute, d.goal_added_time, d.shot_id_key)
        )) AS final_goal_margin
    FROM decisive_winning_goal_events AS d
    INNER JOIN equalizer_goal_events AS e
        ON e.match_id = d.match_id
       AND e.team_id = d.team_id
       AND e.player_id = d.player_id
       AND tuple(e.goal_minute, e.goal_added_time, e.shot_id_key)
            < tuple(d.goal_minute, d.goal_added_time, d.shot_id_key)
    GROUP BY
        d.match_id,
        d.team_id,
        d.player_id
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
    pew.triggered_player_name,
    if(p.team_id = m.home_team_id, m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(p.team_id = m.home_team_id, m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(p.team_id = m.home_team_id, m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(p.team_id = m.home_team_id, m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(1) AS trigger_threshold_min_equalizer_goals,
    toInt32(1) AS trigger_threshold_min_decisive_winning_goals,
    toInt32(pew.triggered_player_equalizer_goals) AS triggered_player_equalizer_goals,
    toInt32(pew.triggered_player_decisive_winning_goals) AS triggered_player_decisive_winning_goals,
    toInt32(pew.triggered_player_first_equalizer_minute) AS triggered_player_first_equalizer_minute,
    toInt32(pew.triggered_player_first_equalizer_added_time) AS triggered_player_first_equalizer_added_time,
    toInt32(pew.triggered_player_first_equalizer_effective_minute)
        AS triggered_player_first_equalizer_effective_minute,
    toInt32(pew.triggered_player_first_decisive_winning_goal_minute)
        AS triggered_player_first_decisive_winning_goal_minute,
    toInt32(pew.triggered_player_first_decisive_winning_goal_added_time)
        AS triggered_player_first_decisive_winning_goal_added_time,
    toInt32(pew.triggered_player_first_decisive_winning_goal_effective_minute)
        AS triggered_player_first_decisive_winning_goal_effective_minute,
    toInt32(pew.triggered_team_score_before_first_equalizer)
        AS triggered_team_score_before_first_equalizer,
    toInt32(pew.opponent_score_before_first_equalizer) AS opponent_score_before_first_equalizer,
    toInt32(pew.triggered_team_score_after_first_equalizer)
        AS triggered_team_score_after_first_equalizer,
    toInt32(pew.opponent_score_after_first_equalizer) AS opponent_score_after_first_equalizer,
    toInt32(pew.triggered_team_score_before_first_decisive_winning_goal)
        AS triggered_team_score_before_first_decisive_winning_goal,
    toInt32(pew.opponent_score_before_first_decisive_winning_goal)
        AS opponent_score_before_first_decisive_winning_goal,
    toInt32(pew.triggered_team_score_after_first_decisive_winning_goal)
        AS triggered_team_score_after_first_decisive_winning_goal,
    toInt32(pew.opponent_score_after_first_decisive_winning_goal)
        AS opponent_score_after_first_decisive_winning_goal,
    toInt32(
        pew.triggered_player_first_decisive_winning_goal_effective_minute
        - pew.triggered_player_first_equalizer_effective_minute
    ) AS minutes_between_first_equalizer_and_first_decisive_winning_goal,
    toInt32(pew.final_goal_margin) AS final_goal_margin,

    toInt32(coalesce(p.goals, 0)) AS triggered_player_goals,
    toFloat32(coalesce(p.expected_goals, 0.0)) AS triggered_player_expected_goals,
    toInt32(coalesce(p.total_shots, 0)) AS triggered_player_total_shots,
    toInt32(coalesce(p.shots_on_target, 0)) AS triggered_player_shots_on_target,
    toFloat32(coalesce(
        round(
            100.0 * coalesce(p.shots_on_target, 0)
            / nullIf(toFloat64(coalesce(p.total_shots, 0)), 0),
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

FROM player_equalizer_winner_events AS pew
INNER JOIN silver.player_match_stat AS p
    ON p.match_id = pew.match_id
   AND p.team_id = pew.team_id
   AND p.player_id = pew.player_id
INNER JOIN silver.match AS m
    ON m.match_id = pew.match_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = pew.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND p.player_id > 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)

ORDER BY
    triggered_player_first_decisive_winning_goal_effective_minute DESC,
    triggered_player_equalizer_goals DESC,
    triggered_player_goals DESC,
    m.match_date DESC,
    m.match_id DESC;
