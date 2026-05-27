INSERT INTO gold.sig_match_discipline_cards_referee_showdown (
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
    trigger_threshold_min_carded_captains,
    match_carded_captains_count,
    home_captain_player_id,
    home_captain_player_name,
    away_captain_player_id,
    away_captain_player_name,
    home_captain_total_cards,
    away_captain_total_cards,
    home_captain_yellow_cards,
    away_captain_yellow_cards,
    home_captain_red_cards,
    away_captain_red_cards,
    home_captain_first_card_minute,
    away_captain_first_card_minute,
    home_captain_last_card_minute,
    away_captain_last_card_minute,
    triggered_captain_player_id,
    triggered_captain_player_name,
    opponent_captain_player_id,
    opponent_captain_player_name,
    triggered_captain_total_cards,
    opponent_captain_total_cards,
    captain_total_cards_delta,
    triggered_captain_yellow_cards,
    opponent_captain_yellow_cards,
    captain_yellow_cards_delta,
    triggered_captain_red_cards,
    opponent_captain_red_cards,
    captain_red_cards_delta,
    triggered_captain_first_card_minute,
    opponent_captain_first_card_minute,
    triggered_team_yellow_cards,
    opponent_yellow_cards,
    yellow_cards_delta,
    triggered_team_red_cards,
    opponent_red_cards,
    red_cards_delta,
    triggered_team_total_cards,
    opponent_total_cards,
    card_count_delta,
    triggered_team_fouls_committed,
    opponent_fouls_committed,
    fouls_committed_delta,
    triggered_team_tackles_won,
    opponent_tackles_won,
    triggered_team_duels_won,
    opponent_duels_won,
    triggered_team_interceptions,
    opponent_interceptions,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct
)
-- Signal: sig_match_discipline_cards_referee_showdown
-- Trigger: both match captains receive at least one card in the same match.
-- Intent: capture bilateral leadership-level discipline escalation with side-oriented team context.
WITH captain_roster AS (
    SELECT
        mp.match_id,
        lowerUTF8(coalesce(mp.team_side, '')) AS captain_side,
        argMax(
            toInt32(mp.person_id),
            coalesce(mp._loaded_at, toDateTime('1970-01-01 00:00:00'))
        ) AS captain_player_id,
        argMax(
            coalesce(mp.name, 'Unknown'),
            coalesce(mp._loaded_at, toDateTime('1970-01-01 00:00:00'))
        ) AS captain_player_name
    FROM silver.match_personnel AS mp
    WHERE mp.match_id > 0
      AND mp.person_id > 0
      AND lowerUTF8(coalesce(mp.team_side, '')) IN ('home', 'away')
      AND lowerUTF8(coalesce(mp.role, '')) = 'starter'
      AND coalesce(mp.is_captain, 0) = 1
    GROUP BY
        mp.match_id,
        captain_side
),
card_events AS (
    SELECT
        c.match_id,
        lowerUTF8(coalesce(c.team_side, '')) AS card_side,
        toInt32(assumeNotNull(c.player_id)) AS card_player_id,
        toInt32(coalesce(c.card_minute, 0)) AS card_minute,
        (
            positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'yellow') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'yellow') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'booked') > 0
        ) AS is_yellow_card,
        (
            positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'red') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'red') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'sent off') > 0
        ) AS is_red_card
    FROM silver.card AS c
    WHERE c.match_id > 0
      AND c.player_id IS NOT NULL
      AND lowerUTF8(coalesce(c.team_side, '')) IN ('home', 'away')
),
captain_card_rollup AS (
    SELECT
        cr.match_id,
        cr.captain_side,
        cr.captain_player_id,
        cr.captain_player_name,
        countIf(ce.is_yellow_card OR ce.is_red_card) AS captain_total_cards,
        countIf(ce.is_yellow_card) AS captain_yellow_cards,
        countIf(ce.is_red_card) AS captain_red_cards,
        toNullable(minIf(ce.card_minute, (ce.is_yellow_card OR ce.is_red_card) AND ce.card_minute > 0)) AS captain_first_card_minute,
        toNullable(maxIf(ce.card_minute, (ce.is_yellow_card OR ce.is_red_card) AND ce.card_minute > 0)) AS captain_last_card_minute
    FROM captain_roster AS cr
    LEFT JOIN card_events AS ce
        ON ce.match_id = cr.match_id
       AND ce.card_side = cr.captain_side
       AND ce.card_player_id = cr.captain_player_id
    GROUP BY
        cr.match_id,
        cr.captain_side,
        cr.captain_player_id,
        cr.captain_player_name
),
dual_captain_matches AS (
    SELECT
        home_ccr.match_id,
        home_ccr.captain_player_id AS home_captain_player_id,
        home_ccr.captain_player_name AS home_captain_player_name,
        away_ccr.captain_player_id AS away_captain_player_id,
        away_ccr.captain_player_name AS away_captain_player_name,
        home_ccr.captain_total_cards AS home_captain_total_cards,
        away_ccr.captain_total_cards AS away_captain_total_cards,
        home_ccr.captain_yellow_cards AS home_captain_yellow_cards,
        away_ccr.captain_yellow_cards AS away_captain_yellow_cards,
        home_ccr.captain_red_cards AS home_captain_red_cards,
        away_ccr.captain_red_cards AS away_captain_red_cards,
        home_ccr.captain_first_card_minute AS home_captain_first_card_minute,
        away_ccr.captain_first_card_minute AS away_captain_first_card_minute,
        home_ccr.captain_last_card_minute AS home_captain_last_card_minute,
        away_ccr.captain_last_card_minute AS away_captain_last_card_minute
    FROM captain_card_rollup AS home_ccr
    INNER JOIN captain_card_rollup AS away_ccr
        ON away_ccr.match_id = home_ccr.match_id
       AND away_ccr.captain_side = 'away'
    WHERE home_ccr.captain_side = 'home'
      AND home_ccr.captain_total_cards > 0
      AND away_ccr.captain_total_cards > 0
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

    'home' AS triggered_side,
    m.home_team_id AS triggered_team_id,
    m.home_team_name AS triggered_team_name,
    m.away_team_id AS opponent_team_id,
    m.away_team_name AS opponent_team_name,

    toInt32(2) AS trigger_threshold_min_carded_captains,
    toInt32(2) AS match_carded_captains_count,
    toNullable(toInt32(dcm.home_captain_player_id)) AS home_captain_player_id,
    dcm.home_captain_player_name,
    toNullable(toInt32(dcm.away_captain_player_id)) AS away_captain_player_id,
    dcm.away_captain_player_name,
    toInt32(dcm.home_captain_total_cards) AS home_captain_total_cards,
    toInt32(dcm.away_captain_total_cards) AS away_captain_total_cards,
    toInt32(dcm.home_captain_yellow_cards) AS home_captain_yellow_cards,
    toInt32(dcm.away_captain_yellow_cards) AS away_captain_yellow_cards,
    toInt32(dcm.home_captain_red_cards) AS home_captain_red_cards,
    toInt32(dcm.away_captain_red_cards) AS away_captain_red_cards,
    toNullable(toInt32(dcm.home_captain_first_card_minute)) AS home_captain_first_card_minute,
    toNullable(toInt32(dcm.away_captain_first_card_minute)) AS away_captain_first_card_minute,
    toNullable(toInt32(dcm.home_captain_last_card_minute)) AS home_captain_last_card_minute,
    toNullable(toInt32(dcm.away_captain_last_card_minute)) AS away_captain_last_card_minute,
    toNullable(toInt32(dcm.home_captain_player_id)) AS triggered_captain_player_id,
    dcm.home_captain_player_name AS triggered_captain_player_name,
    toNullable(toInt32(dcm.away_captain_player_id)) AS opponent_captain_player_id,
    dcm.away_captain_player_name AS opponent_captain_player_name,
    toInt32(dcm.home_captain_total_cards) AS triggered_captain_total_cards,
    toInt32(dcm.away_captain_total_cards) AS opponent_captain_total_cards,
    toInt32(dcm.home_captain_total_cards - dcm.away_captain_total_cards) AS captain_total_cards_delta,
    toInt32(dcm.home_captain_yellow_cards) AS triggered_captain_yellow_cards,
    toInt32(dcm.away_captain_yellow_cards) AS opponent_captain_yellow_cards,
    toInt32(dcm.home_captain_yellow_cards - dcm.away_captain_yellow_cards) AS captain_yellow_cards_delta,
    toInt32(dcm.home_captain_red_cards) AS triggered_captain_red_cards,
    toInt32(dcm.away_captain_red_cards) AS opponent_captain_red_cards,
    toInt32(dcm.home_captain_red_cards - dcm.away_captain_red_cards) AS captain_red_cards_delta,
    toNullable(toInt32(dcm.home_captain_first_card_minute)) AS triggered_captain_first_card_minute,
    toNullable(toInt32(dcm.away_captain_first_card_minute)) AS opponent_captain_first_card_minute,

    toInt32(coalesce(ps.yellow_cards_home, 0)) AS triggered_team_yellow_cards,
    toInt32(coalesce(ps.yellow_cards_away, 0)) AS opponent_yellow_cards,
    toInt32(coalesce(ps.yellow_cards_home, 0) - coalesce(ps.yellow_cards_away, 0)) AS yellow_cards_delta,
    toInt32(coalesce(ps.red_cards_home, 0)) AS triggered_team_red_cards,
    toInt32(coalesce(ps.red_cards_away, 0)) AS opponent_red_cards,
    toInt32(coalesce(ps.red_cards_home, 0) - coalesce(ps.red_cards_away, 0)) AS red_cards_delta,
    toInt32(coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) AS triggered_team_total_cards,
    toInt32(coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)) AS opponent_total_cards,
    toInt32(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0))
        - (coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0))
    ) AS card_count_delta,
    toInt32(coalesce(ps.fouls_home, 0)) AS triggered_team_fouls_committed,
    toInt32(coalesce(ps.fouls_away, 0)) AS opponent_fouls_committed,
    toInt32(coalesce(ps.fouls_home, 0) - coalesce(ps.fouls_away, 0)) AS fouls_committed_delta,
    toInt32(coalesce(ps.tackles_succeeded_home, 0)) AS triggered_team_tackles_won,
    toInt32(coalesce(ps.tackles_succeeded_away, 0)) AS opponent_tackles_won,
    toInt32(coalesce(ps.duels_won_home, 0)) AS triggered_team_duels_won,
    toInt32(coalesce(ps.duels_won_away, 0)) AS opponent_duels_won,
    toInt32(coalesce(ps.interceptions_home, 0)) AS triggered_team_interceptions,
    toInt32(coalesce(ps.interceptions_away, 0)) AS opponent_interceptions,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
            1
        ), 0.0)
        - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_home, 0) - coalesce(ps.ball_possession_away, 0), 1)) AS possession_delta_pct

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
INNER JOIN dual_captain_matches AS dcm
    ON dcm.match_id = m.match_id
