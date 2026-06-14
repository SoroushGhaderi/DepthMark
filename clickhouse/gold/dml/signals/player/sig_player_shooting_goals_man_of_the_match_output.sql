INSERT INTO gold.sig_player_shooting_goals_man_of_the_match_output (
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
    trigger_threshold_min_expected_goals,
    trigger_threshold_min_expected_assists,
    trigger_threshold_min_expected_goal_involvement,
    triggered_player_goals,
    triggered_player_assists,
    triggered_player_expected_goals,
    triggered_player_expected_assists,
    triggered_player_expected_goal_involvement,
    triggered_player_total_shots,
    triggered_player_shots_on_target,
    triggered_player_shot_accuracy_pct,
    triggered_player_expected_goals_per_shot,
    triggered_player_goal_minus_expected_goals,
    triggered_player_assist_minus_expected_assists,
    triggered_player_chances_created,
    triggered_player_minutes_played,
    expected_goals_above_threshold,
    expected_assists_above_threshold,
    expected_goal_involvement_above_threshold,
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
    player_share_of_team_assists_pct,
    player_share_of_team_expected_assists_pct,
    player_share_of_team_chances_created_pct
)
-- Signal: sig_player_shooting_goals_man_of_the_match_output
-- Trigger: player records >= 1.5 expected_goals and >= 1.0 expected_assists in a finished match.
-- Intent: flag all-phase attacking outputs that combine elite shot-quality generation and chance-creation quality
-- in the same game, approximating a man-of-the-match level attacking footprint.
WITH team_player_totals AS (
    SELECT
        p.match_id,
        p.team_id,
        toInt32(sum(coalesce(p.assists, 0))) AS team_assists,
        toFloat32(round(sum(coalesce(p.expected_assists, 0.0)), 3)) AS team_expected_assists,
        toInt32(sum(coalesce(p.chances_created, 0))) AS team_chances_created
    FROM silver.player_match_stat AS p
    WHERE p.match_id > 0
      AND p.team_id > 0
      AND p.player_id > 0
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
    p.player_id AS triggered_player_id,
    coalesce(p.player_name, 'Unknown') AS triggered_player_name,
    if(p.team_id = m.home_team_id, m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(p.team_id = m.home_team_id, m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(p.team_id = m.home_team_id, m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(p.team_id = m.home_team_id, m.away_team_name, m.home_team_name) AS opponent_team_name,

    toFloat32(1.50) AS trigger_threshold_min_expected_goals,
    toFloat32(1.00) AS trigger_threshold_min_expected_assists,
    toFloat32(2.50) AS trigger_threshold_min_expected_goal_involvement,

    toInt32(coalesce(p.goals, 0)) AS triggered_player_goals,
    toInt32(coalesce(p.assists, 0)) AS triggered_player_assists,
    toFloat32(coalesce(p.expected_goals, 0.0)) AS triggered_player_expected_goals,
    toFloat32(coalesce(p.expected_assists, 0.0)) AS triggered_player_expected_assists,
    toFloat32(round(
        coalesce(p.xg_plus_xa, coalesce(p.expected_goals, 0.0) + coalesce(p.expected_assists, 0.0)),
        3
    )) AS triggered_player_expected_goal_involvement,
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
    toFloat32(round(
        coalesce(p.assists, 0) - coalesce(p.expected_assists, 0.0),
        3
    )) AS triggered_player_assist_minus_expected_assists,
    toInt32(coalesce(p.chances_created, 0)) AS triggered_player_chances_created,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,
    toFloat32(round(coalesce(p.expected_goals, 0.0) - 1.50, 3)) AS expected_goals_above_threshold,
    toFloat32(round(coalesce(p.expected_assists, 0.0) - 1.00, 3)) AS expected_assists_above_threshold,
    toFloat32(round(
        coalesce(p.xg_plus_xa, coalesce(p.expected_goals, 0.0) + coalesce(p.expected_assists, 0.0)) - 2.50,
        3
    )) AS expected_goal_involvement_above_threshold,

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
        100.0 * coalesce(p.assists, 0)
        / nullIf(toFloat64(coalesce(tpt.team_assists, 0)), 0),
        1
    ), 0.0)) AS player_share_of_team_assists_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(p.expected_assists, 0.0)
        / nullIf(coalesce(tpt.team_expected_assists, 0.0), 0.0),
        1
    ), 0.0)) AS player_share_of_team_expected_assists_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(p.chances_created, 0)
        / nullIf(toFloat64(coalesce(tpt.team_chances_created, 0)), 0),
        1
    ), 0.0)) AS player_share_of_team_chances_created_pct

FROM silver.player_match_stat AS p
INNER JOIN silver.match AS m
    ON m.match_id = p.match_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = p.match_id
   AND ps.period = 'All'
LEFT JOIN team_player_totals AS tpt
    ON tpt.match_id = p.match_id
   AND tpt.team_id = p.team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND p.player_id > 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)
  AND coalesce(p.expected_goals, 0.0) >= 1.50
  AND coalesce(p.expected_assists, 0.0) >= 1.00

ORDER BY
    triggered_player_expected_goal_involvement DESC,
    triggered_player_expected_goals DESC,
    triggered_player_expected_assists DESC,
    m.match_date DESC,
    m.match_id DESC;
