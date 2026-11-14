INSERT INTO fotmob_gold_signals.sig_match_shooting_goals_set_piece_duel (
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
    trigger_threshold_min_set_piece_goals_per_side,
    match_set_piece_goals,
    match_set_piece_goals_above_threshold,
    home_set_piece_goals,
    away_set_piece_goals,
    triggered_team_goals,
    opponent_goals,
    triggered_team_xg,
    opponent_xg,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    triggered_team_possession_pct,
    opponent_possession_pct
)
-- Signal: sig_match_shooting_goals_set_piece_duel
-- Intent: Find matches decided by dead balls on both sides.
-- Trigger: Both teams score from a corner, free kick or other set piece in a finished match.
WITH team_matches AS (
    SELECT
        m.match_id AS match_id,
        m.match_date AS match_date,
        m.home_team_id AS team_id,
        m.away_team_id AS opponent_id,
        'home' AS side,
        toInt32(coalesce(m.home_score, 0)) AS goals_for,
        toInt32(coalesce(m.away_score, 0)) AS goals_against
    FROM fotmob_silver.match AS m
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND m.home_team_id IS NOT NULL
      AND m.away_team_id IS NOT NULL
      AND m.home_score IS NOT NULL
      AND m.away_score IS NOT NULL
    UNION ALL
    SELECT
        m.match_id AS match_id,
        m.match_date AS match_date,
        m.away_team_id AS team_id,
        m.home_team_id AS opponent_id,
        'away' AS side,
        toInt32(coalesce(m.away_score, 0)) AS goals_for,
        toInt32(coalesce(m.home_score, 0)) AS goals_against
    FROM fotmob_silver.match AS m
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND m.home_team_id IS NOT NULL
      AND m.away_team_id IS NOT NULL
      AND m.home_score IS NOT NULL
      AND m.away_score IS NOT NULL
),
team_results AS (
    SELECT
        tm.match_id AS match_id,
        tm.match_date AS match_date,
        tm.team_id AS team_id,
        tm.opponent_id AS opponent_id,
        tm.side AS side,
        tm.goals_for AS goals_for,
        tm.goals_against AS goals_against,
        row_number() OVER (PARTITION BY tm.team_id ORDER BY tm.match_date, tm.match_id) AS team_seq
    FROM team_matches AS tm
),
fixture_facts AS (
    SELECT
        s.match_id AS match_id,
        toInt32(countIf(coalesce(s.is_home_goal, 0) = 1 AND coalesce(s.situation, '') IN ('FromCorner', 'FreeKick', 'SetPiece', 'ThrowInSetPiece'))) AS home_set_piece_goals,
        toInt32(countIf(s.is_home_goal = 0 AND coalesce(s.situation, '') IN ('FromCorner', 'FreeKick', 'SetPiece', 'ThrowInSetPiece'))) AS away_set_piece_goals
    FROM fotmob_silver.shot AS s
    WHERE s.match_id > 0
      AND coalesce(s.is_goal, 0) = 1
      AND s.is_home_goal IS NOT NULL
    GROUP BY s.match_id
),
streaks AS (
    SELECT ff.match_id AS match_id, 'home' AS side, ff.home_set_piece_goals + ff.away_set_piece_goals AS set_piece_goals, ff.home_set_piece_goals AS home_set_piece_goals, ff.away_set_piece_goals AS away_set_piece_goals
    FROM fixture_facts AS ff
    WHERE ff.home_set_piece_goals >= 1 AND ff.away_set_piece_goals >= 1
    UNION ALL
    SELECT ff.match_id AS match_id, 'away' AS side, ff.home_set_piece_goals + ff.away_set_piece_goals AS set_piece_goals, ff.home_set_piece_goals AS home_set_piece_goals, ff.away_set_piece_goals AS away_set_piece_goals
    FROM fixture_facts AS ff
    WHERE ff.home_set_piece_goals >= 1 AND ff.away_set_piece_goals >= 1
)
SELECT
    m.match_id AS match_id,
    m.match_date AS match_date,
    m.home_team_id AS home_team_id,
    m.home_team_name AS home_team_name,
    m.away_team_id AS away_team_id,
    m.away_team_name AS away_team_name,
    m.home_score AS home_score,
    m.away_score AS away_score,
    s.side AS triggered_side,
    if(s.side = 'home', m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(s.side = 'home', m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(s.side = 'home', m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(s.side = 'home', m.away_team_name, m.home_team_name) AS opponent_team_name,
    toInt32(1) AS trigger_threshold_min_set_piece_goals_per_side,
    toInt32(s.set_piece_goals) AS match_set_piece_goals,
    toInt32(toInt32(s.set_piece_goals) - 1) AS match_set_piece_goals_above_threshold,
    toInt32(s.home_set_piece_goals) AS home_set_piece_goals,
    toInt32(s.away_set_piece_goals) AS away_set_piece_goals,
    toInt32(coalesce(if(s.side = 'home', m.home_score, m.away_score), 0)) AS triggered_team_goals,
    toInt32(coalesce(if(s.side = 'home', m.away_score, m.home_score), 0)) AS opponent_goals,
    toFloat32(coalesce(if(s.side = 'home', ps.expected_goals_home, ps.expected_goals_away), 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(if(s.side = 'home', ps.expected_goals_away, ps.expected_goals_home), 0.0)) AS opponent_xg,
    toInt32(coalesce(if(s.side = 'home', ps.total_shots_home, ps.total_shots_away), 0)) AS triggered_team_total_shots,
    toInt32(coalesce(if(s.side = 'home', ps.total_shots_away, ps.total_shots_home), 0)) AS opponent_total_shots,
    toInt32(coalesce(if(s.side = 'home', ps.shots_on_target_home, ps.shots_on_target_away), 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(if(s.side = 'home', ps.shots_on_target_away, ps.shots_on_target_home), 0)) AS opponent_shots_on_target,
    toFloat32(coalesce(if(s.side = 'home', ps.ball_possession_home, ps.ball_possession_away), 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(if(s.side = 'home', ps.ball_possession_away, ps.ball_possession_home), 0)) AS opponent_possession_pct
FROM streaks AS s
INNER JOIN fotmob_silver.match AS m
    ON m.match_id = s.match_id
LEFT JOIN fotmob_silver.period_stat AS ps
    ON ps.match_id = s.match_id
   AND ps.period = 'All'
WHERE 1 = 1
  AND m.match_finished = 1
  AND m.match_id > 0
ORDER BY m.match_date, m.match_id, s.side;
