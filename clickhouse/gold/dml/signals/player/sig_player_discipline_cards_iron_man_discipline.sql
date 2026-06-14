INSERT INTO gold.sig_player_discipline_cards_iron_man_discipline (
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
    triggered_player_role_group,
    triggered_player_position_id,
    triggered_player_usual_playing_position_id,
    trigger_threshold_minutes_played,
    trigger_threshold_fouls_committed,
    trigger_threshold_tackles_won,
    triggered_player_minutes_played,
    triggered_player_fouls_committed,
    triggered_player_tackles_won,
    triggered_player_tackle_attempts,
    triggered_player_total_cards,
    triggered_player_yellow_cards,
    triggered_player_red_cards,
    triggered_player_was_fouled,
    tackles_won_above_threshold,
    triggered_team_fouls,
    opponent_fouls,
    triggered_team_total_cards,
    opponent_total_cards,
    triggered_team_yellow_cards,
    opponent_yellow_cards,
    triggered_team_red_cards,
    opponent_red_cards,
    triggered_team_tackles_won,
    opponent_tackles_won,
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
),
player_positions AS (
    SELECT
        match_id,
        person_id,
        argMax(position_id, if(role = 'starter', 2, 1)) AS position_id,
        argMax(usual_playing_position_id, if(role = 'starter', 2, 1)) AS usual_playing_position_id
    FROM silver.match_personnel
    WHERE role IN ('starter', 'substitute')
    GROUP BY
        match_id,
        person_id
)
-- Signal: sig_player_discipline_cards_iron_man_discipline
-- Trigger: defender/defensive-midfielder proxy plays exactly 90 minutes, commits 0 fouls, and records >= 5 tackles won.
-- Intent: isolate full-match defensive enforcers who sustain high tackle volume without committing fouls.

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

    multiIf(
        coalesce(mp.usual_playing_position_id, 0) = 1, 'defender',
        coalesce(mp.usual_playing_position_id, 0) = 2, 'defensive_midfielder_proxy',
        'other'
    ) AS triggered_player_role_group,
    toInt32(coalesce(mp.position_id, 0)) AS triggered_player_position_id,
    toInt32(coalesce(mp.usual_playing_position_id, 0)) AS triggered_player_usual_playing_position_id,

    toInt32(90) AS trigger_threshold_minutes_played,
    toInt32(0) AS trigger_threshold_fouls_committed,
    toInt32(5) AS trigger_threshold_tackles_won,

    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,
    toInt32(coalesce(p.fouls_committed, 0)) AS triggered_player_fouls_committed,
    toInt32(coalesce(p.tackles_won, 0)) AS triggered_player_tackles_won,
    toInt32(coalesce(p.tackle_attempts, 0)) AS triggered_player_tackle_attempts,
    toInt32(coalesce(pc.triggered_player_total_cards, 0)) AS triggered_player_total_cards,
    toInt32(coalesce(pc.triggered_player_yellow_cards, 0)) AS triggered_player_yellow_cards,
    toInt32(coalesce(pc.triggered_player_red_cards, 0)) AS triggered_player_red_cards,
    toInt32(coalesce(p.was_fouled, 0)) AS triggered_player_was_fouled,
    toInt32(coalesce(p.tackles_won, 0) - 5) AS tackles_won_above_threshold,

    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.fouls_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.fouls_away, 0),
        0
    ) AS triggered_team_fouls,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.fouls_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.fouls_home, 0),
        0
    ) AS opponent_fouls,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        0
    ) AS triggered_team_total_cards,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        0
    ) AS opponent_total_cards,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.yellow_cards_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.yellow_cards_away, 0),
        0
    ) AS triggered_team_yellow_cards,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.yellow_cards_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.yellow_cards_home, 0),
        0
    ) AS opponent_yellow_cards,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.red_cards_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.red_cards_away, 0),
        0
    ) AS triggered_team_red_cards,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.red_cards_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.red_cards_home, 0),
        0
    ) AS opponent_red_cards,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.tackles_succeeded_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.tackles_succeeded_away, 0),
        0
    ) AS triggered_team_tackles_won,
    multiIf(
        p.team_id = m.home_team_id, coalesce(ps.tackles_succeeded_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.tackles_succeeded_home, 0),
        0
    ) AS opponent_tackles_won,
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
INNER JOIN player_positions AS mp
    ON mp.match_id = p.match_id
   AND mp.person_id = p.player_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = p.match_id
   AND ps.period = 'All'
LEFT JOIN player_cards AS pc
    ON pc.match_id = p.match_id
   AND pc.player_id = p.player_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND p.player_id > 0
  AND p.is_goalkeeper = 0
  AND (p.team_id = m.home_team_id OR p.team_id = m.away_team_id)
  AND coalesce(mp.usual_playing_position_id, 0) IN (1, 2)
  AND coalesce(p.minutes_played, 0) = 90
  AND coalesce(p.fouls_committed, 0) = 0
  AND coalesce(p.tackles_won, 0) >= 5

ORDER BY
    triggered_player_tackles_won DESC,
    triggered_player_tackle_attempts DESC,
    m.match_date DESC,
    m.match_id DESC;
