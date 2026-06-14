INSERT INTO gold.sig_player_discipline_cards_instant_impact_red (
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
    trigger_threshold_minutes_from_substitution,
    triggered_player_substitution_time,
    triggered_player_dismissal_minute,
    minutes_from_substitution_to_dismissal,
    triggered_player_dismissal_event_type,
    triggered_team_score_at_dismissal,
    opponent_score_at_dismissal,
    score_margin_at_dismissal,
    triggered_player_total_cards_match,
    triggered_player_yellow_cards_match,
    triggered_player_red_cards_match,
    triggered_player_fouls_committed,
    triggered_player_was_fouled,
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
-- Signal: sig_player_discipline_cards_instant_impact_red
-- Intent: identify substitutes who are dismissed almost immediately, preserving bilateral discipline and control context.
-- Trigger: substitute player is sent off within 10 minutes of substitution time.
WITH substitute_entries AS (
    SELECT
        mp.match_id,
        toInt32(assumeNotNull(mp.person_id)) AS triggered_player_id,
        toInt32(coalesce(max(mp.substitution_time), 0)) AS triggered_player_substitution_time
    FROM silver.match_personnel AS mp
    WHERE mp.match_id > 0
      AND mp.person_id IS NOT NULL
      AND lowerUTF8(coalesce(mp.role, '')) = 'substitute'
      AND toInt32(coalesce(mp.substitution_time, 0)) > 0
    GROUP BY
        mp.match_id,
        triggered_player_id
),
card_events AS (
    SELECT
        c.match_id,
        toInt32(assumeNotNull(c.player_id)) AS triggered_player_id,
        toInt32(coalesce(c.card_minute, 0)) AS card_minute,
        toInt32(coalesce(c.score_home_at_time, 0)) AS score_home_at_card,
        toInt32(coalesce(c.score_away_at_time, 0)) AS score_away_at_card,
        c.event_id,
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
      AND toInt32(coalesce(c.card_minute, 0)) > 0
),
player_card_counts AS (
    SELECT
        ce.match_id,
        ce.triggered_player_id,
        countIf(ce.is_yellow_card OR ce.is_red_card) AS triggered_player_total_cards_match,
        countIf(ce.is_yellow_card) AS triggered_player_yellow_cards_match,
        countIf(ce.is_red_card) AS triggered_player_red_cards_match
    FROM card_events AS ce
    GROUP BY
        ce.match_id,
        ce.triggered_player_id
),
triggered_substitute_dismissals AS (
    SELECT
        se.match_id,
        se.triggered_player_id,
        se.triggered_player_substitution_time,
        ce.card_minute AS triggered_player_dismissal_minute,
        (ce.card_minute - se.triggered_player_substitution_time) AS minutes_from_substitution_to_dismissal,
        multiIf(
            ce.is_second_yellow_dismissal, 'second_yellow_dismissal',
            ce.is_red_card, 'red',
            'other'
        ) AS triggered_player_dismissal_event_type,
        ce.score_home_at_card,
        ce.score_away_at_card,
        row_number() OVER (
            PARTITION BY se.match_id, se.triggered_player_id
            ORDER BY ce.card_minute ASC, ce.event_id ASC
        ) AS rn
    FROM substitute_entries AS se
    INNER JOIN card_events AS ce
        ON ce.match_id = se.match_id
       AND ce.triggered_player_id = se.triggered_player_id
       AND (ce.is_red_card OR ce.is_second_yellow_dismissal)
    WHERE ce.card_minute >= se.triggered_player_substitution_time
      AND ce.card_minute <= se.triggered_player_substitution_time + 10
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
    tsd.triggered_player_id,
    coalesce(p.player_name, 'Unknown') AS triggered_player_name,
    if(p.team_id = m.home_team_id, m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(p.team_id = m.home_team_id, m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(p.team_id = m.home_team_id, m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(p.team_id = m.home_team_id, m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(10) AS trigger_threshold_minutes_from_substitution,
    tsd.triggered_player_substitution_time,
    tsd.triggered_player_dismissal_minute,
    tsd.minutes_from_substitution_to_dismissal,
    tsd.triggered_player_dismissal_event_type,
    if(
        p.team_id = m.home_team_id,
        tsd.score_home_at_card,
        tsd.score_away_at_card
    ) AS triggered_team_score_at_dismissal,
    if(
        p.team_id = m.home_team_id,
        tsd.score_away_at_card,
        tsd.score_home_at_card
    ) AS opponent_score_at_dismissal,
    if(
        p.team_id = m.home_team_id,
        tsd.score_home_at_card - tsd.score_away_at_card,
        tsd.score_away_at_card - tsd.score_home_at_card
    ) AS score_margin_at_dismissal,

    toInt32(coalesce(pcc.triggered_player_total_cards_match, 0)) AS triggered_player_total_cards_match,
    toInt32(coalesce(pcc.triggered_player_yellow_cards_match, 0)) AS triggered_player_yellow_cards_match,
    toInt32(coalesce(pcc.triggered_player_red_cards_match, 0)) AS triggered_player_red_cards_match,
    toInt32(coalesce(p.fouls_committed, 0)) AS triggered_player_fouls_committed,
    toInt32(coalesce(p.was_fouled, 0)) AS triggered_player_was_fouled,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,

    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.fouls_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.fouls_away, 0),
        0
    )) AS triggered_team_total_fouls,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.fouls_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.fouls_home, 0),
        0
    )) AS opponent_total_fouls,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.yellow_cards_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.yellow_cards_away, 0),
        0
    )) AS triggered_team_yellow_cards_match,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.yellow_cards_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.yellow_cards_home, 0),
        0
    )) AS opponent_yellow_cards_match,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.red_cards_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.red_cards_away, 0),
        0
    )) AS triggered_team_red_cards_match,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.red_cards_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.red_cards_home, 0),
        0
    )) AS opponent_red_cards_match,
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
    toFloat32(coalesce(round(
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
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
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
    ), 0.0)) AS opponent_pass_accuracy_pct

FROM triggered_substitute_dismissals AS tsd
INNER JOIN silver.player_match_stat AS p
    ON p.match_id = tsd.match_id
   AND p.player_id = tsd.triggered_player_id
INNER JOIN silver.match AS m
    ON m.match_id = tsd.match_id
LEFT JOIN player_card_counts AS pcc
    ON pcc.match_id = tsd.match_id
   AND pcc.triggered_player_id = tsd.triggered_player_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = tsd.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)
  AND tsd.rn = 1

ORDER BY
    tsd.minutes_from_substitution_to_dismissal ASC,
    tsd.triggered_player_dismissal_minute ASC,
    m.match_date DESC,
    m.match_id DESC,
    tsd.triggered_player_id ASC;
