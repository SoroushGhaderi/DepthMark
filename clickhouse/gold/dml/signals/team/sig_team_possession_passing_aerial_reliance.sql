INSERT INTO gold.sig_team_possession_passing_aerial_reliance (
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
    triggered_team_aerials_won,
    opponent_aerials_won,
    triggered_team_aerial_attempts,
    opponent_aerial_attempts,
    triggered_team_aerial_success_pct,
    opponent_aerial_success_pct,
    aerial_success_delta,
    triggered_team_long_ball_attempts,
    opponent_long_ball_attempts,
    triggered_team_accurate_long_balls,
    opponent_accurate_long_balls,
    triggered_team_long_ball_accuracy_pct,
    opponent_long_ball_accuracy_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_long_ball_share_pct,
    opponent_long_ball_share_pct,
    long_ball_share_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_xg,
    opponent_xg,
    xg_delta
)
-- Signal: sig_team_possession_passing_aerial_reliance
-- Trigger: triggered_team_aerial_success_pct > 70 with long_ball_attempts >= 20 and long_ball_share_pct >= 18.
-- Intent: identify teams reliant on direct aerial routes that also dominate long-ball header outcomes.

-- Home-side triggers.
SELECT
    -- Match identifiers.
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    -- Triggered team and opponent identifiers.
    'home' AS triggered_side,
    m.home_team_id AS triggered_team_id,
    m.home_team_name AS triggered_team_name,
    m.away_team_id AS opponent_team_id,
    m.away_team_name AS opponent_team_name,

    -- Aerial duel core metrics.
    coalesce(ps.aerials_won_home, 0) AS triggered_team_aerials_won,
    coalesce(ps.aerials_won_away, 0) AS opponent_aerials_won,
    coalesce(ps.aerial_attempts_home, 0) AS triggered_team_aerial_attempts,
    coalesce(ps.aerial_attempts_away, 0) AS opponent_aerial_attempts,
    toFloat32(coalesce(round(100.0 * coalesce(ps.aerials_won_home, 0) / nullIf(coalesce(ps.aerial_attempts_home, 0), 0), 1), 0.0))
        AS triggered_team_aerial_success_pct,
    toFloat32(coalesce(round(100.0 * coalesce(ps.aerials_won_away, 0) / nullIf(coalesce(ps.aerial_attempts_away, 0), 0), 1), 0.0))
        AS opponent_aerial_success_pct,
    toFloat32(round(
        coalesce(round(100.0 * coalesce(ps.aerials_won_home, 0) / nullIf(coalesce(ps.aerial_attempts_home, 0), 0), 1), 0.0)
      - coalesce(round(100.0 * coalesce(ps.aerials_won_away, 0) / nullIf(coalesce(ps.aerial_attempts_away, 0), 0), 1), 0.0),
        1
    )) AS aerial_success_delta,

    -- Long-ball reliance and execution context.
    coalesce(ps.long_ball_attempts_home, 0) AS triggered_team_long_ball_attempts,
    coalesce(ps.long_ball_attempts_away, 0) AS opponent_long_ball_attempts,
    coalesce(ps.accurate_long_balls_home, 0) AS triggered_team_accurate_long_balls,
    coalesce(ps.accurate_long_balls_away, 0) AS opponent_accurate_long_balls,
    toFloat32(coalesce(round(100.0 * coalesce(ps.accurate_long_balls_home, 0) / nullIf(coalesce(ps.long_ball_attempts_home, 0), 0), 1), 0.0))
        AS triggered_team_long_ball_accuracy_pct,
    toFloat32(coalesce(round(100.0 * coalesce(ps.accurate_long_balls_away, 0) / nullIf(coalesce(ps.long_ball_attempts_away, 0), 0), 1), 0.0))
        AS opponent_long_ball_accuracy_pct,

    -- Passing volume denominator for long-ball share.
    coalesce(ps.pass_attempts_home, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_away, 0) AS opponent_pass_attempts,
    toFloat32(coalesce(round(100.0 * coalesce(ps.long_ball_attempts_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0))
        AS triggered_team_long_ball_share_pct,
    toFloat32(coalesce(round(100.0 * coalesce(ps.long_ball_attempts_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0))
        AS opponent_long_ball_share_pct,
    toFloat32(round(
        coalesce(round(100.0 * coalesce(ps.long_ball_attempts_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0)
      - coalesce(round(100.0 * coalesce(ps.long_ball_attempts_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0),
        1
    )) AS long_ball_share_delta,

    -- Output context (shot quality/volume impact).
    coalesce(ps.total_shots_home, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_away, 0) AS opponent_total_shots,
    toFloat32(coalesce(ps.expected_goals_home, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_home, 0) - coalesce(ps.expected_goals_away, 0), 3)) AS xg_delta

-- Join finished matches to full-match period stats.
FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'

-- Apply home-side trigger.
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ps.long_ball_attempts_home, 0) >= 20
  AND coalesce(round(100.0 * coalesce(ps.long_ball_attempts_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0) >= 18
  AND coalesce(round(100.0 * coalesce(ps.aerials_won_home, 0) / nullIf(coalesce(ps.aerial_attempts_home, 0), 0), 1), 0.0) > 70

UNION ALL

-- Away-side triggers.
SELECT
    -- Match identifiers.
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    -- Triggered team and opponent identifiers.
    'away' AS triggered_side,
    m.away_team_id AS triggered_team_id,
    m.away_team_name AS triggered_team_name,
    m.home_team_id AS opponent_team_id,
    m.home_team_name AS opponent_team_name,

    -- Aerial duel core metrics.
    coalesce(ps.aerials_won_away, 0) AS triggered_team_aerials_won,
    coalesce(ps.aerials_won_home, 0) AS opponent_aerials_won,
    coalesce(ps.aerial_attempts_away, 0) AS triggered_team_aerial_attempts,
    coalesce(ps.aerial_attempts_home, 0) AS opponent_aerial_attempts,
    toFloat32(coalesce(round(100.0 * coalesce(ps.aerials_won_away, 0) / nullIf(coalesce(ps.aerial_attempts_away, 0), 0), 1), 0.0))
        AS triggered_team_aerial_success_pct,
    toFloat32(coalesce(round(100.0 * coalesce(ps.aerials_won_home, 0) / nullIf(coalesce(ps.aerial_attempts_home, 0), 0), 1), 0.0))
        AS opponent_aerial_success_pct,
    toFloat32(round(
        coalesce(round(100.0 * coalesce(ps.aerials_won_away, 0) / nullIf(coalesce(ps.aerial_attempts_away, 0), 0), 1), 0.0)
      - coalesce(round(100.0 * coalesce(ps.aerials_won_home, 0) / nullIf(coalesce(ps.aerial_attempts_home, 0), 0), 1), 0.0),
        1
    )) AS aerial_success_delta,

    -- Long-ball reliance and execution context.
    coalesce(ps.long_ball_attempts_away, 0) AS triggered_team_long_ball_attempts,
    coalesce(ps.long_ball_attempts_home, 0) AS opponent_long_ball_attempts,
    coalesce(ps.accurate_long_balls_away, 0) AS triggered_team_accurate_long_balls,
    coalesce(ps.accurate_long_balls_home, 0) AS opponent_accurate_long_balls,
    toFloat32(coalesce(round(100.0 * coalesce(ps.accurate_long_balls_away, 0) / nullIf(coalesce(ps.long_ball_attempts_away, 0), 0), 1), 0.0))
        AS triggered_team_long_ball_accuracy_pct,
    toFloat32(coalesce(round(100.0 * coalesce(ps.accurate_long_balls_home, 0) / nullIf(coalesce(ps.long_ball_attempts_home, 0), 0), 1), 0.0))
        AS opponent_long_ball_accuracy_pct,

    -- Passing volume denominator for long-ball share.
    coalesce(ps.pass_attempts_away, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_home, 0) AS opponent_pass_attempts,
    toFloat32(coalesce(round(100.0 * coalesce(ps.long_ball_attempts_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0))
        AS triggered_team_long_ball_share_pct,
    toFloat32(coalesce(round(100.0 * coalesce(ps.long_ball_attempts_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0))
        AS opponent_long_ball_share_pct,
    toFloat32(round(
        coalesce(round(100.0 * coalesce(ps.long_ball_attempts_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0)
      - coalesce(round(100.0 * coalesce(ps.long_ball_attempts_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0),
        1
    )) AS long_ball_share_delta,

    -- Output context (shot quality/volume impact).
    coalesce(ps.total_shots_away, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_home, 0) AS opponent_total_shots,
    toFloat32(coalesce(ps.expected_goals_away, 0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_away, 0) - coalesce(ps.expected_goals_home, 0), 3)) AS xg_delta

-- Join finished matches to full-match period stats.
FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'

-- Apply away-side trigger.
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ps.long_ball_attempts_away, 0) >= 20
  AND coalesce(round(100.0 * coalesce(ps.long_ball_attempts_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0) >= 18
  AND coalesce(round(100.0 * coalesce(ps.aerials_won_away, 0) / nullIf(coalesce(ps.aerial_attempts_away, 0), 0), 1), 0.0) > 70

-- Prioritize strongest aerial-reliance success.
ORDER BY
    assumeNotNull(triggered_team_aerial_success_pct) DESC,
    m.match_date DESC,
    m.match_id DESC;
