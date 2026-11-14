INSERT INTO fotmob_gold_signals.sig_team_streak_consistency_consistency_king (
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
    trigger_threshold_min_consecutive_settled_lineup_matches,
    triggered_team_settled_lineup_streak_matches,
    streak_matches_above_threshold,
    streak_start_date,
    triggered_team_streak_wins,
    triggered_team_streak_draws,
    triggered_team_streak_goals_scored,
    triggered_team_streak_goals_conceded,
    triggered_team_streak_players_kept,
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
-- Signal: sig_team_streak_consistency_consistency_king
-- Intent: Detect teams that keep an unchanged lineup.
-- Trigger: Team starts the same starting XI in >= 4 consecutive matches (this match included).
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
team_prev AS (
    SELECT
        tr.match_id AS match_id, tr.match_date AS match_date, tr.team_id AS team_id, tr.side AS side,
        tr.goals_for AS goals_for, tr.goals_against AS goals_against, tr.team_seq AS team_seq,
        any(tr.match_id) OVER (PARTITION BY tr.team_id ORDER BY tr.team_seq ROWS BETWEEN 1 PRECEDING AND 1 PRECEDING) AS prev_match_id
    FROM team_results AS tr
),
starters_t AS (
    SELECT
        mp.match_id AS match_id,
        tr.team_id AS team_id,
        toInt64(mp.person_id) AS starter_id,
        toUInt8(1) AS present
    FROM fotmob_silver.match_personnel AS mp
    INNER JOIN team_results AS tr
        ON tr.match_id = mp.match_id
       AND tr.side = mp.team_side
    WHERE mp.role = 'starter'
),
starters_n AS (
    SELECT st.match_id AS match_id, st.team_id AS team_id, toInt32(count()) AS starter_count
    FROM starters_t AS st
    GROUP BY st.match_id, st.team_id
),
lineup_changes AS (
    SELECT
        tp.match_id AS match_id, tp.match_date AS match_date, tp.team_id AS team_id, tp.side AS side,
        tp.goals_for AS goals_for, tp.goals_against AS goals_against, tp.team_seq AS team_seq,
        toInt32(count()) AS starters,
        toInt32(countIf(coalesce(prv.present, 0) = 0)) AS changes,
        toInt32(any(coalesce(pn.starter_count, 0))) AS prev_starters
    FROM team_prev AS tp
    INNER JOIN starters_t AS cur
        ON cur.match_id = tp.match_id
       AND cur.team_id = tp.team_id
    LEFT JOIN starters_t AS prv
        ON prv.match_id = tp.prev_match_id
       AND prv.team_id = tp.team_id
       AND prv.starter_id = cur.starter_id
    LEFT JOIN starters_n AS pn
        ON pn.match_id = tp.prev_match_id
       AND pn.team_id = tp.team_id
    WHERE tp.team_seq > 1
    GROUP BY tp.match_id, tp.match_date, tp.team_id, tp.side, tp.goals_for, tp.goals_against, tp.team_seq
),
runs AS (
    SELECT
        x.match_id AS match_id, x.match_date AS match_date, x.team_id AS team_id, x.side AS side,
        x.goals_for AS goals_for, x.goals_against AS goals_against, x.team_seq AS team_seq, x.starters - x.changes AS metric_value,
        x.team_seq - row_number() OVER (PARTITION BY x.team_id ORDER BY x.team_seq) AS run_key
    FROM lineup_changes AS x
    WHERE x.starters = 11 AND x.prev_starters = 11 AND x.changes = 0
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
    toInt32(4) AS trigger_threshold_min_consecutive_settled_lineup_matches,
    toInt32(s.streak_length) AS triggered_team_settled_lineup_streak_matches,
    toInt32(s.streak_length - 4) AS streak_matches_above_threshold,
    s.streak_start_date AS streak_start_date,
    toInt32(s.streak_wins) AS triggered_team_streak_wins,
    toInt32(s.streak_draws) AS triggered_team_streak_draws,
    toInt32(s.streak_goals_scored) AS triggered_team_streak_goals_scored,
    toInt32(s.streak_goals_conceded) AS triggered_team_streak_goals_conceded,
    toInt32(s.streak_metric) AS triggered_team_streak_players_kept,
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
