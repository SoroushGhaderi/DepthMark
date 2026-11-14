INSERT INTO fotmob_gold_signals.sig_match_streak_consistency_bogey_team (
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
    trigger_threshold_min_winless_meetings,
    triggered_team_winless_meetings_streak,
    streak_matches_above_threshold,
    streak_start_date,
    triggered_team_streak_draws,
    triggered_team_streak_defeats,
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
-- Signal: sig_match_streak_consistency_bogey_team
-- Intent: Detect one-sided head-to-head droughts.
-- Trigger: Triggered team has not beaten the opponent in >= 8 consecutive meetings (this match included).
WITH meeting_results AS (
    SELECT
        tr.match_id AS match_id, tr.match_date AS match_date, tr.team_id AS team_id, tr.opponent_id AS opponent_id, tr.side AS side,
        tr.goals_for AS goals_for, tr.goals_against AS goals_against,
        row_number() OVER (PARTITION BY tr.team_id, tr.opponent_id ORDER BY tr.match_date, tr.match_id) AS meeting_seq
    FROM team_results AS tr
),
winless_runs AS (
    SELECT
        mr.match_id AS match_id, mr.match_date AS match_date, mr.team_id AS team_id, mr.opponent_id AS opponent_id, mr.side AS side,
        mr.goals_for AS goals_for, mr.goals_against AS goals_against, mr.meeting_seq AS meeting_seq,
        mr.meeting_seq - row_number() OVER (PARTITION BY mr.team_id, mr.opponent_id ORDER BY mr.meeting_seq) AS run_key
    FROM meeting_results AS mr
    WHERE mr.goals_for <= mr.goals_against
),
streaks AS (
    SELECT
        wl.match_id AS match_id, wl.team_id AS team_id, wl.side AS side,
        row_number() OVER w AS streak_length,
        min(wl.match_date) OVER w AS streak_start_date,
        sum(toUInt8(wl.goals_for = wl.goals_against)) OVER w AS streak_draws,
        sum(toUInt8(wl.goals_for < wl.goals_against)) OVER w AS streak_defeats,
        sum(wl.goals_for) OVER w AS streak_goals_scored,
        sum(wl.goals_against) OVER w AS streak_goals_conceded
    FROM winless_runs AS wl
    WINDOW w AS (PARTITION BY wl.team_id, wl.opponent_id, wl.run_key ORDER BY wl.meeting_seq)
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
    toInt32(8) AS trigger_threshold_min_winless_meetings,
    toInt32(s.streak_length) AS triggered_team_winless_meetings_streak,
    toInt32(s.streak_length - 8) AS streak_matches_above_threshold,
    s.streak_start_date AS streak_start_date,
    toInt32(s.streak_draws) AS triggered_team_streak_draws,
    toInt32(s.streak_defeats) AS triggered_team_streak_defeats,
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
WHERE s.streak_length >= 8
  AND m.match_finished = 1
  AND m.match_id > 0
ORDER BY m.match_date, m.match_id, s.side;
