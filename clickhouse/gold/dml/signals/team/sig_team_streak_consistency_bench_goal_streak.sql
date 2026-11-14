INSERT INTO fotmob_gold_signals.sig_team_streak_consistency_bench_goal_streak (
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
    trigger_threshold_min_consecutive_bench_goal_matches,
    triggered_team_bench_goal_streak_matches,
    streak_matches_above_threshold,
    streak_start_date,
    triggered_team_streak_wins,
    triggered_team_streak_draws,
    triggered_team_streak_goals_scored,
    triggered_team_streak_goals_conceded,
    triggered_team_streak_bench_goals,
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
-- Signal: sig_team_streak_consistency_bench_goal_streak
-- Intent: Detect teams whose bench keeps deciding matches.
-- Trigger: A substitute scores for the team in >= 3 consecutive matches (this match included).
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
subs AS (
    SELECT DISTINCT
        mp.match_id AS match_id,
        toInt32(mp.person_id) AS sub_person_id
    FROM fotmob_silver.match_personnel AS mp
    WHERE mp.role = 'substitute'
),
bench_goals AS (
    SELECT
        sh.match_id AS match_id,
        toInt32(assumeNotNull(sh.team_id)) AS bench_team_id,
        toInt32(count()) AS sub_goals
    FROM fotmob_silver.shot AS sh
    INNER JOIN subs AS sb
        ON sb.match_id = sh.match_id
       AND sb.sub_person_id = sh.player_id
    WHERE sh.match_id > 0
      AND coalesce(sh.is_goal, 0) = 1
      AND coalesce(sh.is_own_goal, 0) = 0
      AND sh.team_id IS NOT NULL
      AND sh.player_id IS NOT NULL
    GROUP BY sh.match_id, bench_team_id
),
sub_results AS (
    SELECT
        tr.match_id AS match_id, tr.match_date AS match_date, tr.team_id AS team_id, tr.side AS side,
        tr.goals_for AS goals_for, tr.goals_against AS goals_against, tr.team_seq AS team_seq,
        coalesce(bg.sub_goals, 0) AS sub_goals
    FROM team_results AS tr
    LEFT JOIN bench_goals AS bg
        ON bg.match_id = tr.match_id
       AND bg.bench_team_id = tr.team_id
),
runs AS (
    SELECT
        x.match_id AS match_id, x.match_date AS match_date, x.team_id AS team_id, x.side AS side,
        x.goals_for AS goals_for, x.goals_against AS goals_against, x.team_seq AS team_seq, x.sub_goals AS metric_value,
        x.team_seq - row_number() OVER (PARTITION BY x.team_id ORDER BY x.team_seq) AS run_key
    FROM sub_results AS x
    WHERE x.sub_goals >= 1
),
streaks AS (
    SELECT
        r.match_id AS match_id, r.team_id AS team_id, r.side AS side,
        row_number() OVER w AS streak_length,
        min(r.match_date) OVER w AS streak_start_date,
        sum(toUInt8(r.goals_for > r.goals_against)) OVER w AS streak_wins,
        sum(toUInt8(r.goals_for = r.goals_against)) OVER w AS streak_draws,
        sum(r.goals_for) OVER w AS streak_goals_scored,
        sum(r.goals_against) OVER w AS streak_goals_conceded,
        sum(r.metric_value) OVER w AS streak_metric
    FROM runs AS r
    WINDOW w AS (PARTITION BY r.team_id, r.run_key ORDER BY r.team_seq)
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
    toInt32(3) AS trigger_threshold_min_consecutive_bench_goal_matches,
    toInt32(s.streak_length) AS triggered_team_bench_goal_streak_matches,
    toInt32(s.streak_length - 3) AS streak_matches_above_threshold,
    s.streak_start_date AS streak_start_date,
    toInt32(s.streak_wins) AS triggered_team_streak_wins,
    toInt32(s.streak_draws) AS triggered_team_streak_draws,
    toInt32(s.streak_goals_scored) AS triggered_team_streak_goals_scored,
    toInt32(s.streak_goals_conceded) AS triggered_team_streak_goals_conceded,
    toInt32(s.streak_metric) AS triggered_team_streak_bench_goals,
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
WHERE s.streak_length >= 3
  AND m.match_finished = 1
  AND m.match_id > 0
ORDER BY m.match_date, m.match_id, s.side;
