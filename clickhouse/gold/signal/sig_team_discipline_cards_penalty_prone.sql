WITH penalty_shots AS (
    SELECT
        s.match_id,
        if(s.team_id = m.home_team_id, 'home', 'away') AS penalty_awarded_side,
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
match_penalty_totals AS (
    SELECT
        ps.match_id,
        countIf(ps.penalty_awarded_side = 'home') AS home_penalties_awarded,
        countIf(ps.penalty_awarded_side = 'away') AS away_penalties_awarded,
        countIf(ps.penalty_awarded_side = 'home' AND ps.penalty_scored = 1) AS home_penalties_scored,
        countIf(ps.penalty_awarded_side = 'away' AND ps.penalty_scored = 1) AS away_penalties_scored,
        countIf(ps.penalty_awarded_side = 'home' AND ps.penalty_scored = 0) AS home_penalties_missed,
        countIf(ps.penalty_awarded_side = 'away' AND ps.penalty_scored = 0) AS away_penalties_missed,
        count() AS total_match_penalties_awarded
    FROM penalty_shots AS ps
    GROUP BY ps.match_id
)
INSERT INTO gold.sig_team_discipline_cards_penalty_prone (
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
    trigger_threshold_min_penalties_conceded,
    triggered_team_penalties_conceded,
    opponent_penalties_conceded,
    penalties_conceded_delta,
    triggered_team_penalties_awarded,
    opponent_penalties_awarded,
    total_match_penalties_awarded,
    triggered_team_penalties_conceded_scored,
    triggered_team_penalties_conceded_missed,
    opponent_penalties_conceded_scored,
    opponent_penalties_conceded_missed,
    triggered_team_fouls_committed,
    opponent_fouls_committed,
    fouls_committed_delta,
    triggered_team_yellow_cards,
    opponent_yellow_cards,
    triggered_team_red_cards,
    opponent_red_cards,
    triggered_team_total_cards,
    opponent_total_cards,
    card_count_delta,
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
-- Signal: sig_team_discipline_cards_penalty_prone
-- Trigger: team concedes >= 2 penalties in a single match.
-- Intent: detect team-level penalty concession vulnerability with bilateral discipline, defending, and possession context.

-- Home side triggers the signal
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

    toInt32(2) AS trigger_threshold_min_penalties_conceded,
    toInt32(coalesce(mpt.away_penalties_awarded, 0)) AS triggered_team_penalties_conceded,
    toInt32(coalesce(mpt.home_penalties_awarded, 0)) AS opponent_penalties_conceded,
    toInt32(coalesce(mpt.away_penalties_awarded, 0) - coalesce(mpt.home_penalties_awarded, 0)) AS penalties_conceded_delta,
    toInt32(coalesce(mpt.home_penalties_awarded, 0)) AS triggered_team_penalties_awarded,
    toInt32(coalesce(mpt.away_penalties_awarded, 0)) AS opponent_penalties_awarded,
    toInt32(coalesce(mpt.total_match_penalties_awarded, 0)) AS total_match_penalties_awarded,
    toInt32(coalesce(mpt.away_penalties_scored, 0)) AS triggered_team_penalties_conceded_scored,
    toInt32(coalesce(mpt.away_penalties_missed, 0)) AS triggered_team_penalties_conceded_missed,
    toInt32(coalesce(mpt.home_penalties_scored, 0)) AS opponent_penalties_conceded_scored,
    toInt32(coalesce(mpt.home_penalties_missed, 0)) AS opponent_penalties_conceded_missed,

    toInt32(coalesce(ps.fouls_home, 0)) AS triggered_team_fouls_committed,
    toInt32(coalesce(ps.fouls_away, 0)) AS opponent_fouls_committed,
    toInt32(coalesce(ps.fouls_home, 0) - coalesce(ps.fouls_away, 0)) AS fouls_committed_delta,
    toInt32(coalesce(ps.yellow_cards_home, 0)) AS triggered_team_yellow_cards,
    toInt32(coalesce(ps.yellow_cards_away, 0)) AS opponent_yellow_cards,
    toInt32(coalesce(ps.red_cards_home, 0)) AS triggered_team_red_cards,
    toInt32(coalesce(ps.red_cards_away, 0)) AS opponent_red_cards,
    toInt32(coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) AS triggered_team_total_cards,
    toInt32(coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)) AS opponent_total_cards,
    toInt32(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0))
        - (coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0))
    ) AS card_count_delta,
    toInt32(coalesce(ps.duels_won_home, 0)) AS triggered_team_duels_won,
    toInt32(coalesce(ps.duels_won_away, 0)) AS opponent_duels_won,
    toInt32(coalesce(ps.tackles_succeeded_home, 0)) AS triggered_team_tackles_won,
    toInt32(coalesce(ps.tackles_succeeded_away, 0)) AS opponent_tackles_won,
    toInt32(coalesce(ps.interceptions_home, 0)) AS triggered_team_interceptions,
    toInt32(coalesce(ps.interceptions_away, 0)) AS opponent_interceptions,
    toInt32(coalesce(ps.clearances_home, 0)) AS triggered_team_clearances,
    toInt32(coalesce(ps.clearances_away, 0)) AS opponent_clearances,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_home, 0) - coalesce(ps.ball_possession_away, 0), 1)) AS possession_delta_pct

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
INNER JOIN match_penalty_totals AS mpt
    ON mpt.match_id = m.match_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(mpt.away_penalties_awarded, 0) >= 2

