INSERT INTO fotmob_gold_signals.sig_match_goalkeeping_defense_unproductive_possession_match (
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
    trigger_threshold_min_possession_pct,
    match_top_possession_pct,
    match_top_possession_pct_above_threshold,
    match_interception_gap,
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
-- Signal: sig_match_goalkeeping_defense_unproductive_possession_match
-- Intent: Find matches where the team with the ball does little defensive work.
-- Trigger: A team with more than 65% possession makes fewer interceptions than its opponent in a finished match.
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
        toInt32(coalesce(mm.home_score, 0)) AS home_goals, toInt32(coalesce(mm.away_score, 0)) AS away_goals,
        toFloat64(coalesce(ps.expected_goals_home, 0)) AS xg_home, toFloat64(coalesce(ps.expected_goals_away, 0)) AS xg_away,
        toInt32(coalesce(ps.shots_on_target_home, 0)) AS sot_home, toInt32(coalesce(ps.shots_on_target_away, 0)) AS sot_away,
        toInt32(coalesce(ps.total_shots_home, 0)) AS shots_home, toInt32(coalesce(ps.total_shots_away, 0)) AS shots_away,
        toInt32(coalesce(ps.keeper_saves_home, 0)) AS saves_home, toInt32(coalesce(ps.keeper_saves_away, 0)) AS saves_away,
        toInt32(coalesce(ps.touches_opp_box_home, 0)) AS box_home, toInt32(coalesce(ps.touches_opp_box_away, 0)) AS box_away,
        toFloat64(coalesce(ps.ball_possession_home, 0)) AS poss_home, toFloat64(coalesce(ps.ball_possession_away, 0)) AS poss_away,
        toInt32(coalesce(ps.interceptions_home, 0)) AS int_home, toInt32(coalesce(ps.interceptions_away, 0)) AS int_away
    FROM fotmob_silver.period_stat AS ps
    INNER JOIN fotmob_silver.match AS mm
        ON mm.match_id = ps.match_id
    WHERE ps.period = 'All'
),
streaks AS (
    SELECT ff.match_id AS match_id, 'home' AS side, greatest(ff.poss_home, ff.poss_away) AS top_possession, abs(ff.int_home - ff.int_away) AS interception_gap
    FROM fixture_facts AS ff
    WHERE (ff.poss_home > 65 AND ff.int_home < ff.int_away) OR (ff.poss_away > 65 AND ff.int_away < ff.int_home)
    UNION ALL
    SELECT ff.match_id AS match_id, 'away' AS side, greatest(ff.poss_home, ff.poss_away) AS top_possession, abs(ff.int_home - ff.int_away) AS interception_gap
    FROM fixture_facts AS ff
    WHERE (ff.poss_home > 65 AND ff.int_home < ff.int_away) OR (ff.poss_away > 65 AND ff.int_away < ff.int_home)
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
    toFloat64(65) AS trigger_threshold_min_possession_pct,
    toFloat64(s.top_possession) AS match_top_possession_pct,
    toFloat64(toFloat64(s.top_possession) - 65) AS match_top_possession_pct_above_threshold,
    toInt32(s.interception_gap) AS match_interception_gap,
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
