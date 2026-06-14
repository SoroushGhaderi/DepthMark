INSERT INTO gold.sig_team_possession_passing_vertical_imbalance (
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
    score_deficit,
    triggered_team_long_ball_attempts,
    opponent_long_ball_attempts,
    long_ball_attempts_delta,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_long_ball_share_pct,
    opponent_long_ball_share_pct,
    long_ball_share_delta_pct,
    triggered_team_accurate_long_balls,
    opponent_accurate_long_balls,
    triggered_team_long_ball_accuracy_pct,
    opponent_long_ball_accuracy_pct,
    long_ball_accuracy_delta_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_aerial_success_pct,
    opponent_aerial_success_pct,
    aerial_success_delta_pct
)
-- Signal: sig_team_possession_passing_vertical_imbalance
-- Trigger: Team attempts >= 60 long balls while trailing.
-- Intent: identify trailing teams that shift heavily into vertical/direct passing and quantify
--         how far their long-ball profile diverges from the opponent.

-- Home-side trigger: home team is trailing and attempts >= 60 long balls.
SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,
    'home' AS triggered_side,
    m.home_team_id AS triggered_team_id,
    m.home_team_name AS triggered_team_name,
    m.away_team_id AS opponent_team_id,
    m.away_team_name AS opponent_team_name,
    coalesce(m.away_score, 0) - coalesce(m.home_score, 0) AS score_deficit,
    coalesce(ps.long_ball_attempts_home, 0) AS triggered_team_long_ball_attempts,
    coalesce(ps.long_ball_attempts_away, 0) AS opponent_long_ball_attempts,
    coalesce(ps.long_ball_attempts_home, 0) - coalesce(ps.long_ball_attempts_away, 0) AS long_ball_attempts_delta,
    coalesce(ps.pass_attempts_home, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_away, 0) AS opponent_pass_attempts,
    round(100.0 * coalesce(ps.long_ball_attempts_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1) AS triggered_team_long_ball_share_pct,
    round(100.0 * coalesce(ps.long_ball_attempts_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1) AS opponent_long_ball_share_pct,
    round(
        coalesce(round(100.0 * coalesce(ps.long_ball_attempts_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0)
      - coalesce(round(100.0 * coalesce(ps.long_ball_attempts_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0),
        1
    ) AS long_ball_share_delta_pct,
    coalesce(ps.accurate_long_balls_home, 0) AS triggered_team_accurate_long_balls,
    coalesce(ps.accurate_long_balls_away, 0) AS opponent_accurate_long_balls,
    round(100.0 * coalesce(ps.accurate_long_balls_home, 0) / nullIf(coalesce(ps.long_ball_attempts_home, 0), 0), 1) AS triggered_team_long_ball_accuracy_pct,
    round(100.0 * coalesce(ps.accurate_long_balls_away, 0) / nullIf(coalesce(ps.long_ball_attempts_away, 0), 0), 1) AS opponent_long_ball_accuracy_pct,
    round(
        coalesce(round(100.0 * coalesce(ps.accurate_long_balls_home, 0) / nullIf(coalesce(ps.long_ball_attempts_home, 0), 0), 1), 0.0)
      - coalesce(round(100.0 * coalesce(ps.accurate_long_balls_away, 0) / nullIf(coalesce(ps.long_ball_attempts_away, 0), 0), 1), 0.0),
        1
    ) AS long_ball_accuracy_delta_pct,
    round(100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1) AS triggered_team_pass_accuracy_pct,
    round(100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1) AS opponent_pass_accuracy_pct,
    round(
        coalesce(round(100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0)
      - coalesce(round(100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0),
        1
    ) AS pass_accuracy_delta_pct,
    coalesce(ps.ball_possession_home, 0) AS triggered_team_possession_pct,
    coalesce(ps.ball_possession_away, 0) AS opponent_possession_pct,
    coalesce(ps.ball_possession_home, 0) - coalesce(ps.ball_possession_away, 0) AS possession_delta_pct,
    coalesce(ps.expected_goals_home, 0) AS triggered_team_xg,
    coalesce(ps.expected_goals_away, 0) AS opponent_xg,
    coalesce(ps.expected_goals_home, 0) - coalesce(ps.expected_goals_away, 0) AS xg_delta,
    coalesce(ps.total_shots_home, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_away, 0) AS opponent_total_shots,
    round(100.0 * coalesce(ps.aerials_won_home, 0) / nullIf(coalesce(ps.aerial_attempts_home, 0), 0), 1) AS triggered_team_aerial_success_pct,
    round(100.0 * coalesce(ps.aerials_won_away, 0) / nullIf(coalesce(ps.aerial_attempts_away, 0), 0), 1) AS opponent_aerial_success_pct,
    round(
        coalesce(round(100.0 * coalesce(ps.aerials_won_home, 0) / nullIf(coalesce(ps.aerial_attempts_home, 0), 0), 1), 0.0)
      - coalesce(round(100.0 * coalesce(ps.aerials_won_away, 0) / nullIf(coalesce(ps.aerial_attempts_away, 0), 0), 1), 0.0),
        1
    ) AS aerial_success_delta_pct
FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(m.home_score, 0) < coalesce(m.away_score, 0)
  AND coalesce(ps.long_ball_attempts_home, 0) >= 60

UNION ALL

-- Away-side trigger: away team is trailing and attempts >= 60 long balls.
SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,
    'away' AS triggered_side,
    m.away_team_id AS triggered_team_id,
    m.away_team_name AS triggered_team_name,
    m.home_team_id AS opponent_team_id,
    m.home_team_name AS opponent_team_name,
    coalesce(m.home_score, 0) - coalesce(m.away_score, 0) AS score_deficit,
    coalesce(ps.long_ball_attempts_away, 0) AS triggered_team_long_ball_attempts,
    coalesce(ps.long_ball_attempts_home, 0) AS opponent_long_ball_attempts,
    coalesce(ps.long_ball_attempts_away, 0) - coalesce(ps.long_ball_attempts_home, 0) AS long_ball_attempts_delta,
    coalesce(ps.pass_attempts_away, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_home, 0) AS opponent_pass_attempts,
    round(100.0 * coalesce(ps.long_ball_attempts_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1) AS triggered_team_long_ball_share_pct,
    round(100.0 * coalesce(ps.long_ball_attempts_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1) AS opponent_long_ball_share_pct,
    round(
        coalesce(round(100.0 * coalesce(ps.long_ball_attempts_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0)
      - coalesce(round(100.0 * coalesce(ps.long_ball_attempts_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0),
        1
    ) AS long_ball_share_delta_pct,
    coalesce(ps.accurate_long_balls_away, 0) AS triggered_team_accurate_long_balls,
    coalesce(ps.accurate_long_balls_home, 0) AS opponent_accurate_long_balls,
    round(100.0 * coalesce(ps.accurate_long_balls_away, 0) / nullIf(coalesce(ps.long_ball_attempts_away, 0), 0), 1) AS triggered_team_long_ball_accuracy_pct,
    round(100.0 * coalesce(ps.accurate_long_balls_home, 0) / nullIf(coalesce(ps.long_ball_attempts_home, 0), 0), 1) AS opponent_long_ball_accuracy_pct,
    round(
        coalesce(round(100.0 * coalesce(ps.accurate_long_balls_away, 0) / nullIf(coalesce(ps.long_ball_attempts_away, 0), 0), 1), 0.0)
      - coalesce(round(100.0 * coalesce(ps.accurate_long_balls_home, 0) / nullIf(coalesce(ps.long_ball_attempts_home, 0), 0), 1), 0.0),
        1
    ) AS long_ball_accuracy_delta_pct,
    round(100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1) AS triggered_team_pass_accuracy_pct,
    round(100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1) AS opponent_pass_accuracy_pct,
    round(
        coalesce(round(100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0)
      - coalesce(round(100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0),
        1
    ) AS pass_accuracy_delta_pct,
    coalesce(ps.ball_possession_away, 0) AS triggered_team_possession_pct,
    coalesce(ps.ball_possession_home, 0) AS opponent_possession_pct,
    coalesce(ps.ball_possession_away, 0) - coalesce(ps.ball_possession_home, 0) AS possession_delta_pct,
    coalesce(ps.expected_goals_away, 0) AS triggered_team_xg,
    coalesce(ps.expected_goals_home, 0) AS opponent_xg,
    coalesce(ps.expected_goals_away, 0) - coalesce(ps.expected_goals_home, 0) AS xg_delta,
    coalesce(ps.total_shots_away, 0) AS triggered_team_total_shots,
    coalesce(ps.total_shots_home, 0) AS opponent_total_shots,
    round(100.0 * coalesce(ps.aerials_won_away, 0) / nullIf(coalesce(ps.aerial_attempts_away, 0), 0), 1) AS triggered_team_aerial_success_pct,
    round(100.0 * coalesce(ps.aerials_won_home, 0) / nullIf(coalesce(ps.aerial_attempts_home, 0), 0), 1) AS opponent_aerial_success_pct,
    round(
        coalesce(round(100.0 * coalesce(ps.aerials_won_away, 0) / nullIf(coalesce(ps.aerial_attempts_away, 0), 0), 1), 0.0)
      - coalesce(round(100.0 * coalesce(ps.aerials_won_home, 0) / nullIf(coalesce(ps.aerial_attempts_home, 0), 0), 1), 0.0),
        1
    ) AS aerial_success_delta_pct
FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(m.away_score, 0) < coalesce(m.home_score, 0)
  AND coalesce(ps.long_ball_attempts_away, 0) >= 60

ORDER BY
    triggered_team_long_ball_attempts DESC,
    score_deficit DESC,
    match_date DESC,
    match_id DESC;
