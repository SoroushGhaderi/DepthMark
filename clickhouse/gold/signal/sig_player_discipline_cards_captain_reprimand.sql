INSERT INTO gold.sig_player_discipline_cards_captain_reprimand (
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
    trigger_threshold_dissent_yellow_cards,
    triggered_player_is_captain,
    triggered_player_dissent_yellow_card_minute,
    triggered_team_score_at_dissent_card,
    opponent_score_at_dissent_card,
    score_margin_at_dissent_card,
    triggered_player_yellow_cards_match,
    triggered_player_red_cards_match,
    triggered_player_total_cards_match,
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
-- Signal: sig_player_discipline_cards_captain_reprimand
-- Intent: identify captains booked for dissent/reprimand with bilateral discipline and control context.
-- Trigger: team captain receives a yellow card event labeled as dissent/reprimand.
WITH captain_roster AS (
    SELECT
        mp.match_id,
        toInt32(mp.person_id) AS triggered_player_id,
        lowerUTF8(coalesce(mp.team_side, '')) AS triggered_side,
        argMax(
            coalesce(mp.name, 'Unknown'),
            coalesce(mp._loaded_at, toDateTime('1970-01-01 00:00:00'))
        ) AS triggered_player_name
    FROM silver.match_personnel AS mp
    WHERE mp.match_id > 0
      AND mp.person_id > 0
      AND mp.role = 'starter'
      AND coalesce(mp.is_captain, 0) = 1
      AND lowerUTF8(coalesce(mp.team_side, '')) IN ('home', 'away')
    GROUP BY
        mp.match_id,
        triggered_player_id,
        triggered_side
),
card_events AS (
    SELECT
        c.match_id,
        toInt32(assumeNotNull(c.player_id)) AS triggered_player_id,
        coalesce(c.player_name, 'Unknown') AS triggered_player_name,
        lowerUTF8(coalesce(c.team_side, '')) AS triggered_side,
        toInt32OrZero(c.card_minute) AS card_minute,
        c.event_id,
        toInt32OrZero(c.score_home_at_time) AS score_home_at_card,
        toInt32OrZero(c.score_away_at_time) AS score_away_at_card,
        (
            positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'yellow') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'yellow') > 0
        ) AS is_yellow_card,
        (
            positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'red') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'red') > 0
        ) AS is_red_card,
        (
            positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'dissent') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'dissent') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'reprimand') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'reprimand') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'arguing') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'argument') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'protest') > 0
        ) AS is_dissent_context
    FROM silver.card AS c
    WHERE c.match_id > 0
      AND c.player_id IS NOT NULL
      AND lowerUTF8(coalesce(c.team_side, '')) IN ('home', 'away')
),
player_card_rollup AS (
    SELECT
        ce.match_id,
        ce.triggered_player_id,
        countIf(ce.is_yellow_card) AS triggered_player_yellow_cards_match,
        countIf(ce.is_red_card) AS triggered_player_red_cards_match,
        countIf(ce.is_yellow_card OR ce.is_red_card) AS triggered_player_total_cards_match
    FROM card_events AS ce
    GROUP BY
        ce.match_id,
        ce.triggered_player_id
),
captain_dissent_cards AS (
    SELECT
        ce.match_id,
        ce.triggered_player_id,
        coalesce(cr.triggered_player_name, ce.triggered_player_name) AS triggered_player_name,
        ce.triggered_side,
        ce.card_minute AS triggered_player_dissent_yellow_card_minute,
        ce.score_home_at_card,
        ce.score_away_at_card,
        row_number() OVER (
            PARTITION BY ce.match_id, ce.triggered_player_id
            ORDER BY ce.card_minute ASC, ce.event_id ASC
        ) AS rn
    FROM card_events AS ce
    INNER JOIN captain_roster AS cr
        ON cr.match_id = ce.match_id
       AND cr.triggered_player_id = ce.triggered_player_id
       AND cr.triggered_side = ce.triggered_side
    WHERE ce.is_yellow_card
      AND ce.is_dissent_context
      AND ce.card_minute > 0
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
    cdc.triggered_side,
    cdc.triggered_player_id,
    coalesce(p.player_name, cdc.triggered_player_name) AS triggered_player_name,
    if(cdc.triggered_side = 'home', m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(cdc.triggered_side = 'home', m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(cdc.triggered_side = 'home', m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(cdc.triggered_side = 'home', m.away_team_name, m.home_team_name) AS opponent_team_name,
    toInt32(1) AS trigger_threshold_dissent_yellow_cards,
    toUInt8(1) AS triggered_player_is_captain,
    cdc.triggered_player_dissent_yellow_card_minute,
    if(
        cdc.triggered_side = 'home',
        cdc.score_home_at_card,
        cdc.score_away_at_card
    ) AS triggered_team_score_at_dissent_card,
    if(
        cdc.triggered_side = 'home',
        cdc.score_away_at_card,
        cdc.score_home_at_card
    ) AS opponent_score_at_dissent_card,
    if(
        cdc.triggered_side = 'home',
        cdc.score_home_at_card - cdc.score_away_at_card,
        cdc.score_away_at_card - cdc.score_home_at_card
    ) AS score_margin_at_dissent_card,
    toInt32(coalesce(pcr.triggered_player_yellow_cards_match, 0)) AS triggered_player_yellow_cards_match,
    toInt32(coalesce(pcr.triggered_player_red_cards_match, 0)) AS triggered_player_red_cards_match,
    toInt32(coalesce(pcr.triggered_player_total_cards_match, 0)) AS triggered_player_total_cards_match,
    toInt32(coalesce(p.fouls_committed, 0)) AS triggered_player_fouls_committed,
    toInt32(coalesce(p.duels_won, 0)) AS triggered_player_duels_won,
    toInt32(coalesce(p.duels_lost, 0)) AS triggered_player_duels_lost,
    toInt32(coalesce(p.tackles_won, 0)) AS triggered_player_tackles_won,
    toInt32(coalesce(p.interceptions, 0)) AS triggered_player_interceptions,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,
    multiIf(
        cdc.triggered_side = 'home', coalesce(ps.fouls_home, 0),
        cdc.triggered_side = 'away', coalesce(ps.fouls_away, 0),
        0
    ) AS triggered_team_total_fouls,
    multiIf(
        cdc.triggered_side = 'home', coalesce(ps.fouls_away, 0),
        cdc.triggered_side = 'away', coalesce(ps.fouls_home, 0),
        0
    ) AS opponent_total_fouls,
    multiIf(
        cdc.triggered_side = 'home', coalesce(ps.yellow_cards_home, 0),
        cdc.triggered_side = 'away', coalesce(ps.yellow_cards_away, 0),
        0
    ) AS triggered_team_yellow_cards_match,
    multiIf(
        cdc.triggered_side = 'home', coalesce(ps.yellow_cards_away, 0),
        cdc.triggered_side = 'away', coalesce(ps.yellow_cards_home, 0),
        0
    ) AS opponent_yellow_cards_match,
    multiIf(
        cdc.triggered_side = 'home', coalesce(ps.red_cards_home, 0),
        cdc.triggered_side = 'away', coalesce(ps.red_cards_away, 0),
        0
    ) AS triggered_team_red_cards_match,
    multiIf(
        cdc.triggered_side = 'home', coalesce(ps.red_cards_away, 0),
        cdc.triggered_side = 'away', coalesce(ps.red_cards_home, 0),
        0
    ) AS opponent_red_cards_match,
    toFloat32(multiIf(
        cdc.triggered_side = 'home', coalesce(ps.ball_possession_home, 0),
        cdc.triggered_side = 'away', coalesce(ps.ball_possession_away, 0),
        0
    )) AS triggered_team_possession_pct,
    toFloat32(multiIf(
        cdc.triggered_side = 'home', coalesce(ps.ball_possession_away, 0),
        cdc.triggered_side = 'away', coalesce(ps.ball_possession_home, 0),
        0
    )) AS opponent_possession_pct,
    multiIf(
        cdc.triggered_side = 'home', coalesce(ps.pass_attempts_home, 0),
        cdc.triggered_side = 'away', coalesce(ps.pass_attempts_away, 0),
        0
    ) AS triggered_team_pass_attempts,
    multiIf(
        cdc.triggered_side = 'home', coalesce(ps.pass_attempts_away, 0),
        cdc.triggered_side = 'away', coalesce(ps.pass_attempts_home, 0),
        0
    ) AS opponent_pass_attempts,
    multiIf(
        cdc.triggered_side = 'home', coalesce(ps.accurate_passes_home, 0),
        cdc.triggered_side = 'away', coalesce(ps.accurate_passes_away, 0),
        0
    ) AS triggered_team_accurate_passes,
    multiIf(
        cdc.triggered_side = 'home', coalesce(ps.accurate_passes_away, 0),
        cdc.triggered_side = 'away', coalesce(ps.accurate_passes_home, 0),
        0
    ) AS opponent_accurate_passes,
    toFloat32(coalesce(round(
        100.0 * multiIf(
            cdc.triggered_side = 'home', coalesce(ps.accurate_passes_home, 0),
            cdc.triggered_side = 'away', coalesce(ps.accurate_passes_away, 0),
            0
        ) / nullIf(
            multiIf(
                cdc.triggered_side = 'home', coalesce(ps.pass_attempts_home, 0),
                cdc.triggered_side = 'away', coalesce(ps.pass_attempts_away, 0),
                0
            ),
            0
        ),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * multiIf(
            cdc.triggered_side = 'home', coalesce(ps.accurate_passes_away, 0),
            cdc.triggered_side = 'away', coalesce(ps.accurate_passes_home, 0),
            0
        ) / nullIf(
            multiIf(
                cdc.triggered_side = 'home', coalesce(ps.pass_attempts_away, 0),
                cdc.triggered_side = 'away', coalesce(ps.pass_attempts_home, 0),
                0
            ),
            0
        ),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct
FROM captain_dissent_cards AS cdc
INNER JOIN silver.match AS m
    ON m.match_id = cdc.match_id
LEFT JOIN silver.player_match_stat AS p
    ON p.match_id = cdc.match_id
   AND p.player_id = cdc.triggered_player_id
LEFT JOIN player_card_rollup AS pcr
    ON pcr.match_id = cdc.match_id
   AND pcr.triggered_player_id = cdc.triggered_player_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = cdc.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND cdc.rn = 1
ORDER BY
    cdc.triggered_player_dissent_yellow_card_minute ASC,
    triggered_player_total_cards_match DESC,
    triggered_player_fouls_committed DESC,
    m.match_date DESC,
    m.match_id DESC;
