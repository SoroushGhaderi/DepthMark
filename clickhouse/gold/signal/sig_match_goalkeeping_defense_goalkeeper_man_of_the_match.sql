INSERT INTO gold.sig_match_goalkeeping_defense_goalkeeper_man_of_the_match (
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
    trigger_threshold_max_match_total_goals,
    trigger_condition_goalkeeper_highest_rated_required,
    match_total_goals,
    match_low_scoring_flag,
    match_scoreline_label,
    match_highest_player_rating,
    triggered_goalkeeper_player_id,
    triggered_goalkeeper_player_name,
    opponent_goalkeeper_player_id,
    opponent_goalkeeper_player_name,
    triggered_goalkeeper_fotmob_rating,
    opponent_goalkeeper_fotmob_rating,
    goalkeeper_fotmob_rating_delta,
    triggered_goalkeeper_minutes_played,
    opponent_goalkeeper_minutes_played,
    goalkeeper_minutes_played_delta,
    both_goalkeepers_top_rated_flag,
    triggered_team_keeper_saves,
    opponent_keeper_saves,
    keeper_saves_delta,
    triggered_team_shots_on_target_faced,
    opponent_shots_on_target_faced,
    shots_on_target_faced_delta,
    triggered_team_total_shots_faced,
    opponent_total_shots_faced,
    total_shots_faced_delta,
    triggered_team_interceptions,
    opponent_interceptions,
    interceptions_delta,
    triggered_team_clearances,
    opponent_clearances,
    clearances_delta,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_clean_sheet_flag
)
-- Signal: sig_match_goalkeeping_defense_goalkeeper_man_of_the_match
-- Intent: detect low-scoring matches where a goalkeeper owns the highest match rating and preserve
--         bilateral side-oriented defensive workload, control, and result context.
-- Trigger: goalkeeper is the highest-rated player in a finished 1-0 or 0-0 match.
WITH low_scoring_matches AS (
    SELECT
        m.match_id,
        m.match_date,
        m.home_team_id,
        m.home_team_name,
        m.away_team_id,
        m.away_team_name,
        m.home_score,
        m.away_score,
        toInt32(coalesce(m.home_score, 0)) AS home_goals,
        toInt32(coalesce(m.away_score, 0)) AS away_goals,
        toInt32(coalesce(m.home_score, 0) + coalesce(m.away_score, 0)) AS match_total_goals
    FROM silver.match AS m
    WHERE m.match_finished = 1
      AND m.match_id > 0
      AND (
          (coalesce(m.home_score, 0) = 0 AND coalesce(m.away_score, 0) = 0)
          OR (coalesce(m.home_score, 0) = 1 AND coalesce(m.away_score, 0) = 0)
          OR (coalesce(m.home_score, 0) = 0 AND coalesce(m.away_score, 0) = 1)
      )
),
player_ratings AS (
    SELECT
        p.match_id,
        p.player_id,
        p.player_name,
        p.team_id,
        p.is_goalkeeper,
        toFloat32(coalesce(p.fotmob_rating, 0.0)) AS fotmob_rating,
        toInt32(coalesce(p.minutes_played, 0)) AS minutes_played
    FROM silver.player_match_stat AS p
    WHERE p.match_id > 0
      AND p.player_id > 0
      AND p.team_id > 0
      AND p.fotmob_rating IS NOT NULL
),
match_top_rating AS (
    SELECT
        pr.match_id,
        toFloat32(max(pr.fotmob_rating)) AS match_highest_player_rating
    FROM player_ratings AS pr
    GROUP BY pr.match_id
),
team_goalkeeper_top_rating AS (
    SELECT
        pr.match_id,
        pr.team_id,
        argMax(
            pr.player_id,
            tuple(pr.fotmob_rating, pr.minutes_played, pr.player_id)
        ) AS goalkeeper_player_id,
        argMax(
            coalesce(pr.player_name, 'Unknown'),
            tuple(pr.fotmob_rating, pr.minutes_played, pr.player_id)
        ) AS goalkeeper_player_name,
        toFloat32(max(pr.fotmob_rating)) AS goalkeeper_fotmob_rating,
        argMax(
            pr.minutes_played,
            tuple(pr.fotmob_rating, pr.minutes_played, pr.player_id)
        ) AS goalkeeper_minutes_played
    FROM player_ratings AS pr
    WHERE pr.is_goalkeeper = 1
    GROUP BY
        pr.match_id,
        pr.team_id
)
SELECT
    lm.match_id,
    lm.match_date,
    lm.home_team_id,
    lm.home_team_name,
    lm.away_team_id,
    lm.away_team_name,
    lm.home_score,
    lm.away_score,
    'home' AS triggered_side,
    lm.home_team_id AS triggered_team_id,
    lm.home_team_name AS triggered_team_name,
    lm.away_team_id AS opponent_team_id,
    lm.away_team_name AS opponent_team_name,
    toInt32(1) AS trigger_threshold_max_match_total_goals,
    toInt8(1) AS trigger_condition_goalkeeper_highest_rated_required,
    lm.match_total_goals,
    toInt8(1) AS match_low_scoring_flag,
    if(lm.match_total_goals = 0, '0-0', '1-0') AS match_scoreline_label,
    mtr.match_highest_player_rating,
    toInt32(hgk.goalkeeper_player_id) AS triggered_goalkeeper_player_id,
    hgk.goalkeeper_player_name AS triggered_goalkeeper_player_name,
    toInt32(agk.goalkeeper_player_id) AS opponent_goalkeeper_player_id,
    agk.goalkeeper_player_name AS opponent_goalkeeper_player_name,
    hgk.goalkeeper_fotmob_rating AS triggered_goalkeeper_fotmob_rating,
    agk.goalkeeper_fotmob_rating AS opponent_goalkeeper_fotmob_rating,
    toFloat32(round(hgk.goalkeeper_fotmob_rating - agk.goalkeeper_fotmob_rating, 3))
        AS goalkeeper_fotmob_rating_delta,
    toInt32(hgk.goalkeeper_minutes_played) AS triggered_goalkeeper_minutes_played,
    toInt32(agk.goalkeeper_minutes_played) AS opponent_goalkeeper_minutes_played,
    toInt32(hgk.goalkeeper_minutes_played - agk.goalkeeper_minutes_played)
        AS goalkeeper_minutes_played_delta,
    toInt8(if(
        hgk.goalkeeper_fotmob_rating >= mtr.match_highest_player_rating - 0.0001
        AND agk.goalkeeper_fotmob_rating >= mtr.match_highest_player_rating - 0.0001,
        1,
        0
    )) AS both_goalkeepers_top_rated_flag,
    toInt32(coalesce(ps.keeper_saves_home, 0)) AS triggered_team_keeper_saves,
    toInt32(coalesce(ps.keeper_saves_away, 0)) AS opponent_keeper_saves,
    toInt32(coalesce(ps.keeper_saves_home, 0) - coalesce(ps.keeper_saves_away, 0))
        AS keeper_saves_delta,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS triggered_team_shots_on_target_faced,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS opponent_shots_on_target_faced,
    toInt32(coalesce(ps.shots_on_target_away, 0) - coalesce(ps.shots_on_target_home, 0))
        AS shots_on_target_faced_delta,
    toInt32(coalesce(ps.total_shots_away, 0)) AS triggered_team_total_shots_faced,
    toInt32(coalesce(ps.total_shots_home, 0)) AS opponent_total_shots_faced,
    toInt32(coalesce(ps.total_shots_away, 0) - coalesce(ps.total_shots_home, 0))
        AS total_shots_faced_delta,
    toInt32(coalesce(ps.interceptions_home, 0)) AS triggered_team_interceptions,
    toInt32(coalesce(ps.interceptions_away, 0)) AS opponent_interceptions,
    toInt32(coalesce(ps.interceptions_home, 0) - coalesce(ps.interceptions_away, 0))
        AS interceptions_delta,
    toInt32(coalesce(ps.clearances_home, 0)) AS triggered_team_clearances,
    toInt32(coalesce(ps.clearances_away, 0)) AS opponent_clearances,
    toInt32(coalesce(ps.clearances_home, 0) - coalesce(ps.clearances_away, 0))
        AS clearances_delta,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_home, 0) - coalesce(ps.ball_possession_away, 0), 1))
        AS possession_delta_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,
    lm.home_goals AS triggered_team_goals,
    lm.away_goals AS opponent_goals,
    toInt32(lm.home_goals - lm.away_goals) AS goal_delta,
    toInt8(if(lm.away_goals = 0, 1, 0)) AS triggered_team_clean_sheet_flag
