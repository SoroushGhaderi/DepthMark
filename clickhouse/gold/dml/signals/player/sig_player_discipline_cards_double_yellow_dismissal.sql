INSERT INTO gold.sig_player_discipline_cards_double_yellow_dismissal (
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
    trigger_threshold_yellow_cards_for_dismissal,
    triggered_player_first_yellow_card_minute,
    triggered_player_second_yellow_dismissal_minute,
    triggered_player_yellow_cards_match,
    triggered_player_red_cards_match,
    triggered_player_total_cards_match,
    triggered_team_score_at_dismissal,
    opponent_score_at_dismissal,
    score_margin_at_dismissal,
    triggered_player_fouls_committed,
    triggered_player_duels_won,
    triggered_player_duels_lost,
    triggered_player_tackles_won,
    triggered_player_interceptions,
    triggered_player_minutes_played,
    triggered_team_total_fouls,
    opponent_total_fouls,
    triggered_team_yellow_cards_match,
    opponent_yellow_cards_match,
    triggered_team_red_cards_match,
    opponent_red_cards_match,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_accurate_passes,
    opponent_accurate_passes,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct
)
-- Signal: sig_player_discipline_cards_double_yellow_dismissal
-- Intent: isolate players dismissed via second yellow with player-grain and bilateral discipline context.
-- Trigger: player receives at least two yellow cards and a second-yellow dismissal event in the same match.
WITH card_events AS (
    SELECT
        c.match_id,
        toInt32(assumeNotNull(c.player_id)) AS triggered_player_id,
        coalesce(c.player_name, 'Unknown') AS triggered_player_name,
        lowerUTF8(coalesce(c.team_side, '')) AS triggered_side,
        toInt32(coalesce(c.card_minute, 0)) AS card_minute,
        c.event_id,
        toInt32(coalesce(c.score_home_at_time, 0)) AS score_home_at_card,
        toInt32(coalesce(c.score_away_at_time, 0)) AS score_away_at_card,
        (
            positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'yellow') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'yellow') > 0
        ) AS is_yellow_card,
        (
            positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'red') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'red') > 0
        ) AS is_red_card,
        (
            positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'second yellow') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'second yellow') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), '2nd yellow') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'yellowred') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'yellow-red') > 0
            OR (
                positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'yellow') > 0
                AND positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'red') > 0
            )
            OR (
                positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'yellow') > 0
                AND positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'red') > 0
            )
        ) AS is_second_yellow_dismissal
    FROM silver.card AS c
    WHERE c.match_id > 0
      AND c.player_id IS NOT NULL
      AND lowerUTF8(coalesce(c.team_side, '')) IN ('home', 'away')
),
player_card_rollup AS (
    SELECT
        ce.match_id,
        ce.triggered_player_id,
        argMin(
            ce.triggered_player_name,
            tuple(ce.card_minute, ce.event_id)
        ) AS triggered_player_name,
        argMinIf(
            ce.triggered_side,
            tuple(ce.card_minute, ce.event_id),
            ce.is_second_yellow_dismissal
        ) AS triggered_side,
        minIf(ce.card_minute, ce.is_yellow_card) AS triggered_player_first_yellow_card_minute,
        minIf(ce.card_minute, ce.is_second_yellow_dismissal) AS triggered_player_second_yellow_dismissal_minute,
        argMinIf(
            ce.score_home_at_card,
            tuple(ce.card_minute, ce.event_id),
            ce.is_second_yellow_dismissal
        ) AS score_home_at_dismissal,
        argMinIf(
            ce.score_away_at_card,
            tuple(ce.card_minute, ce.event_id),
            ce.is_second_yellow_dismissal
        ) AS score_away_at_dismissal,
        countIf(ce.is_yellow_card) AS triggered_player_yellow_cards_match,
        countIf(ce.is_red_card) AS triggered_player_red_cards_match,
        countIf(ce.is_yellow_card OR ce.is_red_card) AS triggered_player_total_cards_match
    FROM card_events AS ce
    GROUP BY
        ce.match_id,
        ce.triggered_player_id
),
triggered_players AS (
    SELECT
        pcr.match_id,
        pcr.triggered_player_id,
        pcr.triggered_player_name,
        pcr.triggered_side,
        pcr.triggered_player_first_yellow_card_minute,
        pcr.triggered_player_second_yellow_dismissal_minute,
        pcr.score_home_at_dismissal,
        pcr.score_away_at_dismissal,
        pcr.triggered_player_yellow_cards_match,
        pcr.triggered_player_red_cards_match,
        pcr.triggered_player_total_cards_match
    FROM player_card_rollup AS pcr
    WHERE pcr.triggered_player_yellow_cards_match >= 2
      AND pcr.triggered_player_first_yellow_card_minute > 0
      AND pcr.triggered_player_second_yellow_dismissal_minute > 0
      AND pcr.triggered_player_second_yellow_dismissal_minute >= pcr.triggered_player_first_yellow_card_minute
      AND pcr.triggered_side IN ('home', 'away')
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

    tp.triggered_side,
    tp.triggered_player_id,
    coalesce(p.player_name, tp.triggered_player_name) AS triggered_player_name,

    if(tp.triggered_side = 'home', m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(tp.triggered_side = 'home', m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(tp.triggered_side = 'home', m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(tp.triggered_side = 'home', m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(2) AS trigger_threshold_yellow_cards_for_dismissal,
    tp.triggered_player_first_yellow_card_minute,
    tp.triggered_player_second_yellow_dismissal_minute,
    tp.triggered_player_yellow_cards_match,
    tp.triggered_player_red_cards_match,
    tp.triggered_player_total_cards_match,

    if(
        tp.triggered_side = 'home',
        tp.score_home_at_dismissal,
        tp.score_away_at_dismissal
    ) AS triggered_team_score_at_dismissal,
    if(
        tp.triggered_side = 'home',
        tp.score_away_at_dismissal,
        tp.score_home_at_dismissal
    ) AS opponent_score_at_dismissal,
    if(
        tp.triggered_side = 'home',
        tp.score_home_at_dismissal - tp.score_away_at_dismissal,
        tp.score_away_at_dismissal - tp.score_home_at_dismissal
    ) AS score_margin_at_dismissal,

    toInt32(coalesce(p.fouls_committed, 0)) AS triggered_player_fouls_committed,
    toInt32(coalesce(p.duels_won, 0)) AS triggered_player_duels_won,
    toInt32(coalesce(p.duels_lost, 0)) AS triggered_player_duels_lost,
    toInt32(coalesce(p.tackles_won, 0)) AS triggered_player_tackles_won,
    toInt32(coalesce(p.interceptions, 0)) AS triggered_player_interceptions,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,

    multiIf(
        tp.triggered_side = 'home', coalesce(ps.fouls_home, 0),
        tp.triggered_side = 'away', coalesce(ps.fouls_away, 0),
        0
    ) AS triggered_team_total_fouls,
    multiIf(
        tp.triggered_side = 'home', coalesce(ps.fouls_away, 0),
        tp.triggered_side = 'away', coalesce(ps.fouls_home, 0),
        0
    ) AS opponent_total_fouls,
    multiIf(
        tp.triggered_side = 'home', coalesce(ps.yellow_cards_home, 0),
        tp.triggered_side = 'away', coalesce(ps.yellow_cards_away, 0),
        0
    ) AS triggered_team_yellow_cards_match,
    multiIf(
        tp.triggered_side = 'home', coalesce(ps.yellow_cards_away, 0),
        tp.triggered_side = 'away', coalesce(ps.yellow_cards_home, 0),
        0
    ) AS opponent_yellow_cards_match,
    multiIf(
        tp.triggered_side = 'home', coalesce(ps.red_cards_home, 0),
        tp.triggered_side = 'away', coalesce(ps.red_cards_away, 0),
        0
    ) AS triggered_team_red_cards_match,
    multiIf(
        tp.triggered_side = 'home', coalesce(ps.red_cards_away, 0),
        tp.triggered_side = 'away', coalesce(ps.red_cards_home, 0),
        0
    ) AS opponent_red_cards_match,
    toFloat32(multiIf(
        tp.triggered_side = 'home', coalesce(ps.ball_possession_home, 0),
        tp.triggered_side = 'away', coalesce(ps.ball_possession_away, 0),
        0
    )) AS triggered_team_possession_pct,
    toFloat32(multiIf(
        tp.triggered_side = 'home', coalesce(ps.ball_possession_away, 0),
        tp.triggered_side = 'away', coalesce(ps.ball_possession_home, 0),
        0
    )) AS opponent_possession_pct,
    multiIf(
        tp.triggered_side = 'home', coalesce(ps.pass_attempts_home, 0),
        tp.triggered_side = 'away', coalesce(ps.pass_attempts_away, 0),
        0
    ) AS triggered_team_pass_attempts,
    multiIf(
        tp.triggered_side = 'home', coalesce(ps.pass_attempts_away, 0),
        tp.triggered_side = 'away', coalesce(ps.pass_attempts_home, 0),
        0
    ) AS opponent_pass_attempts,
    multiIf(
        tp.triggered_side = 'home', coalesce(ps.accurate_passes_home, 0),
        tp.triggered_side = 'away', coalesce(ps.accurate_passes_away, 0),
        0
    ) AS triggered_team_accurate_passes,
    multiIf(
        tp.triggered_side = 'home', coalesce(ps.accurate_passes_away, 0),
        tp.triggered_side = 'away', coalesce(ps.accurate_passes_home, 0),
        0
    ) AS opponent_accurate_passes,
    toFloat32(coalesce(round(
        100.0 * multiIf(
            tp.triggered_side = 'home', coalesce(ps.accurate_passes_home, 0),
            tp.triggered_side = 'away', coalesce(ps.accurate_passes_away, 0),
            0
        ) / nullIf(
            multiIf(
                tp.triggered_side = 'home', coalesce(ps.pass_attempts_home, 0),
                tp.triggered_side = 'away', coalesce(ps.pass_attempts_away, 0),
                0
            ),
            0
        ),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * multiIf(
            tp.triggered_side = 'home', coalesce(ps.accurate_passes_away, 0),
            tp.triggered_side = 'away', coalesce(ps.accurate_passes_home, 0),
            0
        ) / nullIf(
            multiIf(
                tp.triggered_side = 'home', coalesce(ps.pass_attempts_away, 0),
                tp.triggered_side = 'away', coalesce(ps.pass_attempts_home, 0),
                0
            ),
            0
        ),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct

FROM triggered_players AS tp
INNER JOIN silver.match AS m
    ON m.match_id = tp.match_id
LEFT JOIN silver.player_match_stat AS p
    ON p.match_id = tp.match_id
   AND p.player_id = tp.triggered_player_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = tp.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0

ORDER BY
    tp.triggered_player_second_yellow_dismissal_minute ASC,
    tp.triggered_player_yellow_cards_match DESC,
    m.match_date DESC,
    m.match_id DESC,
    tp.triggered_player_id ASC;
