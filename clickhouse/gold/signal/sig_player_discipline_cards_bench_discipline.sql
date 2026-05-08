INSERT INTO gold.sig_player_discipline_cards_bench_discipline (
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
    triggered_personnel_role,
    triggered_personnel_scope,
    triggered_personnel_substitution_time,
    trigger_threshold_non_playing_substitution_time,
    triggered_player_card_minute,
    triggered_player_card_event_type,
    triggered_team_score_at_card,
    opponent_score_at_card,
    score_margin_at_card,
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
-- Signal: sig_player_discipline_cards_bench_discipline
-- Intent: identify discipline events from non-playing substitutes or managers, with bilateral match-discipline context.
-- Trigger: non-playing substitute (substitution_time <= 0) or manager receives a yellow/red card.
WITH personnel_candidates AS (
    SELECT
        mp.match_id,
        toInt32(mp.person_id) AS triggered_player_id,
        lowerUTF8(coalesce(mp.team_side, '')) AS triggered_side,
        lowerUTF8(coalesce(mp.role, '')) AS triggered_personnel_role,
        argMax(
            coalesce(mp.name, 'Unknown'),
            coalesce(mp._loaded_at, toDateTime('1970-01-01 00:00:00'))
        ) AS triggered_player_name,
        toInt32OrZero(max(mp.substitution_time)) AS triggered_personnel_substitution_time
    FROM silver.match_personnel AS mp
    WHERE mp.match_id > 0
      AND mp.person_id > 0
      AND lowerUTF8(coalesce(mp.team_side, '')) IN ('home', 'away')
      AND lowerUTF8(coalesce(mp.role, '')) IN ('substitute', 'coach')
    GROUP BY
        mp.match_id,
        triggered_player_id,
        triggered_side,
        triggered_personnel_role
),
triggered_personnel AS (
    SELECT
        pc.match_id,
        pc.triggered_player_id,
        pc.triggered_side,
        pc.triggered_personnel_role,
        pc.triggered_player_name,
        pc.triggered_personnel_substitution_time,
        multiIf(
            pc.triggered_personnel_role = 'coach', 'manager',
            pc.triggered_personnel_role = 'substitute'
                AND pc.triggered_personnel_substitution_time <= 0, 'non_playing_substitute',
            'other'
        ) AS triggered_personnel_scope
    FROM personnel_candidates AS pc
    WHERE pc.triggered_personnel_role = 'coach'
       OR (
            pc.triggered_personnel_role = 'substitute'
            AND pc.triggered_personnel_substitution_time <= 0
       )
),
card_events AS (
    SELECT
        c.match_id,
        toInt32(assumeNotNull(c.player_id)) AS triggered_player_id,
        lowerUTF8(coalesce(c.team_side, '')) AS card_team_side,
        toInt32OrZero(c.card_minute) AS card_minute,
        toInt32OrZero(c.score_home_at_time) AS score_home_at_card,
        toInt32OrZero(c.score_away_at_time) AS score_away_at_card,
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
      AND lowerUTF8(coalesce(c.team_side, '')) IN ('home', 'away')
      AND toInt32OrZero(c.card_minute) > 0
),
player_card_rollup AS (
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
triggered_cards AS (
    SELECT
        tp.match_id,
        tp.triggered_player_id,
        tp.triggered_side,
        tp.triggered_personnel_role,
        tp.triggered_personnel_scope,
        tp.triggered_player_name,
        tp.triggered_personnel_substitution_time,
        ce.card_minute AS triggered_player_card_minute,
        multiIf(
            ce.is_second_yellow_dismissal, 'second_yellow_dismissal',
            ce.is_red_card, 'red',
            ce.is_yellow_card, 'yellow',
            'other'
        ) AS triggered_player_card_event_type,
        ce.score_home_at_card,
        ce.score_away_at_card,
        row_number() OVER (
            PARTITION BY tp.match_id, tp.triggered_player_id
            ORDER BY ce.card_minute ASC, ce.event_id ASC
        ) AS rn
    FROM triggered_personnel AS tp
    INNER JOIN card_events AS ce
        ON ce.match_id = tp.match_id
       AND ce.triggered_player_id = tp.triggered_player_id
       AND ce.card_team_side = tp.triggered_side
       AND (ce.is_yellow_card OR ce.is_red_card)
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

    tc.triggered_side,
    tc.triggered_player_id,
    coalesce(p.player_name, tc.triggered_player_name) AS triggered_player_name,
    if(tc.triggered_side = 'home', m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(tc.triggered_side = 'home', m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(tc.triggered_side = 'home', m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(tc.triggered_side = 'home', m.away_team_name, m.home_team_name) AS opponent_team_name,

    tc.triggered_personnel_role,
    tc.triggered_personnel_scope,
    tc.triggered_personnel_substitution_time,
    toInt32(0) AS trigger_threshold_non_playing_substitution_time,
    tc.triggered_player_card_minute,
    tc.triggered_player_card_event_type,
    if(
        tc.triggered_side = 'home',
        tc.score_home_at_card,
        tc.score_away_at_card
    ) AS triggered_team_score_at_card,
    if(
        tc.triggered_side = 'home',
        tc.score_away_at_card,
        tc.score_home_at_card
    ) AS opponent_score_at_card,
    if(
        tc.triggered_side = 'home',
        tc.score_home_at_card - tc.score_away_at_card,
        tc.score_away_at_card - tc.score_home_at_card
    ) AS score_margin_at_card,

    toInt32(coalesce(pcr.triggered_player_total_cards_match, 0)) AS triggered_player_total_cards_match,
    toInt32(coalesce(pcr.triggered_player_yellow_cards_match, 0)) AS triggered_player_yellow_cards_match,
    toInt32(coalesce(pcr.triggered_player_red_cards_match, 0)) AS triggered_player_red_cards_match,
    toInt32(coalesce(p.fouls_committed, 0)) AS triggered_player_fouls_committed,
    toInt32(coalesce(p.was_fouled, 0)) AS triggered_player_was_fouled,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,

    toInt32(multiIf(
        tc.triggered_side = 'home', coalesce(ps.fouls_home, 0),
        tc.triggered_side = 'away', coalesce(ps.fouls_away, 0),
        0
    )) AS triggered_team_total_fouls,
    toInt32(multiIf(
        tc.triggered_side = 'home', coalesce(ps.fouls_away, 0),
        tc.triggered_side = 'away', coalesce(ps.fouls_home, 0),
        0
    )) AS opponent_total_fouls,
    toInt32(multiIf(
        tc.triggered_side = 'home', coalesce(ps.yellow_cards_home, 0),
        tc.triggered_side = 'away', coalesce(ps.yellow_cards_away, 0),
        0
    )) AS triggered_team_yellow_cards_match,
    toInt32(multiIf(
        tc.triggered_side = 'home', coalesce(ps.yellow_cards_away, 0),
        tc.triggered_side = 'away', coalesce(ps.yellow_cards_home, 0),
        0
    )) AS opponent_yellow_cards_match,
    toInt32(multiIf(
        tc.triggered_side = 'home', coalesce(ps.red_cards_home, 0),
        tc.triggered_side = 'away', coalesce(ps.red_cards_away, 0),
        0
    )) AS triggered_team_red_cards_match,
    toInt32(multiIf(
        tc.triggered_side = 'home', coalesce(ps.red_cards_away, 0),
        tc.triggered_side = 'away', coalesce(ps.red_cards_home, 0),
        0
    )) AS opponent_red_cards_match,
    toFloat32(multiIf(
        tc.triggered_side = 'home', coalesce(ps.ball_possession_home, 0),
        tc.triggered_side = 'away', coalesce(ps.ball_possession_away, 0),
        0
    )) AS triggered_team_possession_pct,
    toFloat32(multiIf(
        tc.triggered_side = 'home', coalesce(ps.ball_possession_away, 0),
        tc.triggered_side = 'away', coalesce(ps.ball_possession_home, 0),
        0
    )) AS opponent_possession_pct,
    toInt32(multiIf(
        tc.triggered_side = 'home', coalesce(ps.pass_attempts_home, 0),
        tc.triggered_side = 'away', coalesce(ps.pass_attempts_away, 0),
        0
    )) AS triggered_team_pass_attempts,
    toInt32(multiIf(
        tc.triggered_side = 'home', coalesce(ps.pass_attempts_away, 0),
        tc.triggered_side = 'away', coalesce(ps.pass_attempts_home, 0),
        0
    )) AS opponent_pass_attempts,
    toInt32(multiIf(
        tc.triggered_side = 'home', coalesce(ps.accurate_passes_home, 0),
        tc.triggered_side = 'away', coalesce(ps.accurate_passes_away, 0),
        0
    )) AS triggered_team_accurate_passes,
    toInt32(multiIf(
        tc.triggered_side = 'home', coalesce(ps.accurate_passes_away, 0),
        tc.triggered_side = 'away', coalesce(ps.accurate_passes_home, 0),
        0
    )) AS opponent_accurate_passes,
    toFloat32(coalesce(round(
        100.0 * multiIf(
            tc.triggered_side = 'home', coalesce(ps.accurate_passes_home, 0),
            tc.triggered_side = 'away', coalesce(ps.accurate_passes_away, 0),
            0
        ) / nullIf(
            multiIf(
                tc.triggered_side = 'home', coalesce(ps.pass_attempts_home, 0),
                tc.triggered_side = 'away', coalesce(ps.pass_attempts_away, 0),
                0
            ),
            0
        ),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * multiIf(
            tc.triggered_side = 'home', coalesce(ps.accurate_passes_away, 0),
            tc.triggered_side = 'away', coalesce(ps.accurate_passes_home, 0),
            0
        ) / nullIf(
            multiIf(
                tc.triggered_side = 'home', coalesce(ps.pass_attempts_away, 0),
                tc.triggered_side = 'away', coalesce(ps.pass_attempts_home, 0),
                0
            ),
            0
        ),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct

FROM triggered_cards AS tc
INNER JOIN silver.match AS m
    ON m.match_id = tc.match_id
LEFT JOIN silver.player_match_stat AS p
    ON p.match_id = tc.match_id
   AND p.player_id = tc.triggered_player_id
LEFT JOIN player_card_rollup AS pcr
    ON pcr.match_id = tc.match_id
   AND pcr.triggered_player_id = tc.triggered_player_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = tc.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND tc.rn = 1

ORDER BY
    tc.triggered_player_card_minute ASC,
    m.match_date DESC,
    m.match_id DESC,
    tc.triggered_player_id ASC;
