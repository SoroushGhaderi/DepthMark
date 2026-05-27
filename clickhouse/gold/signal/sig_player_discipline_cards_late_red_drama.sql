INSERT INTO gold.sig_player_discipline_cards_late_red_drama (
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
    trigger_threshold_min_red_card_minute,
    triggered_player_red_card_minute,
    triggered_team_score_at_red,
    opponent_score_at_red,
    triggered_player_red_card_count_match,
    triggered_team_red_cards_match,
    opponent_red_cards_match,
    triggered_team_yellow_cards_match,
    opponent_yellow_cards_match,
    triggered_team_total_fouls,
    opponent_total_fouls,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_accurate_passes,
    opponent_accurate_passes,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct
)
-- Signal: sig_player_discipline_cards_late_red_drama
-- Intent: identify players dismissed late in matches and preserve bilateral match-discipline context.
-- Trigger: player receives a red card at minute > 85.
WITH player_red_card_counts AS (
    SELECT
        c.match_id,
        c.team_id,
        c.player_id,
        count() AS triggered_player_red_card_count_match
    FROM silver.card AS c
    WHERE c.match_id > 0
      AND c.player_id > 0
      AND positionCaseInsensitive(ifNull(c.card_type, ''), 'red') > 0
    GROUP BY
        c.match_id,
        c.team_id,
        c.player_id
),
first_late_red AS (
    SELECT
        c.match_id,
        c.team_side AS triggered_side,
        c.player_id AS triggered_player_id,
        c.player_name AS triggered_player_name,
        toInt32(coalesce(c.card_minute, 0)) AS triggered_player_red_card_minute,
        toInt32(coalesce(c.score_home_at_time, 0)) AS score_home_at_red,
        toInt32(coalesce(c.score_away_at_time, 0)) AS score_away_at_red,
        row_number() OVER (
            PARTITION BY c.match_id, c.team_id, c.player_id
            ORDER BY toInt32(coalesce(c.card_minute, 0)) ASC
        ) AS rn
    FROM silver.card AS c
    WHERE c.match_id > 0
      AND c.player_id > 0
      AND c.team_side IN ('home', 'away')
      AND positionCaseInsensitive(ifNull(c.card_type, ''), 'red') > 0
      AND toInt32(coalesce(c.card_minute, 0)) > 85
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

    lr.triggered_side,
    lr.triggered_player_id,
    lr.triggered_player_name,

    multiIf(
        lr.triggered_side = 'home', m.home_team_id,
        lr.triggered_side = 'away', m.away_team_id,
        NULL
    ) AS triggered_team_id,
    multiIf(
        lr.triggered_side = 'home', m.home_team_name,
        lr.triggered_side = 'away', m.away_team_name,
        NULL
    ) AS triggered_team_name,
    multiIf(
        lr.triggered_side = 'home', m.away_team_id,
        lr.triggered_side = 'away', m.home_team_id,
        NULL
    ) AS opponent_team_id,
    multiIf(
        lr.triggered_side = 'home', m.away_team_name,
        lr.triggered_side = 'away', m.home_team_name,
        NULL
    ) AS opponent_team_name,

    86 AS trigger_threshold_min_red_card_minute,
    lr.triggered_player_red_card_minute,
    multiIf(
        lr.triggered_side = 'home', lr.score_home_at_red,
        lr.triggered_side = 'away', lr.score_away_at_red,
        0
    ) AS triggered_team_score_at_red,
    multiIf(
        lr.triggered_side = 'home', lr.score_away_at_red,
        lr.triggered_side = 'away', lr.score_home_at_red,
        0
    ) AS opponent_score_at_red,

    coalesce(prc.triggered_player_red_card_count_match, 0) AS triggered_player_red_card_count_match,
    multiIf(
        lr.triggered_side = 'home', coalesce(ps.red_cards_home, 0),
        lr.triggered_side = 'away', coalesce(ps.red_cards_away, 0),
        0
    ) AS triggered_team_red_cards_match,
    multiIf(
        lr.triggered_side = 'home', coalesce(ps.red_cards_away, 0),
        lr.triggered_side = 'away', coalesce(ps.red_cards_home, 0),
        0
    ) AS opponent_red_cards_match,
    multiIf(
        lr.triggered_side = 'home', coalesce(ps.yellow_cards_home, 0),
        lr.triggered_side = 'away', coalesce(ps.yellow_cards_away, 0),
        0
    ) AS triggered_team_yellow_cards_match,
    multiIf(
        lr.triggered_side = 'home', coalesce(ps.yellow_cards_away, 0),
        lr.triggered_side = 'away', coalesce(ps.yellow_cards_home, 0),
        0
    ) AS opponent_yellow_cards_match,
    multiIf(
        lr.triggered_side = 'home', coalesce(ps.fouls_home, 0),
        lr.triggered_side = 'away', coalesce(ps.fouls_away, 0),
        0
    ) AS triggered_team_total_fouls,
    multiIf(
        lr.triggered_side = 'home', coalesce(ps.fouls_away, 0),
        lr.triggered_side = 'away', coalesce(ps.fouls_home, 0),
        0
    ) AS opponent_total_fouls,

    toFloat32(multiIf(
        lr.triggered_side = 'home', coalesce(ps.ball_possession_home, 0),
        lr.triggered_side = 'away', coalesce(ps.ball_possession_away, 0),
        0
    )) AS triggered_team_possession_pct,
    toFloat32(multiIf(
        lr.triggered_side = 'home', coalesce(ps.ball_possession_away, 0),
        lr.triggered_side = 'away', coalesce(ps.ball_possession_home, 0),
        0
    )) AS opponent_possession_pct,

    multiIf(
        lr.triggered_side = 'home', coalesce(ps.pass_attempts_home, 0),
        lr.triggered_side = 'away', coalesce(ps.pass_attempts_away, 0),
        0
    ) AS triggered_team_pass_attempts,
    multiIf(
        lr.triggered_side = 'home', coalesce(ps.pass_attempts_away, 0),
        lr.triggered_side = 'away', coalesce(ps.pass_attempts_home, 0),
        0
    ) AS opponent_pass_attempts,
    multiIf(
        lr.triggered_side = 'home', coalesce(ps.accurate_passes_home, 0),
        lr.triggered_side = 'away', coalesce(ps.accurate_passes_away, 0),
        0
    ) AS triggered_team_accurate_passes,
    multiIf(
        lr.triggered_side = 'home', coalesce(ps.accurate_passes_away, 0),
        lr.triggered_side = 'away', coalesce(ps.accurate_passes_home, 0),
        0
    ) AS opponent_accurate_passes,
    toFloat32(coalesce(round(
        100.0 * multiIf(
            lr.triggered_side = 'home', coalesce(ps.accurate_passes_home, 0),
            lr.triggered_side = 'away', coalesce(ps.accurate_passes_away, 0),
            0
        ) / nullIf(
            multiIf(
                lr.triggered_side = 'home', coalesce(ps.pass_attempts_home, 0),
                lr.triggered_side = 'away', coalesce(ps.pass_attempts_away, 0),
                0
            ),
            0
        ),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * multiIf(
            lr.triggered_side = 'home', coalesce(ps.accurate_passes_away, 0),
            lr.triggered_side = 'away', coalesce(ps.accurate_passes_home, 0),
            0
        ) / nullIf(
            multiIf(
                lr.triggered_side = 'home', coalesce(ps.pass_attempts_away, 0),
                lr.triggered_side = 'away', coalesce(ps.pass_attempts_home, 0),
                0
            ),
            0
        ),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct

FROM first_late_red AS lr
INNER JOIN silver.match AS m
    ON m.match_id = lr.match_id
LEFT JOIN player_red_card_counts AS prc
    ON prc.match_id = lr.match_id
   AND prc.team_id = multiIf(lr.triggered_side = 'home', m.home_team_id, lr.triggered_side = 'away', m.away_team_id, -1)
   AND prc.player_id = lr.triggered_player_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = lr.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND lr.rn = 1
  AND (
        (lr.triggered_side = 'home' AND lr.triggered_team_id = m.home_team_id)
        OR
        (lr.triggered_side = 'away' AND lr.triggered_team_id = m.away_team_id)
    )

ORDER BY
    triggered_player_red_card_minute DESC,
    match_date DESC,
    match_id DESC,
    triggered_player_id ASC;
