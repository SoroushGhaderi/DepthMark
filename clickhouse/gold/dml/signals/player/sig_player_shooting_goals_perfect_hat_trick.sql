INSERT INTO fotmob_gold_signals.sig_player_shooting_goals_perfect_hat_trick (
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
    trigger_threshold_min_goal_body_part_kinds,
    triggered_player_goal_body_part_kinds,
    triggered_player_goal_body_part_kinds_above_threshold,
    triggered_player_left_foot_goals,
    triggered_player_right_foot_goals,
    triggered_player_header_goals,
    triggered_player_shots,
    triggered_player_goals,
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
-- Signal: sig_player_shooting_goals_perfect_hat_trick
-- Intent: Find players who score with every body part in one match.
-- Trigger: Player scores with his left foot, his right foot and his head in the same finished match.
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
player_shots AS (
    SELECT
        s.match_id AS match_id,
        toInt32(assumeNotNull(s.player_id)) AS shooter_id,
        toInt32(assumeNotNull(s.team_id)) AS shooter_team_id,
        any(s.player_name) AS shooter_name,
        toInt32(count()) AS shots,
        toInt32(countIf(coalesce(s.is_goal, 0) = 1)) AS goals,
        toInt32(countIf(coalesce(s.is_goal, 0) = 1 AND positionCaseInsensitiveUTF8(coalesce(s.shot_type, ''), 'left') > 0)) AS left_goals,
        toInt32(countIf(coalesce(s.is_goal, 0) = 1 AND positionCaseInsensitiveUTF8(coalesce(s.shot_type, ''), 'right') > 0)) AS right_goals,
        toInt32(countIf(coalesce(s.is_goal, 0) = 1 AND positionCaseInsensitiveUTF8(coalesce(s.shot_type, ''), 'header') > 0)) AS header_goals
    FROM fotmob_silver.shot AS s
    WHERE s.match_id > 0
      AND s.player_id IS NOT NULL
      AND s.team_id IS NOT NULL
      AND coalesce(s.is_own_goal, 0) = 0
    GROUP BY s.match_id, shooter_id, shooter_team_id
),
streaks AS (
    SELECT
        ps.match_id AS match_id, ps.shooter_id AS player_id, ps.shooter_name AS player_name, ps.shooter_team_id AS team_id, tr.side AS side,
        ps.shots AS shots, ps.goals AS goals, ps.left_goals AS left_goals, ps.right_goals AS right_goals, ps.header_goals AS header_goals
    FROM player_shots AS ps
    INNER JOIN team_results AS tr
        ON tr.match_id = ps.match_id
       AND tr.team_id = ps.shooter_team_id
    WHERE ps.left_goals >= 1 AND ps.right_goals >= 1 AND ps.header_goals >= 1
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
    s.player_id AS triggered_player_id,
    s.player_name AS triggered_player_name,
    s.team_id AS triggered_team_id,
    if(s.side = 'home', m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(s.side = 'home', m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(s.side = 'home', m.away_team_name, m.home_team_name) AS opponent_team_name,
    toInt32(3) AS trigger_threshold_min_goal_body_part_kinds,
    toInt32(toUInt8(s.left_goals >= 1) + toUInt8(s.right_goals >= 1) + toUInt8(s.header_goals >= 1)) AS triggered_player_goal_body_part_kinds,
    toInt32(toInt32(toUInt8(s.left_goals >= 1) + toUInt8(s.right_goals >= 1) + toUInt8(s.header_goals >= 1)) - 3) AS triggered_player_goal_body_part_kinds_above_threshold,
    toInt32(s.left_goals) AS triggered_player_left_foot_goals,
    toInt32(s.right_goals) AS triggered_player_right_foot_goals,
    toInt32(s.header_goals) AS triggered_player_header_goals,
    toInt32(s.shots) AS triggered_player_shots,
    toInt32(s.goals) AS triggered_player_goals,
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
ORDER BY m.match_date, m.match_id, s.player_id;
