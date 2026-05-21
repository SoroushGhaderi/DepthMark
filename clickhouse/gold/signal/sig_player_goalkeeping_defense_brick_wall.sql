INSERT INTO gold.sig_player_goalkeeping_defense_brick_wall (
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
    trigger_threshold_keeper_saves,
    triggered_player_saves,
    triggered_player_shots_on_target_faced,
    triggered_player_goals_conceded,
    triggered_player_save_rate_pct,
    triggered_player_minutes_played,
    triggered_player_touches,
    triggered_player_total_passes,
    triggered_player_accurate_passes,
    triggered_player_pass_accuracy_pct,
    triggered_team_keeper_saves,
    opponent_keeper_saves,
    triggered_team_total_shots_faced,
    opponent_total_shots_faced,
    triggered_team_shots_on_target_faced,
    opponent_shots_on_target_faced,
    triggered_team_expected_goals_faced,
    opponent_expected_goals_faced,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    saves_share_of_triggered_team_keeper_saves_pct,
    save_volume_delta_vs_opponent_keeper
)
-- Signal: sig_player_goalkeeping_defense_brick_wall
-- Intent: detect high-save goalkeeper performances and preserve bilateral pressure/control context.
-- Trigger: goalkeeper records at least 8 saves in a finished match.
WITH keeper_shot_events AS (
    SELECT
        s.match_id,
        toInt32(assumeNotNull(s.keeper_id)) AS triggered_player_id,
        countIf(coalesce(s.is_on_target, 0) = 1 AND coalesce(s.is_goal, 0) = 0) AS triggered_player_saves,
        countIf(coalesce(s.is_on_target, 0) = 1) AS triggered_player_shots_on_target_faced,
        countIf(coalesce(s.is_on_target, 0) = 1 AND coalesce(s.is_goal, 0) = 1) AS triggered_player_goals_conceded
    FROM silver.shot AS s
    WHERE s.match_id > 0
      AND s.keeper_id IS NOT NULL
    GROUP BY
        s.match_id,
        triggered_player_id
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

    toInt32(8) AS trigger_threshold_keeper_saves,
    toInt32(coalesce(kse.triggered_player_saves, 0)) AS triggered_player_saves,
    toInt32(coalesce(kse.triggered_player_shots_on_target_faced, 0)) AS triggered_player_shots_on_target_faced,
    toInt32(coalesce(kse.triggered_player_goals_conceded, 0)) AS triggered_player_goals_conceded,
    coalesce(
        round(
            100.0 * coalesce(kse.triggered_player_saves, 0)
            / nullIf(coalesce(kse.triggered_player_shots_on_target_faced, 0), 0),
            1
        ),
        0.0
    ) AS triggered_player_save_rate_pct,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,
    toInt32(coalesce(p.touches, 0)) AS triggered_player_touches,
    toInt32(coalesce(p.total_passes, 0)) AS triggered_player_total_passes,
    toInt32(coalesce(p.accurate_passes, 0)) AS triggered_player_accurate_passes,
    toFloat32(
        coalesce(
            p.pass_accuracy,
            round(
                100.0 * coalesce(p.accurate_passes, 0)
                / nullIf(coalesce(p.total_passes, 0), 0),
                1
            ),
            0.0
        )
    ) AS triggered_player_pass_accuracy_pct,

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
        p.team_id = m.home_team_id, coalesce(ps.ball_possession_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.ball_possession_away, 0),
        0
    )) AS triggered_team_possession_pct,
    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.ball_possession_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.ball_possession_home, 0),
        0
    )) AS opponent_possession_pct,
    coalesce(
        round(
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
        ),
        0.0
    ) AS triggered_team_pass_accuracy_pct,
    coalesce(
        round(
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
        ),
        0.0
    ) AS opponent_pass_accuracy_pct,
    coalesce(
        round(
            100.0 * coalesce(kse.triggered_player_saves, 0)
            / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.keeper_saves_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.keeper_saves_away, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    ) AS saves_share_of_triggered_team_keeper_saves_pct,
    toInt32(
        coalesce(kse.triggered_player_saves, 0)
        - multiIf(
            p.team_id = m.home_team_id, coalesce(ps.keeper_saves_away, 0),
            p.team_id = m.away_team_id, coalesce(ps.keeper_saves_home, 0),
            0
        )
    ) AS save_volume_delta_vs_opponent_keeper

FROM keeper_shot_events AS kse
INNER JOIN silver.player_match_stat AS p
    ON p.match_id = kse.match_id
   AND p.player_id = kse.triggered_player_id
INNER JOIN silver.match AS m
    ON m.match_id = kse.match_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = kse.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND p.is_goalkeeper = 1
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)
  AND coalesce(kse.triggered_player_saves, 0) >= 8

ORDER BY
    triggered_player_saves DESC,
    triggered_player_save_rate_pct DESC,
    triggered_player_shots_on_target_faced DESC,
    m.match_date DESC,
    m.match_id DESC,
    p.player_id ASC;
