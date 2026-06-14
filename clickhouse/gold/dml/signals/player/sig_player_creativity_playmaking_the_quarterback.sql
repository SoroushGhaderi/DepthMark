INSERT INTO gold.sig_player_creativity_playmaking_the_quarterback (
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
    triggered_player_role_group,
    triggered_player_position_id,
    triggered_player_usual_playing_position_id,
    trigger_threshold_min_accurate_long_balls,
    triggered_player_accurate_long_balls,
    triggered_player_accurate_long_balls_above_threshold,
    triggered_player_long_ball_attempts,
    triggered_player_long_ball_success_rate_pct,
    triggered_player_total_passes,
    triggered_player_accurate_passes,
    triggered_player_pass_accuracy_pct,
    triggered_player_passes_final_third,
    triggered_player_chances_created,
    triggered_player_expected_assists,
    triggered_player_touches_opposition_box,
    triggered_player_minutes_played,
    triggered_player_touches,
    triggered_team_long_ball_attempts,
    opponent_long_ball_attempts,
    triggered_team_accurate_long_balls,
    opponent_accurate_long_balls,
    triggered_team_long_ball_accuracy_pct,
    opponent_long_ball_accuracy_pct,
    long_ball_accuracy_delta_pct,
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
    player_share_of_team_accurate_long_balls_pct,
    player_share_of_team_long_ball_attempts_pct
)
WITH player_positions AS (
    SELECT
        mp.match_id,
        toInt32(mp.person_id) AS person_id,
        argMax(mp.position_id, if(mp.role = 'starter', 2, 1)) AS position_id,
        argMax(mp.usual_playing_position_id, if(mp.role = 'starter', 2, 1))
            AS usual_playing_position_id
    FROM silver.match_personnel AS mp
    WHERE mp.role IN ('starter', 'substitute')
    GROUP BY
        mp.match_id,
        person_id
)
-- Signal: sig_player_creativity_playmaking_the_quarterback
-- Intent: detect center backs who drive playmaking through elite long-ball completion volume,
--         while preserving bilateral team passing and control context.
-- Trigger: center back completes >= 8 successful long balls in a finished match.
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

    'center_back' AS triggered_player_role_group,
    toInt32(coalesce(pp.position_id, 0)) AS triggered_player_position_id,
    toInt32(coalesce(pp.usual_playing_position_id, 0)) AS triggered_player_usual_playing_position_id,

    toInt32(8) AS trigger_threshold_min_accurate_long_balls,
    toInt32(coalesce(p.accurate_long_balls, 0)) AS triggered_player_accurate_long_balls,
    toInt32(coalesce(p.accurate_long_balls, 0) - 8) AS triggered_player_accurate_long_balls_above_threshold,
    toInt32(coalesce(p.long_ball_attempts, 0)) AS triggered_player_long_ball_attempts,
    toFloat32(coalesce(
        p.long_ball_success_rate,
        round(
            100.0 * coalesce(p.accurate_long_balls, 0)
            / nullIf(coalesce(p.long_ball_attempts, 0), 0),
            1
        ),
        0.0
    )) AS triggered_player_long_ball_success_rate_pct,
    toInt32(coalesce(p.total_passes, 0)) AS triggered_player_total_passes,
    toInt32(coalesce(p.accurate_passes, 0)) AS triggered_player_accurate_passes,
    toFloat32(coalesce(
        p.pass_accuracy,
        round(
            100.0 * coalesce(p.accurate_passes, 0)
            / nullIf(coalesce(p.total_passes, 0), 0),
            1
        ),
        0.0
    )) AS triggered_player_pass_accuracy_pct,
    toInt32(coalesce(p.passes_final_third, 0)) AS triggered_player_passes_final_third,
    toInt32(coalesce(p.chances_created, 0)) AS triggered_player_chances_created,
    toFloat32(coalesce(p.expected_assists, 0.0)) AS triggered_player_expected_assists,
    toInt32(coalesce(p.touches_opp_box, 0)) AS triggered_player_touches_opposition_box,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,
    toInt32(coalesce(p.touches, 0)) AS triggered_player_touches,

    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.long_ball_attempts_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.long_ball_attempts_away, 0),
        0
    )) AS triggered_team_long_ball_attempts,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.long_ball_attempts_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.long_ball_attempts_home, 0),
        0
    )) AS opponent_long_ball_attempts,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.accurate_long_balls_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.accurate_long_balls_away, 0),
        0
    )) AS triggered_team_accurate_long_balls,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.accurate_long_balls_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.accurate_long_balls_home, 0),
        0
    )) AS opponent_accurate_long_balls,
    toFloat32(coalesce(
        round(
            100.0 * multiIf(
                p.team_id = m.home_team_id, coalesce(ps.accurate_long_balls_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.accurate_long_balls_away, 0),
                0
            ) / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.long_ball_attempts_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.long_ball_attempts_away, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    )) AS triggered_team_long_ball_accuracy_pct,
    toFloat32(coalesce(
        round(
            100.0 * multiIf(
                p.team_id = m.home_team_id, coalesce(ps.accurate_long_balls_away, 0),
                p.team_id = m.away_team_id, coalesce(ps.accurate_long_balls_home, 0),
                0
            ) / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.long_ball_attempts_away, 0),
                    p.team_id = m.away_team_id, coalesce(ps.long_ball_attempts_home, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    )) AS opponent_long_ball_accuracy_pct,
    toFloat32(round(
        coalesce(
            round(
                100.0 * multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.accurate_long_balls_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.accurate_long_balls_away, 0),
                    0
                ) / nullIf(
                    multiIf(
                        p.team_id = m.home_team_id, coalesce(ps.long_ball_attempts_home, 0),
                        p.team_id = m.away_team_id, coalesce(ps.long_ball_attempts_away, 0),
                        0
                    ),
                    0
                ),
                1
            ),
            0.0
        )
      - coalesce(
            round(
                100.0 * multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.accurate_long_balls_away, 0),
                    p.team_id = m.away_team_id, coalesce(ps.accurate_long_balls_home, 0),
                    0
                ) / nullIf(
                    multiIf(
                        p.team_id = m.home_team_id, coalesce(ps.long_ball_attempts_away, 0),
                        p.team_id = m.away_team_id, coalesce(ps.long_ball_attempts_home, 0),
                        0
                    ),
                    0
                ),
                1
            ),
            0.0
        ),
        1
    )) AS long_ball_accuracy_delta_pct,

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
    toFloat32(round(
        coalesce(
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
        )
      - coalesce(
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
        ),
        1
    )) AS pass_accuracy_delta_pct,

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
    toFloat32(round(
        multiIf(
            p.team_id = m.home_team_id, coalesce(ps.ball_possession_home, 0),
            p.team_id = m.away_team_id, coalesce(ps.ball_possession_away, 0),
            0
        ) - multiIf(
            p.team_id = m.home_team_id, coalesce(ps.ball_possession_away, 0),
            p.team_id = m.away_team_id, coalesce(ps.ball_possession_home, 0),
            0
        ),
        1
    )) AS possession_delta_pct,

    toFloat32(coalesce(
        round(
            100.0 * coalesce(p.accurate_long_balls, 0)
            / nullIf(
                toFloat64(multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.accurate_long_balls_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.accurate_long_balls_away, 0),
                    0
                )),
                0.0
            ),
            1
        ),
        0.0
    )) AS player_share_of_team_accurate_long_balls_pct,
    toFloat32(coalesce(
        round(
            100.0 * coalesce(p.long_ball_attempts, 0)
            / nullIf(
                toFloat64(multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.long_ball_attempts_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.long_ball_attempts_away, 0),
                    0
                )),
                0.0
            ),
            1
        ),
        0.0
    )) AS player_share_of_team_long_ball_attempts_pct

FROM silver.player_match_stat AS p
INNER JOIN silver.match AS m
    ON m.match_id = p.match_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = p.match_id
   AND ps.period = 'All'
INNER JOIN player_positions AS pp
    ON pp.match_id = p.match_id
   AND pp.person_id = p.player_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)
  AND coalesce(pp.usual_playing_position_id, 0) = 1
  AND coalesce(pp.position_id, 0) IN (3, 4)
  AND coalesce(p.is_goalkeeper, 0) = 0
  AND coalesce(p.accurate_long_balls, 0) >= 8

ORDER BY
    triggered_player_accurate_long_balls DESC,
    triggered_player_long_ball_success_rate_pct DESC,
    triggered_player_long_ball_attempts DESC,
    m.match_date DESC,
    m.match_id DESC;
