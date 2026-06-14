INSERT INTO gold.sig_match_creativity_playmaking_playmaker_showdown (
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
    trigger_threshold_min_player_key_passes,
    match_players_meeting_key_pass_threshold,
    triggered_team_players_meeting_key_pass_threshold,
    opponent_players_meeting_key_pass_threshold,
    players_meeting_key_pass_threshold_delta,
    triggered_team_top_playmaker_id,
    triggered_team_top_playmaker_name,
    opponent_top_playmaker_id,
    opponent_top_playmaker_name,
    triggered_team_top_playmaker_key_passes,
    opponent_top_playmaker_key_passes,
    top_playmaker_key_passes_delta,
    triggered_team_top_playmaker_expected_assists,
    opponent_top_playmaker_expected_assists,
    top_playmaker_expected_assists_delta,
    triggered_team_top_playmaker_assists,
    opponent_top_playmaker_assists,
    top_playmaker_assists_delta,
    triggered_team_top_playmaker_passes_final_third,
    opponent_top_playmaker_passes_final_third,
    top_playmaker_passes_final_third_delta,
    triggered_team_key_passes,
    opponent_key_passes,
    key_pass_delta,
    triggered_team_expected_assists,
    opponent_expected_assists,
    expected_assists_delta,
    triggered_team_assists,
    opponent_assists,
    assists_delta,
    triggered_team_top_playmaker_share_of_team_key_passes_pct,
    opponent_top_playmaker_share_of_team_key_passes_pct,
    top_playmaker_share_of_team_key_passes_delta_pct,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_chance_conversion_pct,
    opponent_chance_conversion_pct,
    chance_conversion_delta_pct,
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
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    opposition_box_touches_delta
)
WITH player_creation_stats AS (
    SELECT
        p.match_id,
        p.team_id,
        p.player_id,
        coalesce(p.player_name, '') AS player_name,
        toInt32(sum(coalesce(p.chances_created, 0))) AS player_key_passes,
        toFloat32(round(sum(coalesce(p.expected_assists, 0.0)), 3)) AS player_expected_assists,
        toInt32(sum(coalesce(p.assists, 0))) AS player_assists,
        toInt32(sum(coalesce(p.passes_final_third, 0))) AS player_passes_final_third
    FROM silver.player_match_stat AS p
    WHERE p.match_id > 0
      AND coalesce(p.team_id, 0) > 0
      AND coalesce(p.player_id, 0) > 0
    GROUP BY
        p.match_id,
        p.team_id,
        p.player_id,
        player_name
),
team_playmaker_rollup AS (
    SELECT
        pcs.match_id,
        pcs.team_id,
        toInt32(countIf(pcs.player_key_passes >= 5)) AS team_players_meeting_key_pass_threshold,
        toInt32(max(pcs.player_key_passes)) AS team_top_playmaker_key_passes,
        toInt32(argMax(
            pcs.player_id,
            tuple(
                pcs.player_key_passes,
                pcs.player_expected_assists,
                pcs.player_assists,
                -pcs.player_id
            )
        )) AS team_top_playmaker_id,
        argMax(
            pcs.player_name,
            tuple(
                pcs.player_key_passes,
                pcs.player_expected_assists,
                pcs.player_assists,
                -pcs.player_id
            )
        ) AS team_top_playmaker_name,
        toFloat32(argMax(
            pcs.player_expected_assists,
            tuple(
                pcs.player_key_passes,
                pcs.player_expected_assists,
                pcs.player_assists,
                -pcs.player_id
            )
        )) AS team_top_playmaker_expected_assists,
        toInt32(argMax(
            pcs.player_assists,
            tuple(
                pcs.player_key_passes,
                pcs.player_expected_assists,
                pcs.player_assists,
                -pcs.player_id
            )
        )) AS team_top_playmaker_assists,
        toInt32(argMax(
            pcs.player_passes_final_third,
            tuple(
                pcs.player_key_passes,
                pcs.player_expected_assists,
                pcs.player_assists,
                -pcs.player_id
            )
        )) AS team_top_playmaker_passes_final_third
    FROM player_creation_stats AS pcs
    GROUP BY
        pcs.match_id,
        pcs.team_id
),
team_creation_stats AS (
    SELECT
        pcs.match_id,
        pcs.team_id,
        toInt32(sum(pcs.player_key_passes)) AS team_key_passes,
        toFloat32(round(sum(pcs.player_expected_assists), 3)) AS team_expected_assists,
        toInt32(sum(pcs.player_assists)) AS team_assists
    FROM player_creation_stats AS pcs
    GROUP BY
        pcs.match_id,
        pcs.team_id
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

        toInt32(coalesce(home_create.team_key_passes, 0)) AS home_key_passes,
        toInt32(coalesce(away_create.team_key_passes, 0)) AS away_key_passes,
        toFloat32(coalesce(home_create.team_expected_assists, 0.0)) AS home_expected_assists,
        toFloat32(coalesce(away_create.team_expected_assists, 0.0)) AS away_expected_assists,
        toInt32(coalesce(home_create.team_assists, 0)) AS home_assists,
        toInt32(coalesce(away_create.team_assists, 0)) AS away_assists,

        toInt32(coalesce(home_play.team_players_meeting_key_pass_threshold, 0))
            AS home_players_meeting_key_pass_threshold,
        toInt32(coalesce(away_play.team_players_meeting_key_pass_threshold, 0))
            AS away_players_meeting_key_pass_threshold,
        toInt32(coalesce(home_play.team_top_playmaker_id, 0)) AS home_top_playmaker_id,
        toInt32(coalesce(away_play.team_top_playmaker_id, 0)) AS away_top_playmaker_id,
        coalesce(home_play.team_top_playmaker_name, '') AS home_top_playmaker_name,
        coalesce(away_play.team_top_playmaker_name, '') AS away_top_playmaker_name,
        toInt32(coalesce(home_play.team_top_playmaker_key_passes, 0)) AS home_top_playmaker_key_passes,
        toInt32(coalesce(away_play.team_top_playmaker_key_passes, 0)) AS away_top_playmaker_key_passes,
        toFloat32(coalesce(home_play.team_top_playmaker_expected_assists, 0.0))
            AS home_top_playmaker_expected_assists,
        toFloat32(coalesce(away_play.team_top_playmaker_expected_assists, 0.0))
            AS away_top_playmaker_expected_assists,
        toInt32(coalesce(home_play.team_top_playmaker_assists, 0)) AS home_top_playmaker_assists,
        toInt32(coalesce(away_play.team_top_playmaker_assists, 0)) AS away_top_playmaker_assists,
        toInt32(coalesce(home_play.team_top_playmaker_passes_final_third, 0))
            AS home_top_playmaker_passes_final_third,
        toInt32(coalesce(away_play.team_top_playmaker_passes_final_third, 0))
            AS away_top_playmaker_passes_final_third,

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
        toInt32(coalesce(ps.touches_opp_box_home, 0)) AS touches_opposition_box_home,
        toInt32(coalesce(ps.touches_opp_box_away, 0)) AS touches_opposition_box_away,

        toInt32(
            coalesce(home_play.team_players_meeting_key_pass_threshold, 0)
            + coalesce(away_play.team_players_meeting_key_pass_threshold, 0)
        ) AS match_players_meeting_key_pass_threshold

    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.match_date = m.match_date
       AND ps.period = 'All'
    LEFT JOIN team_creation_stats AS home_create
        ON home_create.match_id = m.match_id
       AND home_create.team_id = m.home_team_id
    LEFT JOIN team_creation_stats AS away_create
        ON away_create.match_id = m.match_id
       AND away_create.team_id = m.away_team_id
    LEFT JOIN team_playmaker_rollup AS home_play
        ON home_play.match_id = m.match_id
       AND home_play.team_id = m.home_team_id
    LEFT JOIN team_playmaker_rollup AS away_play
        ON away_play.match_id = m.match_id
       AND away_play.team_id = m.away_team_id
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND coalesce(home_play.team_top_playmaker_key_passes, 0) >= 5
      AND coalesce(away_play.team_top_playmaker_key_passes, 0) >= 5
)
-- Signal: sig_match_creativity_playmaking_playmaker_showdown
-- Trigger: Both teams have at least one player with >= 5 key passes in one finished match.
-- Intent: Surface bilateral playmaker duels where each side fields a high-volume creator,
--         with deterministic top-playmaker identity and match context.
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

    toInt32(5) AS trigger_threshold_min_player_key_passes,
    b.match_players_meeting_key_pass_threshold,
    b.home_players_meeting_key_pass_threshold AS triggered_team_players_meeting_key_pass_threshold,
    b.away_players_meeting_key_pass_threshold AS opponent_players_meeting_key_pass_threshold,
    b.home_players_meeting_key_pass_threshold - b.away_players_meeting_key_pass_threshold
        AS players_meeting_key_pass_threshold_delta,

    b.home_top_playmaker_id AS triggered_team_top_playmaker_id,
    b.home_top_playmaker_name AS triggered_team_top_playmaker_name,
    b.away_top_playmaker_id AS opponent_top_playmaker_id,
    b.away_top_playmaker_name AS opponent_top_playmaker_name,

    b.home_top_playmaker_key_passes AS triggered_team_top_playmaker_key_passes,
    b.away_top_playmaker_key_passes AS opponent_top_playmaker_key_passes,
    b.home_top_playmaker_key_passes - b.away_top_playmaker_key_passes AS top_playmaker_key_passes_delta,

    b.home_top_playmaker_expected_assists AS triggered_team_top_playmaker_expected_assists,
    b.away_top_playmaker_expected_assists AS opponent_top_playmaker_expected_assists,
    toFloat32(round(
        b.home_top_playmaker_expected_assists - b.away_top_playmaker_expected_assists,
        3
    )) AS top_playmaker_expected_assists_delta,

    b.home_top_playmaker_assists AS triggered_team_top_playmaker_assists,
    b.away_top_playmaker_assists AS opponent_top_playmaker_assists,
    b.home_top_playmaker_assists - b.away_top_playmaker_assists AS top_playmaker_assists_delta,

    b.home_top_playmaker_passes_final_third AS triggered_team_top_playmaker_passes_final_third,
    b.away_top_playmaker_passes_final_third AS opponent_top_playmaker_passes_final_third,
    b.home_top_playmaker_passes_final_third - b.away_top_playmaker_passes_final_third
        AS top_playmaker_passes_final_third_delta,

    b.home_key_passes AS triggered_team_key_passes,
    b.away_key_passes AS opponent_key_passes,
    b.home_key_passes - b.away_key_passes AS key_pass_delta,

    b.home_expected_assists AS triggered_team_expected_assists,
    b.away_expected_assists AS opponent_expected_assists,
    toFloat32(round(b.home_expected_assists - b.away_expected_assists, 3)) AS expected_assists_delta,

    b.home_assists AS triggered_team_assists,
    b.away_assists AS opponent_assists,
    b.home_assists - b.away_assists AS assists_delta,

    toFloat32(coalesce(round(
        100.0 * b.home_top_playmaker_key_passes / nullIf(toFloat64(b.home_key_passes), 0),
        1
    ), 0.0)) AS triggered_team_top_playmaker_share_of_team_key_passes_pct,
    toFloat32(coalesce(round(
        100.0 * b.away_top_playmaker_key_passes / nullIf(toFloat64(b.away_key_passes), 0),
        1
    ), 0.0)) AS opponent_top_playmaker_share_of_team_key_passes_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.home_top_playmaker_key_passes / nullIf(toFloat64(b.home_key_passes), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * b.away_top_playmaker_key_passes / nullIf(toFloat64(b.away_key_passes), 0),
            1
        ), 0.0),
        1
    )) AS top_playmaker_share_of_team_key_passes_delta_pct,

    b.home_goals AS triggered_team_goals,
    b.away_goals AS opponent_goals,
    b.home_goals - b.away_goals AS goal_delta,

    toFloat32(coalesce(round(
        100.0 * b.home_goals / nullIf(toFloat64(b.home_key_passes), 0),
        1
    ), 0.0)) AS triggered_team_chance_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * b.away_goals / nullIf(toFloat64(b.away_key_passes), 0),
        1
    ), 0.0)) AS opponent_chance_conversion_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.home_goals / nullIf(toFloat64(b.home_key_passes), 0), 1), 0.0)
      - coalesce(round(100.0 * b.away_goals / nullIf(toFloat64(b.away_key_passes), 0), 1), 0.0),
        1
    )) AS chance_conversion_delta_pct,

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

    toInt32(5) AS trigger_threshold_min_player_key_passes,
    b.match_players_meeting_key_pass_threshold,
    b.away_players_meeting_key_pass_threshold AS triggered_team_players_meeting_key_pass_threshold,
    b.home_players_meeting_key_pass_threshold AS opponent_players_meeting_key_pass_threshold,
    b.away_players_meeting_key_pass_threshold - b.home_players_meeting_key_pass_threshold
        AS players_meeting_key_pass_threshold_delta,

    b.away_top_playmaker_id AS triggered_team_top_playmaker_id,
    b.away_top_playmaker_name AS triggered_team_top_playmaker_name,
    b.home_top_playmaker_id AS opponent_top_playmaker_id,
    b.home_top_playmaker_name AS opponent_top_playmaker_name,

    b.away_top_playmaker_key_passes AS triggered_team_top_playmaker_key_passes,
    b.home_top_playmaker_key_passes AS opponent_top_playmaker_key_passes,
    b.away_top_playmaker_key_passes - b.home_top_playmaker_key_passes AS top_playmaker_key_passes_delta,

    b.away_top_playmaker_expected_assists AS triggered_team_top_playmaker_expected_assists,
    b.home_top_playmaker_expected_assists AS opponent_top_playmaker_expected_assists,
    toFloat32(round(
        b.away_top_playmaker_expected_assists - b.home_top_playmaker_expected_assists,
        3
    )) AS top_playmaker_expected_assists_delta,

    b.away_top_playmaker_assists AS triggered_team_top_playmaker_assists,
    b.home_top_playmaker_assists AS opponent_top_playmaker_assists,
    b.away_top_playmaker_assists - b.home_top_playmaker_assists AS top_playmaker_assists_delta,

    b.away_top_playmaker_passes_final_third AS triggered_team_top_playmaker_passes_final_third,
    b.home_top_playmaker_passes_final_third AS opponent_top_playmaker_passes_final_third,
    b.away_top_playmaker_passes_final_third - b.home_top_playmaker_passes_final_third
        AS top_playmaker_passes_final_third_delta,

    b.away_key_passes AS triggered_team_key_passes,
    b.home_key_passes AS opponent_key_passes,
    b.away_key_passes - b.home_key_passes AS key_pass_delta,

    b.away_expected_assists AS triggered_team_expected_assists,
    b.home_expected_assists AS opponent_expected_assists,
    toFloat32(round(b.away_expected_assists - b.home_expected_assists, 3)) AS expected_assists_delta,

    b.away_assists AS triggered_team_assists,
    b.home_assists AS opponent_assists,
    b.away_assists - b.home_assists AS assists_delta,

    toFloat32(coalesce(round(
        100.0 * b.away_top_playmaker_key_passes / nullIf(toFloat64(b.away_key_passes), 0),
        1
    ), 0.0)) AS triggered_team_top_playmaker_share_of_team_key_passes_pct,
    toFloat32(coalesce(round(
        100.0 * b.home_top_playmaker_key_passes / nullIf(toFloat64(b.home_key_passes), 0),
        1
    ), 0.0)) AS opponent_top_playmaker_share_of_team_key_passes_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.away_top_playmaker_key_passes / nullIf(toFloat64(b.away_key_passes), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * b.home_top_playmaker_key_passes / nullIf(toFloat64(b.home_key_passes), 0),
            1
        ), 0.0),
        1
    )) AS top_playmaker_share_of_team_key_passes_delta_pct,

    b.away_goals AS triggered_team_goals,
    b.home_goals AS opponent_goals,
    b.away_goals - b.home_goals AS goal_delta,

    toFloat32(coalesce(round(
        100.0 * b.away_goals / nullIf(toFloat64(b.away_key_passes), 0),
        1
    ), 0.0)) AS triggered_team_chance_conversion_pct,
    toFloat32(coalesce(round(
        100.0 * b.home_goals / nullIf(toFloat64(b.home_key_passes), 0),
        1
    ), 0.0)) AS opponent_chance_conversion_pct,
    toFloat32(round(
        coalesce(round(100.0 * b.away_goals / nullIf(toFloat64(b.away_key_passes), 0), 1), 0.0)
      - coalesce(round(100.0 * b.home_goals / nullIf(toFloat64(b.home_key_passes), 0), 1), 0.0),
        1
    )) AS chance_conversion_delta_pct,

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

    b.touches_opposition_box_away AS triggered_team_touches_opposition_box,
    b.touches_opposition_box_home AS opponent_touches_opposition_box,
    b.touches_opposition_box_away - b.touches_opposition_box_home AS opposition_box_touches_delta

FROM base_stats AS b

ORDER BY match_id, triggered_side;
