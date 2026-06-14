INSERT INTO gold.sig_player_creativity_playmaking_unselfish_forward (
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
    trigger_threshold_min_key_passes,
    trigger_threshold_max_total_shots,
    trigger_threshold_required_usual_playing_position_id,
    triggered_player_key_passes,
    triggered_player_key_passes_above_threshold,
    triggered_player_total_shots,
    triggered_player_shots_on_target,
    triggered_player_shot_accuracy_pct,
    triggered_player_assists,
    triggered_player_expected_assists,
    triggered_player_chances_created,
    triggered_player_passes_final_third,
    triggered_player_touches_opposition_box,
    triggered_player_accurate_passes,
    triggered_player_total_passes,
    triggered_player_pass_accuracy_pct,
    triggered_player_minutes_played,
    triggered_player_touches,
    triggered_team_total_key_passes,
    opponent_total_key_passes,
    key_pass_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    total_shot_delta,
    triggered_team_expected_goals,
    opponent_expected_goals,
    expected_goals_delta,
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
    player_share_of_team_key_passes_pct,
    player_share_of_team_passes_pct,
    player_share_of_team_opposition_box_touches_pct
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
), team_key_passes AS (
    SELECT
        p.match_id,
        p.team_id,
        toInt32(sum(coalesce(p.chances_created, 0))) AS team_total_key_passes
    FROM silver.player_match_stat AS p
    WHERE p.team_id IS NOT NULL
    GROUP BY
        p.match_id,
        p.team_id
)
-- Signal: sig_player_creativity_playmaking_unselfish_forward
-- Trigger: striker proxy records >= 3 key passes with 0 total shots in a finished match.
-- Intent: identify forward playmakers who prioritize chance creation over finishing,
--         while preserving bilateral passing, shot-volume, and territorial context.
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

    'striker_proxy' AS triggered_player_role_group,
    toInt32(coalesce(pp.position_id, 0)) AS triggered_player_position_id,
    toInt32(coalesce(pp.usual_playing_position_id, 0)) AS triggered_player_usual_playing_position_id,

    toInt32(3) AS trigger_threshold_min_key_passes,
    toInt32(0) AS trigger_threshold_max_total_shots,
    toInt32(3) AS trigger_threshold_required_usual_playing_position_id,
    toInt32(coalesce(p.chances_created, 0)) AS triggered_player_key_passes,
    toInt32(coalesce(p.chances_created, 0) - 3) AS triggered_player_key_passes_above_threshold,
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
    toInt32(coalesce(p.assists, 0)) AS triggered_player_assists,
    toFloat32(coalesce(p.expected_assists, 0.0)) AS triggered_player_expected_assists,
    toInt32(coalesce(p.chances_created, 0)) AS triggered_player_chances_created,
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
    toInt32(coalesce(tkt.team_total_key_passes, 0)) AS triggered_team_total_key_passes,
    toInt32(coalesce(tko.team_total_key_passes, 0)) AS opponent_total_key_passes,
    toInt32(coalesce(tkt.team_total_key_passes, 0) - coalesce(tko.team_total_key_passes, 0))
        AS key_pass_delta,
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
        p.team_id = m.home_team_id,
            coalesce(ps.total_shots_home, 0) - coalesce(ps.total_shots_away, 0),
        p.team_id = m.away_team_id,
            coalesce(ps.total_shots_away, 0) - coalesce(ps.total_shots_home, 0),
        0
    )) AS total_shot_delta,
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
    toFloat32(coalesce(
        round(
            100.0 * coalesce(p.chances_created, 0)
            / nullIf(toFloat64(coalesce(tkt.team_total_key_passes, 0)), 0),
            1
        ),
        0.0
    )) AS player_share_of_team_key_passes_pct,
    toFloat32(coalesce(
        round(
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
        ),
        0.0
    )) AS player_share_of_team_passes_pct,
    toFloat32(coalesce(
        round(
            100.0 * coalesce(p.touches_opp_box, 0)
            / nullIf(
                toFloat64(multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.touches_opp_box_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.touches_opp_box_away, 0),
                    0
                )),
                0
            ),
            1
        ),
        0.0
    )) AS player_share_of_team_opposition_box_touches_pct

FROM silver.player_match_stat AS p
INNER JOIN silver.match AS m
    ON m.match_id = p.match_id
INNER JOIN player_positions AS pp
    ON pp.match_id = p.match_id
   AND pp.person_id = toInt32(p.player_id)
LEFT JOIN team_key_passes AS tkt
    ON tkt.match_id = p.match_id
   AND tkt.team_id = p.team_id
LEFT JOIN team_key_passes AS tko
    ON tko.match_id = p.match_id
   AND tko.team_id = if(p.team_id = m.home_team_id, m.away_team_id, m.home_team_id)
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = p.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND p.player_id > 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)
  AND coalesce(pp.usual_playing_position_id, 0) = 3
  AND coalesce(p.chances_created, 0) >= 3
  AND coalesce(p.total_shots, 0) = 0

ORDER BY
    triggered_player_key_passes DESC,
    triggered_player_expected_assists DESC,
    triggered_player_passes_final_third DESC,
    m.match_date DESC,
    m.match_id DESC;
