INSERT INTO gold.sig_team_possession_passing_press_resistance (
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
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_accurate_passes,
    opponent_accurate_passes,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_own_half_passes,
    opponent_own_half_passes,
    triggered_team_own_half_pass_share_pct,
    opponent_own_half_pass_share_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    triggered_team_interceptions,
    opponent_interceptions,
    triggered_team_tackles_won,
    opponent_tackles_won,
    triggered_team_fouls,
    opponent_fouls,
    triggered_team_press_actions,
    opponent_press_actions,
    opponent_press_actions_per_100_triggered_passes,
    press_actions_delta
)
-- Signal: sig_team_possession_passing_press_resistance
-- Trigger: triggered team pass accuracy > 85 with >= 300 pass attempts while opponent high-press proxy (interceptions + tackles won + fouls) >= 35 and >= 10.0 per 100 triggered-team pass attempts.
-- Intent: identify teams that preserve elite pass completion under sustained opponent pressure, with bilateral possession, field-territory, and defensive-action context.

-- Home-side triggers.
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

    coalesce(ps.pass_attempts_home, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_away, 0) AS opponent_pass_attempts,
    coalesce(ps.accurate_passes_home, 0) AS triggered_team_accurate_passes,
    coalesce(ps.accurate_passes_away, 0) AS opponent_accurate_passes,
    coalesce(round(100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0) AS triggered_team_pass_accuracy_pct,
    coalesce(round(100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0) AS opponent_pass_accuracy_pct,
    round(
        coalesce(round(100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0)
      - coalesce(round(100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0),
        1
    ) AS pass_accuracy_delta_pct,

    coalesce(ps.own_half_passes_home, 0) AS triggered_team_own_half_passes,
    coalesce(ps.own_half_passes_away, 0) AS opponent_own_half_passes,
    coalesce(round(100.0 * coalesce(ps.own_half_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0) AS triggered_team_own_half_pass_share_pct,
    coalesce(round(100.0 * coalesce(ps.own_half_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0) AS opponent_own_half_pass_share_pct,

    toFloat32(coalesce(ps.ball_possession_home, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS opponent_possession_pct,

    coalesce(ps.interceptions_home, 0) AS triggered_team_interceptions,
    coalesce(ps.interceptions_away, 0) AS opponent_interceptions,
    coalesce(ps.tackles_succeeded_home, 0) AS triggered_team_tackles_won,
    coalesce(ps.tackles_succeeded_away, 0) AS opponent_tackles_won,
    coalesce(ps.fouls_home, 0) AS triggered_team_fouls,
    coalesce(ps.fouls_away, 0) AS opponent_fouls,

    coalesce(ps.interceptions_home, 0)
  + coalesce(ps.tackles_succeeded_home, 0)
  + coalesce(ps.fouls_home, 0) AS triggered_team_press_actions,
    coalesce(ps.interceptions_away, 0)
  + coalesce(ps.tackles_succeeded_away, 0)
  + coalesce(ps.fouls_away, 0) AS opponent_press_actions,
    coalesce(
        round(
            100.0 * (
                coalesce(ps.interceptions_away, 0)
              + coalesce(ps.tackles_succeeded_away, 0)
              + coalesce(ps.fouls_away, 0)
            ) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
            1
        ),
        0.0
    ) AS opponent_press_actions_per_100_triggered_passes,
    (
        coalesce(ps.interceptions_away, 0)
      + coalesce(ps.tackles_succeeded_away, 0)
      + coalesce(ps.fouls_away, 0)
    ) - (
        coalesce(ps.interceptions_home, 0)
      + coalesce(ps.tackles_succeeded_home, 0)
      + coalesce(ps.fouls_home, 0)
    ) AS press_actions_delta

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ps.pass_attempts_home, 0) >= 300
  AND coalesce(
        round(100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1),
        0.0
      ) > 85
  AND (
        coalesce(ps.interceptions_away, 0)
      + coalesce(ps.tackles_succeeded_away, 0)
      + coalesce(ps.fouls_away, 0)
      ) >= 35
  AND coalesce(
        round(
            100.0 * (
                coalesce(ps.interceptions_away, 0)
              + coalesce(ps.tackles_succeeded_away, 0)
              + coalesce(ps.fouls_away, 0)
            ) / nullIf(coalesce(ps.pass_attempts_home, 0), 0),
            1
        ),
        0.0
      ) >= 10.0

UNION ALL

-- Away-side triggers.
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

    coalesce(ps.pass_attempts_away, 0) AS triggered_team_pass_attempts,
    coalesce(ps.pass_attempts_home, 0) AS opponent_pass_attempts,
    coalesce(ps.accurate_passes_away, 0) AS triggered_team_accurate_passes,
    coalesce(ps.accurate_passes_home, 0) AS opponent_accurate_passes,
    coalesce(round(100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0) AS triggered_team_pass_accuracy_pct,
    coalesce(round(100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0) AS opponent_pass_accuracy_pct,
    round(
        coalesce(round(100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0)
      - coalesce(round(100.0 * coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0),
        1
    ) AS pass_accuracy_delta_pct,

    coalesce(ps.own_half_passes_away, 0) AS triggered_team_own_half_passes,
    coalesce(ps.own_half_passes_home, 0) AS opponent_own_half_passes,
    coalesce(round(100.0 * coalesce(ps.own_half_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1), 0.0) AS triggered_team_own_half_pass_share_pct,
    coalesce(round(100.0 * coalesce(ps.own_half_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0), 1), 0.0) AS opponent_own_half_pass_share_pct,

    toFloat32(coalesce(ps.ball_possession_away, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS opponent_possession_pct,

    coalesce(ps.interceptions_away, 0) AS triggered_team_interceptions,
    coalesce(ps.interceptions_home, 0) AS opponent_interceptions,
    coalesce(ps.tackles_succeeded_away, 0) AS triggered_team_tackles_won,
    coalesce(ps.tackles_succeeded_home, 0) AS opponent_tackles_won,
    coalesce(ps.fouls_away, 0) AS triggered_team_fouls,
    coalesce(ps.fouls_home, 0) AS opponent_fouls,

    coalesce(ps.interceptions_away, 0)
  + coalesce(ps.tackles_succeeded_away, 0)
  + coalesce(ps.fouls_away, 0) AS triggered_team_press_actions,
    coalesce(ps.interceptions_home, 0)
  + coalesce(ps.tackles_succeeded_home, 0)
  + coalesce(ps.fouls_home, 0) AS opponent_press_actions,
    coalesce(
        round(
            100.0 * (
                coalesce(ps.interceptions_home, 0)
              + coalesce(ps.tackles_succeeded_home, 0)
              + coalesce(ps.fouls_home, 0)
            ) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
            1
        ),
        0.0
    ) AS opponent_press_actions_per_100_triggered_passes,
    (
        coalesce(ps.interceptions_home, 0)
      + coalesce(ps.tackles_succeeded_home, 0)
      + coalesce(ps.fouls_home, 0)
    ) - (
        coalesce(ps.interceptions_away, 0)
      + coalesce(ps.tackles_succeeded_away, 0)
      + coalesce(ps.fouls_away, 0)
    ) AS press_actions_delta

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(ps.pass_attempts_away, 0) >= 300
  AND coalesce(
        round(100.0 * coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0), 1),
        0.0
      ) > 85
  AND (
        coalesce(ps.interceptions_home, 0)
      + coalesce(ps.tackles_succeeded_home, 0)
      + coalesce(ps.fouls_home, 0)
      ) >= 35
  AND coalesce(
        round(
            100.0 * (
                coalesce(ps.interceptions_home, 0)
              + coalesce(ps.tackles_succeeded_home, 0)
              + coalesce(ps.fouls_home, 0)
            ) / nullIf(coalesce(ps.pass_attempts_away, 0), 0),
            1
        ),
        0.0
      ) >= 10.0

ORDER BY
    opponent_press_actions_per_100_triggered_passes DESC,
    triggered_team_pass_accuracy_pct DESC,
    m.match_date DESC,
    m.match_id DESC;
