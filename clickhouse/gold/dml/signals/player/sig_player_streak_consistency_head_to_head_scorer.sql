INSERT INTO fotmob_gold_signals.sig_player_streak_consistency_head_to_head_scorer (
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
    trigger_threshold_min_consecutive_scoring_meetings_vs_opponent,
    triggered_player_scoring_meetings_streak_vs_opponent,
    streak_matches_above_threshold,
    streak_start_date,
    triggered_player_goals,
    triggered_player_streak_goals,
    triggered_player_streak_shots,
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
-- Signal: sig_player_streak_consistency_head_to_head_scorer
-- Intent: Detect players who always score against one particular opponent.
-- Trigger: Player has scored against this opponent in each of his last >= 4 meetings with it (this match included).
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
meeting_seq AS (
    SELECT
        tr.match_id AS match_id, tr.match_date AS match_date, tr.team_id AS team_id, tr.opponent_id AS opponent_id, tr.side AS side,
        row_number() OVER (PARTITION BY tr.team_id, tr.opponent_id ORDER BY tr.match_date, tr.match_id) AS opp_seq
    FROM team_results AS tr
),
player_meetings AS (
    SELECT
        ms.match_id AS match_id, ms.match_date AS match_date, p.player_id AS player_id, p.player_name AS player_name,
        p.team_id AS team_id, ms.opponent_id AS opponent_id, ms.side AS side, ms.opp_seq AS opp_seq,
        toInt32(coalesce(p.goals, 0)) AS goals, toInt32(coalesce(p.total_shots, 0)) AS shots
    FROM meeting_seq AS ms
    INNER JOIN fotmob_silver.player_match_stat AS p
        ON p.match_id = ms.match_id
       AND p.team_id = ms.team_id
    WHERE p.player_id > 0
      AND coalesce(p.minutes_played, 0) > 0
),
runs AS (
    SELECT
        pm.match_id AS match_id, pm.match_date AS match_date, pm.player_id AS player_id, pm.player_name AS player_name,
        pm.team_id AS team_id, pm.opponent_id AS opponent_id, pm.side AS side, pm.opp_seq AS opp_seq,
        pm.goals AS goals, pm.shots AS shots,
        pm.opp_seq - row_number() OVER (PARTITION BY pm.player_id, pm.team_id, pm.opponent_id ORDER BY pm.opp_seq) AS run_key
    FROM player_meetings AS pm
    WHERE pm.goals >= 1
),
streaks AS (
    SELECT
        r.match_id AS match_id, r.player_id AS player_id, r.player_name AS player_name, r.team_id AS team_id, r.side AS side,
        row_number() OVER w AS streak_length,
        min(r.match_date) OVER w AS streak_start_date,
        r.goals AS match_goals,
        sum(r.goals) OVER w AS streak_goals,
        sum(r.shots) OVER w AS streak_shots
    FROM runs AS r
    WINDOW w AS (PARTITION BY r.player_id, r.team_id, r.opponent_id, r.run_key ORDER BY r.opp_seq)
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
    toInt32(4) AS trigger_threshold_min_consecutive_scoring_meetings_vs_opponent,
    toInt32(s.streak_length) AS triggered_player_scoring_meetings_streak_vs_opponent,
    toInt32(s.streak_length - 4) AS streak_matches_above_threshold,
    s.streak_start_date AS streak_start_date,
    toInt32(s.match_goals) AS triggered_player_goals,
    toInt32(s.streak_goals) AS triggered_player_streak_goals,
    toInt32(s.streak_shots) AS triggered_player_streak_shots,
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
WHERE s.streak_length >= 4
  AND m.match_finished = 1
  AND m.match_id > 0
ORDER BY m.match_date, m.match_id, s.player_id;