UNION ALL

-- Away side triggers the signal
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

    toInt32(2) AS trigger_threshold_min_penalties_conceded,
    toInt32(coalesce(mpt.home_penalties_awarded, 0)) AS triggered_team_penalties_conceded,
    toInt32(coalesce(mpt.away_penalties_awarded, 0)) AS opponent_penalties_conceded,
    toInt32(coalesce(mpt.home_penalties_awarded, 0) - coalesce(mpt.away_penalties_awarded, 0)) AS penalties_conceded_delta,
    toInt32(coalesce(mpt.away_penalties_awarded, 0)) AS triggered_team_penalties_awarded,
    toInt32(coalesce(mpt.home_penalties_awarded, 0)) AS opponent_penalties_awarded,
    toInt32(coalesce(mpt.total_match_penalties_awarded, 0)) AS total_match_penalties_awarded,
    toInt32(coalesce(mpt.home_penalties_scored, 0)) AS triggered_team_penalties_conceded_scored,
    toInt32(coalesce(mpt.home_penalties_missed, 0)) AS triggered_team_penalties_conceded_missed,
    toInt32(coalesce(mpt.away_penalties_scored, 0)) AS opponent_penalties_conceded_scored,
    toInt32(coalesce(mpt.away_penalties_missed, 0)) AS opponent_penalties_conceded_missed,

    toInt32(coalesce(ps.fouls_away, 0)) AS triggered_team_fouls_committed,
    toInt32(coalesce(ps.fouls_home, 0)) AS opponent_fouls_committed,
    toInt32(coalesce(ps.fouls_away, 0) - coalesce(ps.fouls_home, 0)) AS fouls_committed_delta,
    toInt32(coalesce(ps.yellow_cards_away, 0)) AS triggered_team_yellow_cards,
    toInt32(coalesce(ps.yellow_cards_home, 0)) AS opponent_yellow_cards,
    toInt32(coalesce(ps.red_cards_away, 0)) AS triggered_team_red_cards,
    toInt32(coalesce(ps.red_cards_home, 0)) AS opponent_red_cards,
    toInt32(coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)) AS triggered_team_total_cards,
    toInt32(coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) AS opponent_total_cards,
    toInt32(
        (coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0))
        - (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0))
    ) AS card_count_delta,
    toInt32(coalesce(ps.duels_won_away, 0)) AS triggered_team_duels_won,
    toInt32(coalesce(ps.duels_won_home, 0)) AS opponent_duels_won,
    toInt32(coalesce(ps.tackles_succeeded_away, 0)) AS triggered_team_tackles_won,
    toInt32(coalesce(ps.tackles_succeeded_home, 0)) AS opponent_tackles_won,
    toInt32(coalesce(ps.interceptions_away, 0)) AS triggered_team_interceptions,
    toInt32(coalesce(ps.interceptions_home, 0)) AS opponent_interceptions,
    toInt32(coalesce(ps.clearances_away, 0)) AS triggered_team_clearances,
    toInt32(coalesce(ps.clearances_home, 0)) AS opponent_clearances,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_away, 0) - coalesce(ps.ball_possession_home, 0), 1)) AS possession_delta_pct

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
INNER JOIN match_penalty_totals AS mpt
    ON mpt.match_id = m.match_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(mpt.home_penalties_awarded, 0) >= 2

ORDER BY
    triggered_team_penalties_conceded DESC,
    penalties_conceded_delta DESC,
    triggered_team_fouls_committed DESC,
    m.match_date DESC,
    m.match_id DESC;
