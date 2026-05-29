INSERT INTO gold.sig_team_possession_passing_long_ball_desperation (
    match_id,
    match_date,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,
    triggered_side,
    score_margin_home_perspective,
    triggered_team_id,
    triggered_team_name,
    opponent_team_id,
    opponent_team_name,
    triggered_team_long_ball_attempts,
    opponent_long_ball_attempts,
    long_ball_attempts_delta,
    triggered_team_accurate_long_balls,
    opponent_accurate_long_balls,
    triggered_team_long_ball_accuracy_pct,
    opponent_long_ball_accuracy_pct,
    triggered_team_long_ball_share_pct,
    opponent_long_ball_share_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_aerials_won,
    opponent_aerials_won,
    triggered_team_aerial_success_pct,
    opponent_aerial_success_pct,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_clearances_conceded,
    opponent_clearances_conceded
)
-- ============================================================
-- Signal: sig_team_possession_passing_long_ball_desperation
-- Intent: Detect matches where the losing team attempts more
--         than 60 long balls — a tactical fingerprint of
--         desperation: a side unable to build through the lines
--         resorting to direct, bypassing distribution to chase
--         the game. High long-ball volume under a losing scoreline
--         signals pressing discomfort, midfield bypass, aerial
--         overload attempts, or a complete breakdown in
--         structured build-up play.
--         Trigger resolves to the losing side only; draws are
--         excluded by construction since neither team is losing.
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
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        'home',
        'away'
    )                                                                                           AS triggered_side,

    -- Score margin — size of the deficit driving desperation behaviour (bilateral by construction)
    (coalesce(m.home_score, 0) - coalesce(m.away_score, 0))                                    AS score_margin_home_perspective,

    -- Triggered team identity — always the losing side that crossed the long-ball threshold
    if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        m.home_team_id,
        m.away_team_id
    )                                                                                           AS triggered_team_id,
    if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        m.home_team_name,
        m.away_team_name
    )                                                                                           AS triggered_team_name,
    if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        m.away_team_id,
        m.home_team_id
    )                                                                                           AS opponent_team_id,
    if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        m.away_team_name,
        m.home_team_name
    )                                                                                           AS opponent_team_name,

    -- Signal value: long-ball attempts for triggered team and opponent (symmetric pair)
    if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.long_ball_attempts_home, 0),
        coalesce(ps.long_ball_attempts_away, 0)
    )                                                                                           AS triggered_team_long_ball_attempts,
    if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.long_ball_attempts_away, 0),
        coalesce(ps.long_ball_attempts_home, 0)
    )                                                                                           AS opponent_long_ball_attempts,

    -- Long-ball attempt differential — net aerial bypass volume imbalance (bilateral by construction)
    (coalesce(ps.long_ball_attempts_home, 0) - coalesce(ps.long_ball_attempts_away, 0))        AS long_ball_attempts_delta,

    -- Accurate long balls — does desperation volume retain any directional precision? (symmetric pair)
    if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.accurate_long_balls_home, 0),
        coalesce(ps.accurate_long_balls_away, 0)
    )                                                                                           AS triggered_team_accurate_long_balls,
    if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.accurate_long_balls_away, 0),
        coalesce(ps.accurate_long_balls_home, 0)
    )                                                                                           AS opponent_accurate_long_balls,

    -- Long-ball accuracy rate — low accuracy confirms panic distribution vs. deliberate direct play (symmetric pair)
    round(if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.accurate_long_balls_home, 0),
        coalesce(ps.accurate_long_balls_away, 0)
    ) / nullIf(if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.long_ball_attempts_home, 0),
        coalesce(ps.long_ball_attempts_away, 0)
    ), 0) * 100, 1)                                                                             AS triggered_team_long_ball_accuracy_pct,
    round(if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.accurate_long_balls_away, 0),
        coalesce(ps.accurate_long_balls_home, 0)
    ) / nullIf(if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.long_ball_attempts_away, 0),
        coalesce(ps.long_ball_attempts_home, 0)
    ), 0) * 100, 1)                                                                             AS opponent_long_ball_accuracy_pct,

    -- Long balls as share of total passes — measures how extreme the tactical shift was (symmetric pair)
    round(if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.long_ball_attempts_home, 0),
        coalesce(ps.long_ball_attempts_away, 0)
    ) / nullIf(if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.pass_attempts_home, 0),
        coalesce(ps.pass_attempts_away, 0)
    ), 0) * 100, 1)                                                                             AS triggered_team_long_ball_share_pct,
    round(if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.long_ball_attempts_away, 0),
        coalesce(ps.long_ball_attempts_home, 0)
    ) / nullIf(if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.pass_attempts_away, 0),
        coalesce(ps.pass_attempts_home, 0)
    ), 0) * 100, 1)                                                                             AS opponent_long_ball_share_pct,

    -- Overall pass accuracy — low accuracy alongside high long-ball volume confirms build-up collapse (symmetric pair)
    round(if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.accurate_passes_home, 0),
        coalesce(ps.accurate_passes_away, 0)
    ) / nullIf(if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.pass_attempts_home, 0),
        coalesce(ps.pass_attempts_away, 0)
    ), 0) * 100, 1)                                                                             AS triggered_team_pass_accuracy_pct,
    round(if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.accurate_passes_away, 0),
        coalesce(ps.accurate_passes_home, 0)
    ) / nullIf(if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.pass_attempts_away, 0),
        coalesce(ps.pass_attempts_home, 0)
    ), 0) * 100, 1)                                                                             AS opponent_pass_accuracy_pct,

    -- Possession share — losing teams with low possession resort to direct play more often (symmetric pair)
    if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.ball_possession_home, 0),
        coalesce(ps.ball_possession_away, 0)
    )                                                                                           AS triggered_team_possession_pct,
    if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.ball_possession_away, 0),
        coalesce(ps.ball_possession_home, 0)
    )                                                                                           AS opponent_possession_pct,

    -- Aerial duels won — quantifies whether the long-ball route was actually winning second balls (symmetric pair)
    if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.aerials_won_home, 0),
        coalesce(ps.aerials_won_away, 0)
    )                                                                                           AS triggered_team_aerials_won,
    if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.aerials_won_away, 0),
        coalesce(ps.aerials_won_home, 0)
    )                                                                                           AS opponent_aerials_won,

    -- Aerial duel success rate — low win rate exposes the long-ball route as ineffective (symmetric pair)
    round(if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.aerials_won_home, 0),
        coalesce(ps.aerials_won_away, 0)
    ) / nullIf(if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.aerial_attempts_home, 0),
        coalesce(ps.aerial_attempts_away, 0)
    ), 0) * 100, 1)                                                                             AS triggered_team_aerial_success_pct,
    round(if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.aerials_won_away, 0),
        coalesce(ps.aerials_won_home, 0)
    ) / nullIf(if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.aerial_attempts_away, 0),
        coalesce(ps.aerial_attempts_home, 0)
    ), 0) * 100, 1)                                                                             AS opponent_aerial_success_pct,

    -- xG — despite desperation volume, did the long-ball route manufacture genuine chances? (symmetric pair)
    if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.expected_goals_home, 0),
        coalesce(ps.expected_goals_away, 0)
    )                                                                                           AS triggered_team_xg,
    if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.expected_goals_away, 0),
        coalesce(ps.expected_goals_home, 0)
    )                                                                                           AS opponent_xg,

    -- xG net — overall attacking threat imbalance in the match (bilateral by construction)
    (coalesce(ps.expected_goals_home, 0) - coalesce(ps.expected_goals_away, 0))                AS xg_delta,

    -- Total shots — volume of attempts generated despite direct play route (symmetric pair)
    if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.total_shots_home, 0),
        coalesce(ps.total_shots_away, 0)
    )                                                                                           AS triggered_team_total_shots,
    if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.total_shots_away, 0),
        coalesce(ps.total_shots_home, 0)
    )                                                                                           AS opponent_total_shots,

    -- Clearances — opponent's defensive workload from absorbing long-ball pressure (symmetric pair)
    if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.clearances_away, 0),
        coalesce(ps.clearances_home, 0)
    )                                                                                           AS triggered_team_clearances_conceded,
    if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.clearances_home, 0),
        coalesce(ps.clearances_away, 0)
    )                                                                                           AS opponent_clearances_conceded

FROM silver.match AS m
-- Full-match aggregated stats only
INNER JOIN silver.period_stat AS ps
    ON  ps.match_id = m.match_id
    AND ps.period   = 'All'

WHERE
    m.match_finished = 1
    AND m.match_id > 0
    -- Exclude draws: the signal requires a clearly losing team
    AND coalesce(m.home_score, 0) != coalesce(m.away_score, 0)
    -- Data quality: long-ball attempt data must be present
    AND (ps.long_ball_attempts_home IS NOT NULL OR ps.long_ball_attempts_away IS NOT NULL)
    -- Signal filter: the losing side must have attempted more than 60 long balls
    AND (
        (coalesce(m.home_score, 0) < coalesce(m.away_score, 0) AND coalesce(ps.long_ball_attempts_home, 0) > 60)
        OR
        (coalesce(m.away_score, 0) < coalesce(m.home_score, 0) AND coalesce(ps.long_ball_attempts_away, 0) > 60)
    )

-- Surface the most extreme long-ball desperation first
ORDER BY
    if(
        coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
        AND coalesce(ps.long_ball_attempts_home, 0) > 60,
        coalesce(ps.long_ball_attempts_home, 0),
        coalesce(ps.long_ball_attempts_away, 0)
    ) DESC;
