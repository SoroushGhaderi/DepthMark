INSERT INTO fotmob_gold_signals.sig_match_discipline_cards_physical_mismatch (
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
    trigger_threshold_min_fouls_by_one_team,
    match_top_team_fouls,
    match_top_team_fouls_above_threshold,
    match_low_team_fouls,
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
-- Signal: sig_match_discipline_cards_physical_mismatch
-- Intent: Find matches with a huge foul imbalance.
-- Trigger: One team commits >= 25 fouls while the other commits 5 or fewer in a finished match.
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
        toInt32(coalesce(ps.total_shots_home, 0)) AS shots_home, toInt32(coalesce(ps.total_shots_away, 0)) AS shots_away,
        toInt32(coalesce(ps.shots_on_target_home, 0)) AS sot_home, toInt32(coalesce(ps.shots_on_target_away, 0)) AS sot_away,
        toInt32(coalesce(ps.fouls_home, 0)) AS fouls_home, toInt32(coalesce(ps.fouls_away, 0)) AS fouls_away
    FROM fotmob_silver.period_stat AS ps
    WHERE ps.period = 'All'
),
streaks AS (
    SELECT ff.match_id AS match_id, 'home' AS side, greatest(ff.fouls_home, ff.fouls_away) AS top_fouls, least(ff.fouls_home, ff.fouls_away) AS low_fouls
    FROM fixture_facts AS ff
    WHERE (ff.fouls_home >= 25 AND ff.fouls_away <= 5) OR (ff.fouls_away >= 25 AND ff.fouls_home <= 5)
    UNION ALL
    SELECT ff.match_id AS match_id, 'away' AS side, greatest(ff.fouls_home, ff.fouls_away) AS top_fouls, least(ff.fouls_home, ff.fouls_away) AS low_fouls
    FROM fixture_facts AS ff
    WHERE (ff.fouls_home >= 25 AND ff.fouls_away <= 5) OR (ff.fouls_away >= 25 AND ff.fouls_home <= 5)
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
    toInt32(25) AS trigger_threshold_min_fouls_by_one_team,
    toInt32(s.top_fouls) AS match_top_team_fouls,
    toInt32(toInt32(s.top_fouls) - 25) AS match_top_team_fouls_above_threshold,
    toInt32(s.low_fouls) AS match_low_team_fouls,
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
