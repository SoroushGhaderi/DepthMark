INSERT INTO fotmob_gold_signals.sig_match_streak_consistency_manager_duel_streak (
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
    trigger_threshold_min_consecutive_manager_wins,
    triggered_manager_win_streak_meetings,
    streak_matches_above_threshold,
    streak_start_date,
    triggered_team_streak_wins,
    triggered_team_streak_draws,
    triggered_team_streak_goals_scored,
    triggered_team_streak_goals_conceded,
    triggered_manager_id,
    opponent_manager_id,
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
-- Signal: sig_match_streak_consistency_manager_duel_streak
-- Intent: Detect managers who keep beating the same rival.
-- Trigger: The triggered side's manager has beaten the opposing manager in >= 4 consecutive meetings (this match included).
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
managers AS (
    SELECT
        mp.match_id AS match_id,
        mp.team_side AS team_side,
        min(toInt64(mp.person_id)) AS manager_id
    FROM fotmob_silver.match_personnel AS mp
    WHERE mp.role = 'coach'
    GROUP BY mp.match_id, mp.team_side
),
meeting_results AS (
    SELECT
        tr.match_id AS match_id, tr.match_date AS match_date, tr.team_id AS team_id, tr.opponent_id AS opponent_id, tr.side AS side,
        tr.goals_for AS goals_for, tr.goals_against AS goals_against,
        mg.manager_id AS manager_id, mo.manager_id AS opponent_manager_id,
        row_number() OVER (PARTITION BY mg.manager_id, mo.manager_id ORDER BY tr.match_date, tr.match_id) AS meeting_seq
    FROM team_results AS tr
    INNER JOIN managers AS mg
        ON mg.match_id = tr.match_id
       AND mg.team_side = tr.side
    INNER JOIN managers AS mo
        ON mo.match_id = tr.match_id
       AND mo.team_side = if(tr.side = 'home', 'away', 'home')
),
runs AS (
    SELECT
        mr.match_id AS match_id, mr.match_date AS match_date, mr.team_id AS team_id, mr.opponent_id AS opponent_id, mr.side AS side,
        mr.goals_for AS goals_for, mr.goals_against AS goals_against, mr.meeting_seq AS meeting_seq,
        mr.manager_id AS manager_id,
        mr.opponent_manager_id AS opponent_manager_id,
        mr.meeting_seq - row_number() OVER (PARTITION BY mr.manager_id, mr.opponent_manager_id ORDER BY mr.meeting_seq) AS run_key
    FROM meeting_results AS mr
    WHERE mr.goals_for > mr.goals_against
),
streaks AS (
    SELECT
        r.match_id AS match_id, r.team_id AS team_id, r.side AS side,
        r.manager_id AS manager_id,
        r.opponent_manager_id AS opponent_manager_id,
        row_number() OVER w AS streak_length,
        min(r.match_date) OVER w AS streak_start_date,
        sum(toUInt8(r.goals_for > r.goals_against)) OVER w AS streak_wins,
        sum(toUInt8(r.goals_for = r.goals_against)) OVER w AS streak_draws,
        sum(r.goals_for) OVER w AS streak_goals_scored,
        sum(r.goals_against) OVER w AS streak_goals_conceded
    FROM runs AS r
    WINDOW w AS (PARTITION BY r.manager_id, r.opponent_manager_id, r.run_key ORDER BY r.meeting_seq)
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
    toInt32(4) AS trigger_threshold_min_consecutive_manager_wins,
    toInt32(s.streak_length) AS triggered_manager_win_streak_meetings,
    toInt32(s.streak_length - 4) AS streak_matches_above_threshold,
    s.streak_start_date AS streak_start_date,
    toInt32(s.streak_wins) AS triggered_team_streak_wins,
    toInt32(s.streak_draws) AS triggered_team_streak_draws,
    toInt32(s.streak_goals_scored) AS triggered_team_streak_goals_scored,
    toInt32(s.streak_goals_conceded) AS triggered_team_streak_goals_conceded,
    s.manager_id AS triggered_manager_id,
    s.opponent_manager_id AS opponent_manager_id,
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
ORDER BY m.match_date, m.match_id, s.side;
