INSERT INTO fotmob_gold_signals.sig_player_streak_consistency_tackle_wall (
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
    trigger_threshold_min_consecutive_tackling_matches,
    triggered_player_tackling_streak_matches,
    streak_matches_above_threshold,
    streak_start_date,
    triggered_player_streak_tackles_won,
    triggered_player_tackles_won,
    triggered_player_streak_fouls_committed,
    triggered_player_fouls_committed,
    triggered_player_minutes_played_match,
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
-- Signal: sig_player_streak_consistency_tackle_wall
-- Intent: Detect players who defend actively every match.
-- Trigger: Player wins >= 3 tackles in >= 6 consecutive team matches (this match included).
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
card_counts AS (
    SELECT
        c.match_id AS match_id,
        toInt32(assumeNotNull(c.player_id)) AS player_id,
        count() AS cards
    FROM fotmob_silver.card AS c
    WHERE c.match_id > 0
      AND c.player_id IS NOT NULL
      AND c.player_id > 0
    GROUP BY c.match_id, player_id
),
player_rows AS (
    SELECT
        p.match_id AS match_id, p.match_date AS match_date, p.player_id AS player_id, p.player_name AS player_name,
        p.team_id AS team_id, tr.side AS side, tr.team_seq AS team_seq,
        row_number() OVER (PARTITION BY p.player_id ORDER BY p.match_date, p.match_id) AS app_seq,
        toInt32(coalesce(p.total_shots, 0)) AS shots,
        toInt32(coalesce(p.shots_on_target, 0)) AS shots_on_target,
        toInt32(coalesce(p.successful_dribbles, 0)) AS dribbles,
        toInt32(coalesce(p.tackles_won, 0)) AS tackles,
        toInt32(coalesce(p.was_fouled, 0)) AS times_fouled,
        toInt32(coalesce(p.fouls_committed, 0)) AS fouls,
        toInt32(coalesce(p.chances_created, 0)) AS key_passes,
        toInt32(coalesce(p.goals, 0)) AS goals,
        toInt32(coalesce(p.minutes_played, 0)) AS minutes,
        toInt32(coalesce(cc.cards, 0)) AS cards
    FROM fotmob_silver.player_match_stat AS p
    INNER JOIN team_results AS tr
        ON tr.match_id = p.match_id
       AND tr.team_id = p.team_id
    LEFT JOIN card_counts AS cc
        ON cc.match_id = p.match_id
       AND cc.player_id = p.player_id
    WHERE p.player_id > 0
      AND coalesce(p.minutes_played, 0) > 0
),
runs AS (
    SELECT
        pr.match_id AS match_id, pr.match_date AS match_date, pr.player_id AS player_id, pr.player_name AS player_name,
        pr.team_id AS team_id, pr.side AS side, pr.team_seq AS seq, pr.shots AS shots, pr.shots_on_target AS shots_on_target, pr.dribbles AS dribbles, pr.tackles AS tackles, pr.times_fouled AS times_fouled, pr.fouls AS fouls, pr.key_passes AS key_passes, pr.goals AS goals, pr.minutes AS minutes, pr.cards AS cards,
        pr.team_seq - row_number() OVER (PARTITION BY pr.player_id, pr.team_id ORDER BY pr.team_seq) AS run_key
    FROM player_rows AS pr
    WHERE pr.tackles >= 3
),
streaks AS (
    SELECT
        r.match_id AS match_id, r.player_id AS player_id, r.player_name AS player_name, r.team_id AS team_id, r.side AS side,
        row_number() OVER w AS streak_length,
        min(r.match_date) OVER w AS streak_start_date,
        r.shots AS match_shots,
        r.shots_on_target AS match_shots_on_target,
        r.dribbles AS match_dribbles,
        r.tackles AS match_tackles,
        r.times_fouled AS match_times_fouled,
        r.fouls AS match_fouls,
        r.key_passes AS match_key_passes,
        r.goals AS match_goals,
        r.minutes AS match_minutes,
        r.cards AS match_cards,
        sum(r.shots) OVER w AS streak_shots,
        sum(r.shots_on_target) OVER w AS streak_shots_on_target,
        sum(r.dribbles) OVER w AS streak_dribbles,
        sum(r.tackles) OVER w AS streak_tackles,
        sum(r.times_fouled) OVER w AS streak_times_fouled,
        sum(r.fouls) OVER w AS streak_fouls,
        sum(r.key_passes) OVER w AS streak_key_passes,
        sum(r.goals) OVER w AS streak_goals,
        sum(r.minutes) OVER w AS streak_minutes,
        sum(r.cards) OVER w AS streak_cards
    FROM runs AS r
    WINDOW w AS (PARTITION BY r.player_id, r.team_id, r.run_key ORDER BY r.seq)
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
    toInt32(6) AS trigger_threshold_min_consecutive_tackling_matches,
    toInt32(s.streak_length) AS triggered_player_tackling_streak_matches,
    toInt32(s.streak_length - 6) AS streak_matches_above_threshold,
    s.streak_start_date AS streak_start_date,
    toInt32(s.streak_tackles) AS triggered_player_streak_tackles_won,
    toInt32(s.match_tackles) AS triggered_player_tackles_won,
    toInt32(s.streak_fouls) AS triggered_player_streak_fouls_committed,
    toInt32(s.match_fouls) AS triggered_player_fouls_committed,
    toInt32(s.match_minutes) AS triggered_player_minutes_played_match,
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
WHERE s.streak_length >= 6
  AND m.match_finished = 1
  AND m.match_id > 0
ORDER BY m.match_date, m.match_id, s.player_id;
