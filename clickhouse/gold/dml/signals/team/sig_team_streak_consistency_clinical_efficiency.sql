INSERT INTO fotmob_gold_signals.sig_team_streak_consistency_clinical_efficiency (
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
    trigger_threshold_min_window_conversion_pct,
    triggered_team_window_conversion_pct,
    streak_matches_above_threshold,
    streak_start_date,
    triggered_team_streak_wins,
    triggered_team_streak_draws,
    triggered_team_streak_goals_scored,
    triggered_team_streak_goals_conceded,
    triggered_team_window_shots,
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
-- Signal: sig_team_streak_consistency_clinical_efficiency
-- Intent: Detect teams that are unusually efficient in front of goal.
-- Trigger: Team converts > 25% of its shots into goals over its last 3 matches (this match included).
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
stat_results AS (
    SELECT
        tr.match_id AS match_id,
        tr.match_date AS match_date,
        tr.team_id AS team_id,
        tr.side AS side,
        tr.goals_for AS goals_for,
        tr.goals_against AS goals_against,
        tr.team_seq AS team_seq,
        toFloat64(coalesce(if(tr.side = 'home', ps.ball_possession_home, ps.ball_possession_away), 0)) AS possession_for,
        toInt32(coalesce(if(tr.side = 'home', ps.total_shots_home, ps.total_shots_away), 0)) AS shots_for,
        toInt32(coalesce(if(tr.side = 'home', ps.total_shots_away, ps.total_shots_home), 0)) AS shots_against,
        toInt32(coalesce(if(tr.side = 'home', ps.shots_on_target_home, ps.shots_on_target_away), 0)) AS shots_on_target_for,
        toInt32(coalesce(if(tr.side = 'home', ps.corners_home, ps.corners_away), 0)) AS corners_for,
        toInt32(coalesce(if(tr.side = 'home', ps.corners_away, ps.corners_home), 0)) AS corners_against,
        toInt32(coalesce(if(tr.side = 'home', ps.aerials_won_home, ps.aerials_won_away), 0)) AS aerials_won_for,
        toInt32(coalesce(if(tr.side = 'home', ps.aerial_attempts_home, ps.aerial_attempts_away), 0)) AS aerial_attempts_for,
        toInt32(coalesce(if(tr.side = 'home', ps.keeper_saves_home, ps.keeper_saves_away), 0)) AS saves_for,
        toFloat64(coalesce(if(tr.side = 'home', ps.expected_goals_home, ps.expected_goals_away), 0)) AS xg_for,
        toFloat64(coalesce(if(tr.side = 'home', ps.expected_goals_away, ps.expected_goals_home), 0)) AS xg_against,
        if(shots_for > 0, 100.0 * shots_on_target_for / shots_for, 0.0) AS shot_accuracy_pct,
        if(aerial_attempts_for > 0, 100.0 * aerials_won_for / aerial_attempts_for, 0.0) AS aerial_win_pct
    FROM team_results AS tr
    INNER JOIN fotmob_silver.period_stat AS ps
        ON ps.match_id = tr.match_id
       AND ps.period = 'All'
),
form AS (
    SELECT
        x.match_id AS match_id, x.match_date AS match_date, x.team_id AS team_id, x.side AS side,
        x.goals_for AS goals_for, x.goals_against AS goals_against, x.team_seq AS team_seq, x.shots_for AS shots_for
    FROM stat_results AS x
),
window_stats AS (
    SELECT
        f.match_id AS match_id, f.team_id AS team_id, f.side AS side,
        count() OVER w AS window_matches,
        min(f.match_date) OVER w AS streak_start_date,
        sum(f.goals_for) OVER w AS streak_goals_scored,
        sum(f.goals_against) OVER w AS streak_goals_conceded,
        sum(f.shots_for) OVER w AS window_shots,
        sum(toUInt8(f.goals_for > f.goals_against)) OVER w AS streak_wins,
        sum(toUInt8(f.goals_for = f.goals_against)) OVER w AS streak_draws
    FROM form AS f
    WINDOW w AS (PARTITION BY f.team_id ORDER BY f.team_seq ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
),
streaks AS (
    SELECT
        ws.match_id AS match_id, ws.team_id AS team_id, ws.side AS side, ws.window_matches AS window_matches,
        ws.streak_start_date AS streak_start_date, ws.streak_goals_scored AS streak_goals_scored,
        ws.streak_goals_conceded AS streak_goals_conceded, ws.window_shots AS window_shots,
        ws.streak_wins AS streak_wins, ws.streak_draws AS streak_draws,
        if(ws.window_shots > 0, 100.0 * ws.streak_goals_scored / ws.window_shots, 0.0) AS window_conversion_pct
    FROM window_stats AS ws
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
    toInt32(25) AS trigger_threshold_min_window_conversion_pct,
    toFloat64(round(s.window_conversion_pct, 2)) AS triggered_team_window_conversion_pct,
    toFloat64(round(s.window_conversion_pct - 25, 2)) AS streak_matches_above_threshold,
    s.streak_start_date AS streak_start_date,
    toInt32(s.streak_wins) AS triggered_team_streak_wins,
    toInt32(s.streak_draws) AS triggered_team_streak_draws,
    toInt32(s.streak_goals_scored) AS triggered_team_streak_goals_scored,
    toInt32(s.streak_goals_conceded) AS triggered_team_streak_goals_conceded,
    toInt32(s.window_shots) AS triggered_team_window_shots,
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
WHERE s.window_matches = 3 AND s.window_shots > 0 AND s.window_conversion_pct > 25
  AND m.match_finished = 1
  AND m.match_id > 0
ORDER BY m.match_date, m.match_id, s.side;