FROM low_scoring_matches AS lm
INNER JOIN match_top_rating AS mtr
    ON mtr.match_id = lm.match_id
INNER JOIN team_goalkeeper_top_rating AS hgk
    ON hgk.match_id = lm.match_id
   AND hgk.team_id = lm.home_team_id
INNER JOIN team_goalkeeper_top_rating AS agk
    ON agk.match_id = lm.match_id
   AND agk.team_id = lm.away_team_id
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = lm.match_id
   AND ps.match_date = lm.match_date
   AND ps.period = 'All'
WHERE hgk.goalkeeper_fotmob_rating >= mtr.match_highest_player_rating - 0.0001

UNION ALL

SELECT
    lm.match_id,
    lm.match_date,
    lm.home_team_id,
    lm.home_team_name,
    lm.away_team_id,
    lm.away_team_name,
    lm.home_score,
    lm.away_score,
    'away' AS triggered_side,
    lm.away_team_id AS triggered_team_id,
    lm.away_team_name AS triggered_team_name,
    lm.home_team_id AS opponent_team_id,
    lm.home_team_name AS opponent_team_name,
    toInt32(1) AS trigger_threshold_max_match_total_goals,
    toInt8(1) AS trigger_condition_goalkeeper_highest_rated_required,
    lm.match_total_goals,
    toInt8(1) AS match_low_scoring_flag,
    if(lm.match_total_goals = 0, '0-0', '1-0') AS match_scoreline_label,
    mtr.match_highest_player_rating,
    toInt32(agk.goalkeeper_player_id) AS triggered_goalkeeper_player_id,
    agk.goalkeeper_player_name AS triggered_goalkeeper_player_name,
    toInt32(hgk.goalkeeper_player_id) AS opponent_goalkeeper_player_id,
    hgk.goalkeeper_player_name AS opponent_goalkeeper_player_name,
    agk.goalkeeper_fotmob_rating AS triggered_goalkeeper_fotmob_rating,
    hgk.goalkeeper_fotmob_rating AS opponent_goalkeeper_fotmob_rating,
    toFloat32(round(agk.goalkeeper_fotmob_rating - hgk.goalkeeper_fotmob_rating, 3))
        AS goalkeeper_fotmob_rating_delta,
    toInt32(agk.goalkeeper_minutes_played) AS triggered_goalkeeper_minutes_played,
    toInt32(hgk.goalkeeper_minutes_played) AS opponent_goalkeeper_minutes_played,
    toInt32(agk.goalkeeper_minutes_played - hgk.goalkeeper_minutes_played)
        AS goalkeeper_minutes_played_delta,
    toInt8(if(
        hgk.goalkeeper_fotmob_rating >= mtr.match_highest_player_rating - 0.0001
        AND agk.goalkeeper_fotmob_rating >= mtr.match_highest_player_rating - 0.0001,
        1,
        0
    )) AS both_goalkeepers_top_rated_flag,
    toInt32(coalesce(ps.keeper_saves_away, 0)) AS triggered_team_keeper_saves,
    toInt32(coalesce(ps.keeper_saves_home, 0)) AS opponent_keeper_saves,
    toInt32(coalesce(ps.keeper_saves_away, 0) - coalesce(ps.keeper_saves_home, 0))
        AS keeper_saves_delta,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS triggered_team_shots_on_target_faced,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS opponent_shots_on_target_faced,
    toInt32(coalesce(ps.shots_on_target_home, 0) - coalesce(ps.shots_on_target_away, 0))
        AS shots_on_target_faced_delta,
    toInt32(coalesce(ps.total_shots_home, 0)) AS triggered_team_total_shots_faced,
    toInt32(coalesce(ps.total_shots_away, 0)) AS opponent_total_shots_faced,
    toInt32(coalesce(ps.total_shots_home, 0) - coalesce(ps.total_shots_away, 0))
        AS total_shots_faced_delta,
    toInt32(coalesce(ps.interceptions_away, 0)) AS triggered_team_interceptions,
    toInt32(coalesce(ps.interceptions_home, 0)) AS opponent_interceptions,
    toInt32(coalesce(ps.interceptions_away, 0) - coalesce(ps.interceptions_home, 0))
        AS interceptions_delta,
    toInt32(coalesce(ps.clearances_away, 0)) AS triggered_team_clearances,
    toInt32(coalesce(ps.clearances_home, 0)) AS opponent_clearances,
    toInt32(coalesce(ps.clearances_away, 0) - coalesce(ps.clearances_home, 0))
        AS clearances_delta,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_away, 0) - coalesce(ps.ball_possession_home, 0), 1))
        AS possession_delta_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,
    lm.away_goals AS triggered_team_goals,
    lm.home_goals AS opponent_goals,
    toInt32(lm.away_goals - lm.home_goals) AS goal_delta,
    toInt8(if(lm.home_goals = 0, 1, 0)) AS triggered_team_clean_sheet_flag
FROM low_scoring_matches AS lm
INNER JOIN match_top_rating AS mtr
    ON mtr.match_id = lm.match_id
INNER JOIN team_goalkeeper_top_rating AS hgk
    ON hgk.match_id = lm.match_id
   AND hgk.team_id = lm.home_team_id
INNER JOIN team_goalkeeper_top_rating AS agk
    ON agk.match_id = lm.match_id
   AND agk.team_id = lm.away_team_id
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = lm.match_id
   AND ps.match_date = lm.match_date
   AND ps.period = 'All'
WHERE agk.goalkeeper_fotmob_rating >= mtr.match_highest_player_rating - 0.0001

ORDER BY
    match_highest_player_rating DESC,
    triggered_goalkeeper_fotmob_rating DESC,
    match_date DESC,
    match_id DESC,
    triggered_side;
