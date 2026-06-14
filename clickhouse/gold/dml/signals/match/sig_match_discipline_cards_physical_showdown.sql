INSERT INTO gold.sig_match_discipline_cards_physical_showdown (
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
    trigger_threshold_min_starting_defenders,
    trigger_threshold_min_cards_per_starting_defender,
    triggered_team_starting_defenders,
    opponent_starting_defenders,
    starting_defenders_delta,
    triggered_team_starting_defenders_carded,
    opponent_starting_defenders_carded,
    starting_defenders_carded_delta,
    triggered_team_starting_defenders_carded_share_pct,
    opponent_starting_defenders_carded_share_pct,
    triggered_team_cards_on_starting_defenders,
    opponent_cards_on_starting_defenders,
    cards_on_starting_defenders_delta,
    triggered_team_first_starting_defender_card_minute,
    opponent_first_starting_defender_card_minute,
    triggered_team_last_starting_defender_card_minute,
    opponent_last_starting_defender_card_minute,
    triggered_team_yellow_cards,
    opponent_yellow_cards,
    triggered_team_red_cards,
    opponent_red_cards,
    triggered_team_total_cards,
    opponent_total_cards,
    card_count_delta,
    triggered_team_fouls_committed,
    opponent_fouls_committed,
    fouls_committed_delta,
    triggered_team_duels_won,
    opponent_duels_won,
    triggered_team_tackles_won,
    opponent_tackles_won,
    triggered_team_interceptions,
    opponent_interceptions,
    triggered_team_clearances,
    opponent_clearances,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct
)
-- Signal: sig_match_discipline_cards_physical_showdown
-- Trigger: every starter defender on one side receives at least one card.
-- Intent: detect defensive-line matches where card pressure is distributed across the full starting back line.
WITH starting_defenders AS (
    SELECT
        mp.match_id,
        lowerUTF8(coalesce(mp.team_side, '')) AS triggered_side,
        toInt32(mp.person_id) AS triggered_player_id
    FROM silver.match_personnel AS mp
    WHERE mp.match_id > 0
      AND mp.person_id > 0
      AND lowerUTF8(coalesce(mp.team_side, '')) IN ('home', 'away')
      AND lowerUTF8(coalesce(mp.role, '')) = 'starter'
      AND coalesce(mp.usual_playing_position_id, 0) = 1
    GROUP BY
        mp.match_id,
        triggered_side,
        triggered_player_id
),
card_events AS (
    SELECT
        c.match_id,
        lowerUTF8(coalesce(c.team_side, '')) AS triggered_side,
        toInt32(assumeNotNull(c.player_id)) AS triggered_player_id,
        toInt32(coalesce(c.card_minute, 0)) AS card_minute,
        toUInt8(1) AS has_card_event
    FROM silver.card AS c
    WHERE c.match_id > 0
      AND c.player_id IS NOT NULL
      AND lowerUTF8(coalesce(c.team_side, '')) IN ('home', 'away')
      AND (
            positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'yellow') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'red') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'yellow') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'red') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'booked') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'sent off') > 0
      )
),
defender_card_rollup AS (
    SELECT
        sd.match_id,
        sd.triggered_side,
        sd.triggered_player_id,
        countIf(ce.has_card_event = 1 AND ce.card_minute > 0) AS triggered_player_cards,
        toNullable(minIf(ce.card_minute, ce.has_card_event = 1 AND ce.card_minute > 0)) AS triggered_player_first_card_minute,
        toNullable(maxIf(ce.card_minute, ce.has_card_event = 1 AND ce.card_minute > 0)) AS triggered_player_last_card_minute
    FROM starting_defenders AS sd
    LEFT JOIN card_events AS ce
        ON ce.match_id = sd.match_id
       AND ce.triggered_side = sd.triggered_side
       AND ce.triggered_player_id = sd.triggered_player_id
    GROUP BY
        sd.match_id,
        sd.triggered_side,
        sd.triggered_player_id
),
team_defender_rollup AS (
    SELECT
        sd.match_id,
        sd.triggered_side,
        count() AS triggered_team_starting_defenders,
        countIf(coalesce(dcr.triggered_player_cards, 0) > 0) AS triggered_team_starting_defenders_carded,
        sum(coalesce(dcr.triggered_player_cards, 0)) AS triggered_team_cards_on_starting_defenders,
        if(
            countIf(coalesce(dcr.triggered_player_cards, 0) > 0) > 0,
            minIf(
                toInt32(assumeNotNull(dcr.triggered_player_first_card_minute)),
                coalesce(dcr.triggered_player_cards, 0) > 0
            ),
            NULL
        ) AS triggered_team_first_starting_defender_card_minute,
        if(
            countIf(coalesce(dcr.triggered_player_cards, 0) > 0) > 0,
            maxIf(
                toInt32(assumeNotNull(dcr.triggered_player_last_card_minute)),
                coalesce(dcr.triggered_player_cards, 0) > 0
            ),
            NULL
        ) AS triggered_team_last_starting_defender_card_minute
    FROM starting_defenders AS sd
    LEFT JOIN defender_card_rollup AS dcr
        ON dcr.match_id = sd.match_id
       AND dcr.triggered_side = sd.triggered_side
       AND dcr.triggered_player_id = sd.triggered_player_id
    GROUP BY
        sd.match_id,
        sd.triggered_side
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

    tdr.triggered_side,
    if(tdr.triggered_side = 'home', m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(tdr.triggered_side = 'home', m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(tdr.triggered_side = 'home', m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(tdr.triggered_side = 'home', m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(3) AS trigger_threshold_min_starting_defenders,
    toInt32(1) AS trigger_threshold_min_cards_per_starting_defender,
    toInt32(tdr.triggered_team_starting_defenders) AS triggered_team_starting_defenders,
    toInt32(coalesce(odr.triggered_team_starting_defenders, 0)) AS opponent_starting_defenders,
    toInt32(tdr.triggered_team_starting_defenders - coalesce(odr.triggered_team_starting_defenders, 0)) AS starting_defenders_delta,
    toInt32(tdr.triggered_team_starting_defenders_carded) AS triggered_team_starting_defenders_carded,
    toInt32(coalesce(odr.triggered_team_starting_defenders_carded, 0)) AS opponent_starting_defenders_carded,
    toInt32(
        tdr.triggered_team_starting_defenders_carded
        - coalesce(odr.triggered_team_starting_defenders_carded, 0)
    ) AS starting_defenders_carded_delta,
    toFloat32(round(
        100.0 * tdr.triggered_team_starting_defenders_carded
        / nullIf(tdr.triggered_team_starting_defenders, 0),
        1
    )) AS triggered_team_starting_defenders_carded_share_pct,
    toNullable(toFloat32(round(
        100.0 * coalesce(odr.triggered_team_starting_defenders_carded, 0)
        / nullIf(coalesce(odr.triggered_team_starting_defenders, 0), 0),
        1
    ))) AS opponent_starting_defenders_carded_share_pct,
    toInt32(tdr.triggered_team_cards_on_starting_defenders) AS triggered_team_cards_on_starting_defenders,
    toInt32(coalesce(odr.triggered_team_cards_on_starting_defenders, 0)) AS opponent_cards_on_starting_defenders,
    toInt32(
        tdr.triggered_team_cards_on_starting_defenders
        - coalesce(odr.triggered_team_cards_on_starting_defenders, 0)
    ) AS cards_on_starting_defenders_delta,
    toNullable(toInt32(tdr.triggered_team_first_starting_defender_card_minute)) AS triggered_team_first_starting_defender_card_minute,
    toNullable(toInt32(odr.triggered_team_first_starting_defender_card_minute)) AS opponent_first_starting_defender_card_minute,
    toNullable(toInt32(tdr.triggered_team_last_starting_defender_card_minute)) AS triggered_team_last_starting_defender_card_minute,
    toNullable(toInt32(odr.triggered_team_last_starting_defender_card_minute)) AS opponent_last_starting_defender_card_minute,

    toInt32(multiIf(
        tdr.triggered_side = 'home', coalesce(ps.yellow_cards_home, 0),
        tdr.triggered_side = 'away', coalesce(ps.yellow_cards_away, 0),
        0
    )) AS triggered_team_yellow_cards,
    toInt32(multiIf(
        tdr.triggered_side = 'home', coalesce(ps.yellow_cards_away, 0),
        tdr.triggered_side = 'away', coalesce(ps.yellow_cards_home, 0),
        0
    )) AS opponent_yellow_cards,
    toInt32(multiIf(
        tdr.triggered_side = 'home', coalesce(ps.red_cards_home, 0),
        tdr.triggered_side = 'away', coalesce(ps.red_cards_away, 0),
        0
    )) AS triggered_team_red_cards,
    toInt32(multiIf(
        tdr.triggered_side = 'home', coalesce(ps.red_cards_away, 0),
        tdr.triggered_side = 'away', coalesce(ps.red_cards_home, 0),
        0
    )) AS opponent_red_cards,
    toInt32(multiIf(
        tdr.triggered_side = 'home',
            coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        tdr.triggered_side = 'away',
            coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        0
    )) AS triggered_team_total_cards,
    toInt32(multiIf(
        tdr.triggered_side = 'home',
            coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        tdr.triggered_side = 'away',
            coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        0
    )) AS opponent_total_cards,
    toInt32(
        multiIf(
            tdr.triggered_side = 'home',
                coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
            tdr.triggered_side = 'away',
                coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
            0
        ) - multiIf(
            tdr.triggered_side = 'home',
                coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
            tdr.triggered_side = 'away',
                coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
            0
        )
    ) AS card_count_delta,
    toInt32(multiIf(
        tdr.triggered_side = 'home', coalesce(ps.fouls_home, 0),
        tdr.triggered_side = 'away', coalesce(ps.fouls_away, 0),
        0
    )) AS triggered_team_fouls_committed,
    toInt32(multiIf(
        tdr.triggered_side = 'home', coalesce(ps.fouls_away, 0),
        tdr.triggered_side = 'away', coalesce(ps.fouls_home, 0),
        0
    )) AS opponent_fouls_committed,
    toInt32(
        multiIf(
            tdr.triggered_side = 'home', coalesce(ps.fouls_home, 0),
            tdr.triggered_side = 'away', coalesce(ps.fouls_away, 0),
            0
        ) - multiIf(
            tdr.triggered_side = 'home', coalesce(ps.fouls_away, 0),
            tdr.triggered_side = 'away', coalesce(ps.fouls_home, 0),
            0
        )
    ) AS fouls_committed_delta,
    toInt32(multiIf(
        tdr.triggered_side = 'home', coalesce(ps.duels_won_home, 0),
        tdr.triggered_side = 'away', coalesce(ps.duels_won_away, 0),
        0
    )) AS triggered_team_duels_won,
    toInt32(multiIf(
        tdr.triggered_side = 'home', coalesce(ps.duels_won_away, 0),
        tdr.triggered_side = 'away', coalesce(ps.duels_won_home, 0),
        0
    )) AS opponent_duels_won,
    toInt32(multiIf(
        tdr.triggered_side = 'home', coalesce(ps.tackles_succeeded_home, 0),
        tdr.triggered_side = 'away', coalesce(ps.tackles_succeeded_away, 0),
        0
    )) AS triggered_team_tackles_won,
    toInt32(multiIf(
        tdr.triggered_side = 'home', coalesce(ps.tackles_succeeded_away, 0),
        tdr.triggered_side = 'away', coalesce(ps.tackles_succeeded_home, 0),
        0
    )) AS opponent_tackles_won,
    toInt32(multiIf(
        tdr.triggered_side = 'home', coalesce(ps.interceptions_home, 0),
        tdr.triggered_side = 'away', coalesce(ps.interceptions_away, 0),
        0
    )) AS triggered_team_interceptions,
    toInt32(multiIf(
        tdr.triggered_side = 'home', coalesce(ps.interceptions_away, 0),
        tdr.triggered_side = 'away', coalesce(ps.interceptions_home, 0),
        0
    )) AS opponent_interceptions,
    toInt32(multiIf(
        tdr.triggered_side = 'home', coalesce(ps.clearances_home, 0),
        tdr.triggered_side = 'away', coalesce(ps.clearances_away, 0),
        0
    )) AS triggered_team_clearances,
    toInt32(multiIf(
        tdr.triggered_side = 'home', coalesce(ps.clearances_away, 0),
        tdr.triggered_side = 'away', coalesce(ps.clearances_home, 0),
        0
    )) AS opponent_clearances,
    toFloat32(multiIf(
        tdr.triggered_side = 'home', coalesce(ps.ball_possession_home, 0),
        tdr.triggered_side = 'away', coalesce(ps.ball_possession_away, 0),
        0
    )) AS triggered_team_possession_pct,
    toFloat32(multiIf(
        tdr.triggered_side = 'home', coalesce(ps.ball_possession_away, 0),
        tdr.triggered_side = 'away', coalesce(ps.ball_possession_home, 0),
        0
    )) AS opponent_possession_pct,
    toFloat32(round(
        multiIf(
            tdr.triggered_side = 'home', coalesce(ps.ball_possession_home, 0),
            tdr.triggered_side = 'away', coalesce(ps.ball_possession_away, 0),
            0
        ) - multiIf(
            tdr.triggered_side = 'home', coalesce(ps.ball_possession_away, 0),
            tdr.triggered_side = 'away', coalesce(ps.ball_possession_home, 0),
            0
        ),
        1
    )) AS possession_delta_pct

FROM team_defender_rollup AS tdr
INNER JOIN silver.match AS m
    ON m.match_id = tdr.match_id
LEFT JOIN team_defender_rollup AS odr
    ON odr.match_id = tdr.match_id
   AND odr.triggered_side = if(tdr.triggered_side = 'home', 'away', 'home')
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = tdr.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND tdr.triggered_team_starting_defenders >= 3
  AND tdr.triggered_team_starting_defenders_carded = tdr.triggered_team_starting_defenders

ORDER BY
    triggered_team_starting_defenders DESC,
    triggered_team_cards_on_starting_defenders DESC,
    cards_on_starting_defenders_delta DESC,
    m.match_date DESC,
    m.match_id DESC;
