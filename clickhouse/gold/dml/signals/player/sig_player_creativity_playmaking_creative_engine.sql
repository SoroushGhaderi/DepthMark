INSERT INTO fotmob_gold_signals.sig_player_creativity_playmaking_creative_engine (
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
    trigger_threshold_min_touches,
    triggered_player_touches,
    triggered_player_touches_above_threshold,
    triggered_player_key_passes,
    triggered_player_minutes_played,
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
-- Signal: sig_player_creativity_playmaking_creative_engine
-- Intent: Find players who are both heavily involved and creative.
-- Trigger: Player records >= 80 touches and >= 4 key passes in a finished match.
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
team_pass_totals AS (
    SELECT
        p.match_id AS match_id,
        toInt32(assumeNotNull(p.team_id)) AS total_team_id,
        toInt32(sum(coalesce(p.passes_final_third, 0))) AS team_final_third_passes
    FROM fotmob_silver.player_match_stat AS p
    WHERE p.match_id > 0
      AND p.team_id IS NOT NULL
    GROUP BY p.match_id, total_team_id
),
player_creative AS (
    SELECT
        p.match_id AS match_id, p.player_id AS player_id, p.player_name AS player_name, p.team_id AS team_id, tr.side AS side,
        toInt32(coalesce(p.minutes_played, 0)) AS minutes_played,
        toInt32(coalesce(p.touches, 0)) AS touches,
        toInt32(coalesce(p.chances_created, 0)) AS chances_created,
        toInt32(coalesce(p.assists, 0)) AS assists,
        toInt32(coalesce(p.passes_final_third, 0)) AS final_third_passes,
        toInt32(coalesce(tt.team_final_third_passes, 0)) AS team_final_third_passes,
        toFloat64(coalesce(if(tr.side = 'home', pst.ball_possession_home, pst.ball_possession_away), 0)) AS possession_pct
    FROM fotmob_silver.player_match_stat AS p
    INNER JOIN team_results AS tr
        ON tr.match_id = p.match_id
       AND tr.team_id = p.team_id
    INNER JOIN fotmob_silver.period_stat AS pst
        ON pst.match_id = p.match_id
       AND pst.period = 'All'
    LEFT JOIN team_pass_totals AS tt
        ON tt.match_id = p.match_id
       AND tt.total_team_id = p.team_id
    WHERE p.player_id > 0
      AND coalesce(p.minutes_played, 0) > 0
),
streaks AS (
    SELECT pc.*
    FROM player_creative AS pc
    WHERE pc.touches >= 80 AND pc.chances_created >= 4
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
    toInt32(80) AS trigger_threshold_min_touches,
    toInt32(s.touches) AS triggered_player_touches,
    toInt32(toInt32(s.touches) - 80) AS triggered_player_touches_above_threshold,
    toInt32(s.chances_created) AS triggered_player_key_passes,
    toInt32(s.minutes_played) AS triggered_player_minutes_played,
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
WHERE 1 = 1
  AND m.match_finished = 1
  AND m.match_id > 0
ORDER BY m.match_date, m.match_id, s.player_id;
