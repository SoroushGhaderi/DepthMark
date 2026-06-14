INSERT INTO gold.sig_player_discipline_cards_foul_magnet (
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
    trigger_threshold_was_fouled,
    triggered_player_was_fouled,
    triggered_player_fouls_committed,
    triggered_player_total_cards,
    triggered_player_yellow_cards,
    triggered_player_red_cards,
    triggered_player_minutes_played,
    was_fouled_count_above_threshold,
    triggered_team_total_fouls,
    opponent_total_fouls,
    triggered_team_total_cards,
    opponent_total_cards,
    triggered_team_yellow_cards,
    opponent_yellow_cards,
    triggered_team_red_cards,
    opponent_red_cards,
    triggered_team_possession_pct,
    opponent_possession_pct
)
WITH player_cards AS (
    SELECT
        match_id,
        assumeNotNull(player_id) AS player_id,
        count() AS triggered_player_total_cards,
        countIf(
            positionCaseInsensitiveUTF8(coalesce(card_type, ''), 'yellow') > 0
            OR positionCaseInsensitiveUTF8(coalesce(description, ''), 'yellow') > 0
        ) AS triggered_player_yellow_cards,
        countIf(
            positionCaseInsensitiveUTF8(coalesce(card_type, ''), 'red') > 0
            OR positionCaseInsensitiveUTF8(coalesce(description, ''), 'red') > 0
        ) AS triggered_player_red_cards
    FROM silver.card
    WHERE match_id > 0
      AND player_id IS NOT NULL
    GROUP BY
        match_id,
        player_id
)
-- Signal: sig_player_discipline_cards_foul_magnet
-- Trigger: player is fouled >= 6 times in a single match.
-- Intent: identify players who repeatedly draw contact, with bilateral discipline and possession context.

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

    toInt32(6) AS trigger_threshold_was_fouled,
    toInt32(coalesce(p.was_fouled, 0)) AS triggered_player_was_fouled,
    toInt32(coalesce(p.fouls_committed, 0)) AS triggered_player_fouls_committed,
    toInt32(coalesce(pc.triggered_player_total_cards, 0)) AS triggered_player_total_cards,
    toInt32(coalesce(pc.triggered_player_yellow_cards, 0)) AS triggered_player_yellow_cards,
    toInt32(coalesce(pc.triggered_player_red_cards, 0)) AS triggered_player_red_cards,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,
    toInt32(coalesce(p.was_fouled, 0) - 6) AS was_fouled_count_above_threshold,

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
        p.team_id = m.home_team_id, coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        0
    )) AS triggered_team_total_cards,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        0
    )) AS opponent_total_cards,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.yellow_cards_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.yellow_cards_away, 0),
        0
    )) AS triggered_team_yellow_cards,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.yellow_cards_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.yellow_cards_home, 0),
        0
    )) AS opponent_yellow_cards,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.red_cards_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.red_cards_away, 0),
        0
    )) AS triggered_team_red_cards,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.red_cards_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.red_cards_home, 0),
        0
    )) AS opponent_red_cards,
    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.ball_possession_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.ball_possession_away, 0),
        0
    )) AS triggered_team_possession_pct,
    toFloat32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.ball_possession_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.ball_possession_home, 0),
        0
    )) AS opponent_possession_pct

FROM silver.player_match_stat AS p
INNER JOIN silver.match AS m
    ON m.match_id = p.match_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = p.match_id
   AND ps.period = 'All'
LEFT JOIN player_cards AS pc
    ON pc.match_id = p.match_id
   AND pc.player_id = p.player_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND p.player_id > 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)
  AND coalesce(p.was_fouled, 0) >= 6

ORDER BY
    triggered_player_was_fouled DESC,
    triggered_player_minutes_played DESC,
    m.match_date DESC,
    m.match_id DESC;
