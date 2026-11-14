INSERT INTO fotmob_gold_signals.sig_team_streak_consistency_goal_sharing (
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
    trigger_threshold_min_distinct_scorers,
    triggered_team_window_distinct_scorers,
    streak_matches_above_threshold,
    streak_start_date,
    triggered_team_streak_wins,
    triggered_team_streak_draws,
    triggered_team_streak_goals_scored,
    triggered_team_streak_goals_conceded,
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
-- Signal: sig_team_streak_consistency_goal_sharing
-- Intent: Detect teams whose goals come from many different players.
-- Trigger: Team has >= 5 different goalscorers across its last 3 consecutive matches (this match included).
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
scorers AS (
    SELECT DISTINCT
        sh.match_id AS match_id,
        toInt32(assumeNotNull(sh.team_id)) AS scorer_team_id,
        toInt32(assumeNotNull(sh.player_id)) AS scorer_id
    FROM fotmob_silver.shot AS sh
    WHERE sh.match_id > 0
      AND coalesce(sh.is_goal, 0) = 1
      AND coalesce(sh.is_own_goal, 0) = 0
      AND sh.team_id IS NOT NULL
      AND sh.player_id IS NOT NULL
),
people_window AS (
    SELECT
        tr.match_id AS match_id, tr.team_id AS team_id,
        toInt32(count(DISTINCT tr2.match_id)) AS window_matches,
        toInt32(count(DISTINCT if(src.scorer_id > 0, src.scorer_id, NULL))) AS distinct_people
    FROM team_results AS tr
    INNER JOIN team_results AS tr2
        ON tr2.team_id = tr.team_id
       AND tr2.team_seq BETWEEN tr.team_seq - 2 AND tr.team_seq
    LEFT JOIN scorers AS src
        ON src.match_id = tr2.match_id
       AND src.scorer_team_id = tr.team_id
    GROUP BY tr.match_id, tr.team_id
),
streaks AS (
    SELECT
        tr.match_id AS match_id, tr.team_id AS team_id, tr.side AS side,
        pw.distinct_people AS streak_length,
        pw.window_matches AS window_matches,
        min(tr.match_date) OVER w AS streak_start_date,
        sum(toUInt8(tr.goals_for > tr.goals_against)) OVER w AS streak_wins,
        sum(toUInt8(tr.goals_for = tr.goals_against)) OVER w AS streak_draws,
        sum(tr.goals_for) OVER w AS streak_goals_scored,
        sum(tr.goals_against) OVER w AS streak_goals_conceded
    FROM team_results AS tr
    INNER JOIN people_window AS pw
        ON pw.match_id = tr.match_id
       AND pw.team_id = tr.team_id
    WINDOW w AS (PARTITION BY tr.team_id ORDER BY tr.team_seq ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
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
    toInt32(5) AS trigger_threshold_min_distinct_scorers,
    toInt32(s.streak_length) AS triggered_team_window_distinct_scorers,
    toInt32(s.streak_length - 5) AS streak_matches_above_threshold,
    s.streak_start_date AS streak_start_date,
    toInt32(s.streak_wins) AS triggered_team_streak_wins,
    toInt32(s.streak_draws) AS triggered_team_streak_draws,
    toInt32(s.streak_goals_scored) AS triggered_team_streak_goals_scored,
    toInt32(s.streak_goals_conceded) AS triggered_team_streak_goals_conceded,
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
WHERE s.window_matches = 3 AND s.streak_length >= 5
  AND m.match_finished = 1
  AND m.match_id > 0
ORDER BY m.match_date, m.match_id, s.side;
