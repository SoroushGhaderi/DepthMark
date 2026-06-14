INSERT INTO gold.sig_team_possession_passing_siege_mode (
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
    possession_delta,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_accurate_passes,
    opponent_accurate_passes,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_opposition_half_passes,
    opponent_opposition_half_passes,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    triggered_team_corners,
    opponent_corners,
    triggered_team_shots,
    opponent_shots,
    triggered_team_shots_on_target,
    triggered_team_big_chances,
    opponent_big_chances,
    triggered_team_xg,
    opponent_xg,
    xg_delta
)
-- ============================================================
-- Signal: sig_team_possession_passing_siege_mode
-- Intent: Identify teams sustaining >80% possession as a full-
--         match territorial siege, and evaluate whether that
--         control was productive via progression, final-third
--         pressure, and chance-quality outputs.
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

    -- Signal value: possession split
    assumeNotNull(ps.ball_possession_home) AS triggered_team_possession_pct,
    assumeNotNull(ps.ball_possession_away) AS opponent_possession_pct,
    assumeNotNull(ps.ball_possession_home) - assumeNotNull(ps.ball_possession_away) AS possession_delta,

    -- Passing volume (siege load)
    coalesce(ps.pass_attempts_home, 0)    AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_away, 0)    AS opponent_pass_attempts,
    coalesce(ps.accurate_passes_home, 0)  AS triggered_team_accurate_passes,
    coalesce(ps.accurate_passes_away, 0)  AS opponent_accurate_passes,

    -- Pass accuracy rates (quality vs volume)
    if(coalesce(ps.pass_attempts_home, 0) > 0,
       round(coalesce(ps.accurate_passes_home, 0) / ps.pass_attempts_home * 100, 1),
       NULL)                              AS triggered_team_pass_accuracy_pct,
    if(coalesce(ps.pass_attempts_away, 0) > 0,
       round(coalesce(ps.accurate_passes_away, 0) / ps.pass_attempts_away * 100, 1),
       NULL)                             AS opponent_pass_accuracy_pct,

    -- Progression: how much possession is pushed into the opposition half
    coalesce(ps.opposition_half_passes_home, 0) AS triggered_team_opposition_half_passes,
    coalesce(ps.opposition_half_passes_away, 0) AS opponent_opposition_half_passes,

    -- Final-third penetration (is the siege dangerous?)
    coalesce(ps.touches_opp_box_home, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_away, 0) AS opponent_touches_opposition_box,
    coalesce(ps.corners_home, 0)         AS triggered_team_corners,
    coalesce(ps.corners_away, 0)         AS opponent_corners,

    -- Shot threat generated from dominance
    coalesce(ps.total_shots_home, 0)         AS triggered_team_shots,
    coalesce(ps.total_shots_away, 0)         AS opponent_shots,
    coalesce(ps.shots_on_target_home, 0)     AS triggered_team_shots_on_target,
    coalesce(ps.big_chances_home, 0)         AS triggered_team_big_chances,
    coalesce(ps.big_chances_away, 0)         AS opponent_big_chances,

    -- xG: did dominance translate to genuine chance quality?
    coalesce(ps.expected_goals_home, 0)      AS triggered_team_xg,
    coalesce(ps.expected_goals_away, 0)      AS opponent_xg,
    coalesce(ps.expected_goals_home, 0)
        - coalesce(ps.expected_goals_away, 0) AS xg_delta

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON  ps.match_id = m.match_id
    AND ps.period   = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND assumeNotNull(ps.ball_possession_home) > 80

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

    assumeNotNull(ps.ball_possession_away) AS triggered_team_possession_pct,
    assumeNotNull(ps.ball_possession_home) AS opponent_possession_pct,
    assumeNotNull(ps.ball_possession_away) - assumeNotNull(ps.ball_possession_home) AS possession_delta,

    coalesce(ps.pass_attempts_away, 0)    AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_home, 0)    AS opponent_pass_attempts,
    coalesce(ps.accurate_passes_away, 0)  AS triggered_team_accurate_passes,
    coalesce(ps.accurate_passes_home, 0)  AS opponent_accurate_passes,

    if(coalesce(ps.pass_attempts_away, 0) > 0,
       round(coalesce(ps.accurate_passes_away, 0) / ps.pass_attempts_away * 100, 1),
       NULL)                              AS triggered_team_pass_accuracy_pct,
    if(coalesce(ps.pass_attempts_home, 0) > 0,
       round(coalesce(ps.accurate_passes_home, 0) / ps.pass_attempts_home * 100, 1),
       NULL)                             AS opponent_pass_accuracy_pct,

    coalesce(ps.opposition_half_passes_away, 0) AS triggered_team_opposition_half_passes,
    coalesce(ps.opposition_half_passes_home, 0) AS opponent_opposition_half_passes,

    coalesce(ps.touches_opp_box_away, 0) AS triggered_team_touches_opposition_box,
    coalesce(ps.touches_opp_box_home, 0) AS opponent_touches_opposition_box,
    coalesce(ps.corners_away, 0)         AS triggered_team_corners,
    coalesce(ps.corners_home, 0)         AS opponent_corners,

    coalesce(ps.total_shots_away, 0)         AS triggered_team_shots,
    coalesce(ps.total_shots_home, 0)         AS opponent_shots,
    coalesce(ps.shots_on_target_away, 0)     AS triggered_team_shots_on_target,
    coalesce(ps.big_chances_away, 0)         AS triggered_team_big_chances,
    coalesce(ps.big_chances_home, 0)         AS opponent_big_chances,

    coalesce(ps.expected_goals_away, 0)      AS triggered_team_xg,
    coalesce(ps.expected_goals_home, 0)      AS opponent_xg,
    coalesce(ps.expected_goals_away, 0)
        - coalesce(ps.expected_goals_home, 0) AS xg_delta

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON  ps.match_id = m.match_id
    AND ps.period   = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND assumeNotNull(ps.ball_possession_away) > 80

ORDER BY m.match_date DESC, match_id;
