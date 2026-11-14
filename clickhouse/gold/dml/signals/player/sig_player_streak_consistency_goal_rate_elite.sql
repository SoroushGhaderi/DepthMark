INSERT INTO fotmob_gold_signals.sig_player_streak_consistency_goal_rate_elite (
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
    trigger_threshold_min_window_goals_per_90,
    triggered_player_window_goals_per_90,
    streak_matches_above_threshold,
    streak_start_date,
    triggered_player_window_goals,
    triggered_player_window_minutes,
    triggered_player_goals,
    triggered_player_minutes_played,
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
-- Signal: sig_player_streak_consistency_goal_rate_elite
-- Intent: Detect players scoring at an elite rate.
-- Trigger: Player averages more than 1.0 goals per 90 minutes over his last 5 consecutive team matches (this match included).
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
card_counts AS (
    SELECT
        c.match_id AS match_id,
        toInt32(assumeNotNull(c.player_id)) AS player_id,
        count() AS cards
    FROM fotmob_silver.card AS c
    WHERE c.match_id > 0
      AND c.player_id IS NOT NULL
      AND c.player_id > 0
    GROUP BY c.match_id, player_id
),
player_rows AS (
    SELECT
        p.match_id AS match_id, p.match_date AS match_date, p.player_id AS player_id, p.player_name AS player_name,
        p.team_id AS team_id, tr.side AS side, tr.team_seq AS team_seq,
        row_number() OVER (PARTITION BY p.player_id ORDER BY p.match_date, p.match_id) AS app_seq,
        toInt32(coalesce(p.total_shots, 0)) AS shots,
        toInt32(coalesce(p.shots_on_target, 0)) AS shots_on_target,
        toInt32(coalesce(p.successful_dribbles, 0)) AS dribbles,
        toInt32(coalesce(p.tackles_won, 0)) AS tackles,
        toInt32(coalesce(p.was_fouled, 0)) AS times_fouled,
        toInt32(coalesce(p.fouls_committed, 0)) AS fouls,
        toInt32(coalesce(p.chances_created, 0)) AS key_passes,
        toInt32(coalesce(p.goals, 0)) AS goals,
        toInt32(coalesce(p.minutes_played, 0)) AS minutes,
        toInt32(coalesce(cc.cards, 0)) AS cards,
        toInt32(coalesce(p.assists, 0)) AS assists,
        toInt32(toInt32(round(coalesce(p.expected_assists, 0) * 1000))) AS xa_milli,
        toInt32(coalesce(p.recoveries, 0)) AS recoveries,
        toInt32(coalesce(p.interceptions, 0)) AS interceptions
    FROM fotmob_silver.player_match_stat AS p
    INNER JOIN team_results AS tr
        ON tr.match_id = p.match_id
       AND tr.team_id = p.team_id
    LEFT JOIN card_counts AS cc
        ON cc.match_id = p.match_id
       AND cc.player_id = p.player_id
    WHERE p.player_id > 0
      AND coalesce(p.minutes_played, 0) > 0
),
streaks AS (
    SELECT
        pr.match_id AS match_id, pr.player_id AS player_id, pr.player_name AS player_name, pr.team_id AS team_id, pr.side AS side,
        count() OVER w AS window_rows,
        min(pr.match_date) OVER w AS streak_start_date,
        pr.minutes AS match_minutes,
        sum(pr.goals) OVER w AS window_goals,
        sum(pr.minutes) OVER w AS window_minutes,
        pr.goals AS match_goals
    FROM player_rows AS pr
    WINDOW w AS (PARTITION BY pr.player_id, pr.team_id ORDER BY pr.team_seq RANGE BETWEEN 4 PRECEDING AND CURRENT ROW)
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
    toFloat64(1.0) AS trigger_threshold_min_window_goals_per_90,
    toFloat64(round(s.window_goals * 90.0 / s.window_minutes, 2)) AS triggered_player_window_goals_per_90,
    toFloat64(round(s.window_goals * 90.0 / s.window_minutes - 1.0, 2)) AS streak_matches_above_threshold,
    s.streak_start_date AS streak_start_date,
    toInt32(s.window_goals) AS triggered_player_window_goals,
    toInt32(s.window_minutes) AS triggered_player_window_minutes,
    toInt32(s.match_goals) AS triggered_player_goals,
    toInt32(s.match_minutes) AS triggered_player_minutes_played,
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
WHERE s.window_rows = 5 AND s.window_minutes > 0 AND s.window_goals * 90.0 / s.window_minutes > 1.0
  AND m.match_finished = 1
  AND m.match_id > 0
ORDER BY m.match_date, m.match_id, s.player_id;
