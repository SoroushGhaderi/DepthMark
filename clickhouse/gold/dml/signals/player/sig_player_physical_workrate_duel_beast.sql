INSERT INTO fotmob_gold_signals.sig_player_physical_workrate_duel_beast (
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
    trigger_threshold_min_total_duels,
    triggered_player_total_duels,
    triggered_player_total_duels_above_threshold,
    triggered_player_duels_won,
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
-- Signal: sig_player_physical_workrate_duel_beast
-- Intent: Find players who are involved in a huge number of duels.
-- Trigger: Player contests >= 25 duels (won plus lost) in a single finished match.
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
player_roles AS (
    SELECT
        mp.match_id AS match_id,
        toInt32(mp.person_id) AS role_person_id,
        toUInt8(max(toUInt8(mp.role = 'starter'))) AS is_starter,
        toUInt8(max(toUInt8(mp.role = 'substitute'))) AS has_sub_row,
        toUInt8(max(toUInt8(coalesce(mp.is_captain, 0) = 1))) AS is_captain,
        toInt32(coalesce(argMax(mp.usual_playing_position_id, if(mp.role = 'starter', 2, 1)), 0)) AS usual_pos
    FROM fotmob_silver.match_personnel AS mp
    WHERE mp.role IN ('starter', 'substitute')
    GROUP BY mp.match_id, role_person_id
),
player_phys AS (
    SELECT
        p.match_id AS match_id, p.player_id AS player_id, p.player_name AS player_name, p.team_id AS team_id, tr.side AS side,
        toInt32(coalesce(p.minutes_played, 0)) AS minutes_played,
        toInt32(coalesce(p.duels_won, 0)) AS duels_won,
        toInt32(coalesce(p.duels_lost, 0)) AS duels_lost,
        toInt32(coalesce(p.ground_duels_won, 0)) AS ground_won,
        toInt32(coalesce(p.ground_duel_attempts, 0)) AS ground_attempts,
        toInt32(coalesce(p.aerial_duels_won, 0)) AS aerial_won,
        toInt32(coalesce(p.aerial_duel_attempts, 0)) AS aerial_attempts,
        toInt32(coalesce(pro.usual_pos, 0)) AS usual_pos
    FROM fotmob_silver.player_match_stat AS p
    INNER JOIN team_results AS tr
        ON tr.match_id = p.match_id
       AND tr.team_id = p.team_id
    LEFT JOIN player_roles AS pro
        ON pro.match_id = p.match_id
       AND pro.role_person_id = p.player_id
    WHERE p.player_id > 0
      AND coalesce(p.minutes_played, 0) > 0
),
streaks AS (
    SELECT pp.*
    FROM player_phys AS pp
    WHERE pp.duels_won + pp.duels_lost >= 25
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
    toInt32(25) AS trigger_threshold_min_total_duels,
    toInt32(s.duels_won + s.duels_lost) AS triggered_player_total_duels,
    toInt32(toInt32(s.duels_won + s.duels_lost) - 25) AS triggered_player_total_duels_above_threshold,
    toInt32(s.duels_won) AS triggered_player_duels_won,
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
