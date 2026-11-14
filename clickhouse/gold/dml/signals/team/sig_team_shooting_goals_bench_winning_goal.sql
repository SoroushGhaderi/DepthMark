INSERT INTO fotmob_gold_signals.sig_team_shooting_goals_bench_winning_goal (
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
    trigger_threshold_min_winning_goal_minute,
    triggered_team_winning_goal_minute,
    triggered_team_winning_goal_minute_above_threshold,
    triggered_team_winning_scorer_id,
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
-- Signal: sig_team_shooting_goals_bench_winning_goal
-- Intent: Find wins decided by a late goal from the bench.
-- Trigger: A substitute scores the winning goal after minute 80 in a one-goal win.
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
final_goal AS (
    SELECT
        g.match_id AS match_id, g.last_player AS last_player, g.last_side AS last_side, g.last_time AS last_time
    FROM (
        SELECT
            s.match_id AS match_id,
            toInt32(argMax(coalesce(s.player_id, 0), coalesce(s.home_score_after, 0) + coalesce(s.away_score_after, 0))) AS last_player,
            if(argMax(coalesce(s.is_home_goal, 0), coalesce(s.home_score_after, 0) + coalesce(s.away_score_after, 0)) = 1, 'home', 'away') AS last_side,
            toInt32(argMax(coalesce(s.goal_time, 0), coalesce(s.home_score_after, 0) + coalesce(s.away_score_after, 0))) AS last_time,
            toInt32(max(coalesce(s.home_score_after, 0) + coalesce(s.away_score_after, 0))) AS last_total
        FROM fotmob_silver.shot AS s
        WHERE s.match_id > 0
          AND coalesce(s.is_goal, 0) = 1
          AND coalesce(s.is_own_goal, 0) = 0
          AND s.is_home_goal IS NOT NULL
          AND coalesce(s.goal_time, 0) > 0
        GROUP BY s.match_id
    ) AS g
    INNER JOIN fotmob_silver.match AS mm
        ON mm.match_id = g.match_id
    WHERE g.last_total = coalesce(mm.home_score, 0) + coalesce(mm.away_score, 0)
      AND abs(coalesce(mm.home_score, 0) - coalesce(mm.away_score, 0)) = 1
),
subs AS (
    SELECT DISTINCT mp.match_id AS match_id, toInt32(mp.person_id) AS sub_person_id
    FROM fotmob_silver.match_personnel AS mp
    WHERE mp.role = 'substitute'
),
streaks AS (
    SELECT tr.match_id AS match_id, tr.team_id AS team_id, tr.side AS side, fg.last_time AS winner_minute, fg.last_player AS winner_player_id
    FROM team_results AS tr
    INNER JOIN final_goal AS fg
        ON fg.match_id = tr.match_id
       AND fg.last_side = tr.side
    INNER JOIN subs AS sb
        ON sb.match_id = fg.match_id
       AND sb.sub_person_id = fg.last_player
    WHERE fg.last_time > 80
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
    toInt32(80) AS trigger_threshold_min_winning_goal_minute,
    toInt32(s.winner_minute) AS triggered_team_winning_goal_minute,
    toInt32(toInt32(s.winner_minute) - 80) AS triggered_team_winning_goal_minute_above_threshold,
    toInt32(s.winner_player_id) AS triggered_team_winning_scorer_id,
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
