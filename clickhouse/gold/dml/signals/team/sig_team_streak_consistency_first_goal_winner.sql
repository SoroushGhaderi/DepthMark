INSERT INTO fotmob_gold_signals.sig_team_streak_consistency_first_goal_winner (
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
    trigger_threshold_min_first_goal_wins,
    triggered_team_first_goal_win_streak_matches,
    streak_matches_above_threshold,
    streak_start_date,
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
-- Signal: sig_team_streak_consistency_first_goal_winner
-- Intent: Detect teams that always convert an opening goal into a win.
-- Trigger: Team has won its last >= 10 matches in which it scored first (this match included).
WITH first_goals AS (
    SELECT
        sh.match_id AS match_id,
        any(if(coalesce(sh.home_score_after, 0) = 1, 'home', 'away')) AS first_scorer_side
    FROM fotmob_silver.shot AS sh
    WHERE sh.match_id > 0
      AND coalesce(sh.is_goal, 0) = 1
      AND coalesce(sh.home_score_after, 0) + coalesce(sh.away_score_after, 0) = 1
    GROUP BY sh.match_id
),
scored_first AS (
    SELECT
        tr.match_id AS match_id, tr.match_date AS match_date, tr.team_id AS team_id, tr.side AS side,
        tr.goals_for AS goals_for, tr.goals_against AS goals_against,
        row_number() OVER (PARTITION BY tr.team_id ORDER BY tr.match_date, tr.match_id) AS first_goal_seq
    FROM team_results AS tr
    INNER JOIN first_goals AS fg
        ON fg.match_id = tr.match_id
       AND fg.first_scorer_side = tr.side
),
win_runs AS (
    SELECT
        sf.match_id AS match_id, sf.match_date AS match_date, sf.team_id AS team_id, sf.side AS side,
        sf.goals_for AS goals_for, sf.goals_against AS goals_against, sf.first_goal_seq AS first_goal_seq,
        sf.first_goal_seq - row_number() OVER (PARTITION BY sf.team_id ORDER BY sf.first_goal_seq) AS run_key
    FROM scored_first AS sf
    WHERE sf.goals_for > sf.goals_against
),
streaks AS (
    SELECT
        wr.match_id AS match_id, wr.team_id AS team_id, wr.side AS side,
        row_number() OVER w AS streak_length,
        min(wr.match_date) OVER w AS streak_start_date,
        sum(wr.goals_for) OVER w AS streak_goals_scored,
        sum(wr.goals_against) OVER w AS streak_goals_conceded
    FROM win_runs AS wr
    WINDOW w AS (PARTITION BY wr.team_id, wr.run_key ORDER BY wr.first_goal_seq)
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
    toInt32(10) AS trigger_threshold_min_first_goal_wins,
    toInt32(s.streak_length) AS triggered_team_first_goal_win_streak_matches,
    toInt32(s.streak_length - 10) AS streak_matches_above_threshold,
    s.streak_start_date AS streak_start_date,
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
WHERE s.streak_length >= 10
  AND m.match_finished = 1
  AND m.match_id > 0
ORDER BY m.match_date, m.match_id, s.side;
