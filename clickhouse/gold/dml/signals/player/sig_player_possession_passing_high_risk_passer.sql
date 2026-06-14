INSERT INTO gold.sig_player_possession_passing_high_risk_passer (
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
    triggered_player_big_chances_created,
    triggered_player_chances_created,
    triggered_player_expected_assists,
    triggered_player_passes_final_third,
    triggered_player_touches_opposition_box,
    triggered_player_accurate_passes,
    triggered_player_total_passes,
    triggered_player_pass_accuracy_pct,
    triggered_player_minutes_played,
    triggered_player_touches,
    triggered_team_big_chances,
    opponent_big_chances,
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
    player_share_of_team_big_chances_pct,
    player_share_of_team_passes_pct
)
-- Signal: sig_player_possession_passing_high_risk_passer
-- Trigger: player pass accuracy < 70% and player big chances created >= 5 in a single match.
-- Intent: identify high-upside, high-risk passers who create many high-quality chances despite low pass completion, with bilateral team context.

WITH player_big_chance_creation AS (
    SELECT
        s.match_id,
        assumeNotNull(s.assist_player_id) AS triggered_player_id,
        countIf(coalesce(s.expected_goals, 0.0) >= 0.30) AS triggered_player_big_chances_created
    FROM silver.shot AS s
    WHERE s.assist_player_id IS NOT NULL
    GROUP BY
        s.match_id,
        s.assist_player_id
    HAVING triggered_player_big_chances_created >= 5
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
    p.player_name AS triggered_player_name,

    if(p.team_id = m.home_team_id, m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(p.team_id = m.home_team_id, m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(p.team_id = m.home_team_id, m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(p.team_id = m.home_team_id, m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(c.triggered_player_big_chances_created) AS triggered_player_big_chances_created,
    coalesce(p.chances_created, 0) AS triggered_player_chances_created,
    toFloat32(coalesce(p.expected_assists, 0.0)) AS triggered_player_expected_assists,
    coalesce(p.passes_final_third, 0) AS triggered_player_passes_final_third,
    coalesce(p.touches_opp_box, 0) AS triggered_player_touches_opposition_box,
    coalesce(p.accurate_passes, 0) AS triggered_player_accurate_passes,
    coalesce(p.total_passes, 0) AS triggered_player_total_passes,
    toFloat32(coalesce(
        p.pass_accuracy,
        round(
            100.0 * coalesce(p.accurate_passes, 0)
            / nullIf(coalesce(p.total_passes, 0), 0),
            1
        ),
        0.0
    )) AS triggered_player_pass_accuracy_pct,
    coalesce(p.minutes_played, 0) AS triggered_player_minutes_played,
    coalesce(p.touches, 0) AS triggered_player_touches,

    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.big_chances_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.big_chances_away, 0),
        0
    ) AS triggered_team_big_chances,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.big_chances_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.big_chances_home, 0),
        0
    ) AS opponent_big_chances,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.pass_attempts_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.pass_attempts_away, 0),
        0
    ) AS triggered_team_pass_attempts,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.pass_attempts_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.pass_attempts_home, 0),
        0
    ) AS opponent_pass_attempts,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.accurate_passes_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.accurate_passes_away, 0),
        0
    ) AS triggered_team_accurate_passes,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.accurate_passes_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.accurate_passes_home, 0),
        0
    ) AS opponent_accurate_passes,
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
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.touches_opp_box_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.touches_opp_box_away, 0),
        0
    ) AS triggered_team_touches_opposition_box,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.touches_opp_box_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.touches_opp_box_home, 0),
        0
    ) AS opponent_touches_opposition_box,
    toFloat32(coalesce(
        round(
            100.0 * c.triggered_player_big_chances_created
            / nullIf(
                multiIf(
                    p.team_id = m.home_team_id, coalesce(ps.big_chances_home, 0),
                    p.team_id = m.away_team_id, coalesce(ps.big_chances_away, 0),
                    0
                ),
                0
            ),
            1
        ),
        0.0
    )) AS player_share_of_team_big_chances_pct,
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
    )) AS player_share_of_team_passes_pct

FROM silver.player_match_stat AS p
INNER JOIN silver.match AS m
    ON m.match_id = p.match_id
INNER JOIN player_big_chance_creation AS c
    ON c.match_id = p.match_id
   AND c.triggered_player_id = p.player_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = p.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)
  AND coalesce(
        p.pass_accuracy,
        round(
            100.0 * coalesce(p.accurate_passes, 0)
            / nullIf(coalesce(p.total_passes, 0), 0),
            1
        ),
        0.0
    ) < 70.0

ORDER BY
    triggered_player_big_chances_created DESC,
    triggered_player_pass_accuracy_pct ASC,
    triggered_player_expected_assists DESC,
    m.match_date DESC,
    m.match_id DESC;
