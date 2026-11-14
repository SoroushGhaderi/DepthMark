INSERT INTO fotmob_gold_signals.sig_match_streak_consistency_card_fest_rivalry (
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
    trigger_threshold_min_window_yellow_cards,
    triggered_team_window_yellow_cards,
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
-- Signal: sig_match_streak_consistency_card_fest_rivalry
-- Intent: Detect fixtures that are always full of yellow cards.
-- Trigger: The last 10 meetings of the same two teams averaged >= 6 yellow cards per meeting (this match included).
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
gk_best AS (
    SELECT
        p.match_id AS match_id,
        toUInt8(1) AS keeper_top_rated
    FROM fotmob_silver.player_match_stat AS p
    INNER JOIN (
        SELECT q.match_id AS match_id, max(coalesce(q.fotmob_rating, 0)) AS best_rating
        FROM fotmob_silver.player_match_stat AS q
        WHERE coalesce(q.minutes_played, 0) > 0
        GROUP BY q.match_id
    ) AS b
        ON b.match_id = p.match_id
    WHERE p.is_goalkeeper = 1
      AND coalesce(p.minutes_played, 0) > 0
      AND b.best_rating > 0
      AND coalesce(p.fotmob_rating, 0) = b.best_rating
    GROUP BY p.match_id
),
pair_meetings AS (
    SELECT
        bm.match_id AS match_id, bm.match_date AS match_date, bm.pair_low AS pair_low, bm.pair_high AS pair_high,
        bm.home_goals AS home_goals, bm.away_goals AS away_goals, bm.meeting_seq AS meeting_seq,
        toUInt8(coalesce(ps.period, '') = 'All') AS has_stats,
        toInt32(coalesce(ps.shots_woodwork_home, 0) + coalesce(ps.shots_woodwork_away, 0)) AS woodwork_total,
        toInt32(coalesce(ps.yellow_cards_home, 0) + coalesce(ps.yellow_cards_away, 0)) AS yellows_total,
        toInt32(round((coalesce(ps.expected_goals_home, 0) + coalesce(ps.expected_goals_away, 0)) * 100)) AS xg_hundredths,
        coalesce(gb.keeper_top_rated, 0) AS keeper_top_rated
    FROM base_meetings AS bm
    LEFT JOIN fotmob_silver.period_stat AS ps
        ON ps.match_id = bm.match_id
       AND ps.period = 'All'
    LEFT JOIN gk_best AS gb
        ON gb.match_id = bm.match_id
),
pair_windows AS (
    SELECT
        pm.match_id AS match_id,
        count() OVER w AS window_meetings,
        sum(pm.has_stats) OVER w AS window_stats,
        min(pm.match_date) OVER w AS streak_start_date,
        sum(pm.home_goals + pm.away_goals) OVER w AS streak_total_goals,
        sum(pm.yellows_total) OVER w AS window_value
    FROM pair_meetings AS pm
    WINDOW w AS (PARTITION BY pm.pair_low, pm.pair_high ORDER BY pm.meeting_seq ROWS BETWEEN 9 PRECEDING AND CURRENT ROW)
),
streaks AS (
    SELECT pw.match_id AS match_id, pw.window_meetings AS window_meetings, pw.window_stats AS window_stats, pw.streak_start_date AS streak_start_date,
           pw.streak_total_goals AS streak_total_goals, pw.window_value AS streak_length, 'home' AS side
    FROM pair_windows AS pw
    UNION ALL
    SELECT pw.match_id AS match_id, pw.window_meetings AS window_meetings, pw.window_stats AS window_stats, pw.streak_start_date AS streak_start_date,
           pw.streak_total_goals AS streak_total_goals, pw.window_value AS streak_length, 'away' AS side
    FROM pair_windows AS pw
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
    toInt32(60) AS trigger_threshold_min_window_yellow_cards,
    toInt32(s.streak_length) AS triggered_team_window_yellow_cards,
    toInt32(s.streak_length - 60) AS streak_matches_above_threshold,
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
WHERE s.window_meetings = 10 AND s.window_stats = 10 AND s.streak_length >= 60
  AND m.match_finished = 1
  AND m.match_id > 0
ORDER BY m.match_date, m.match_id, s.side;
