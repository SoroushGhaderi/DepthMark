INSERT INTO fotmob_gold_signals.sig_player_streak_consistency_penalty_specialist (
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
    trigger_threshold_min_consecutive_penalties_scored,
    triggered_player_penalties_scored_streak,
    streak_matches_above_threshold,
    streak_start_date,
    triggered_player_events_in_match,
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
-- Signal: sig_player_streak_consistency_penalty_specialist
-- Intent: Detect penalty takers who never miss.
-- Trigger: Player has scored his last >= 5 penalties in a row (this match included).
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
event_seq AS (
    SELECT
        s.match_id AS match_id, s.match_date AS match_date,
        toInt32(assumeNotNull(s.player_id)) AS event_player_id,
        s.player_name AS event_player_name,
        toInt32(assumeNotNull(s.team_id)) AS event_team_id,
        toInt32(coalesce(s.is_goal, 0) = 1) AS flag,
        row_number() OVER (PARTITION BY s.player_id ORDER BY s.match_date, s.match_id, coalesce(s.minute, 0), s.shot_id) AS event_seq
    FROM fotmob_silver.shot AS s
    WHERE s.match_id > 0
      AND s.player_id IS NOT NULL
      AND s.team_id IS NOT NULL
      AND positionCaseInsensitiveUTF8(coalesce(s.situation, ''), 'penalty') > 0 AND positionCaseInsensitiveUTF8(coalesce(s.period, ''), 'shootout') = 0
),
event_runs AS (
    SELECT
        e.match_id AS match_id, e.match_date AS match_date, e.event_player_id AS event_player_id, e.event_player_name AS event_player_name,
        e.event_team_id AS event_team_id, e.event_seq AS event_seq,
        e.event_seq - row_number() OVER (PARTITION BY e.event_player_id ORDER BY e.event_seq) AS run_key
    FROM event_seq AS e
    WHERE e.flag = 1
),
event_streaks AS (
    SELECT
        er.match_id AS match_id, er.event_player_id AS event_player_id, er.event_player_name AS event_player_name, er.event_team_id AS event_team_id,
        row_number() OVER w AS streak_length,
        min(er.match_date) OVER w AS streak_start_date
    FROM event_runs AS er
    WINDOW w AS (PARTITION BY er.event_player_id, er.run_key ORDER BY er.event_seq)
),
streaks AS (
    SELECT
        es.match_id AS match_id, es.event_player_id AS player_id, any(es.event_player_name) AS player_name, es.event_team_id AS team_id,
        any(tr.side) AS side, max(es.streak_length) AS streak_length, min(es.streak_start_date) AS streak_start_date, count() AS match_events
    FROM event_streaks AS es
    INNER JOIN team_results AS tr
        ON tr.match_id = es.match_id
       AND tr.team_id = es.event_team_id
    GROUP BY es.match_id, es.event_player_id, es.event_team_id
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
    toInt32(5) AS trigger_threshold_min_consecutive_penalties_scored,
    toInt32(s.streak_length) AS triggered_player_penalties_scored_streak,
    toInt32(s.streak_length - 5) AS streak_matches_above_threshold,
    s.streak_start_date AS streak_start_date,
    toInt32(s.match_events) AS triggered_player_events_in_match,
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
WHERE s.streak_length >= 5
  AND m.match_finished = 1
  AND m.match_id > 0
ORDER BY m.match_date, m.match_id, s.player_id;
