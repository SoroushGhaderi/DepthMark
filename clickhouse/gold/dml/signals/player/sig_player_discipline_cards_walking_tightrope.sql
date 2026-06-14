INSERT INTO gold.sig_player_discipline_cards_walking_tightrope (
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
    trigger_threshold_card_minute,
    triggered_player_first_yellow_card_minute,
    triggered_player_yellow_cards_total,
    triggered_player_red_cards_total,
    triggered_player_total_cards,
    score_margin_at_first_yellow,
    triggered_player_fouls_committed,
    triggered_player_duels_won,
    triggered_player_duels_lost,
    triggered_player_tackles_won,
    triggered_player_interceptions,
    triggered_player_minutes_played,
    triggered_team_total_fouls,
    opponent_total_fouls,
    triggered_team_yellow_cards,
    opponent_yellow_cards,
    triggered_team_red_cards,
    opponent_red_cards,
    triggered_team_duels_won,
    opponent_duels_won,
    triggered_team_tackles_won,
    opponent_tackles_won,
    triggered_team_interceptions,
    opponent_interceptions,
    triggered_team_possession_pct,
    opponent_possession_pct
)
-- Signal: sig_player_discipline_cards_walking_tightrope
-- Trigger: Player receives a yellow card before the 20th minute.
-- Intent: identify players forced into early disciplinary risk, with player behavior and bilateral match-intensity context.

