INSERT INTO gold.sig_match_creativity_playmaking_playmaker_to_striker_connection (
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
    trigger_threshold_min_creator_key_passes,
    trigger_threshold_min_assisted_goals_to_same_teammate_proxy,
    trigger_connection_proxy_source,
    match_players_meeting_connection_proxy_threshold,
    triggered_team_players_meeting_connection_proxy_threshold,
    opponent_players_meeting_connection_proxy_threshold,
    players_meeting_connection_proxy_threshold_delta,
    triggered_team_connection_creator_player_id,
    triggered_team_connection_creator_player_name,
    opponent_connection_creator_player_id,
    opponent_connection_creator_player_name,
    triggered_team_connection_finisher_player_id,
    triggered_team_connection_finisher_player_name,
    opponent_connection_finisher_player_id,
    opponent_connection_finisher_player_name,
    triggered_team_creator_key_passes,
    opponent_creator_key_passes,
    creator_key_passes_delta,
    triggered_team_creator_expected_assists,
    opponent_creator_expected_assists,
    creator_expected_assists_delta,
    triggered_team_assisted_goals_to_connection_finisher_proxy,
    opponent_assisted_goals_to_connection_finisher_proxy,
    assisted_goals_to_connection_finisher_proxy_delta,
    triggered_team_connection_creator_share_of_team_key_passes_pct,
    opponent_connection_creator_share_of_team_key_passes_pct,
    connection_creator_share_of_team_key_passes_delta_pct,
    triggered_team_key_passes,
    opponent_key_passes,
    key_pass_delta,
    triggered_team_expected_assists,
    opponent_expected_assists,
    expected_assists_delta,
    triggered_team_assists,
    opponent_assists,
    assists_delta,
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
        p.match_id AS match_id,
        p.team_id AS team_id,
        p.player_id AS player_id,
        coalesce(p.player_name, '') AS player_name,
        toInt32(sum(coalesce(p.chances_created, 0))) AS player_key_passes,
        toFloat32(round(sum(coalesce(p.expected_assists, 0.0)), 3)) AS player_expected_assists,
        toInt32(sum(coalesce(p.assists, 0))) AS player_assists,
        toInt32(sum(coalesce(p.goals, 0))) AS player_goals
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
assist_connection_stats AS (
    SELECT
        s.match_id AS match_id,
        s.team_id AS team_id,
        toInt32(s.assist_player_id) AS assist_player_id,
        coalesce(s.assist_player_name, '') AS assist_player_name,
        toInt32(s.player_id) AS finisher_player_id,
        coalesce(s.player_name, '') AS finisher_player_name,
        toInt32(count()) AS assisted_goals_to_finisher_proxy
    FROM silver.shot AS s
    WHERE s.match_id > 0
      AND coalesce(s.team_id, 0) > 0
      AND coalesce(s.assist_player_id, 0) > 0
      AND coalesce(s.player_id, 0) > 0
      AND coalesce(s.assist_player_id, 0) != coalesce(s.player_id, 0)
      AND s.is_goal = 1
    GROUP BY
        s.match_id,
        s.team_id,
        assist_player_id,
        assist_player_name,
        finisher_player_id,
        finisher_player_name
),
team_connection_candidates AS (
    SELECT
        acs.match_id AS match_id,
        acs.team_id AS team_id,
        acs.assist_player_id AS assist_player_id,
        coalesce(nullIf(acs.assist_player_name, ''), creator.player_name, '')
            AS assist_player_name,
        acs.finisher_player_id AS finisher_player_id,
        coalesce(nullIf(acs.finisher_player_name, ''), finisher.player_name, '')
            AS finisher_player_name,
        toInt32(acs.assisted_goals_to_finisher_proxy) AS assisted_goals_to_finisher_proxy,
        toInt32(coalesce(creator.player_key_passes, 0)) AS creator_key_passes,
        toFloat32(coalesce(creator.player_expected_assists, 0.0)) AS creator_expected_assists
    FROM assist_connection_stats AS acs
    INNER JOIN player_creation_stats AS creator
        ON creator.match_id = acs.match_id
       AND creator.team_id = acs.team_id
       AND creator.player_id = acs.assist_player_id
    LEFT JOIN player_creation_stats AS finisher
        ON finisher.match_id = acs.match_id
       AND finisher.team_id = acs.team_id
       AND finisher.player_id = acs.finisher_player_id
    WHERE coalesce(creator.player_key_passes, 0) >= 5
),
team_connection_rollup AS (
    SELECT
        c.match_id AS match_id,
        c.team_id AS team_id,
        toInt32(uniqExact(c.assist_player_id)) AS team_creators_meeting_connection_proxy_threshold,
        toInt32(argMax(
            c.assist_player_id,
            tuple(
                c.creator_key_passes,
                c.assisted_goals_to_finisher_proxy,
                c.creator_expected_assists,
                -c.assist_player_id,
                -c.finisher_player_id
            )
        )) AS team_connection_creator_player_id,
        argMax(
            c.assist_player_name,
            tuple(
                c.creator_key_passes,
                c.assisted_goals_to_finisher_proxy,
                c.creator_expected_assists,
                -c.assist_player_id,
                -c.finisher_player_id
            )
        ) AS team_connection_creator_player_name,
        toInt32(argMax(
            c.finisher_player_id,
            tuple(
                c.creator_key_passes,
                c.assisted_goals_to_finisher_proxy,
                c.creator_expected_assists,
                -c.assist_player_id,
                -c.finisher_player_id
            )
        )) AS team_connection_finisher_player_id,
        argMax(
            c.finisher_player_name,
            tuple(
                c.creator_key_passes,
                c.assisted_goals_to_finisher_proxy,
                c.creator_expected_assists,
                -c.assist_player_id,
                -c.finisher_player_id
            )
        ) AS team_connection_finisher_player_name,
        toInt32(argMax(
            c.creator_key_passes,
            tuple(
                c.creator_key_passes,
                c.assisted_goals_to_finisher_proxy,
                c.creator_expected_assists,
                -c.assist_player_id,
                -c.finisher_player_id
            )
        )) AS team_connection_creator_key_passes,
        toFloat32(argMax(
            c.creator_expected_assists,
            tuple(
                c.creator_key_passes,
                c.assisted_goals_to_finisher_proxy,
                c.creator_expected_assists,
                -c.assist_player_id,
                -c.finisher_player_id
            )
        )) AS team_connection_creator_expected_assists,
        toInt32(argMax(
            c.assisted_goals_to_finisher_proxy,
            tuple(
                c.creator_key_passes,
                c.assisted_goals_to_finisher_proxy,
                c.creator_expected_assists,
                -c.assist_player_id,
                -c.finisher_player_id
            )
        )) AS team_assisted_goals_to_connection_finisher_proxy
    FROM team_connection_candidates AS c
    GROUP BY
        c.match_id,
        c.team_id
),
team_creation_stats AS (
    SELECT
        pcs.match_id AS match_id,
        pcs.team_id AS team_id,
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

        toInt32(coalesce(home_conn.team_creators_meeting_connection_proxy_threshold, 0))
            AS home_players_meeting_connection_proxy_threshold,
        toInt32(coalesce(away_conn.team_creators_meeting_connection_proxy_threshold, 0))
            AS away_players_meeting_connection_proxy_threshold,

        toInt32(coalesce(home_conn.team_connection_creator_player_id, 0))
            AS home_connection_creator_player_id,
        coalesce(home_conn.team_connection_creator_player_name, '')
            AS home_connection_creator_player_name,
        toInt32(coalesce(home_conn.team_connection_finisher_player_id, 0))
            AS home_connection_finisher_player_id,
        coalesce(home_conn.team_connection_finisher_player_name, '')
            AS home_connection_finisher_player_name,
        toInt32(coalesce(home_conn.team_connection_creator_key_passes, 0))
            AS home_connection_creator_key_passes,
        toFloat32(coalesce(home_conn.team_connection_creator_expected_assists, 0.0))
            AS home_connection_creator_expected_assists,
        toInt32(coalesce(home_conn.team_assisted_goals_to_connection_finisher_proxy, 0))
            AS home_assisted_goals_to_connection_finisher_proxy,

        toInt32(coalesce(away_conn.team_connection_creator_player_id, 0))
            AS away_connection_creator_player_id,
        coalesce(away_conn.team_connection_creator_player_name, '')
            AS away_connection_creator_player_name,
        toInt32(coalesce(away_conn.team_connection_finisher_player_id, 0))
            AS away_connection_finisher_player_id,
        coalesce(away_conn.team_connection_finisher_player_name, '')
            AS away_connection_finisher_player_name,
        toInt32(coalesce(away_conn.team_connection_creator_key_passes, 0))
            AS away_connection_creator_key_passes,
        toFloat32(coalesce(away_conn.team_connection_creator_expected_assists, 0.0))
            AS away_connection_creator_expected_assists,
        toInt32(coalesce(away_conn.team_assisted_goals_to_connection_finisher_proxy, 0))
            AS away_assisted_goals_to_connection_finisher_proxy,

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
            coalesce(home_conn.team_creators_meeting_connection_proxy_threshold, 0)
          + coalesce(away_conn.team_creators_meeting_connection_proxy_threshold, 0)
        ) AS match_players_meeting_connection_proxy_threshold
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
    LEFT JOIN team_connection_rollup AS home_conn
        ON home_conn.match_id = m.match_id
       AND home_conn.team_id = m.home_team_id
    LEFT JOIN team_connection_rollup AS away_conn
        ON away_conn.match_id = m.match_id
       AND away_conn.team_id = m.away_team_id
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND (
            coalesce(home_conn.team_creators_meeting_connection_proxy_threshold, 0) > 0
         OR coalesce(away_conn.team_creators_meeting_connection_proxy_threshold, 0) > 0
      )
)
-- Signal: sig_match_creativity_playmaking_playmaker_to_striker_connection
-- Trigger: one player has >= 5 key passes and a same-teammate finish-link via goal assist.
-- Intent: surface creator-finisher partnerships when elite playmaking volume aligns
--         with repeated direct goal-link connection patterns in one finished match.
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
    toInt32(5) AS trigger_threshold_min_creator_key_passes,
    toInt32(1) AS trigger_threshold_min_assisted_goals_to_same_teammate_proxy,
    'key_pass_volume_plus_goal_assist_link_proxy' AS trigger_connection_proxy_source,
    b.match_players_meeting_connection_proxy_threshold,
    b.home_players_meeting_connection_proxy_threshold
        AS triggered_team_players_meeting_connection_proxy_threshold,
    b.away_players_meeting_connection_proxy_threshold
        AS opponent_players_meeting_connection_proxy_threshold,
    b.home_players_meeting_connection_proxy_threshold
      - b.away_players_meeting_connection_proxy_threshold
        AS players_meeting_connection_proxy_threshold_delta,
    b.home_connection_creator_player_id AS triggered_team_connection_creator_player_id,
    b.home_connection_creator_player_name AS triggered_team_connection_creator_player_name,
    b.away_connection_creator_player_id AS opponent_connection_creator_player_id,
    b.away_connection_creator_player_name AS opponent_connection_creator_player_name,
    b.home_connection_finisher_player_id AS triggered_team_connection_finisher_player_id,
    b.home_connection_finisher_player_name AS triggered_team_connection_finisher_player_name,
    b.away_connection_finisher_player_id AS opponent_connection_finisher_player_id,
    b.away_connection_finisher_player_name AS opponent_connection_finisher_player_name,
    b.home_connection_creator_key_passes AS triggered_team_creator_key_passes,
    b.away_connection_creator_key_passes AS opponent_creator_key_passes,
    b.home_connection_creator_key_passes - b.away_connection_creator_key_passes AS creator_key_passes_delta,
    b.home_connection_creator_expected_assists AS triggered_team_creator_expected_assists,
    b.away_connection_creator_expected_assists AS opponent_creator_expected_assists,
    toFloat32(round(
        b.home_connection_creator_expected_assists - b.away_connection_creator_expected_assists,
        3
    )) AS creator_expected_assists_delta,
    b.home_assisted_goals_to_connection_finisher_proxy
        AS triggered_team_assisted_goals_to_connection_finisher_proxy,
    b.away_assisted_goals_to_connection_finisher_proxy
        AS opponent_assisted_goals_to_connection_finisher_proxy,
    b.home_assisted_goals_to_connection_finisher_proxy
      - b.away_assisted_goals_to_connection_finisher_proxy
        AS assisted_goals_to_connection_finisher_proxy_delta,
    toFloat32(coalesce(round(
        100.0 * b.home_connection_creator_key_passes / nullIf(toFloat64(b.home_key_passes), 0),
        1
    ), 0.0)) AS triggered_team_connection_creator_share_of_team_key_passes_pct,
    toFloat32(coalesce(round(
        100.0 * b.away_connection_creator_key_passes / nullIf(toFloat64(b.away_key_passes), 0),
        1
    ), 0.0)) AS opponent_connection_creator_share_of_team_key_passes_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.home_connection_creator_key_passes / nullIf(toFloat64(b.home_key_passes), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * b.away_connection_creator_key_passes / nullIf(toFloat64(b.away_key_passes), 0),
            1
        ), 0.0),
        1
    )) AS connection_creator_share_of_team_key_passes_delta_pct,
    b.home_key_passes AS triggered_team_key_passes,
    b.away_key_passes AS opponent_key_passes,
    b.home_key_passes - b.away_key_passes AS key_pass_delta,
    b.home_expected_assists AS triggered_team_expected_assists,
    b.away_expected_assists AS opponent_expected_assists,
    toFloat32(round(b.home_expected_assists - b.away_expected_assists, 3)) AS expected_assists_delta,
    b.home_assists AS triggered_team_assists,
    b.away_assists AS opponent_assists,
    b.home_assists - b.away_assists AS assists_delta,
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
    toInt32(5) AS trigger_threshold_min_creator_key_passes,
    toInt32(1) AS trigger_threshold_min_assisted_goals_to_same_teammate_proxy,
    'key_pass_volume_plus_goal_assist_link_proxy' AS trigger_connection_proxy_source,
    b.match_players_meeting_connection_proxy_threshold,
    b.away_players_meeting_connection_proxy_threshold
        AS triggered_team_players_meeting_connection_proxy_threshold,
    b.home_players_meeting_connection_proxy_threshold
        AS opponent_players_meeting_connection_proxy_threshold,
    b.away_players_meeting_connection_proxy_threshold
      - b.home_players_meeting_connection_proxy_threshold
        AS players_meeting_connection_proxy_threshold_delta,
    b.away_connection_creator_player_id AS triggered_team_connection_creator_player_id,
    b.away_connection_creator_player_name AS triggered_team_connection_creator_player_name,
    b.home_connection_creator_player_id AS opponent_connection_creator_player_id,
    b.home_connection_creator_player_name AS opponent_connection_creator_player_name,
    b.away_connection_finisher_player_id AS triggered_team_connection_finisher_player_id,
    b.away_connection_finisher_player_name AS triggered_team_connection_finisher_player_name,
    b.home_connection_finisher_player_id AS opponent_connection_finisher_player_id,
    b.home_connection_finisher_player_name AS opponent_connection_finisher_player_name,
    b.away_connection_creator_key_passes AS triggered_team_creator_key_passes,
    b.home_connection_creator_key_passes AS opponent_creator_key_passes,
    b.away_connection_creator_key_passes - b.home_connection_creator_key_passes AS creator_key_passes_delta,
    b.away_connection_creator_expected_assists AS triggered_team_creator_expected_assists,
    b.home_connection_creator_expected_assists AS opponent_creator_expected_assists,
    toFloat32(round(
        b.away_connection_creator_expected_assists - b.home_connection_creator_expected_assists,
        3
    )) AS creator_expected_assists_delta,
    b.away_assisted_goals_to_connection_finisher_proxy
        AS triggered_team_assisted_goals_to_connection_finisher_proxy,
    b.home_assisted_goals_to_connection_finisher_proxy
        AS opponent_assisted_goals_to_connection_finisher_proxy,
    b.away_assisted_goals_to_connection_finisher_proxy
      - b.home_assisted_goals_to_connection_finisher_proxy
        AS assisted_goals_to_connection_finisher_proxy_delta,
    toFloat32(coalesce(round(
        100.0 * b.away_connection_creator_key_passes / nullIf(toFloat64(b.away_key_passes), 0),
        1
    ), 0.0)) AS triggered_team_connection_creator_share_of_team_key_passes_pct,
    toFloat32(coalesce(round(
        100.0 * b.home_connection_creator_key_passes / nullIf(toFloat64(b.home_key_passes), 0),
        1
    ), 0.0)) AS opponent_connection_creator_share_of_team_key_passes_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * b.away_connection_creator_key_passes / nullIf(toFloat64(b.away_key_passes), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * b.home_connection_creator_key_passes / nullIf(toFloat64(b.home_key_passes), 0),
            1
        ), 0.0),
        1
    )) AS connection_creator_share_of_team_key_passes_delta_pct,
    b.away_key_passes AS triggered_team_key_passes,
    b.home_key_passes AS opponent_key_passes,
    b.away_key_passes - b.home_key_passes AS key_pass_delta,
    b.away_expected_assists AS triggered_team_expected_assists,
    b.home_expected_assists AS opponent_expected_assists,
    toFloat32(round(b.away_expected_assists - b.home_expected_assists, 3)) AS expected_assists_delta,
    b.away_assists AS triggered_team_assists,
    b.home_assists AS opponent_assists,
    b.away_assists - b.home_assists AS assists_delta,
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
