INSERT INTO gold.sig_team_possession_passing_efficient_directness (
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
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    triggered_team_shots_inside_box,
    opponent_shots_inside_box,
    triggered_team_big_chances,
    opponent_big_chances,
    triggered_team_big_chances_missed,
    opponent_big_chances_missed,
    triggered_team_xg,
    opponent_xg,
    triggered_team_xg_open_play,
    opponent_xg_open_play,
    triggered_team_xg_on_target,
    opponent_xg_on_target,
    xg_delta,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_accurate_passes,
    opponent_accurate_passes,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_long_ball_attempts,
    opponent_long_ball_attempts,
    triggered_team_accurate_long_balls,
    opponent_accurate_long_balls,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    triggered_team_opposition_half_passes,
    opponent_opposition_half_passes,
    triggered_team_interceptions,
    opponent_interceptions,
    triggered_team_tackles_won,
    opponent_tackles_won,
    triggered_team_clearances,
    opponent_clearances,
    triggered_team_cross_attempts,
    opponent_cross_attempts,
    triggered_team_accurate_crosses,
    opponent_accurate_crosses,
    triggered_team_corners,
    opponent_corners,
    triggered_team_fouls,
    opponent_fouls
)
-- ============================================================
-- Signal: sig_team_possession_passing_efficient_directness
-- Intent: Identify teams generating >=15 shots with <=35%
--         possession, capturing efficient direct/transition
--         threat and contrasting it with opponent control via
--         shot quality, progression, and recovery context.
-- ============================================================

