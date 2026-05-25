WITH team_key_passes AS (
    SELECT
        match_id,
        team_id,
        sum(coalesce(chances_created, 0)) AS triggered_team_total_key_passes
    FROM silver.player_match_stat
    GROUP BY
        match_id,
        team_id
)
INSERT INTO gold.sig_player_creativity_playmaking_isolated_creativity (
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
    trigger_threshold_min_player_share_of_team_key_passes_pct,
    triggered_player_key_passes,
    triggered_team_total_key_passes,
    player_share_of_team_key_passes_pct,
    player_share_of_team_key_passes_above_threshold_pct,
    triggered_player_expected_assists,
    triggered_player_passes_final_third,
    triggered_player_touches_opposition_box,
    triggered_player_accurate_passes,
    triggered_player_total_passes,
    triggered_player_pass_accuracy_pct,
    triggered_player_minutes_played,
    triggered_player_touches,
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
    player_share_of_team_passes_pct,
    player_share_of_team_opposition_box_touches_pct
)
-- Signal: sig_player_creativity_playmaking_isolated_creativity
-- Trigger: player creates >= 50% of their team's total key passes in a finished match.
-- Intent: detect isolated single-player chance-creation burden, while preserving bilateral
--         passing and territorial context for tactical interpretation.
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

    toFloat32(50.0) AS trigger_threshold_min_player_share_of_team_key_passes_pct,
    toInt32(coalesce(p.chances_created, 0)) AS triggered_player_key_passes,
    toInt32(coalesce(team_key_passes.triggered_team_total_key_passes, 0))
        AS triggered_team_total_key_passes,
    toFloat32(coalesce(
        round(
            100.0 * coalesce(p.chances_created, 0)
            / nullIf(coalesce(team_key_passes.triggered_team_total_key_passes, 0), 0),
            1
        ),
        0.0
    )) AS player_share_of_team_key_passes_pct,
    toFloat32(round(
        coalesce(
            round(
                100.0 * coalesce(p.chances_created, 0)
                / nullIf(coalesce(team_key_passes.triggered_team_total_key_passes, 0), 0),
                1
            ),
            0.0
        ) - 50.0,
        1
    )) AS player_share_of_team_key_passes_above_threshold_pct,
    toFloat32(coalesce(p.expected_assists, 0.0)) AS triggered_player_expected_assists,
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
            100.0 * coalesce(p.total_passes, 0)
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
    )) AS player_share_of_team_passes_pct,
    toFloat32(coalesce(
        round(
            100.0 * coalesce(p.touches_opp_box, 0)
            / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.touches_opp_box_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.touches_opp_box_away, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    )) AS player_share_of_team_opposition_box_touches_pct

FROM silver.player_match_stat AS p
INNER JOIN silver.match AS m
    ON m.match_id = p.match_id
INNER JOIN team_key_passes
    ON team_key_passes.match_id = p.match_id
   AND team_key_passes.team_id = p.team_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = p.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)
  AND coalesce(team_key_passes.triggered_team_total_key_passes, 0) > 0
  AND (
    100.0 * coalesce(p.chances_created, 0)
    / nullIf(coalesce(team_key_passes.triggered_team_total_key_passes, 0), 0)
  ) >= 50.0

ORDER BY
    player_share_of_team_key_passes_pct DESC,
    triggered_player_key_passes DESC,
    triggered_player_expected_assists DESC,
    m.match_date DESC,
    m.match_id DESC;
