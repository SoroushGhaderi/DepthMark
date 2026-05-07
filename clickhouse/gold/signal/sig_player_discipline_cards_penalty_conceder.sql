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
),
penalty_shots AS (
    SELECT
        s.match_id,
        s.shot_id AS penalty_shot_id,
        if(s.team_id = m.home_team_id, 'home', 'away') AS penalty_awarded_side,
        toInt32(coalesce(s.minute, 0)) AS penalty_minute,
        toInt32(coalesce(s.minute_added, 0)) AS penalty_added_time,
        toUInt8(
            positionCaseInsensitiveUTF8(coalesce(s.event_type, ''), 'goal') > 0
        ) AS penalty_scored
    FROM silver.shot AS s
    INNER JOIN silver.match AS m
        ON m.match_id = s.match_id
    WHERE s.match_id > 0
      AND (s.team_id = m.home_team_id OR s.team_id = m.away_team_id)
      AND (
          positionCaseInsensitiveUTF8(coalesce(s.situation, ''), 'penalty') > 0
          OR positionCaseInsensitiveUTF8(coalesce(s.shot_type, ''), 'penalty') > 0
      )
),
penalty_card_candidates AS (
    SELECT
        ps.match_id,
        ps.penalty_shot_id,
        toInt32(assumeNotNull(c.player_id)) AS triggered_player_id,
        coalesce(c.player_name, 'Unknown') AS triggered_player_name,
        lowerUTF8(coalesce(c.team_side, '')) AS triggered_side,
        toInt32(c.card_minute) AS penalty_conceded_card_minute,
        toInt32(coalesce(c.added_time, 0)) AS penalty_conceded_card_added_time,
        toInt32(coalesce(c.score_home_at_time, 0)) AS score_home_at_penalty_concession,
        toInt32(coalesce(c.score_away_at_time, 0)) AS score_away_at_penalty_concession,
        ps.penalty_scored,
        abs(toInt32(c.card_minute) - ps.penalty_minute) AS minute_distance,
        abs(toInt32(coalesce(c.added_time, 0)) - ps.penalty_added_time) AS added_time_distance,
        multiIf(
            positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'penalty') > 0, 3,
            positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'handball') > 0, 2,
            positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'foul') > 0, 1,
            0
        ) AS penalty_relevance_score,
        c.event_id
    FROM penalty_shots AS ps
    INNER JOIN silver.card AS c
        ON c.match_id = ps.match_id
       AND c.player_id IS NOT NULL
       AND lowerUTF8(coalesce(c.team_side, '')) IN ('home', 'away')
       AND lowerUTF8(coalesce(c.team_side, '')) != ps.penalty_awarded_side
       AND abs(toInt32(c.card_minute) - ps.penalty_minute) <= 1
),
assigned_penalty_conceders AS (
    SELECT
        match_id,
        penalty_shot_id,
        triggered_player_id,
        triggered_player_name,
        triggered_side,
        penalty_conceded_card_minute,
        penalty_conceded_card_added_time,
        score_home_at_penalty_concession,
        score_away_at_penalty_concession,
        penalty_scored
    FROM (
        SELECT
            pcc.*,
            row_number() OVER (
                PARTITION BY pcc.match_id, pcc.penalty_shot_id
                ORDER BY
                    pcc.penalty_relevance_score DESC,
                    pcc.minute_distance ASC,
                    pcc.added_time_distance ASC,
                    pcc.penalty_conceded_card_minute ASC,
                    pcc.event_id ASC
            ) AS candidate_rank
        FROM penalty_card_candidates AS pcc
        WHERE pcc.penalty_relevance_score > 0
    )
    WHERE candidate_rank = 1
),
player_penalty_concessions AS (
    SELECT
        apc.match_id,
        apc.triggered_player_id,
        argMin(
            apc.triggered_player_name,
            tuple(apc.penalty_conceded_card_minute, apc.penalty_shot_id)
        ) AS triggered_player_name,
        argMin(
            apc.triggered_side,
            tuple(apc.penalty_conceded_card_minute, apc.penalty_shot_id)
        ) AS triggered_side,
        countDistinct(apc.penalty_shot_id) AS triggered_player_penalties_conceded,
        min(apc.penalty_conceded_card_minute) AS triggered_player_first_penalty_conceded_minute,
        argMin(
            apc.score_home_at_penalty_concession,
            tuple(apc.penalty_conceded_card_minute, apc.penalty_shot_id)
        ) AS score_home_at_first_penalty_concession,
        argMin(
            apc.score_away_at_penalty_concession,
            tuple(apc.penalty_conceded_card_minute, apc.penalty_shot_id)
        ) AS score_away_at_first_penalty_concession,
        countIf(apc.penalty_scored = 1) AS triggered_player_penalties_conceded_scored,
        countIf(apc.penalty_scored = 0) AS triggered_player_penalties_conceded_missed
    FROM assigned_penalty_conceders AS apc
    GROUP BY
        apc.match_id,
        apc.triggered_player_id
),
match_penalty_totals AS (
    SELECT
        ps.match_id,
        countIf(ps.penalty_awarded_side = 'home') AS home_penalties_awarded,
        countIf(ps.penalty_awarded_side = 'away') AS away_penalties_awarded,
        count() AS total_match_penalties_awarded
    FROM penalty_shots AS ps
    GROUP BY ps.match_id
)
INSERT INTO gold.sig_player_discipline_cards_penalty_conceder (
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
    trigger_threshold_penalties_conceded,
    triggered_player_penalties_conceded,
    triggered_player_first_penalty_conceded_minute,
    triggered_player_penalties_conceded_scored,
    triggered_player_penalties_conceded_missed,
    triggered_player_fouls_committed,
    triggered_player_was_fouled,
    triggered_player_total_cards,
    triggered_player_yellow_cards,
    triggered_player_red_cards,
    triggered_player_minutes_played,
    score_margin_at_first_penalty_concession,
    triggered_team_penalties_awarded,
    opponent_penalties_awarded,
    total_match_penalties_awarded,
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
-- Signal: sig_player_discipline_cards_penalty_conceder
-- Trigger: player commits a foul resulting in a penalty.
-- Intent: identify players whose fouls concede penalties, with player-grain and bilateral discipline context.
SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,
    ppc.triggered_side,
    ppc.triggered_player_id,
    coalesce(p.player_name, ppc.triggered_player_name) AS triggered_player_name,
    if(ppc.triggered_side = 'home', m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(ppc.triggered_side = 'home', m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(ppc.triggered_side = 'home', m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(ppc.triggered_side = 'home', m.away_team_name, m.home_team_name) AS opponent_team_name,
    toInt32(1) AS trigger_threshold_penalties_conceded,
    toInt32(ppc.triggered_player_penalties_conceded) AS triggered_player_penalties_conceded,
    toInt32(ppc.triggered_player_first_penalty_conceded_minute) AS triggered_player_first_penalty_conceded_minute,
    toInt32(ppc.triggered_player_penalties_conceded_scored) AS triggered_player_penalties_conceded_scored,
    toInt32(ppc.triggered_player_penalties_conceded_missed) AS triggered_player_penalties_conceded_missed,
    toInt32(coalesce(p.fouls_committed, 0)) AS triggered_player_fouls_committed,
    toInt32(coalesce(p.was_fouled, 0)) AS triggered_player_was_fouled,
    toInt32(coalesce(pc.triggered_player_total_cards, 0)) AS triggered_player_total_cards,
    toInt32(coalesce(pc.triggered_player_yellow_cards, 0)) AS triggered_player_yellow_cards,
    toInt32(coalesce(pc.triggered_player_red_cards, 0)) AS triggered_player_red_cards,
    toInt32(coalesce(p.minutes_played, 0)) AS triggered_player_minutes_played,
    toInt32(
        if(
            ppc.triggered_side = 'home',
            ppc.score_home_at_first_penalty_concession - ppc.score_away_at_first_penalty_concession,
            ppc.score_away_at_first_penalty_concession - ppc.score_home_at_first_penalty_concession
        )
    ) AS score_margin_at_first_penalty_concession,
    toInt32(multiIf(
        ppc.triggered_side = 'home', coalesce(mpt.home_penalties_awarded, 0),
        ppc.triggered_side = 'away', coalesce(mpt.away_penalties_awarded, 0),
        0
    )) AS triggered_team_penalties_awarded,
    toInt32(multiIf(
        ppc.triggered_side = 'home', coalesce(mpt.away_penalties_awarded, 0),
        ppc.triggered_side = 'away', coalesce(mpt.home_penalties_awarded, 0),
        0
    )) AS opponent_penalties_awarded,
    toInt32(coalesce(mpt.total_match_penalties_awarded, 0)) AS total_match_penalties_awarded,
    toInt32(multiIf(
        ppc.triggered_side = 'home', coalesce(ps.fouls_home, 0),
        ppc.triggered_side = 'away', coalesce(ps.fouls_away, 0),
        0
    )) AS triggered_team_total_fouls,
    toInt32(multiIf(
        ppc.triggered_side = 'home', coalesce(ps.fouls_away, 0),
        ppc.triggered_side = 'away', coalesce(ps.fouls_home, 0),
        0
    )) AS opponent_total_fouls,
    toInt32(multiIf(
        ppc.triggered_side = 'home', coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        ppc.triggered_side = 'away', coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        0
    )) AS triggered_team_total_cards,
    toInt32(multiIf(
        ppc.triggered_side = 'home', coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        ppc.triggered_side = 'away', coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        0
    )) AS opponent_total_cards,
    toInt32(multiIf(
        ppc.triggered_side = 'home', coalesce(ps.yellow_cards_home, 0),
        ppc.triggered_side = 'away', coalesce(ps.yellow_cards_away, 0),
        0
    )) AS triggered_team_yellow_cards,
    toInt32(multiIf(
        ppc.triggered_side = 'home', coalesce(ps.yellow_cards_away, 0),
        ppc.triggered_side = 'away', coalesce(ps.yellow_cards_home, 0),
        0
    )) AS opponent_yellow_cards,
    toInt32(multiIf(
        ppc.triggered_side = 'home', coalesce(ps.red_cards_home, 0),
        ppc.triggered_side = 'away', coalesce(ps.red_cards_away, 0),
        0
    )) AS triggered_team_red_cards,
    toInt32(multiIf(
        ppc.triggered_side = 'home', coalesce(ps.red_cards_away, 0),
        ppc.triggered_side = 'away', coalesce(ps.red_cards_home, 0),
        0
    )) AS opponent_red_cards,
    toFloat32(multiIf(
        ppc.triggered_side = 'home', coalesce(ps.ball_possession_home, 0),
        ppc.triggered_side = 'away', coalesce(ps.ball_possession_away, 0),
        0
    )) AS triggered_team_possession_pct,
    toFloat32(multiIf(
        ppc.triggered_side = 'home', coalesce(ps.ball_possession_away, 0),
        ppc.triggered_side = 'away', coalesce(ps.ball_possession_home, 0),
        0
    )) AS opponent_possession_pct
FROM player_penalty_concessions AS ppc
INNER JOIN silver.match AS m
    ON m.match_id = ppc.match_id
LEFT JOIN silver.player_match_stat AS p
    ON p.match_id = ppc.match_id
   AND p.player_id = ppc.triggered_player_id
LEFT JOIN player_cards AS pc
    ON pc.match_id = ppc.match_id
   AND pc.player_id = ppc.triggered_player_id
LEFT JOIN match_penalty_totals AS mpt
    ON mpt.match_id = ppc.match_id
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = ppc.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND ppc.triggered_player_penalties_conceded >= 1
ORDER BY
    triggered_player_penalties_conceded DESC,
    triggered_player_first_penalty_conceded_minute ASC,
    m.match_date DESC,
    m.match_id DESC,
    ppc.triggered_player_id ASC;
