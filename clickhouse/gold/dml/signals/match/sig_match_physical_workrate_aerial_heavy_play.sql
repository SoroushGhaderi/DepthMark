INSERT INTO fotmob_gold_signals.sig_match_physical_workrate_aerial_heavy_play (
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
    trigger_threshold_min_aerial_duel_share_pct,
    match_aerial_duel_share_pct,
    match_aerial_duel_share_pct_above_threshold,
    match_aerial_duels,
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
-- Signal: sig_match_physical_workrate_aerial_heavy_play
-- Intent: Find matches played in the air.
-- Trigger: More than 40% of all contested duels in a finished match are aerial duels.
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
fixture_facts AS (
    SELECT
        ps.match_id AS match_id,
        toInt32(coalesce(ps.aerial_attempts_home, 0)) AS aer_att_home, toInt32(coalesce(ps.aerial_attempts_away, 0)) AS aer_att_away,
        toInt32(coalesce(ps.aerials_won_home, 0)) AS aer_won_home, toInt32(coalesce(ps.aerials_won_away, 0)) AS aer_won_away,
        toInt32(coalesce(ps.ground_duel_attempts_home, 0)) AS gr_att_home, toInt32(coalesce(ps.ground_duel_attempts_away, 0)) AS gr_att_away,
        toInt32(coalesce(ps.ground_duels_won_home, 0)) AS gr_won_home, toInt32(coalesce(ps.ground_duels_won_away, 0)) AS gr_won_away
    FROM fotmob_silver.period_stat AS ps
    WHERE ps.period = 'All'
),
streaks AS (
    SELECT ff.match_id AS match_id, 'home' AS side, toFloat64(round(100.0 * (ff.aer_att_home + ff.aer_att_away) / greatest(ff.aer_att_home + ff.aer_att_away + ff.gr_att_home + ff.gr_att_away, 1), 1)) AS aerial_share_pct, ff.aer_att_home + ff.aer_att_away AS aerial_duels
    FROM fixture_facts AS ff
    WHERE ff.aer_att_home + ff.aer_att_away + ff.gr_att_home + ff.gr_att_away >= 40 AND 100.0 * (ff.aer_att_home + ff.aer_att_away) / (ff.aer_att_home + ff.aer_att_away + ff.gr_att_home + ff.gr_att_away) > 40
    UNION ALL
    SELECT ff.match_id AS match_id, 'away' AS side, toFloat64(round(100.0 * (ff.aer_att_home + ff.aer_att_away) / greatest(ff.aer_att_home + ff.aer_att_away + ff.gr_att_home + ff.gr_att_away, 1), 1)) AS aerial_share_pct, ff.aer_att_home + ff.aer_att_away AS aerial_duels
    FROM fixture_facts AS ff
    WHERE ff.aer_att_home + ff.aer_att_away + ff.gr_att_home + ff.gr_att_away >= 40 AND 100.0 * (ff.aer_att_home + ff.aer_att_away) / (ff.aer_att_home + ff.aer_att_away + ff.gr_att_home + ff.gr_att_away) > 40
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
    toFloat64(40) AS trigger_threshold_min_aerial_duel_share_pct,
    s.aerial_share_pct AS match_aerial_duel_share_pct,
    toFloat64(s.aerial_share_pct - 40) AS match_aerial_duel_share_pct_above_threshold,
    toInt32(s.aerial_duels) AS match_aerial_duels,
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
ORDER BY m.match_date, m.match_id, s.side;
