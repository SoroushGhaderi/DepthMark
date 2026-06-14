INSERT INTO gold.sig_team_possession_passing_death_by_passes (
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
    both_sides_triggered,
    triggered_team_opposition_box_touches,
    opponent_opposition_box_touches,
    opposition_box_touches_delta,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_opposition_half_passes,
    opponent_opposition_half_passes,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_box_touch_per_pass_pct,
    opponent_box_touch_per_pass_pct,
    triggered_team_xg,
    opponent_xg,
    triggered_team_xg_per_box_touch,
    opponent_xg_per_box_touch,
    xg_delta,
    triggered_team_big_chances,
    opponent_big_chances,
    triggered_team_big_chances_missed,
    opponent_big_chances_missed,
    triggered_team_shots_inside_box,
    opponent_shots_inside_box,
    triggered_team_corners,
    opponent_corners,
    triggered_team_accurate_crosses,
    opponent_accurate_crosses
)
-- ============================================================
-- Signal: sig_team_possession_passing_death_by_passes
-- Intent: Identify matches where a team accumulates >50 touches
--         in the opposition box across the full match — a proxy
--         for sustained, suffocating final-third dominance that
--         signals siege-style possession, relentless overloads,
--         or an opponent pinned into a deep defensive block.
--         Columns are resolved dynamically: triggered_team_* is
--         always the side that fired the signal; opponent_* is
--         always the other side. When both sides trigger, the
--         home team is treated as the primary triggered team.
-- ============================================================

