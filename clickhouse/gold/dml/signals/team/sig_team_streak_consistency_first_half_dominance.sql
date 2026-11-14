INSERT INTO fotmob_gold_signals.sig_team_streak_consistency_first_half_dominance (
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
    trigger_threshold_min_consecutive_half_time_lead_matches,
    triggered_team_half_time_lead_streak_matches,
    streak_matches_above_threshold,
    streak_start_date,
    triggered_team_streak_wins,
    triggered_team_streak_draws,
    triggered_team_streak_goals_scored,
    triggered_team_streak_goals_conceded,
    triggered_team_streak_half_time_goal_lead,
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
-- Signal: sig_team_streak_consistency_first_half_dominance
-- Intent: Detect teams that take control before the break.
-- Trigger: Team leads at half-time in >= 5 consecutive matches (this match included).
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
goal_events AS (
    SELECT
        s.match_id AS match_id,
        toInt32(countIf(s.is_home_goal = 1 AND coalesce(s.goal_time, 0) <= 10)) AS home_g10,
        toInt32(countIf(s.is_home_goal = 0 AND coalesce(s.goal_time, 0) <= 10)) AS away_g10,
        toInt32(countIf(s.is_home_goal = 1 AND coalesce(s.goal_time, 0) <= 15)) AS home_g15,
        toInt32(countIf(s.is_home_goal = 0 AND coalesce(s.goal_time, 0) <= 15)) AS away_g15,
        toInt32(countIf(s.is_home_goal = 1 AND coalesce(s.goal_time, 0) >= 90)) AS home_g90,
        toInt32(countIf(s.is_home_goal = 0 AND coalesce(s.goal_time, 0) >= 90)) AS away_g90,
        toInt32(countIf(s.is_home_goal = 1 AND coalesce(s.goal_time, 0) <= 45)) AS home_ht,
        toInt32(countIf(s.is_home_goal = 0 AND coalesce(s.goal_time, 0) <= 45)) AS away_ht,
        toInt32(countIf(s.is_home_goal = 1 AND coalesce(s.goal_time, 0) > 45)) AS home_h2,
        toInt32(countIf(s.is_home_goal = 0 AND coalesce(s.goal_time, 0) > 45)) AS away_h2,
        toInt32(countIf(s.is_home_goal = 1 AND coalesce(s.situation, '') IN ('FromCorner', 'FreeKick', 'SetPiece', 'ThrowInSetPiece'))) AS home_sp,
        toInt32(countIf(s.is_home_goal = 0 AND coalesce(s.situation, '') IN ('FromCorner', 'FreeKick', 'SetPiece', 'ThrowInSetPiece'))) AS away_sp,
        toInt32(countIf(s.home_score_after < s.away_score_after)) AS home_trailed,
        toInt32(countIf(s.away_score_after < s.home_score_after)) AS away_trailed
    FROM fotmob_silver.shot AS s
    WHERE s.match_id > 0
      AND s.is_goal = 1
      AND s.is_home_goal IS NOT NULL
      AND coalesce(s.goal_time, 0) > 0
    GROUP BY s.match_id
),
penalty_events AS (
    SELECT
        s.match_id AS match_id,
        toInt32(assumeNotNull(s.team_id)) AS team_id,
        toInt32(countIf(positionCaseInsensitiveUTF8(coalesce(s.situation, ''), 'penalty') > 0)) AS penalties
    FROM fotmob_silver.shot AS s
    WHERE s.match_id > 0
      AND s.team_id IS NOT NULL
    GROUP BY s.match_id, team_id
),
event_results AS (
    SELECT
        tr.match_id AS match_id,
        tr.match_date AS match_date,
        tr.team_id AS team_id,
        tr.side AS side,
        tr.goals_for AS goals_for,
        tr.goals_against AS goals_against,
        tr.team_seq AS team_seq,
        coalesce(if(tr.side = 'home', ge.home_g10, ge.away_g10), 0) AS early_goals_for,
        coalesce(if(tr.side = 'home', ge.away_g15, ge.home_g15), 0) AS early_goals_against,
        coalesce(if(tr.side = 'home', ge.home_g90, ge.away_g90), 0) AS late_goals_for,
        coalesce(if(tr.side = 'home', ge.home_ht, ge.away_ht), 0) AS ht_goals_for,
        coalesce(if(tr.side = 'home', ge.away_ht, ge.home_ht), 0) AS ht_goals_against,
        coalesce(if(tr.side = 'home', ge.home_h2, ge.away_h2), 0) AS second_half_goals_for,
        coalesce(if(tr.side = 'home', ge.away_h2, ge.home_h2), 0) AS second_half_goals_against,
        coalesce(if(tr.side = 'home', ge.home_sp, ge.away_sp), 0) AS set_piece_goals_for,
        coalesce(if(tr.side = 'home', ge.away_sp, ge.home_sp), 0) AS set_piece_goals_against,
        toInt32(if(tr.side = 'home', coalesce(ge.home_trailed, 0), coalesce(ge.away_trailed, 0)) > 0) AS trailed,
        coalesce(pf.penalties, 0) AS penalties_for,
        coalesce(pa.penalties, 0) AS penalties_against
    FROM team_results AS tr
    LEFT JOIN goal_events AS ge
        ON ge.match_id = tr.match_id
    LEFT JOIN penalty_events AS pf
        ON pf.match_id = tr.match_id
       AND pf.team_id = tr.team_id
    LEFT JOIN penalty_events AS pa
        ON pa.match_id = tr.match_id
       AND pa.team_id = tr.opponent_id
),
runs AS (
    SELECT
        x.match_id AS match_id, x.match_date AS match_date, x.team_id AS team_id, x.side AS side,
        x.goals_for AS goals_for, x.goals_against AS goals_against, x.team_seq AS team_seq, x.ht_goals_for - x.ht_goals_against AS metric_value,
        x.team_seq - row_number() OVER (PARTITION BY x.team_id ORDER BY x.team_seq) AS run_key
    FROM event_results AS x
    WHERE x.ht_goals_for > x.ht_goals_against
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
    toInt32(5) AS trigger_threshold_min_consecutive_half_time_lead_matches,
    toInt32(s.streak_length) AS triggered_team_half_time_lead_streak_matches,
    toInt32(s.streak_length - 5) AS streak_matches_above_threshold,
    s.streak_start_date AS streak_start_date,
    toInt32(s.streak_wins) AS triggered_team_streak_wins,
    toInt32(s.streak_draws) AS triggered_team_streak_draws,
    toInt32(s.streak_goals_scored) AS triggered_team_streak_goals_scored,
    toInt32(s.streak_goals_conceded) AS triggered_team_streak_goals_conceded,
    toInt32(s.streak_metric) AS triggered_team_streak_half_time_goal_lead,
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
WHERE s.streak_length >= 5
  AND m.match_finished = 1
  AND m.match_id > 0
ORDER BY m.match_date, m.match_id, s.side;