WITH early_yellow AS (
    SELECT
        c.match_id,
        toInt32(assumeNotNull(c.player_id)) AS triggered_player_id,
        any(coalesce(c.player_name, 'Unknown')) AS triggered_player_name,
        lowerUTF8(c.team_side) AS triggered_side,
        min(c.card_minute) AS triggered_player_first_yellow_card_minute,
        argMin(
            coalesce(c.score_home_at_time, 0),
            tuple(c.card_minute, c.event_id)
        ) AS score_home_at_first_yellow,
        argMin(
            coalesce(c.score_away_at_time, 0),
            tuple(c.card_minute, c.event_id)
        ) AS score_away_at_first_yellow
    FROM silver.card AS c
    WHERE c.match_id > 0
      AND c.player_id IS NOT NULL
      AND lowerUTF8(coalesce(c.team_side, '')) IN ('home', 'away')
      AND positionCaseInsensitive(coalesce(c.card_type, ''), 'yellow') > 0
      AND c.card_minute < 20
    GROUP BY
        c.match_id,
        triggered_player_id,
        triggered_side
),
player_cards AS (
    SELECT
        c.match_id,
        toInt32(assumeNotNull(c.player_id)) AS player_id,
        countIf(positionCaseInsensitive(coalesce(c.card_type, ''), 'yellow') > 0) AS triggered_player_yellow_cards_total,
        countIf(positionCaseInsensitive(coalesce(c.card_type, ''), 'red') > 0) AS triggered_player_red_cards_total
    FROM silver.card AS c
    WHERE c.match_id > 0
      AND c.player_id IS NOT NULL
    GROUP BY
        c.match_id,
        player_id
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
    ey.triggered_side,
    ey.triggered_player_id,
    coalesce(p.player_name, ey.triggered_player_name) AS triggered_player_name,
    if(ey.triggered_side = 'home', m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(ey.triggered_side = 'home', m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(ey.triggered_side = 'home', m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(ey.triggered_side = 'home', m.away_team_name, m.home_team_name) AS opponent_team_name,
    toInt32(20) AS trigger_threshold_card_minute,
    ey.triggered_player_first_yellow_card_minute,
    coalesce(pc.triggered_player_yellow_cards_total, 0) AS triggered_player_yellow_cards_total,
    coalesce(pc.triggered_player_red_cards_total, 0) AS triggered_player_red_cards_total,
    coalesce(pc.triggered_player_yellow_cards_total, 0) + coalesce(pc.triggered_player_red_cards_total, 0) AS triggered_player_total_cards,
    if(
        ey.triggered_side = 'home',
        ey.score_home_at_first_yellow - ey.score_away_at_first_yellow,
        ey.score_away_at_first_yellow - ey.score_home_at_first_yellow
    ) AS score_margin_at_first_yellow,

    coalesce(p.fouls_committed, 0) AS triggered_player_fouls_committed,
    coalesce(p.duels_won, 0) AS triggered_player_duels_won,
    coalesce(p.duels_lost, 0) AS triggered_player_duels_lost,
    coalesce(p.tackles_won, 0) AS triggered_player_tackles_won,
    coalesce(p.interceptions, 0) AS triggered_player_interceptions,
    coalesce(p.minutes_played, 0) AS triggered_player_minutes_played,

    multiIf(
        ey.triggered_side = 'home', coalesce(ps.fouls_home, 0),
        ey.triggered_side = 'away', coalesce(ps.fouls_away, 0),
        0
    ) AS triggered_team_total_fouls,
    multiIf(
        ey.triggered_side = 'home', coalesce(ps.fouls_away, 0),
        ey.triggered_side = 'away', coalesce(ps.fouls_home, 0),
        0
    ) AS opponent_total_fouls,
    multiIf(
        ey.triggered_side = 'home', coalesce(ps.yellow_cards_home, 0),
        ey.triggered_side = 'away', coalesce(ps.yellow_cards_away, 0),
        0
    ) AS triggered_team_yellow_cards,
    multiIf(
        ey.triggered_side = 'home', coalesce(ps.yellow_cards_away, 0),
        ey.triggered_side = 'away', coalesce(ps.yellow_cards_home, 0),
        0
    ) AS opponent_yellow_cards,
    multiIf(
        ey.triggered_side = 'home', coalesce(ps.red_cards_home, 0),
        ey.triggered_side = 'away', coalesce(ps.red_cards_away, 0),
        0
    ) AS triggered_team_red_cards,
    multiIf(
        ey.triggered_side = 'home', coalesce(ps.red_cards_away, 0),
        ey.triggered_side = 'away', coalesce(ps.red_cards_home, 0),
        0
    ) AS opponent_red_cards,
    multiIf(
        ey.triggered_side = 'home', coalesce(ps.duels_won_home, 0),
        ey.triggered_side = 'away', coalesce(ps.duels_won_away, 0),
        0
    ) AS triggered_team_duels_won,
    multiIf(
        ey.triggered_side = 'home', coalesce(ps.duels_won_away, 0),
        ey.triggered_side = 'away', coalesce(ps.duels_won_home, 0),
        0
    ) AS opponent_duels_won,
    multiIf(
        ey.triggered_side = 'home', coalesce(ps.tackles_succeeded_home, 0),
        ey.triggered_side = 'away', coalesce(ps.tackles_succeeded_away, 0),
        0
    ) AS triggered_team_tackles_won,
    multiIf(
        ey.triggered_side = 'home', coalesce(ps.tackles_succeeded_away, 0),
        ey.triggered_side = 'away', coalesce(ps.tackles_succeeded_home, 0),
        0
    ) AS opponent_tackles_won,
    multiIf(
        ey.triggered_side = 'home', coalesce(ps.interceptions_home, 0),
        ey.triggered_side = 'away', coalesce(ps.interceptions_away, 0),
        0
    ) AS triggered_team_interceptions,
    multiIf(
        ey.triggered_side = 'home', coalesce(ps.interceptions_away, 0),
        ey.triggered_side = 'away', coalesce(ps.interceptions_home, 0),
        0
    ) AS opponent_interceptions,
    toFloat32(multiIf(
        ey.triggered_side = 'home', coalesce(ps.ball_possession_home, 0),
        ey.triggered_side = 'away', coalesce(ps.ball_possession_away, 0),
        0
    )) AS triggered_team_possession_pct,
    toFloat32(multiIf(
        ey.triggered_side = 'home', coalesce(ps.ball_possession_away, 0),
        ey.triggered_side = 'away', coalesce(ps.ball_possession_home, 0),
        0
    )) AS opponent_possession_pct
FROM early_yellow AS ey
INNER JOIN silver.match AS m
    ON m.match_id = ey.match_id
LEFT JOIN silver.player_match_stat AS p
    ON p.match_id = ey.match_id
   AND p.player_id = ey.triggered_player_id
LEFT JOIN player_cards AS pc
    ON pc.match_id = ey.match_id
   AND pc.player_id = ey.triggered_player_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = ey.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
ORDER BY
    ey.triggered_player_first_yellow_card_minute ASC,
    triggered_player_total_cards DESC,
    triggered_player_fouls_committed DESC,
    m.match_date DESC,
    m.match_id DESC;