WHERE m.match_finished = 1
  AND m.match_id > 0

UNION ALL

SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    'away' AS triggered_side,
    m.away_team_id AS triggered_team_id,
    m.away_team_name AS triggered_team_name,
    m.home_team_id AS opponent_team_id,
    m.home_team_name AS opponent_team_name,

    toInt32(2) AS trigger_threshold_min_carded_captains,
    toInt32(2) AS match_carded_captains_count,
    toNullable(toInt32(dcm.home_captain_player_id)) AS home_captain_player_id,
    dcm.home_captain_player_name,
    toNullable(toInt32(dcm.away_captain_player_id)) AS away_captain_player_id,
    dcm.away_captain_player_name,
    toInt32(dcm.home_captain_total_cards) AS home_captain_total_cards,
    toInt32(dcm.away_captain_total_cards) AS away_captain_total_cards,
    toInt32(dcm.home_captain_yellow_cards) AS home_captain_yellow_cards,
    toInt32(dcm.away_captain_yellow_cards) AS away_captain_yellow_cards,
    toInt32(dcm.home_captain_red_cards) AS home_captain_red_cards,
    toInt32(dcm.away_captain_red_cards) AS away_captain_red_cards,
    toNullable(toInt32(dcm.home_captain_first_card_minute)) AS home_captain_first_card_minute,
    toNullable(toInt32(dcm.away_captain_first_card_minute)) AS away_captain_first_card_minute,
    toNullable(toInt32(dcm.home_captain_last_card_minute)) AS home_captain_last_card_minute,
    toNullable(toInt32(dcm.away_captain_last_card_minute)) AS away_captain_last_card_minute,
    toNullable(toInt32(dcm.away_captain_player_id)) AS triggered_captain_player_id,
    dcm.away_captain_player_name AS triggered_captain_player_name,
    toNullable(toInt32(dcm.home_captain_player_id)) AS opponent_captain_player_id,
    dcm.home_captain_player_name AS opponent_captain_player_name,
    toInt32(dcm.away_captain_total_cards) AS triggered_captain_total_cards,
    toInt32(dcm.home_captain_total_cards) AS opponent_captain_total_cards,
    toInt32(dcm.away_captain_total_cards - dcm.home_captain_total_cards) AS captain_total_cards_delta,
    toInt32(dcm.away_captain_yellow_cards) AS triggered_captain_yellow_cards,
    toInt32(dcm.home_captain_yellow_cards) AS opponent_captain_yellow_cards,
    toInt32(dcm.away_captain_yellow_cards - dcm.home_captain_yellow_cards) AS captain_yellow_cards_delta,
    toInt32(dcm.away_captain_red_cards) AS triggered_captain_red_cards,
    toInt32(dcm.home_captain_red_cards) AS opponent_captain_red_cards,
    toInt32(dcm.away_captain_red_cards - dcm.home_captain_red_cards) AS captain_red_cards_delta,
    toNullable(toInt32(dcm.away_captain_first_card_minute)) AS triggered_captain_first_card_minute,
    toNullable(toInt32(dcm.home_captain_first_card_minute)) AS opponent_captain_first_card_minute,

    toInt32(coalesce(ps.yellow_cards_away, 0)) AS triggered_team_yellow_cards,
    toInt32(coalesce(ps.yellow_cards_home, 0)) AS opponent_yellow_cards,
    toInt32(coalesce(ps.yellow_cards_away, 0) - coalesce(ps.yellow_cards_home, 0)) AS yellow_cards_delta,
    toInt32(coalesce(ps.red_cards_away, 0)) AS triggered_team_red_cards,
    toInt32(coalesce(ps.red_cards_home, 0)) AS opponent_red_cards,
    toInt32(coalesce(ps.red_cards_away, 0) - coalesce(ps.red_cards_home, 0)) AS red_cards_delta,
    toInt32(coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)) AS triggered_team_total_cards,
    toInt32(coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) AS opponent_total_cards,
    toInt32(
        (coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0))
        - (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0))
    ) AS card_count_delta,
    toInt32(coalesce(ps.fouls_away, 0)) AS triggered_team_fouls_committed,
    toInt32(coalesce(ps.fouls_home, 0)) AS opponent_fouls_committed,
    toInt32(coalesce(ps.fouls_away, 0) - coalesce(ps.fouls_home, 0)) AS fouls_committed_delta,
    toInt32(coalesce(ps.tackles_succeeded_away, 0)) AS triggered_team_tackles_won,
    toInt32(coalesce(ps.tackles_succeeded_home, 0)) AS opponent_tackles_won,
    toInt32(coalesce(ps.duels_won_away, 0)) AS triggered_team_duels_won,
    toInt32(coalesce(ps.duels_won_home, 0)) AS opponent_duels_won,
    toInt32(coalesce(ps.interceptions_away, 0)) AS triggered_team_interceptions,
    toInt32(coalesce(ps.interceptions_home, 0)) AS opponent_interceptions,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
            1
        ), 0.0)
        - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_away, 0) - coalesce(ps.ball_possession_home, 0), 1)) AS possession_delta_pct

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
INNER JOIN dual_captain_matches AS dcm
    ON dcm.match_id = m.match_id
WHERE m.match_finished = 1
  AND m.match_id > 0

ORDER BY m.match_id, triggered_side;
