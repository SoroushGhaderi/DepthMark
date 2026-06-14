INSERT INTO gold.sig_team_possession_passing_low_block_frustration (
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
    triggered_team_cross_attempts,
    opponent_cross_attempts,
    triggered_team_accurate_crosses,
    opponent_accurate_crosses,
    triggered_team_cross_accuracy_pct,
    opponent_cross_accuracy_pct,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    triggered_team_opposition_half_passes,
    opponent_opposition_half_passes,
    triggered_team_dribbles_succeeded,
    opponent_dribbles_succeeded,
    triggered_team_dribble_attempts,
    opponent_dribble_attempts,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_accurate_passes,
    opponent_accurate_passes,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    triggered_team_shots_inside_box,
    opponent_shots_inside_box,
    triggered_team_shots_outside_box,
    opponent_shots_outside_box,
    triggered_team_big_chances,
    opponent_big_chances,
    triggered_team_big_chances_missed,
    opponent_big_chances_missed,
    triggered_team_xg,
    opponent_xg,
    triggered_team_xg_set_play,
    opponent_xg_set_play,
    triggered_team_xg_open_play,
    opponent_xg_open_play,
    xg_delta,
    triggered_team_clearances,
    opponent_clearances,
    triggered_team_interceptions,
    opponent_interceptions,
    triggered_team_shot_blocks,
    opponent_shot_blocks,
    triggered_team_aerials_won,
    opponent_aerials_won,
    triggered_team_aerial_attempts,
    opponent_aerial_attempts,
    triggered_team_corners,
    opponent_corners,
    triggered_team_fouls,
    opponent_fouls
)
-- ============================================================
-- Signal: sig_team_possession_passing_low_block_frustration
-- Intent: Detect matches where a team attempts >40 crosses,
--         indicating central-access denial and wide-overload
--         frustration; enrich with penetration, chance quality,
--         and defensive-resistance context to validate low-block
--         causality versus stylistic crossing.
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

    -- Signal values: cross volume as wide-overload proxy
    coalesce(ps.cross_attempts_home, 0)           AS triggered_team_cross_attempts,
    coalesce(ps.cross_attempts_away, 0)           AS opponent_cross_attempts,
    coalesce(ps.accurate_crosses_home, 0)         AS triggered_team_accurate_crosses,
    coalesce(ps.accurate_crosses_away, 0)         AS opponent_accurate_crosses,
    if(coalesce(ps.cross_attempts_home, 0) > 0,
       round(coalesce(ps.accurate_crosses_home, 0) / ps.cross_attempts_home * 100, 1),
       NULL)                                      AS triggered_team_cross_accuracy_pct,
    if(coalesce(ps.cross_attempts_away, 0) > 0,
       round(coalesce(ps.accurate_crosses_away, 0) / ps.cross_attempts_away * 100, 1),
       NULL)                                      AS opponent_cross_accuracy_pct,

    -- Central penetration proxies: low values confirm the middle was locked
    coalesce(ps.touches_opp_box_home, 0)          AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_away, 0)          AS opponent_touches_opposition_box,
    coalesce(ps.opposition_half_passes_home, 0)   AS triggered_team_opposition_half_passes,
    coalesce(ps.opposition_half_passes_away, 0)   AS opponent_opposition_half_passes,
    coalesce(ps.dribbles_succeeded_home, 0)       AS triggered_team_dribbles_succeeded,
    coalesce(ps.dribbles_succeeded_away, 0)       AS opponent_dribbles_succeeded,
    coalesce(ps.dribble_attempts_home, 0)         AS triggered_team_dribble_attempts,
    coalesce(ps.dribble_attempts_away, 0)         AS opponent_dribble_attempts,

    -- Possession context: dominance establishes the siege framing
    assumeNotNull(ps.ball_possession_home)        AS triggered_team_possession_pct,
    assumeNotNull(ps.ball_possession_away)        AS opponent_possession_pct,
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

    -- Shot output: did the wide overload eventually yield attempts?
    coalesce(ps.total_shots_home, 0)              AS triggered_team_total_shots,
    coalesce(ps.total_shots_away, 0)              AS opponent_total_shots,
    coalesce(ps.shots_on_target_home, 0)          AS triggered_team_shots_on_target,
    coalesce(ps.shots_on_target_away, 0)          AS opponent_shots_on_target,
    coalesce(ps.shots_inside_box_home, 0)         AS triggered_team_shots_inside_box,
    coalesce(ps.shots_inside_box_away, 0)         AS opponent_shots_inside_box,
    coalesce(ps.shots_outside_box_home, 0)        AS triggered_team_shots_outside_box,
    coalesce(ps.shots_outside_box_away, 0)        AS opponent_shots_outside_box,
    coalesce(ps.big_chances_home, 0)              AS triggered_team_big_chances,
    coalesce(ps.big_chances_away, 0)              AS opponent_big_chances,
    coalesce(ps.big_chances_missed_home, 0)       AS triggered_team_big_chances_missed,
    coalesce(ps.big_chances_missed_away, 0)       AS opponent_big_chances_missed,

    -- xG: cross-heavy attacks often produce low-quality headers — validate here
    coalesce(ps.expected_goals_home, 0)           AS triggered_team_xg,
    coalesce(ps.expected_goals_away, 0)           AS opponent_xg,
    coalesce(ps.expected_goals_set_play_home, 0)  AS triggered_team_xg_set_play,
    coalesce(ps.expected_goals_set_play_away, 0)  AS opponent_xg_set_play,
    coalesce(ps.expected_goals_open_play_home, 0) AS triggered_team_xg_open_play,
    coalesce(ps.expected_goals_open_play_away, 0) AS opponent_xg_open_play,
    round(coalesce(ps.expected_goals_home, 0)
        - coalesce(ps.expected_goals_away, 0), 3) AS xg_delta,

    -- Opponent defensive solidity: confirms a genuine low block was present
    coalesce(ps.clearances_home, 0)               AS triggered_team_clearances,
    coalesce(ps.clearances_away, 0)               AS opponent_clearances,
    coalesce(ps.interceptions_home, 0)            AS triggered_team_interceptions,
    coalesce(ps.interceptions_away, 0)            AS opponent_interceptions,
    coalesce(ps.shot_blocks_home, 0)              AS triggered_team_shot_blocks,
    coalesce(ps.shot_blocks_away, 0)              AS opponent_shot_blocks,
    coalesce(ps.aerials_won_home, 0)              AS triggered_team_aerials_won,
    coalesce(ps.aerials_won_away, 0)              AS opponent_aerials_won,
    coalesce(ps.aerial_attempts_home, 0)          AS triggered_team_aerial_attempts,
    coalesce(ps.aerial_attempts_away, 0)          AS opponent_aerial_attempts,

    -- Corners: high-cross volume typically co-occurs with corner accumulation
    coalesce(ps.corners_home, 0)                  AS triggered_team_corners,
    coalesce(ps.corners_away, 0)                  AS opponent_corners,

    -- Fouls: opponent foul rate reveals how aggressively the block was defended
    coalesce(ps.fouls_home, 0)                    AS triggered_team_fouls,
    coalesce(ps.fouls_away, 0)                    AS opponent_fouls

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON  ps.match_id = m.match_id
    AND ps.period   = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ps.cross_attempts_home, 0) > 40

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

    coalesce(ps.cross_attempts_away, 0)           AS triggered_team_cross_attempts,
    coalesce(ps.cross_attempts_home, 0)           AS opponent_cross_attempts,
    coalesce(ps.accurate_crosses_away, 0)         AS triggered_team_accurate_crosses,
    coalesce(ps.accurate_crosses_home, 0)         AS opponent_accurate_crosses,
    if(coalesce(ps.cross_attempts_away, 0) > 0,
       round(coalesce(ps.accurate_crosses_away, 0) / ps.cross_attempts_away * 100, 1),
       NULL)                                      AS triggered_team_cross_accuracy_pct,
    if(coalesce(ps.cross_attempts_home, 0) > 0,
       round(coalesce(ps.accurate_crosses_home, 0) / ps.cross_attempts_home * 100, 1),
       NULL)                                      AS opponent_cross_accuracy_pct,

    coalesce(ps.touches_opp_box_away, 0)          AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_home, 0)          AS opponent_touches_opposition_box,
    coalesce(ps.opposition_half_passes_away, 0)   AS triggered_team_opposition_half_passes,
    coalesce(ps.opposition_half_passes_home, 0)   AS opponent_opposition_half_passes,
    coalesce(ps.dribbles_succeeded_away, 0)       AS triggered_team_dribbles_succeeded,
    coalesce(ps.dribbles_succeeded_home, 0)       AS opponent_dribbles_succeeded,
    coalesce(ps.dribble_attempts_away, 0)         AS triggered_team_dribble_attempts,
    coalesce(ps.dribble_attempts_home, 0)         AS opponent_dribble_attempts,

    assumeNotNull(ps.ball_possession_away)        AS triggered_team_possession_pct,
    assumeNotNull(ps.ball_possession_home)        AS opponent_possession_pct,
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

    coalesce(ps.total_shots_away, 0)              AS triggered_team_total_shots,
    coalesce(ps.total_shots_home, 0)              AS opponent_total_shots,
    coalesce(ps.shots_on_target_away, 0)          AS triggered_team_shots_on_target,
    coalesce(ps.shots_on_target_home, 0)          AS opponent_shots_on_target,
    coalesce(ps.shots_inside_box_away, 0)         AS triggered_team_shots_inside_box,
    coalesce(ps.shots_inside_box_home, 0)         AS opponent_shots_inside_box,
    coalesce(ps.shots_outside_box_away, 0)        AS triggered_team_shots_outside_box,
    coalesce(ps.shots_outside_box_home, 0)        AS opponent_shots_outside_box,
    coalesce(ps.big_chances_away, 0)              AS triggered_team_big_chances,
    coalesce(ps.big_chances_home, 0)              AS opponent_big_chances,
    coalesce(ps.big_chances_missed_away, 0)       AS triggered_team_big_chances_missed,
    coalesce(ps.big_chances_missed_home, 0)       AS opponent_big_chances_missed,

    coalesce(ps.expected_goals_away, 0)           AS triggered_team_xg,
    coalesce(ps.expected_goals_home, 0)           AS opponent_xg,
    coalesce(ps.expected_goals_set_play_away, 0)  AS triggered_team_xg_set_play,
    coalesce(ps.expected_goals_set_play_home, 0)  AS opponent_xg_set_play,
    coalesce(ps.expected_goals_open_play_away, 0) AS triggered_team_xg_open_play,
    coalesce(ps.expected_goals_open_play_home, 0) AS opponent_xg_open_play,
    round(coalesce(ps.expected_goals_away, 0)
        - coalesce(ps.expected_goals_home, 0), 3) AS xg_delta,

    coalesce(ps.clearances_away, 0)               AS triggered_team_clearances,
    coalesce(ps.clearances_home, 0)               AS opponent_clearances,
    coalesce(ps.interceptions_away, 0)            AS triggered_team_interceptions,
    coalesce(ps.interceptions_home, 0)            AS opponent_interceptions,
    coalesce(ps.shot_blocks_away, 0)              AS triggered_team_shot_blocks,
    coalesce(ps.shot_blocks_home, 0)              AS opponent_shot_blocks,
    coalesce(ps.aerials_won_away, 0)              AS triggered_team_aerials_won,
    coalesce(ps.aerials_won_home, 0)              AS opponent_aerials_won,
    coalesce(ps.aerial_attempts_away, 0)          AS triggered_team_aerial_attempts,
    coalesce(ps.aerial_attempts_home, 0)          AS opponent_aerial_attempts,

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
  AND coalesce(ps.cross_attempts_away, 0) > 40

ORDER BY m.match_date DESC, match_id;
