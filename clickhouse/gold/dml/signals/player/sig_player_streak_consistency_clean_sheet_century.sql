INSERT INTO fotmob_gold_signals.sig_player_streak_consistency_clean_sheet_century (
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
    trigger_threshold_min_clean_sheet_minutes,
    triggered_player_clean_sheet_streak_minutes,
    streak_minutes_above_threshold,
    triggered_player_clean_sheet_streak_appearances,
    streak_start_date,
    triggered_player_minutes_played,
    triggered_player_saves,
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
-- Signal: sig_player_streak_consistency_clean_sheet_century
-- Intent: Detect goalkeepers with a long unbeaten-goal run.
-- Trigger: Goalkeeper has played >= 450 minutes across consecutive appearances without his team conceding (this match included).
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
gk_rows AS (
    SELECT
        p.match_id AS match_id, p.match_date AS match_date, p.player_id AS player_id, p.player_name AS player_name,
        p.team_id AS team_id, tr.side AS side, tr.goals_against AS goals_against,
        toInt32(coalesce(p.minutes_played, 0)) AS minutes_played,
        row_number() OVER (PARTITION BY p.player_id ORDER BY p.match_date, p.match_id) AS appearance_seq
    FROM fotmob_silver.player_match_stat AS p
    INNER JOIN team_results AS tr
        ON tr.match_id = p.match_id
       AND tr.team_id = p.team_id
    WHERE p.player_id > 0
      AND p.is_goalkeeper = 1
      AND coalesce(p.minutes_played, 0) > 0
),
runs AS (
    SELECT
        g.match_id AS match_id, g.match_date AS match_date, g.player_id AS player_id, g.player_name AS player_name,
        g.team_id AS team_id, g.side AS side, g.minutes_played AS minutes_played, g.appearance_seq AS appearance_seq,
        g.appearance_seq - row_number() OVER (PARTITION BY g.player_id ORDER BY g.appearance_seq) AS run_key
    FROM gk_rows AS g
    WHERE g.goals_against = 0
),
saves AS (
    SELECT
        sh.match_id AS match_id,
        toInt32(assumeNotNull(sh.keeper_id)) AS player_id,
        countIf(coalesce(sh.is_on_target, 0) = 1 AND coalesce(sh.is_goal, 0) = 0 AND coalesce(sh.is_saved_off_line, 0) = 0) AS saves
    FROM fotmob_silver.shot AS sh
    WHERE sh.match_id > 0
      AND coalesce(sh.keeper_id, 0) > 0
    GROUP BY sh.match_id, player_id
),
streaks AS (
    SELECT
        r.match_id AS match_id, r.player_id AS player_id, r.player_name AS player_name, r.team_id AS team_id, r.side AS side,
        row_number() OVER w AS streak_length,
        min(r.match_date) OVER w AS streak_start_date,
        sum(r.minutes_played) OVER w AS streak_minutes,
        r.minutes_played AS match_minutes,
        coalesce(sv.saves, 0) AS match_saves
    FROM runs AS r
    LEFT JOIN saves AS sv
        ON sv.match_id = r.match_id
       AND sv.player_id = r.player_id
    WINDOW w AS (PARTITION BY r.player_id, r.run_key ORDER BY r.appearance_seq)
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
    toInt32(450) AS trigger_threshold_min_clean_sheet_minutes,
    toInt32(s.streak_minutes) AS triggered_player_clean_sheet_streak_minutes,
    toInt32(s.streak_minutes - 450) AS streak_minutes_above_threshold,
    toInt32(s.streak_length) AS triggered_player_clean_sheet_streak_appearances,
    s.streak_start_date AS streak_start_date,
    toInt32(s.match_minutes) AS triggered_player_minutes_played,
    toInt32(s.match_saves) AS triggered_player_saves,
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
WHERE s.streak_minutes >= 450
  AND m.match_finished = 1
  AND m.match_id > 0
ORDER BY m.match_date, m.match_id, s.player_id;
