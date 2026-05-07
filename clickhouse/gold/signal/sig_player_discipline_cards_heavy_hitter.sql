WITH player_cards AS (
    SELECT
        c.match_id,
        toInt32(assumeNotNull(c.player_id)) AS player_id,
        count() AS triggered_player_total_cards,
        countIf(
            positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'yellow') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'yellow') > 0
        ) AS triggered_player_yellow_cards,
        countIf(
            positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'red') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'red') > 0
        ) AS triggered_player_red_cards
    FROM silver.card AS c
    WHERE c.match_id > 0
      AND c.player_id IS NOT NULL
    GROUP BY
        c.match_id,
        player_id
)
INSERT INTO gold.sig_player_discipline_cards_heavy_hitter (
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
    trigger_threshold_max_tackle_success_pct,
    trigger_threshold_min_fouls_committed,
    triggered_player_tackles_won,
    triggered_player_tackle_attempts,
    triggered_player_tackle_success_pct,
    triggered_player_fouls_committed,
    triggered_player_total_cards,
    triggered_player_yellow_cards,
    triggered_player_red_cards,
    triggered_player_minutes_played,
    tackle_success_below_threshold_pct,
    foul_count_above_threshold,
    triggered_team_total_fouls,
    opponent_total_fouls,
    triggered_team_total_cards,
    opponent_total_cards,
    triggered_team_tackles_won,
    opponent_tackles_won,
    triggered_team_duels_won,
    opponent_duels_won,
    triggered_team_possession_pct,
    opponent_possession_pct
)
-- Signal: sig_player_discipline_cards_heavy_hitter
-- Trigger: player wins <= 20% of tackles while committing >= 4 fouls in the same match.
-- Intent: isolate foul-heavy defenders with poor tackle efficiency, with bilateral discipline and duel context.

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
    coalesce(p.player_name, 'Unknown') AS triggered_player_name,
    if(p.team_id = m.home_team_id, m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(p.team_id = m.home_team_id, m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(p.team_id = m.home_team_id, m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(p.team_id = m.home_team_id, m.away_team_name, m.home_team_name) AS opponent_team_name,

    toFloat32(20.0) AS trigger_threshold_max_tackle_success_pct,
    toInt32(4) AS trigger_threshold_min_fouls_committed,

    toInt32(coalesce(p.tackles_won, 0)) AS triggered_player_tackles_won,
    toInt32(coalesce(p.tackle_attempts, 0)) AS triggered_player_tackle_attempts,
    toFloat32(coalesce(
        p.tackle_success_rate,
        round(
            100.0 * coalesce(p.tackles_won, 0)
            / nullIf(coalesce(p.tackle_attempts, 0), 0),
            1
        ),
        0.0
    )) AS triggered_player_tackle_success_pct,
    toInt32(coalesce(p.fouls_committed, 0)) AS triggered_player_fouls_committed,
    toInt32(coalesce(pc.triggered_player_total_cards, 0)) AS triggered_player_total_cards,
    toInt32(coalesce(pc.triggered_player_yellow_cards, 0)) AS triggered_player_yellow_cards,
    toInt32(coalesce(pc.triggered_player_red_cards, 0)) AS triggered_player_red_cards,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,

    toFloat32(
        20.0 - coalesce(
            p.tackle_success_rate,
            round(
                100.0 * coalesce(p.tackles_won, 0)
                / nullIf(coalesce(p.tackle_attempts, 0), 0),
                1
            ),
            0.0
        )
    ) AS tackle_success_below_threshold_pct,
    toInt32(coalesce(p.fouls_committed, 0) - 4) AS foul_count_above_threshold,

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
        p.team_id = m.home_team_id, coalesce(ps.tackles_succeeded_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.tackles_succeeded_away, 0),
        0
    )) AS triggered_team_tackles_won,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.tackles_succeeded_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.tackles_succeeded_home, 0),
        0
    )) AS opponent_tackles_won,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.duels_won_home, 0),
        p.team_id = m.away_team_id, coalesce(ps.duels_won_away, 0),
        0
    )) AS triggered_team_duels_won,
    toInt32(multiIf(
        p.team_id = m.home_team_id, coalesce(ps.duels_won_away, 0),
        p.team_id = m.away_team_id, coalesce(ps.duels_won_home, 0),
        0
    )) AS opponent_duels_won,
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
  AND coalesce(p.tackle_attempts, 0) > 0
  AND coalesce(p.fouls_committed, 0) >= 4
  AND coalesce(
      p.tackle_success_rate,
      round(
          100.0 * coalesce(p.tackles_won, 0)
          / nullIf(coalesce(p.tackle_attempts, 0), 0),
          1
      ),
      0.0
  ) <= 20.0

ORDER BY
    triggered_player_fouls_committed DESC,
    triggered_player_tackle_success_pct ASC,
    triggered_player_minutes_played DESC,
    m.match_date DESC,
    m.match_id DESC;