-- Home side triggers the signal
SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    -- Signal: triggered team identity
    'home'           AS triggered_side,
    m.home_team_id   AS triggered_team_id,
    m.home_team_name AS triggered_team_name,
    m.away_team_id   AS opponent_team_id,
    m.away_team_name AS opponent_team_name,

    -- Signal values: low possession + high shot volume
    assumeNotNull(ps.ball_possession_home)        AS triggered_team_possession_pct,
    assumeNotNull(ps.ball_possession_away)        AS opponent_possession_pct,
    coalesce(ps.total_shots_home, 0)              AS triggered_team_total_shots,
    coalesce(ps.total_shots_away, 0)              AS opponent_total_shots,

    -- Shot quality: is directness converting into genuine threat?
    coalesce(ps.shots_on_target_home, 0)          AS triggered_team_shots_on_target,
    coalesce(ps.shots_on_target_away, 0)          AS opponent_shots_on_target,
    coalesce(ps.shots_inside_box_home, 0)         AS triggered_team_shots_inside_box,
    coalesce(ps.shots_inside_box_away, 0)         AS opponent_shots_inside_box,
    coalesce(ps.big_chances_home, 0)              AS triggered_team_big_chances,
    coalesce(ps.big_chances_away, 0)              AS opponent_big_chances,
    coalesce(ps.big_chances_missed_home, 0)       AS triggered_team_big_chances_missed,
    coalesce(ps.big_chances_missed_away, 0)       AS opponent_big_chances_missed,

    -- xG: shot volume must be validated against expected quality
    coalesce(ps.expected_goals_home, 0)           AS triggered_team_xg,
    coalesce(ps.expected_goals_away, 0)           AS opponent_xg,
    coalesce(ps.expected_goals_open_play_home, 0) AS triggered_team_xg_open_play,
    coalesce(ps.expected_goals_open_play_away, 0) AS opponent_xg_open_play,
    coalesce(ps.expected_goals_on_target_home, 0) AS triggered_team_xg_on_target,
    coalesce(ps.expected_goals_on_target_away, 0) AS opponent_xg_on_target,
    round(coalesce(ps.expected_goals_home, 0)
        - coalesce(ps.expected_goals_away, 0), 3) AS xg_delta,

    -- Directness proxies: long balls and low pass volume signal vertical intent
    coalesce(ps.pass_attempts_home, 0)            AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_away, 0)            AS opponent_pass_attempts,
    coalesce(ps.accurate_passes_home, 0)          AS triggered_team_accurate_passes,
    coalesce(ps.accurate_passes_away, 0)          AS opponent_accurate_passes,
    if(coalesce(ps.pass_attempts_home, 0) > 0,
       round(coalesce(ps.accurate_passes_home, 0) / ps.pass_attempts_home * 100, 1),
       NULL)                                      AS triggered_team_pass_accuracy_pct,
    if(coalesce(ps.pass_attempts_away, 0) > 0,
       round(coalesce(ps.accurate_passes_away, 0) / ps.pass_attempts_away * 100, 1),
       NULL)                                      AS opponent_pass_accuracy_pct,
    coalesce(ps.long_ball_attempts_home, 0)       AS triggered_team_long_ball_attempts,
    coalesce(ps.long_ball_attempts_away, 0)       AS opponent_long_ball_attempts,
    coalesce(ps.accurate_long_balls_home, 0)      AS triggered_team_accurate_long_balls,
    coalesce(ps.accurate_long_balls_away, 0)      AS opponent_accurate_long_balls,

    -- Transition threat: final-third penetration with minimal possession
    coalesce(ps.touches_opp_box_home, 0)          AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_away, 0)          AS opponent_touches_opposition_box,
    coalesce(ps.opposition_half_passes_home, 0)   AS triggered_team_opposition_half_passes,
    coalesce(ps.opposition_half_passes_away, 0)   AS opponent_opposition_half_passes,

    -- Ball-winning: how is the triggered team recovering possession to transition?
    coalesce(ps.interceptions_home, 0)            AS triggered_team_interceptions,
    coalesce(ps.interceptions_away, 0)            AS opponent_interceptions,
    coalesce(ps.tackles_succeeded_home, 0)        AS triggered_team_tackles_won,
    coalesce(ps.tackles_succeeded_away, 0)        AS opponent_tackles_won,
    coalesce(ps.clearances_home, 0)               AS triggered_team_clearances,
    coalesce(ps.clearances_away, 0)               AS opponent_clearances,

    -- Opponent's wide-channel output: are they over-committing to attack?
    coalesce(ps.cross_attempts_home, 0)           AS triggered_team_cross_attempts,
    coalesce(ps.cross_attempts_away, 0)           AS opponent_cross_attempts,
    coalesce(ps.accurate_crosses_home, 0)         AS triggered_team_accurate_crosses,
    coalesce(ps.accurate_crosses_away, 0)         AS opponent_accurate_crosses,

    -- Set-piece efficiency: corners and fouls drawn as transition by-products
    coalesce(ps.corners_home, 0)                  AS triggered_team_corners,
    coalesce(ps.corners_away, 0)                  AS opponent_corners,
    coalesce(ps.fouls_home, 0)                    AS triggered_team_fouls,
    coalesce(ps.fouls_away, 0)                    AS opponent_fouls

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON  ps.match_id = m.match_id
    AND ps.period   = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND assumeNotNull(ps.ball_possession_home) <= 35
  AND coalesce(ps.total_shots_home, 0) >= 15

UNION ALL

