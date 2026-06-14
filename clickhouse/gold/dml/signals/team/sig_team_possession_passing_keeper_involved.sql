INSERT INTO gold.sig_team_possession_passing_keeper_involved (
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
    triggered_goalkeeper_player_id,
    triggered_goalkeeper_player_name,
    triggered_team_goalkeeper_touches,
    opponent_team_id,
    opponent_team_name,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_own_half_passes,
    opponent_own_half_passes,
    triggered_team_long_ball_attempts,
    opponent_long_ball_attempts,
    triggered_team_long_ball_accuracy_pct,
    opponent_long_ball_accuracy_pct,
    possession_delta,
    pass_attempt_delta
)
-- Signal: sig_team_possession_passing_keeper_involved
-- Trigger: max goalkeeper touches by team in a finished match > 50.
-- Intent: detect keeper-heavy build-up usage and enrich with symmetric passing and possession context.

-- Select triggered team rows with required match context and bilateral tactical enrichment.
SELECT
    -- Match identifiers and scoreline context
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,
    if(
        gk.gk_team_id = assumeNotNull(m.home_team_id),
        'home',
        'away'
    ) AS triggered_side,

    -- Triggered team + goalkeeper identifiers.
    gk.gk_team_id AS triggered_team_id,
    if(
        gk.gk_team_id = assumeNotNull(m.home_team_id),
        assumeNotNull(m.home_team_name),
        assumeNotNull(m.away_team_name)
    ) AS triggered_team_name,
    gk.triggered_goalkeeper_player_id AS triggered_goalkeeper_player_id,
    gk.triggered_goalkeeper_player_name AS triggered_goalkeeper_player_name,
    toInt32(gk.gk_touches) AS triggered_team_goalkeeper_touches,

    -- Opponent team identifiers
    if(
        gk.gk_team_id = assumeNotNull(m.home_team_id),
        assumeNotNull(m.away_team_id),
        assumeNotNull(m.home_team_id)
    ) AS opponent_team_id,
    if(
        gk.gk_team_id = assumeNotNull(m.home_team_id),
        assumeNotNull(m.away_team_name),
        assumeNotNull(m.home_team_name)
    ) AS opponent_team_name,

    -- Possession context (symmetric pair)
    if(
        gk.gk_team_id = assumeNotNull(m.home_team_id),
        coalesce(ps.ball_possession_home, 0),
        coalesce(ps.ball_possession_away, 0)
    ) AS triggered_team_possession_pct,
    if(
        gk.gk_team_id = assumeNotNull(m.home_team_id),
        coalesce(ps.ball_possession_away, 0),
        coalesce(ps.ball_possession_home, 0)
    ) AS opponent_possession_pct,

    -- Pass volume context (symmetric pair)
    if(
        gk.gk_team_id = assumeNotNull(m.home_team_id),
        coalesce(ps.pass_attempts_home, 0),
        coalesce(ps.pass_attempts_away, 0)
    ) AS triggered_team_pass_attempts,
    if(
        gk.gk_team_id = assumeNotNull(m.home_team_id),
        coalesce(ps.pass_attempts_away, 0),
        coalesce(ps.pass_attempts_home, 0)
    ) AS opponent_pass_attempts,

    -- Pass execution quality (symmetric pair)
    if(
        gk.gk_team_id = assumeNotNull(m.home_team_id),
        coalesce(
            round(
                100.0 * coalesce(ps.accurate_passes_home, 0)
                / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
                1
            ),
            0.0
        ),
        coalesce(
            round(
                100.0 * coalesce(ps.accurate_passes_away, 0)
                / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
                1
            ),
            0.0
        )
    ) AS triggered_team_pass_accuracy_pct,
    if(
        gk.gk_team_id = assumeNotNull(m.home_team_id),
        coalesce(
            round(
                100.0 * coalesce(ps.accurate_passes_away, 0)
                / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
                1
            ),
            0.0
        ),
        coalesce(
            round(
                100.0 * coalesce(ps.accurate_passes_home, 0)
                / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
                1
            ),
            0.0
        )
    ) AS opponent_pass_accuracy_pct,

    -- Build-up depth context (symmetric pair)
    if(
        gk.gk_team_id = assumeNotNull(m.home_team_id),
        coalesce(ps.own_half_passes_home, 0),
        coalesce(ps.own_half_passes_away, 0)
    ) AS triggered_team_own_half_passes,
    if(
        gk.gk_team_id = assumeNotNull(m.home_team_id),
        coalesce(ps.own_half_passes_away, 0),
        coalesce(ps.own_half_passes_home, 0)
    ) AS opponent_own_half_passes,

    -- Long-ball release context (symmetric pair)
    if(
        gk.gk_team_id = assumeNotNull(m.home_team_id),
        coalesce(ps.long_ball_attempts_home, 0),
        coalesce(ps.long_ball_attempts_away, 0)
    ) AS triggered_team_long_ball_attempts,
    if(
        gk.gk_team_id = assumeNotNull(m.home_team_id),
        coalesce(ps.long_ball_attempts_away, 0),
        coalesce(ps.long_ball_attempts_home, 0)
    ) AS opponent_long_ball_attempts,
    if(
        gk.gk_team_id = assumeNotNull(m.home_team_id),
        coalesce(
            round(
                100.0 * coalesce(ps.accurate_long_balls_home, 0)
                / nullIf(coalesce(ps.long_ball_attempts_home, 0), 0),
                1
            ),
            0.0
        ),
        coalesce(
            round(
                100.0 * coalesce(ps.accurate_long_balls_away, 0)
                / nullIf(coalesce(ps.long_ball_attempts_away, 0), 0),
                1
            ),
            0.0
        )
    ) AS triggered_team_long_ball_accuracy_pct,
    if(
        gk.gk_team_id = assumeNotNull(m.home_team_id),
        coalesce(
            round(
                100.0 * coalesce(ps.accurate_long_balls_away, 0)
                / nullIf(coalesce(ps.long_ball_attempts_away, 0), 0),
                1
            ),
            0.0
        ),
        coalesce(
            round(
                100.0 * coalesce(ps.accurate_long_balls_home, 0)
                / nullIf(coalesce(ps.long_ball_attempts_home, 0), 0),
                1
            ),
            0.0
        )
    ) AS opponent_long_ball_accuracy_pct,

    -- Bilateral net columns
    if(
        gk.gk_team_id = assumeNotNull(m.home_team_id),
        coalesce(ps.ball_possession_home, 0) - coalesce(ps.ball_possession_away, 0),
        coalesce(ps.ball_possession_away, 0) - coalesce(ps.ball_possession_home, 0)
    ) AS possession_delta,
    if(
        gk.gk_team_id = assumeNotNull(m.home_team_id),
        coalesce(ps.pass_attempts_home, 0) - coalesce(ps.pass_attempts_away, 0),
        coalesce(ps.pass_attempts_away, 0) - coalesce(ps.pass_attempts_home, 0)
    ) AS pass_attempt_delta

-- Base match context for triggered rows.
FROM silver.match AS m

-- Join one goalkeeper trigger per team-match (highest GK touches, then threshold > 50).
INNER JOIN (
    SELECT
        pms.match_id,
        assumeNotNull(pms.team_id) AS gk_team_id,
        argMax(pms.player_id, coalesce(pms.touches, 0)) AS triggered_goalkeeper_player_id,
        argMax(pms.player_name, coalesce(pms.touches, 0)) AS triggered_goalkeeper_player_name,
        max(coalesce(pms.touches, 0)) AS gk_touches
    FROM silver.player_match_stat AS pms
    WHERE pms.is_goalkeeper = 1
      AND pms.team_id IS NOT NULL
    GROUP BY
        pms.match_id,
        assumeNotNull(pms.team_id)
    HAVING max(coalesce(pms.touches, 0)) > 50
) AS gk
    ON gk.match_id = m.match_id

-- Join full-match period stats for tactical enrichment.
LEFT JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'

-- Restrict to finished matches.
WHERE m.match_finished = 1
  AND m.match_id > 0

-- Strongest keeper-involvement cases first.
ORDER BY
    assumeNotNull(gk.gk_touches) DESC,
    m.match_date DESC,
    m.match_id DESC;
