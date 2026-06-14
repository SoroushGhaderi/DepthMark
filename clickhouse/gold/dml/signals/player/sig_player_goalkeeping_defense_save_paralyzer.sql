INSERT INTO gold.sig_player_goalkeeping_defense_save_paralyzer (
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
    trigger_threshold_min_saved_shot_expected_goals,
    trigger_threshold_min_effective_minute,
    triggered_player_big_chance_saves_final_ten,
    triggered_player_first_big_chance_save_effective_minute,
    triggered_player_last_big_chance_save_effective_minute,
    triggered_player_highest_saved_shot_expected_goals_final_ten,
    triggered_player_avg_saved_shot_expected_goals_final_ten,
    triggered_player_saves_match,
    triggered_player_shots_on_target_faced_match,
    triggered_player_goals_conceded_match,
    triggered_player_save_rate_match_pct,
    triggered_player_minutes_played,
    triggered_player_touches,
    triggered_player_total_passes,
    triggered_player_accurate_passes,
    triggered_player_pass_accuracy_pct,
    triggered_team_score_at_first_big_chance_save,
    opponent_score_at_first_big_chance_save,
    score_margin_at_first_big_chance_save,
    triggered_team_big_chance_saves_final_ten,
    opponent_big_chance_saves_final_ten,
    triggered_team_keeper_saves,
    opponent_keeper_saves,
    triggered_team_total_shots_faced,
    opponent_total_shots_faced,
    triggered_team_shots_on_target_faced,
    opponent_shots_on_target_faced,
    triggered_team_expected_goals_faced,
    opponent_expected_goals_faced,
    triggered_team_expected_goals_on_target_faced,
    opponent_expected_goals_on_target_faced,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    big_chance_save_share_of_triggered_team_keeper_saves_pct,
    save_volume_delta_vs_opponent_keeper
)
-- Signal: sig_player_goalkeeping_defense_save_paralyzer
-- Intent: detect goalkeepers who deny high-quality shots late in matches and preserve bilateral
--         pressure/control context for tactical interpretation and downstream modeling.
-- Trigger: goalkeeper saves a shot with expected_goals > 0.4 at effective minute >= 80.
WITH keeper_shot_events AS (
    SELECT
        s.match_id,
        toInt32(assumeNotNull(s.keeper_id)) AS keeper_id,
        toInt64(coalesce(s.shot_id, 0)) AS shot_id,
        if(s.team_id = m.home_team_id, 'away', 'home') AS keeper_side,
        toInt32(
            coalesce(s.minute, s.goal_time, 0) + coalesce(s.minute_added, s.goal_overload_time, 0)
        ) AS shot_effective_minute,
        toUInt8(coalesce(s.is_on_target, 0)) AS is_on_target,
        toUInt8(coalesce(s.is_goal, 0)) AS is_goal,
        toUInt8(coalesce(s.is_saved_off_line, 0)) AS is_saved_off_line,
        toUInt8(
            coalesce(s.is_on_target, 0) = 1
            AND coalesce(s.is_goal, 0) = 0
            AND coalesce(s.is_saved_off_line, 0) = 0
        ) AS is_save,
        toFloat32(coalesce(s.expected_goals, 0.0)) AS shot_expected_goals,
        toInt32(coalesce(s.home_score_after, 0)) AS home_score_after,
        toInt32(coalesce(s.away_score_after, 0)) AS away_score_after
    FROM silver.shot AS s
    INNER JOIN silver.match AS m
        ON m.match_id = s.match_id
    WHERE s.match_id > 0
      AND s.keeper_id IS NOT NULL
      AND m.match_finished = 1
      AND (s.team_id = m.home_team_id OR s.team_id = m.away_team_id)
),
trigger_events AS (
    SELECT
        kse.match_id,
        kse.keeper_id,
        kse.shot_id,
        kse.keeper_side,
        kse.shot_effective_minute,
        kse.shot_expected_goals,
        kse.home_score_after,
        kse.away_score_after
    FROM keeper_shot_events AS kse
    WHERE kse.is_save = 1
      AND kse.shot_expected_goals > 0.4
      AND kse.shot_effective_minute >= 80
      AND kse.keeper_side IN ('home', 'away')
),
trigger_rollup AS (
    SELECT
        te.match_id,
        te.keeper_id AS triggered_player_id,
        argMin(te.keeper_side, tuple(te.shot_effective_minute, te.shot_id))
            AS triggered_side_from_events,
        toInt32(countDistinct(te.shot_id)) AS triggered_player_big_chance_saves_final_ten,
        min(te.shot_effective_minute) AS triggered_player_first_big_chance_save_effective_minute,
        max(te.shot_effective_minute) AS triggered_player_last_big_chance_save_effective_minute,
        toFloat32(round(max(te.shot_expected_goals), 3))
            AS triggered_player_highest_saved_shot_expected_goals_final_ten,
        toFloat32(round(avg(te.shot_expected_goals), 3))
            AS triggered_player_avg_saved_shot_expected_goals_final_ten,
        argMin(te.home_score_after, tuple(te.shot_effective_minute, te.shot_id))
            AS home_score_at_first_big_chance_save,
        argMin(te.away_score_after, tuple(te.shot_effective_minute, te.shot_id))
            AS away_score_at_first_big_chance_save
    FROM trigger_events AS te
    GROUP BY
        te.match_id,
        triggered_player_id
),
keeper_match_totals AS (
    SELECT
        kse.match_id,
        kse.keeper_id AS triggered_player_id,
        toInt32(countIf(kse.is_save = 1)) AS triggered_player_saves_match,
        toInt32(countIf(kse.is_on_target = 1)) AS triggered_player_shots_on_target_faced_match,
        toInt32(countIf(kse.is_on_target = 1 AND kse.is_goal = 1)) AS triggered_player_goals_conceded_match
    FROM keeper_shot_events AS kse
    GROUP BY
        kse.match_id,
        triggered_player_id
),
trigger_side_rollup AS (
    SELECT
        te.match_id,
        te.keeper_side,
        toInt32(countDistinct(te.shot_id)) AS side_big_chance_saves_final_ten
    FROM trigger_events AS te
    GROUP BY
        te.match_id,
        te.keeper_side
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

    toFloat32(0.4) AS trigger_threshold_min_saved_shot_expected_goals,
    toInt32(80) AS trigger_threshold_min_effective_minute,
    toInt32(tr.triggered_player_big_chance_saves_final_ten) AS triggered_player_big_chance_saves_final_ten,
    toInt32(tr.triggered_player_first_big_chance_save_effective_minute)
        AS triggered_player_first_big_chance_save_effective_minute,
    toInt32(tr.triggered_player_last_big_chance_save_effective_minute)
        AS triggered_player_last_big_chance_save_effective_minute,
    tr.triggered_player_highest_saved_shot_expected_goals_final_ten,
    tr.triggered_player_avg_saved_shot_expected_goals_final_ten,
    toInt32(coalesce(kmt.triggered_player_saves_match, 0)) AS triggered_player_saves_match,
    toInt32(coalesce(kmt.triggered_player_shots_on_target_faced_match, 0))
        AS triggered_player_shots_on_target_faced_match,
    toInt32(coalesce(kmt.triggered_player_goals_conceded_match, 0))
        AS triggered_player_goals_conceded_match,
    toFloat32(coalesce(round(
        100.0 * coalesce(kmt.triggered_player_saves_match, 0)
            / nullIf(coalesce(kmt.triggered_player_shots_on_target_faced_match, 0), 0),
        1
    ), 0.0)) AS triggered_player_save_rate_match_pct,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,
    toInt32(coalesce(p.touches, 0)) AS triggered_player_touches,
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
    toInt32(
        if(
            p.team_id = m.home_team_id,
            tr.home_score_at_first_big_chance_save,
            tr.away_score_at_first_big_chance_save
        )
    ) AS triggered_team_score_at_first_big_chance_save,
    toInt32(
        if(
            p.team_id = m.home_team_id,
            tr.away_score_at_first_big_chance_save,
            tr.home_score_at_first_big_chance_save
        )
    ) AS opponent_score_at_first_big_chance_save,
    toInt32(
        if(
            p.team_id = m.home_team_id,
            tr.home_score_at_first_big_chance_save - tr.away_score_at_first_big_chance_save,
            tr.away_score_at_first_big_chance_save - tr.home_score_at_first_big_chance_save
        )
    ) AS score_margin_at_first_big_chance_save,
    toInt32(coalesce(tsr.side_big_chance_saves_final_ten, 0)) AS triggered_team_big_chance_saves_final_ten,
    toInt32(coalesce(osr.side_big_chance_saves_final_ten, 0)) AS opponent_big_chance_saves_final_ten,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.keeper_saves_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.keeper_saves_away, 0),
        0
    )) AS triggered_team_keeper_saves,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.keeper_saves_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.keeper_saves_home, 0),
        0
    )) AS opponent_keeper_saves,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.total_shots_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.total_shots_home, 0),
        0
    )) AS triggered_team_total_shots_faced,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.total_shots_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.total_shots_away, 0),
        0
    )) AS opponent_total_shots_faced,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.shots_on_target_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.shots_on_target_home, 0),
        0
    )) AS triggered_team_shots_on_target_faced,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.shots_on_target_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.shots_on_target_away, 0),
        0
    )) AS opponent_shots_on_target_faced,
    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.expected_goals_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.expected_goals_home, 0),
        0
    )) AS triggered_team_expected_goals_faced,
    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.expected_goals_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.expected_goals_away, 0),
        0
    )) AS opponent_expected_goals_faced,
    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.expected_goals_on_target_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.expected_goals_on_target_home, 0),
        0
    )) AS triggered_team_expected_goals_on_target_faced,
    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.expected_goals_on_target_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.expected_goals_on_target_away, 0),
        0
    )) AS opponent_expected_goals_on_target_faced,
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
    toFloat32(coalesce(round(
        100.0 * multiIf(
            p.team_id = m.home_team_id, coalesce(ps.accurate_passes_home, 0),
            p.team_id = m.away_team_id, coalesce(ps.accurate_passes_away, 0),
            0
        )
        / nullIf(
            multiIf(
                p.team_id = m.home_team_id, coalesce(ps.pass_attempts_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.pass_attempts_away, 0),
                0
            ),
            0
        ),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * multiIf(
            p.team_id = m.home_team_id, coalesce(ps.accurate_passes_away, 0),
            p.team_id = m.away_team_id, coalesce(ps.accurate_passes_home, 0),
            0
        )
        / nullIf(
            multiIf(
                p.team_id = m.home_team_id, coalesce(ps.pass_attempts_away, 0),
                p.team_id = m.away_team_id, coalesce(ps.pass_attempts_home, 0),
                0
            ),
            0
        ),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * tr.triggered_player_big_chance_saves_final_ten
        / nullIf(
            multiIf(
                p.team_id = m.home_team_id, coalesce(ps.keeper_saves_home, 0),
                p.team_id = m.away_team_id, coalesce(ps.keeper_saves_away, 0),
                0
            ),
            0
        ),
        1
    ), 0.0)) AS big_chance_save_share_of_triggered_team_keeper_saves_pct,
    toInt32(
        coalesce(kmt.triggered_player_saves_match, 0)
        - multiIf(
            p.team_id = m.home_team_id, coalesce(ps.keeper_saves_away, 0),
            p.team_id = m.away_team_id, coalesce(ps.keeper_saves_home, 0),
            0
        )
    ) AS save_volume_delta_vs_opponent_keeper

FROM trigger_rollup AS tr
INNER JOIN silver.player_match_stat AS p
    ON p.match_id = tr.match_id
   AND p.player_id = tr.triggered_player_id
INNER JOIN silver.match AS m
    ON m.match_id = tr.match_id
LEFT JOIN keeper_match_totals AS kmt
    ON kmt.match_id = tr.match_id
   AND kmt.triggered_player_id = tr.triggered_player_id
LEFT JOIN trigger_side_rollup AS tsr
    ON tsr.match_id = tr.match_id
   AND tsr.keeper_side = if(p.team_id = m.home_team_id, 'home', 'away')
LEFT JOIN trigger_side_rollup AS osr
    ON osr.match_id = tr.match_id
   AND osr.keeper_side = if(p.team_id = m.home_team_id, 'away', 'home')
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = tr.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND p.is_goalkeeper = 1
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)
  AND tr.triggered_side_from_events = if(p.team_id = m.home_team_id, 'home', 'away')

ORDER BY
    triggered_player_big_chance_saves_final_ten DESC,
    triggered_player_highest_saved_shot_expected_goals_final_ten DESC,
    triggered_player_first_big_chance_save_effective_minute DESC,
    m.match_date DESC,
    m.match_id DESC,
    p.player_id ASC;