-- Away side triggers the signal
SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    'away'           AS triggered_side,
    m.away_team_id   AS triggered_team_id,
    m.away_team_name AS triggered_team_name,
    m.home_team_id   AS opponent_team_id,
    m.home_team_name AS opponent_team_name,

    assumeNotNull(ps.ball_possession_away)        AS triggered_team_possession_pct,
    assumeNotNull(ps.ball_possession_home)        AS opponent_possession_pct,
    coalesce(ps.total_shots_away, 0)              AS triggered_team_total_shots,
    coalesce(ps.total_shots_home, 0)              AS opponent_total_shots,

    coalesce(ps.shots_on_target_away, 0)          AS triggered_team_shots_on_target,
    coalesce(ps.shots_on_target_home, 0)          AS opponent_shots_on_target,
    coalesce(ps.shots_inside_box_away, 0)         AS triggered_team_shots_inside_box,
    coalesce(ps.shots_inside_box_home, 0)         AS opponent_shots_inside_box,
    coalesce(ps.big_chances_away, 0)              AS triggered_team_big_chances,
    coalesce(ps.big_chances_home, 0)              AS opponent_big_chances,
    coalesce(ps.big_chances_missed_away, 0)       AS triggered_team_big_chances_missed,
    coalesce(ps.big_chances_missed_home, 0)       AS opponent_big_chances_missed,

    coalesce(ps.expected_goals_away, 0)           AS triggered_team_xg,
    coalesce(ps.expected_goals_home, 0)           AS opponent_xg,
    coalesce(ps.expected_goals_open_play_away, 0) AS triggered_team_xg_open_play,
    coalesce(ps.expected_goals_open_play_home, 0) AS opponent_xg_open_play,
    coalesce(ps.expected_goals_on_target_away, 0) AS triggered_team_xg_on_target,
    coalesce(ps.expected_goals_on_target_home, 0) AS opponent_xg_on_target,
    round(coalesce(ps.expected_goals_away, 0)
        - coalesce(ps.expected_goals_home, 0), 3) AS xg_delta,

    coalesce(ps.pass_attempts_away, 0)            AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_home, 0)            AS opponent_pass_attempts,
    coalesce(ps.accurate_passes_away, 0)          AS triggered_team_accurate_passes,
    coalesce(ps.accurate_passes_home, 0)          AS opponent_accurate_passes,
    if(coalesce(ps.pass_attempts_away, 0) > 0,
       round(coalesce(ps.accurate_passes_away, 0) / ps.pass_attempts_away * 100, 1),
       NULL)                                      AS triggered_team_pass_accuracy_pct,
    if(coalesce(ps.pass_attempts_home, 0) > 0,
       round(coalesce(ps.accurate_passes_home, 0) / ps.pass_attempts_home * 100, 1),
       NULL)                                      AS opponent_pass_accuracy_pct,
    coalesce(ps.long_ball_attempts_away, 0)       AS triggered_team_long_ball_attempts,
    coalesce(ps.long_ball_attempts_home, 0)       AS opponent_long_ball_attempts,
    coalesce(ps.accurate_long_balls_away, 0)      AS triggered_team_accurate_long_balls,
    coalesce(ps.accurate_long_balls_home, 0)      AS opponent_accurate_long_balls,

    coalesce(ps.touches_opp_box_away, 0)          AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_home, 0)          AS opponent_touches_opposition_box,
    coalesce(ps.opposition_half_passes_away, 0)   AS triggered_team_opposition_half_passes,
    coalesce(ps.opposition_half_passes_home, 0)   AS opponent_opposition_half_passes,

    coalesce(ps.interceptions_away, 0)            AS triggered_team_interceptions,
    coalesce(ps.interceptions_home, 0)            AS opponent_interceptions,
    coalesce(ps.tackles_succeeded_away, 0)        AS triggered_team_tackles_won,
    coalesce(ps.tackles_succeeded_home, 0)        AS opponent_tackles_won,
    coalesce(ps.clearances_away, 0)               AS triggered_team_clearances,
    coalesce(ps.clearances_home, 0)               AS opponent_clearances,

    coalesce(ps.cross_attempts_away, 0)           AS triggered_team_cross_attempts,
    coalesce(ps.cross_attempts_home, 0)           AS opponent_cross_attempts,
    coalesce(ps.accurate_crosses_away, 0)         AS triggered_team_accurate_crosses,
    coalesce(ps.accurate_crosses_home, 0)         AS opponent_accurate_crosses,

    coalesce(ps.corners_away, 0)                  AS triggered_team_corners,
    coalesce(ps.corners_home, 0)                  AS opponent_corners,
    coalesce(ps.fouls_away, 0)                    AS triggered_team_fouls,
    coalesce(ps.fouls_home, 0)                    AS opponent_fouls

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON  ps.match_id = m.match_id
    AND ps.period   = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND assumeNotNull(ps.ball_possession_away) <= 35
  AND coalesce(ps.total_shots_away, 0) >= 15

ORDER BY m.match_date DESC, match_id;
