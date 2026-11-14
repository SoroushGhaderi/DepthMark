INSERT INTO fotmob_gold_signals.sig_match_streak_consistency_stalemate_cycle (
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
    trigger_threshold_min_drawn_meetings,
    triggered_team_drawn_meetings_streak,
    streak_matches_above_threshold,
    streak_start_date,
    streak_total_goals,
    stadium_name,
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
-- Signal: sig_match_streak_consistency_stalemate_cycle
-- Intent: Detect fixtures that keep ending level at the same venue.
-- Trigger: The last >= 4 meetings of the same two teams at this stadium all ended in draws (this match included).
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
venue_meetings AS (
    SELECT
        m.match_id AS match_id, m.match_date AS match_date,
        least(m.home_team_id, m.away_team_id) AS pair_low,
        greatest(m.home_team_id, m.away_team_id) AS pair_high,
        m.stadium_name AS stadium_name,
        toInt32(m.home_score) AS home_goals, toInt32(m.away_score) AS away_goals,
        row_number() OVER (
            PARTITION BY least(m.home_team_id, m.away_team_id), greatest(m.home_team_id, m.away_team_id), m.stadium_name
            ORDER BY m.match_date, m.match_id
        ) AS venue_seq
    FROM fotmob_silver.match AS m
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND m.home_team_id IS NOT NULL
      AND m.away_team_id IS NOT NULL
      AND m.home_score IS NOT NULL
      AND m.away_score IS NOT NULL
      AND m.stadium_name IS NOT NULL
      AND m.stadium_name != ''
),
draw_runs AS (
    SELECT
        vm.match_id AS match_id, vm.match_date AS match_date, vm.pair_low AS pair_low, vm.pair_high AS pair_high,
        vm.stadium_name AS stadium_name, vm.home_goals AS home_goals, vm.away_goals AS away_goals, vm.venue_seq AS venue_seq,
        vm.venue_seq - row_number() OVER (PARTITION BY vm.pair_low, vm.pair_high, vm.stadium_name ORDER BY vm.venue_seq) AS run_key
    FROM venue_meetings AS vm
    WHERE vm.home_goals = vm.away_goals
),
draw_streaks AS (
    SELECT
        dr.match_id AS match_id,
        row_number() OVER w AS streak_length,
        min(dr.match_date) OVER w AS streak_start_date,
        sum(dr.home_goals + dr.away_goals) OVER w AS streak_total_goals
    FROM draw_runs AS dr
    WINDOW w AS (PARTITION BY dr.pair_low, dr.pair_high, dr.stadium_name, dr.run_key ORDER BY dr.venue_seq)
),
streaks AS (
    SELECT ds.match_id AS match_id, ds.streak_length AS streak_length, ds.streak_start_date AS streak_start_date,
           ds.streak_total_goals AS streak_total_goals, 'home' AS side
    FROM draw_streaks AS ds
    UNION ALL
    SELECT ds.match_id AS match_id, ds.streak_length AS streak_length, ds.streak_start_date AS streak_start_date,
           ds.streak_total_goals AS streak_total_goals, 'away' AS side
    FROM draw_streaks AS ds
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
    toInt32(4) AS trigger_threshold_min_drawn_meetings,
    toInt32(s.streak_length) AS triggered_team_drawn_meetings_streak,
    toInt32(s.streak_length - 4) AS streak_matches_above_threshold,
    s.streak_start_date AS streak_start_date,
    toInt32(s.streak_total_goals) AS streak_total_goals,
    m.stadium_name AS stadium_name,
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
