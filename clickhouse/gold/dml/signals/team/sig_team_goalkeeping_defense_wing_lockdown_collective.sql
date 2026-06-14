INSERT INTO gold.sig_team_goalkeeping_defense_wing_lockdown_collective (
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
    trigger_threshold_min_fullbacks_and_wingers_tackles_won,
    trigger_fullback_position_ids,
    trigger_winger_position_ids,
    triggered_team_fullbacks_and_wingers,
    opponent_fullbacks_and_wingers,
    fullbacks_and_wingers_count_delta,
    triggered_team_fullbacks_and_wingers_with_tackles,
    opponent_fullbacks_and_wingers_with_tackles,
    fullbacks_and_wingers_with_tackles_delta,
    triggered_team_fullbacks_tackles_won,
    opponent_fullbacks_tackles_won,
    fullbacks_tackles_won_delta,
    triggered_team_wingers_tackles_won,
    opponent_wingers_tackles_won,
    wingers_tackles_won_delta,
    triggered_team_fullbacks_and_wingers_tackles_won,
    opponent_fullbacks_and_wingers_tackles_won,
    fullbacks_and_wingers_tackles_won_delta,
    triggered_team_fullbacks_and_wingers_tackles_won_above_threshold,
    fullbacks_and_wingers_tackles_share_of_team_tackles_pct,
    opponent_fullbacks_and_wingers_tackles_share_of_team_tackles_pct,
    fullbacks_and_wingers_tackles_share_of_team_tackles_delta_pct,
    triggered_team_tackles_won,
    opponent_tackles_won,
    tackles_won_delta,
    triggered_team_interceptions,
    opponent_interceptions,
    interceptions_delta,
    triggered_team_clearances,
    opponent_clearances,
    clearances_delta,
    triggered_team_shot_blocks,
    opponent_shot_blocks,
    shot_blocks_delta,
    triggered_team_duels_won,
    opponent_duels_won,
    duels_won_delta,
    triggered_team_aerials_won,
    opponent_aerials_won,
    aerials_won_delta,
    triggered_team_total_shots_faced,
    opponent_total_shots_faced,
    total_shots_faced_delta,
    triggered_team_shots_on_target_faced,
    opponent_shots_on_target_faced,
    shots_on_target_faced_delta,
    triggered_team_keeper_saves,
    opponent_keeper_saves,
    keeper_saves_delta,
    triggered_team_fouls,
    opponent_fouls,
    fouls_delta,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_clean_sheet_flag
)
-- Signal: sig_team_goalkeeping_defense_wing_lockdown_collective
-- Intent: detect wing-lane defensive performances where fullback and winger roles combine
--         for very high tackle output, preserving bilateral defensive and control context.
-- Trigger: fullbacks and wingers combine for >= 15 tackles in a finished match (`period = 'All'`).
WITH player_role AS (
    SELECT
        mp.match_id,
        lowerUTF8(coalesce(mp.team_side, '')) AS team_side,
        toInt32(mp.person_id) AS player_id,
        argMax(mp.position_id, if(mp.role = 'starter', 2, 1)) AS position_id,
        argMax(mp.usual_playing_position_id, if(mp.role = 'starter', 2, 1))
            AS usual_playing_position_id
    FROM silver.match_personnel AS mp
    WHERE mp.match_id > 0
      AND coalesce(mp.person_id, 0) > 0
      AND mp.role IN ('starter', 'substitute')
      AND lowerUTF8(coalesce(mp.team_side, '')) IN ('home', 'away')
    GROUP BY
        mp.match_id,
        team_side,
        player_id
),
fullback_and_winger_tackles AS (
    SELECT
        pms.match_id,
        pr.team_side AS triggered_side,
        toInt32(pms.team_id) AS triggered_team_id,
        pr.player_id AS triggered_player_id,
        toInt32(coalesce(pms.tackles_won, 0)) AS triggered_player_tackles_won,
        toInt8(if(
            coalesce(pr.usual_playing_position_id, 0) = 1
            AND coalesce(pr.position_id, 0) IN (2, 5),
            1,
            0
        )) AS is_fullback_proxy,
        toInt8(if(
            coalesce(pr.usual_playing_position_id, 0) = 3
            AND coalesce(pr.position_id, 0) IN (2, 4),
            1,
            0
        )) AS is_winger_proxy
    FROM silver.player_match_stat AS pms
    INNER JOIN player_role AS pr
        ON pr.match_id = pms.match_id
       AND pr.player_id = pms.player_id
    WHERE pms.match_id > 0
      AND coalesce(pms.player_id, 0) > 0
      AND coalesce(pms.team_id, 0) > 0
      AND pr.team_side IN ('home', 'away')
      AND (
        (
            coalesce(pr.usual_playing_position_id, 0) = 1
            AND coalesce(pr.position_id, 0) IN (2, 5)
        )
        OR (
            coalesce(pr.usual_playing_position_id, 0) = 3
            AND coalesce(pr.position_id, 0) IN (2, 4)
        )
      )
),
team_role_tackle_rollup AS (
    SELECT
        rt.match_id AS match_id,
        rt.triggered_side AS triggered_side,
        rt.triggered_team_id AS triggered_team_id,
        toInt32(count()) AS rollup_fullbacks_and_wingers,
        toInt32(countIf(rt.triggered_player_tackles_won > 0))
            AS rollup_fullbacks_and_wingers_with_tackles,
        toInt32(sum(rt.triggered_player_tackles_won)) AS rollup_fullbacks_and_wingers_tackles_won,
        toInt32(sumIf(rt.triggered_player_tackles_won, rt.is_fullback_proxy = 1))
            AS rollup_fullbacks_tackles_won,
        toInt32(sumIf(rt.triggered_player_tackles_won, rt.is_winger_proxy = 1))
            AS rollup_wingers_tackles_won
    FROM fullback_and_winger_tackles AS rt
    GROUP BY
        rt.match_id,
        rt.triggered_side,
        rt.triggered_team_id
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

    ttr.triggered_side,
    if(ttr.triggered_side = 'home', m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(ttr.triggered_side = 'home', m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(ttr.triggered_side = 'home', m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(ttr.triggered_side = 'home', m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(15) AS trigger_threshold_min_fullbacks_and_wingers_tackles_won,
    '[2,5]' AS trigger_fullback_position_ids,
    '[2,4]' AS trigger_winger_position_ids,

    toInt32(ttr.rollup_fullbacks_and_wingers) AS triggered_team_fullbacks_and_wingers,
    toInt32(coalesce(otr.rollup_fullbacks_and_wingers, 0)) AS opponent_fullbacks_and_wingers,
    toInt32(
        ttr.rollup_fullbacks_and_wingers
        - coalesce(otr.rollup_fullbacks_and_wingers, 0)
    ) AS fullbacks_and_wingers_count_delta,

    toInt32(ttr.rollup_fullbacks_and_wingers_with_tackles)
        AS triggered_team_fullbacks_and_wingers_with_tackles,
    toInt32(coalesce(otr.rollup_fullbacks_and_wingers_with_tackles, 0))
        AS opponent_fullbacks_and_wingers_with_tackles,
    toInt32(
        ttr.rollup_fullbacks_and_wingers_with_tackles
      - coalesce(otr.rollup_fullbacks_and_wingers_with_tackles, 0)
    ) AS fullbacks_and_wingers_with_tackles_delta,

    toInt32(ttr.rollup_fullbacks_tackles_won) AS triggered_team_fullbacks_tackles_won,
    toInt32(coalesce(otr.rollup_fullbacks_tackles_won, 0)) AS opponent_fullbacks_tackles_won,
    toInt32(
        ttr.rollup_fullbacks_tackles_won
      - coalesce(otr.rollup_fullbacks_tackles_won, 0)
    ) AS fullbacks_tackles_won_delta,

    toInt32(ttr.rollup_wingers_tackles_won) AS triggered_team_wingers_tackles_won,
    toInt32(coalesce(otr.rollup_wingers_tackles_won, 0)) AS opponent_wingers_tackles_won,
    toInt32(
        ttr.rollup_wingers_tackles_won
      - coalesce(otr.rollup_wingers_tackles_won, 0)
    ) AS wingers_tackles_won_delta,

    toInt32(ttr.rollup_fullbacks_and_wingers_tackles_won)
        AS triggered_team_fullbacks_and_wingers_tackles_won,
    toInt32(coalesce(otr.rollup_fullbacks_and_wingers_tackles_won, 0))
        AS opponent_fullbacks_and_wingers_tackles_won,
    toInt32(
        ttr.rollup_fullbacks_and_wingers_tackles_won
      - coalesce(otr.rollup_fullbacks_and_wingers_tackles_won, 0)
    ) AS fullbacks_and_wingers_tackles_won_delta,
    toInt32(ttr.rollup_fullbacks_and_wingers_tackles_won - 15)
        AS triggered_team_fullbacks_and_wingers_tackles_won_above_threshold,

    toFloat32(coalesce(round(
        100.0 * ttr.rollup_fullbacks_and_wingers_tackles_won
        / nullIf(toFloat64(multiIf(
            ttr.triggered_side = 'home', coalesce(ps.tackles_succeeded_home, 0),
            ttr.triggered_side = 'away', coalesce(ps.tackles_succeeded_away, 0),
            0
        )), 0),
        1
    ), 0.0)) AS fullbacks_and_wingers_tackles_share_of_team_tackles_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(otr.rollup_fullbacks_and_wingers_tackles_won, 0)
        / nullIf(toFloat64(multiIf(
            ttr.triggered_side = 'home', coalesce(ps.tackles_succeeded_away, 0),
            ttr.triggered_side = 'away', coalesce(ps.tackles_succeeded_home, 0),
            0
        )), 0),
        1
    ), 0.0)) AS opponent_fullbacks_and_wingers_tackles_share_of_team_tackles_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * ttr.rollup_fullbacks_and_wingers_tackles_won
            / nullIf(toFloat64(multiIf(
                ttr.triggered_side = 'home', coalesce(ps.tackles_succeeded_home, 0),
                ttr.triggered_side = 'away', coalesce(ps.tackles_succeeded_away, 0),
                0
            )), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(otr.rollup_fullbacks_and_wingers_tackles_won, 0)
            / nullIf(toFloat64(multiIf(
                ttr.triggered_side = 'home', coalesce(ps.tackles_succeeded_away, 0),
                ttr.triggered_side = 'away', coalesce(ps.tackles_succeeded_home, 0),
                0
            )), 0),
            1
        ), 0.0),
        1
    )) AS fullbacks_and_wingers_tackles_share_of_team_tackles_delta_pct,

    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.tackles_succeeded_home, 0),
        ttr.triggered_side = 'away', coalesce(ps.tackles_succeeded_away, 0),
        0
    )) AS triggered_team_tackles_won,
    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.tackles_succeeded_away, 0),
        ttr.triggered_side = 'away', coalesce(ps.tackles_succeeded_home, 0),
        0
    )) AS opponent_tackles_won,
    toInt32(
        multiIf(
            ttr.triggered_side = 'home', coalesce(ps.tackles_succeeded_home, 0),
            ttr.triggered_side = 'away', coalesce(ps.tackles_succeeded_away, 0),
            0
        ) - multiIf(
            ttr.triggered_side = 'home', coalesce(ps.tackles_succeeded_away, 0),
            ttr.triggered_side = 'away', coalesce(ps.tackles_succeeded_home, 0),
            0
        )
    ) AS tackles_won_delta,

    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.interceptions_home, 0),
        ttr.triggered_side = 'away', coalesce(ps.interceptions_away, 0),
        0
    )) AS triggered_team_interceptions,
    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.interceptions_away, 0),
        ttr.triggered_side = 'away', coalesce(ps.interceptions_home, 0),
        0
    )) AS opponent_interceptions,
    toInt32(
        multiIf(
            ttr.triggered_side = 'home', coalesce(ps.interceptions_home, 0),
            ttr.triggered_side = 'away', coalesce(ps.interceptions_away, 0),
            0
        ) - multiIf(
            ttr.triggered_side = 'home', coalesce(ps.interceptions_away, 0),
            ttr.triggered_side = 'away', coalesce(ps.interceptions_home, 0),
            0
        )
    ) AS interceptions_delta,

    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.clearances_home, 0),
        ttr.triggered_side = 'away', coalesce(ps.clearances_away, 0),
        0
    )) AS triggered_team_clearances,
    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.clearances_away, 0),
        ttr.triggered_side = 'away', coalesce(ps.clearances_home, 0),
        0
    )) AS opponent_clearances,
    toInt32(
        multiIf(
            ttr.triggered_side = 'home', coalesce(ps.clearances_home, 0),
            ttr.triggered_side = 'away', coalesce(ps.clearances_away, 0),
            0
        ) - multiIf(
            ttr.triggered_side = 'home', coalesce(ps.clearances_away, 0),
            ttr.triggered_side = 'away', coalesce(ps.clearances_home, 0),
            0
        )
    ) AS clearances_delta,

    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.shot_blocks_home, 0),
        ttr.triggered_side = 'away', coalesce(ps.shot_blocks_away, 0),
        0
    )) AS triggered_team_shot_blocks,
    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.shot_blocks_away, 0),
        ttr.triggered_side = 'away', coalesce(ps.shot_blocks_home, 0),
        0
    )) AS opponent_shot_blocks,
    toInt32(
        multiIf(
            ttr.triggered_side = 'home', coalesce(ps.shot_blocks_home, 0),
            ttr.triggered_side = 'away', coalesce(ps.shot_blocks_away, 0),
            0
        ) - multiIf(
            ttr.triggered_side = 'home', coalesce(ps.shot_blocks_away, 0),
            ttr.triggered_side = 'away', coalesce(ps.shot_blocks_home, 0),
            0
        )
    ) AS shot_blocks_delta,

    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.duels_won_home, 0),
        ttr.triggered_side = 'away', coalesce(ps.duels_won_away, 0),
        0
    )) AS triggered_team_duels_won,
    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.duels_won_away, 0),
        ttr.triggered_side = 'away', coalesce(ps.duels_won_home, 0),
        0
    )) AS opponent_duels_won,
    toInt32(
        multiIf(
            ttr.triggered_side = 'home', coalesce(ps.duels_won_home, 0),
            ttr.triggered_side = 'away', coalesce(ps.duels_won_away, 0),
            0
        ) - multiIf(
            ttr.triggered_side = 'home', coalesce(ps.duels_won_away, 0),
            ttr.triggered_side = 'away', coalesce(ps.duels_won_home, 0),
            0
        )
    ) AS duels_won_delta,

    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.aerials_won_home, 0),
        ttr.triggered_side = 'away', coalesce(ps.aerials_won_away, 0),
        0
    )) AS triggered_team_aerials_won,
    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.aerials_won_away, 0),
        ttr.triggered_side = 'away', coalesce(ps.aerials_won_home, 0),
        0
    )) AS opponent_aerials_won,
    toInt32(
        multiIf(
            ttr.triggered_side = 'home', coalesce(ps.aerials_won_home, 0),
            ttr.triggered_side = 'away', coalesce(ps.aerials_won_away, 0),
            0
        ) - multiIf(
            ttr.triggered_side = 'home', coalesce(ps.aerials_won_away, 0),
            ttr.triggered_side = 'away', coalesce(ps.aerials_won_home, 0),
            0
        )
    ) AS aerials_won_delta,

    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.total_shots_away, 0),
        ttr.triggered_side = 'away', coalesce(ps.total_shots_home, 0),
        0
    )) AS triggered_team_total_shots_faced,
    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.total_shots_home, 0),
        ttr.triggered_side = 'away', coalesce(ps.total_shots_away, 0),
        0
    )) AS opponent_total_shots_faced,
    toInt32(
        multiIf(
            ttr.triggered_side = 'home', coalesce(ps.total_shots_away, 0),
            ttr.triggered_side = 'away', coalesce(ps.total_shots_home, 0),
            0
        ) - multiIf(
            ttr.triggered_side = 'home', coalesce(ps.total_shots_home, 0),
            ttr.triggered_side = 'away', coalesce(ps.total_shots_away, 0),
            0
        )
    ) AS total_shots_faced_delta,

    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.shots_on_target_away, 0),
        ttr.triggered_side = 'away', coalesce(ps.shots_on_target_home, 0),
        0
    )) AS triggered_team_shots_on_target_faced,
    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.shots_on_target_home, 0),
        ttr.triggered_side = 'away', coalesce(ps.shots_on_target_away, 0),
        0
    )) AS opponent_shots_on_target_faced,
    toInt32(
        multiIf(
            ttr.triggered_side = 'home', coalesce(ps.shots_on_target_away, 0),
            ttr.triggered_side = 'away', coalesce(ps.shots_on_target_home, 0),
            0
        ) - multiIf(
            ttr.triggered_side = 'home', coalesce(ps.shots_on_target_home, 0),
            ttr.triggered_side = 'away', coalesce(ps.shots_on_target_away, 0),
            0
        )
    ) AS shots_on_target_faced_delta,

    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.keeper_saves_home, 0),
        ttr.triggered_side = 'away', coalesce(ps.keeper_saves_away, 0),
        0
    )) AS triggered_team_keeper_saves,
    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.keeper_saves_away, 0),
        ttr.triggered_side = 'away', coalesce(ps.keeper_saves_home, 0),
        0
    )) AS opponent_keeper_saves,
    toInt32(
        multiIf(
            ttr.triggered_side = 'home', coalesce(ps.keeper_saves_home, 0),
            ttr.triggered_side = 'away', coalesce(ps.keeper_saves_away, 0),
            0
        ) - multiIf(
            ttr.triggered_side = 'home', coalesce(ps.keeper_saves_away, 0),
            ttr.triggered_side = 'away', coalesce(ps.keeper_saves_home, 0),
            0
        )
    ) AS keeper_saves_delta,

    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.fouls_home, 0),
        ttr.triggered_side = 'away', coalesce(ps.fouls_away, 0),
        0
    )) AS triggered_team_fouls,
    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.fouls_away, 0),
        ttr.triggered_side = 'away', coalesce(ps.fouls_home, 0),
        0
    )) AS opponent_fouls,
    toInt32(
        multiIf(
            ttr.triggered_side = 'home', coalesce(ps.fouls_home, 0),
            ttr.triggered_side = 'away', coalesce(ps.fouls_away, 0),
            0
        ) - multiIf(
            ttr.triggered_side = 'home', coalesce(ps.fouls_away, 0),
            ttr.triggered_side = 'away', coalesce(ps.fouls_home, 0),
            0
        )
    ) AS fouls_delta,

    toFloat32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.ball_possession_home, 0),
        ttr.triggered_side = 'away', coalesce(ps.ball_possession_away, 0),
        0
    )) AS triggered_team_possession_pct,
    toFloat32(multiIf(
        ttr.triggered_side = 'home', coalesce(ps.ball_possession_away, 0),
        ttr.triggered_side = 'away', coalesce(ps.ball_possession_home, 0),
        0
    )) AS opponent_possession_pct,
    toFloat32(round(
        multiIf(
            ttr.triggered_side = 'home', coalesce(ps.ball_possession_home, 0),
            ttr.triggered_side = 'away', coalesce(ps.ball_possession_away, 0),
            0
        ) - multiIf(
            ttr.triggered_side = 'home', coalesce(ps.ball_possession_away, 0),
            ttr.triggered_side = 'away', coalesce(ps.ball_possession_home, 0),
            0
        ),
        1
    )) AS possession_delta_pct,

    toFloat32(coalesce(round(
        100.0 * multiIf(
            ttr.triggered_side = 'home', coalesce(ps.accurate_passes_home, 0),
            ttr.triggered_side = 'away', coalesce(ps.accurate_passes_away, 0),
            0
        ) / nullIf(toFloat64(multiIf(
            ttr.triggered_side = 'home', coalesce(ps.pass_attempts_home, 0),
            ttr.triggered_side = 'away', coalesce(ps.pass_attempts_away, 0),
            0
        )), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * multiIf(
            ttr.triggered_side = 'home', coalesce(ps.accurate_passes_away, 0),
            ttr.triggered_side = 'away', coalesce(ps.accurate_passes_home, 0),
            0
        ) / nullIf(toFloat64(multiIf(
            ttr.triggered_side = 'home', coalesce(ps.pass_attempts_away, 0),
            ttr.triggered_side = 'away', coalesce(ps.pass_attempts_home, 0),
            0
        )), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * multiIf(
                ttr.triggered_side = 'home', coalesce(ps.accurate_passes_home, 0),
                ttr.triggered_side = 'away', coalesce(ps.accurate_passes_away, 0),
                0
            ) / nullIf(toFloat64(multiIf(
                ttr.triggered_side = 'home', coalesce(ps.pass_attempts_home, 0),
                ttr.triggered_side = 'away', coalesce(ps.pass_attempts_away, 0),
                0
            )), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * multiIf(
                ttr.triggered_side = 'home', coalesce(ps.accurate_passes_away, 0),
                ttr.triggered_side = 'away', coalesce(ps.accurate_passes_home, 0),
                0
            ) / nullIf(toFloat64(multiIf(
                ttr.triggered_side = 'home', coalesce(ps.pass_attempts_away, 0),
                ttr.triggered_side = 'away', coalesce(ps.pass_attempts_home, 0),
                0
            )), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(m.home_score, 0),
        ttr.triggered_side = 'away', coalesce(m.away_score, 0),
        0
    )) AS triggered_team_goals,
    toInt32(multiIf(
        ttr.triggered_side = 'home', coalesce(m.away_score, 0),
        ttr.triggered_side = 'away', coalesce(m.home_score, 0),
        0
    )) AS opponent_goals,
    toInt32(
        multiIf(
            ttr.triggered_side = 'home', coalesce(m.home_score, 0),
            ttr.triggered_side = 'away', coalesce(m.away_score, 0),
            0
        ) - multiIf(
            ttr.triggered_side = 'home', coalesce(m.away_score, 0),
            ttr.triggered_side = 'away', coalesce(m.home_score, 0),
            0
        )
    ) AS goal_delta,
    toInt8(if(
        multiIf(
            ttr.triggered_side = 'home', coalesce(m.away_score, 0),
            ttr.triggered_side = 'away', coalesce(m.home_score, 0),
            0
        ) = 0,
        1,
        0
    )) AS triggered_team_clean_sheet_flag
FROM team_role_tackle_rollup AS ttr
INNER JOIN silver.match AS m
    ON m.match_id = ttr.match_id
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN team_role_tackle_rollup AS otr
    ON otr.match_id = ttr.match_id
   AND otr.triggered_side = if(ttr.triggered_side = 'home', 'away', 'home')
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND ttr.triggered_team_id = if(ttr.triggered_side = 'home', m.home_team_id, m.away_team_id)
  AND ttr.rollup_fullbacks_and_wingers_tackles_won >= 15
ORDER BY
    rollup_fullbacks_and_wingers_tackles_won_above_threshold DESC,
    fullbacks_and_wingers_tackles_won_delta DESC,
    m.match_date DESC,
    m.match_id DESC,
    ttr.triggered_side;
