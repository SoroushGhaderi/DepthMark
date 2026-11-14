INSERT INTO fotmob_gold_signals.sig_team_creativity_playmaking_long_ball_efficiency (
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
    trigger_threshold_min_long_ball_accuracy_pct,
    triggered_team_long_ball_accuracy_pct,
    triggered_team_long_ball_accuracy_pct_above_threshold,
    triggered_team_long_ball_attempts,
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
-- Signal: sig_team_creativity_playmaking_long_ball_efficiency
-- Intent: Find teams whose direct passing is accurate.
-- Trigger: Team completes more than 60% of its long balls with at least 20 attempts in a finished match.
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
team_player_facts AS (
    SELECT
        p.match_id AS match_id,
        toInt32(assumeNotNull(p.team_id)) AS fact_team_id,
        toFloat64(sum(coalesce(p.expected_assists, 0))) AS xa_sum,
        toFloat64(max(coalesce(p.expected_assists, 0))) AS xa_max,
        toInt32(sum(coalesce(p.chances_created, 0))) AS key_passes,
        toInt32(countIf(coalesce(p.expected_assists, 0) >= 0.5)) AS players_xa_half
    FROM fotmob_silver.player_match_stat AS p
    WHERE p.match_id > 0
      AND p.team_id IS NOT NULL
      AND coalesce(p.minutes_played, 0) > 0
    GROUP BY p.match_id, fact_team_id
),
shooters AS (
    SELECT
        s.match_id AS match_id,
        toInt32(assumeNotNull(s.team_id)) AS shooter_team_id,
        toInt32(count(DISTINCT s.player_id)) AS distinct_shooters
    FROM fotmob_silver.shot AS s
    WHERE s.match_id > 0
      AND s.team_id IS NOT NULL
      AND s.player_id IS NOT NULL
      AND coalesce(s.is_own_goal, 0) = 0
    GROUP BY s.match_id, shooter_team_id
),
streaks AS (
    SELECT
        tr.match_id AS match_id, tr.team_id AS team_id, tr.side AS side, toFloat64(round(100.0 * toInt32(coalesce(if(tr.side = 'home', pst.accurate_long_balls_home, pst.accurate_long_balls_away), 0)) / greatest(toInt32(coalesce(if(tr.side = 'home', pst.long_ball_attempts_home, pst.long_ball_attempts_away), 0)), 1), 1)) AS long_ball_pct, toInt32(coalesce(if(tr.side = 'home', pst.long_ball_attempts_home, pst.long_ball_attempts_away), 0)) AS long_ball_attempts
    FROM team_results AS tr
    LEFT JOIN team_player_facts AS f
        ON f.match_id = tr.match_id
       AND f.fact_team_id = tr.team_id
    LEFT JOIN team_player_facts AS fo
        ON fo.match_id = tr.match_id
       AND fo.fact_team_id = tr.opponent_id
    LEFT JOIN shooters AS sh
        ON sh.match_id = tr.match_id
       AND sh.shooter_team_id = tr.team_id
    INNER JOIN fotmob_silver.period_stat AS pst
        ON pst.match_id = tr.match_id
       AND pst.period = 'All'
    WHERE toInt32(coalesce(if(tr.side = 'home', pst.long_ball_attempts_home, pst.long_ball_attempts_away), 0)) >= 20 AND 100.0 * toInt32(coalesce(if(tr.side = 'home', pst.accurate_long_balls_home, pst.accurate_long_balls_away), 0)) / toInt32(coalesce(if(tr.side = 'home', pst.long_ball_attempts_home, pst.long_ball_attempts_away), 0)) > 60
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
    toFloat64(60) AS trigger_threshold_min_long_ball_accuracy_pct,
    s.long_ball_pct AS triggered_team_long_ball_accuracy_pct,
    toFloat64(s.long_ball_pct - 60) AS triggered_team_long_ball_accuracy_pct_above_threshold,
    toInt32(s.long_ball_attempts) AS triggered_team_long_ball_attempts,
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
