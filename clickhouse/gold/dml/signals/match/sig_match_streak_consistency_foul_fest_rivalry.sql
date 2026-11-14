INSERT INTO fotmob_gold_signals.sig_match_streak_consistency_foul_fest_rivalry (
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
    trigger_threshold_min_consecutive_foul_heavy_meetings,
    triggered_team_foul_heavy_meetings_streak,
    streak_matches_above_threshold,
    streak_start_date,
    streak_total_goals,
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
-- Signal: sig_match_streak_consistency_foul_fest_rivalry
-- Intent: Detect fixtures that are always physical.
-- Trigger: The last >= 5 meetings of the same two teams each had >= 30 combined fouls (this match included).
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
base_meetings AS (
    SELECT
        m.match_id AS match_id, m.match_date AS match_date,
        least(m.home_team_id, m.away_team_id) AS pair_low,
        greatest(m.home_team_id, m.away_team_id) AS pair_high,
        toInt32(m.home_score) AS home_goals, toInt32(m.away_score) AS away_goals,
        row_number() OVER (
            PARTITION BY least(m.home_team_id, m.away_team_id), greatest(m.home_team_id, m.away_team_id)
            ORDER BY m.match_date, m.match_id
        ) AS meeting_seq
    FROM fotmob_silver.match AS m
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND m.home_team_id IS NOT NULL
      AND m.away_team_id IS NOT NULL
      AND m.home_score IS NOT NULL
      AND m.away_score IS NOT NULL
),
goal_events AS (
    SELECT
        s.match_id AS match_id,
        toInt32(countIf(coalesce(s.goal_time, 0) <= 10)) AS goals_first_10,
        toInt32(countIf(coalesce(s.goal_time, 0) > 85)) AS goals_after_85,
        toInt32(countIf(coalesce(s.goal_time, 0) <= 45)) AS goals_first_half,
        toInt32(count()) AS goal_rows
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
        toInt32(countIf(positionCaseInsensitiveUTF8(coalesce(s.situation, ''), 'penalty') > 0)) AS penalty_shots
    FROM fotmob_silver.shot AS s
    WHERE s.match_id > 0
    GROUP BY s.match_id
),
pair_meetings AS (
    SELECT
        bm.match_id AS match_id, bm.match_date AS match_date, bm.pair_low AS pair_low, bm.pair_high AS pair_high,
        bm.home_goals AS home_goals, bm.away_goals AS away_goals, bm.meeting_seq AS meeting_seq,
        toUInt8(coalesce(ps.period, '') = 'All') AS has_stats,
        toInt32(coalesce(ps.red_cards_home, 0) + coalesce(ps.red_cards_away, 0)) AS red_cards,
        toInt32(coalesce(ps.fouls_home, 0) + coalesce(ps.fouls_away, 0)) AS fouls_total,
        toInt32(coalesce(ps.corners_home, 0) + coalesce(ps.corners_away, 0)) AS corners_total,
        toInt32(coalesce(ps.total_shots_home, 0)) AS shots_home,
        toInt32(coalesce(ps.total_shots_away, 0)) AS shots_away,
        toFloat64(coalesce(ps.ball_possession_home, 0)) AS possession_home,
        coalesce(ge.goals_first_10, 0) AS goals_first_10,
        coalesce(ge.goals_after_85, 0) AS goals_after_85,
        coalesce(ge.goals_first_half, 0) AS goals_first_half,
        coalesce(ge.goal_rows, 0) AS goal_rows,
        coalesce(pe.penalty_shots, 0) AS penalty_shots
    FROM base_meetings AS bm
    LEFT JOIN fotmob_silver.period_stat AS ps
        ON ps.match_id = bm.match_id
       AND ps.period = 'All'
    LEFT JOIN goal_events AS ge
        ON ge.match_id = bm.match_id
    LEFT JOIN penalty_events AS pe
        ON pe.match_id = bm.match_id
),
pair_runs AS (
    SELECT
        pm.match_id AS match_id, pm.match_date AS match_date, pm.pair_low AS pair_low, pm.pair_high AS pair_high,
        pm.home_goals AS home_goals, pm.away_goals AS away_goals, pm.meeting_seq AS meeting_seq,
        pm.meeting_seq - row_number() OVER (PARTITION BY pm.pair_low, pm.pair_high ORDER BY pm.meeting_seq) AS run_key
    FROM pair_meetings AS pm
    WHERE pm.has_stats = 1 AND pm.fouls_total >= 30
),
pair_streaks AS (
    SELECT
        pr.match_id AS match_id,
        row_number() OVER w AS streak_length,
        min(pr.match_date) OVER w AS streak_start_date,
        sum(pr.home_goals + pr.away_goals) OVER w AS streak_total_goals
    FROM pair_runs AS pr
    WINDOW w AS (PARTITION BY pr.pair_low, pr.pair_high, pr.run_key ORDER BY pr.meeting_seq)
),
streaks AS (
    SELECT ps.match_id AS match_id, ps.streak_length AS streak_length, ps.streak_start_date AS streak_start_date,
           ps.streak_total_goals AS streak_total_goals, 'home' AS side
    FROM pair_streaks AS ps
    UNION ALL
    SELECT ps.match_id AS match_id, ps.streak_length AS streak_length, ps.streak_start_date AS streak_start_date,
           ps.streak_total_goals AS streak_total_goals, 'away' AS side
    FROM pair_streaks AS ps
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
    toInt32(5) AS trigger_threshold_min_consecutive_foul_heavy_meetings,
    toInt32(s.streak_length) AS triggered_team_foul_heavy_meetings_streak,
    toInt32(s.streak_length - 5) AS streak_matches_above_threshold,
    s.streak_start_date AS streak_start_date,
    toInt32(s.streak_total_goals) AS streak_total_goals,
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