SELECT
    -- Identifiers
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        'home',
        'away'
    )                                                                                           AS triggered_side,

    -- Triggered team identity — resolved dynamically
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        m.home_team_id,
        m.away_team_id
    )                                                                                           AS triggered_team_id,
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        m.home_team_name,
        m.away_team_name
    )                                                                                           AS triggered_team_name,
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        m.away_team_id,
        m.home_team_id
    )                                                                                           AS opponent_team_id,
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        m.away_team_name,
        m.home_team_name
    )                                                                                           AS opponent_team_name,

    -- Flag: both sides simultaneously exceeded the threshold
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50
        AND coalesce(ps.touches_opp_box_away, 0) > 50,
        1, 0
    )                                                                                           AS both_sides_triggered,

    -- Signal value: opposition-box touches for triggered team and opponent (symmetric pair)
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.touches_opp_box_home, 0),
        coalesce(ps.touches_opp_box_away, 0)
    )                                                                                           AS triggered_team_opposition_box_touches,
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.touches_opp_box_away, 0),
        coalesce(ps.touches_opp_box_home, 0)
    )                                                                                           AS opponent_opposition_box_touches,

    -- Box touch differential — net spatial dominance in the final third (bilateral by construction)
    (coalesce(ps.touches_opp_box_home, 0) - coalesce(ps.touches_opp_box_away, 0))              AS opposition_box_touches_delta,

    -- Possession share — sustained box presence should align with possession control (symmetric pair)
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.ball_possession_home, 0),
        coalesce(ps.ball_possession_away, 0)
    )                                                                                           AS triggered_team_possession_pct,
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.ball_possession_away, 0),
        coalesce(ps.ball_possession_home, 0)
    )                                                                                           AS opponent_possession_pct,

    -- Opposition-half passes — confirms advanced territorial operation enabling box penetration (symmetric pair)
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.opposition_half_passes_home, 0),
        coalesce(ps.opposition_half_passes_away, 0)
    )                                                                                           AS triggered_team_opposition_half_passes,
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.opposition_half_passes_away, 0),
        coalesce(ps.opposition_half_passes_home, 0)
    )                                                                                           AS opponent_opposition_half_passes,

    -- Total pass attempts — denominates box touches within overall passing activity (symmetric pair)
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.pass_attempts_home, 0),
        coalesce(ps.pass_attempts_away, 0)
    )                                                                                           AS triggered_team_pass_attempts,
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.pass_attempts_away, 0),
        coalesce(ps.pass_attempts_home, 0)
    )                                                                                           AS opponent_pass_attempts,

    -- Pass accuracy — high touch counts with poor accuracy = chaotic, not controlled dominance (symmetric pair)
    round(if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.accurate_passes_home, 0),
        coalesce(ps.accurate_passes_away, 0)
    ) / nullIf(if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.pass_attempts_home, 0),
        coalesce(ps.pass_attempts_away, 0)
    ), 0) * 100, 1)                                                                             AS triggered_team_pass_accuracy_pct,
    round(if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.accurate_passes_away, 0),
        coalesce(ps.accurate_passes_home, 0)
    ) / nullIf(if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.pass_attempts_away, 0),
        coalesce(ps.pass_attempts_home, 0)
    ), 0) * 100, 1)                                                                             AS opponent_pass_accuracy_pct,

    -- Box touches per pass attempt — efficiency of possession funnelled into box-level activity (symmetric pair)
    round(if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.touches_opp_box_home, 0),
        coalesce(ps.touches_opp_box_away, 0)
    ) / nullIf(if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.pass_attempts_home, 0),
        coalesce(ps.pass_attempts_away, 0)
    ), 0) * 100, 2)                                                                             AS triggered_team_box_touch_per_pass_pct,
    round(if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.touches_opp_box_away, 0),
        coalesce(ps.touches_opp_box_home, 0)
    ) / nullIf(if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.pass_attempts_away, 0),
        coalesce(ps.pass_attempts_home, 0)
    ), 0) * 100, 2)                                                                             AS opponent_box_touch_per_pass_pct,

    -- xG — did sustained box presence generate high-quality chances? (symmetric pair)
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.expected_goals_home, 0),
        coalesce(ps.expected_goals_away, 0)
    )                                                                                           AS triggered_team_xg,
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.expected_goals_away, 0),
        coalesce(ps.expected_goals_home, 0)
    )                                                                                           AS opponent_xg,

    -- xG per box touch — quality efficiency of box entries; low = sterile domination (symmetric pair)
    round(if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.expected_goals_home, 0),
        coalesce(ps.expected_goals_away, 0)
    ) / nullIf(if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.touches_opp_box_home, 0),
        coalesce(ps.touches_opp_box_away, 0)
    ), 0), 4)                                                                                   AS triggered_team_xg_per_box_touch,
    round(if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.expected_goals_away, 0),
        coalesce(ps.expected_goals_home, 0)
    ) / nullIf(if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.touches_opp_box_away, 0),
        coalesce(ps.touches_opp_box_home, 0)
    ), 0), 4)                                                                                   AS opponent_xg_per_box_touch,

    -- xG net — overall attacking threat imbalance (bilateral by construction)
    (coalesce(ps.expected_goals_home, 0) - coalesce(ps.expected_goals_away, 0))                AS xg_delta,

    -- Big chances — tests whether box dominance yielded clear-cut opportunities (symmetric pair)
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.big_chances_home, 0),
        coalesce(ps.big_chances_away, 0)
    )                                                                                           AS triggered_team_big_chances,
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.big_chances_away, 0),
        coalesce(ps.big_chances_home, 0)
    )                                                                                           AS opponent_big_chances,

    -- Big chances missed — clinical failure despite territorial control (symmetric pair)
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.big_chances_missed_home, 0),
        coalesce(ps.big_chances_missed_away, 0)
    )                                                                                           AS triggered_team_big_chances_missed,
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.big_chances_missed_away, 0),
        coalesce(ps.big_chances_missed_home, 0)
    )                                                                                           AS opponent_big_chances_missed,

    -- Shots inside box — confirms touches converted into close-range attempts (symmetric pair)
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.shots_inside_box_home, 0),
        coalesce(ps.shots_inside_box_away, 0)
    )                                                                                           AS triggered_team_shots_inside_box,
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.shots_inside_box_away, 0),
        coalesce(ps.shots_inside_box_home, 0)
    )                                                                                           AS opponent_shots_inside_box,

    -- Corners — correlates with sustained box-area pressure and failed clearances (symmetric pair)
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.corners_home, 0),
        coalesce(ps.corners_away, 0)
    )                                                                                           AS triggered_team_corners,
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.corners_away, 0),
        coalesce(ps.corners_home, 0)
    )                                                                                           AS opponent_corners,

    -- Accurate crosses — delivery volume feeding box touch accumulation (symmetric pair)
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.accurate_crosses_home, 0),
        coalesce(ps.accurate_crosses_away, 0)
    )                                                                                           AS triggered_team_accurate_crosses,
    if(
        coalesce(ps.touches_opp_box_home, 0) > 50,
        coalesce(ps.accurate_crosses_away, 0),
        coalesce(ps.accurate_crosses_home, 0)
    )                                                                                           AS opponent_accurate_crosses

FROM silver.match AS m
-- Full-match aggregated stats only
INNER JOIN silver.period_stat AS ps
    ON  ps.match_id = m.match_id
    AND ps.period   = 'All'

WHERE
    m.match_finished = 1
    AND m.match_id > 0
    -- Data quality: box touch data must be present for at least one side
    AND (ps.touches_opp_box_home IS NOT NULL OR ps.touches_opp_box_away IS NOT NULL)
    -- Signal filter: at least one team exceeded 50 opposition-box touches
    AND (
           coalesce(ps.touches_opp_box_home, 0) > 50
        OR coalesce(ps.touches_opp_box_away, 0) > 50
    )

-- Surface the most extreme cases of box domination first
ORDER BY
    greatest(
        coalesce(ps.touches_opp_box_home, 0),
        coalesce(ps.touches_opp_box_away, 0)
    ) DESC;
