INSERT INTO gold.sig_match_discipline_cards_one_sided_discipline (
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
    trigger_threshold_min_triggered_team_total_cards,
    trigger_threshold_max_opponent_total_cards,
    triggered_team_total_cards,
    opponent_total_cards,
    card_count_delta,
    triggered_team_cards_above_threshold,
    triggered_team_cards_share_pct,
    opponent_cards_share_pct,
    match_total_cards,
    match_total_yellow_cards,
    match_total_red_cards,
    triggered_team_yellow_cards,
    opponent_yellow_cards,
    yellow_cards_delta,
    triggered_team_red_cards,
    opponent_red_cards,
    red_cards_delta,
    triggered_team_fouls_committed,
    opponent_fouls_committed,
    fouls_committed_delta,
    triggered_team_cards_per_foul_pct,
    opponent_cards_per_foul_pct,
    cards_per_foul_delta_pct,
    triggered_team_duels_won,
    opponent_duels_won,
    triggered_team_tackles_won,
    opponent_tackles_won,
    triggered_team_interceptions,
    opponent_interceptions,
    triggered_team_clearances,
    opponent_clearances,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct
)
-- Signal: sig_match_discipline_cards_one_sided_discipline
-- Intent: detect sharply asymmetric discipline matches where one side absorbs all sanctions while the opponent remains card-free.
-- Trigger: one team has >= 5 total cards and the opponent has 0 total cards at period='All'.
SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        'home',
        'away'
    ) AS triggered_side,
    if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        m.home_team_id,
        m.away_team_id
    ) AS triggered_team_id,
    if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        m.home_team_name,
        m.away_team_name
    ) AS triggered_team_name,
    if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        m.away_team_id,
        m.home_team_id
    ) AS opponent_team_id,
    if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        m.away_team_name,
        m.home_team_name
    ) AS opponent_team_name,

    toInt32(5) AS trigger_threshold_min_triggered_team_total_cards,
    toInt32(0) AS trigger_threshold_max_opponent_total_cards,
    toInt32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
        coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)
    )) AS triggered_team_total_cards,
    toInt32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
        coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)
    )) AS opponent_total_cards,
    toInt32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0))
        - (coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)),
        (coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0))
        - (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0))
    )) AS card_count_delta,
    toInt32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) - 5,
        (coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)) - 5
    )) AS triggered_team_cards_above_threshold,
    toFloat32(coalesce(round(
        100.0 * if(
            (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
            coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
            coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)
        ) / nullIf(
            (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0))
            + (coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)),
            0
        ),
        1
    ), 0.0)) AS triggered_team_cards_share_pct,
    toFloat32(coalesce(round(
        100.0 * if(
            (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
            coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
            coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)
        ) / nullIf(
            (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0))
            + (coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)),
            0
        ),
        1
    ), 0.0)) AS opponent_cards_share_pct,

    toInt32(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0))
        + (coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0))
    ) AS match_total_cards,
    toInt32(coalesce(ps.yellow_cards_home, 0) + coalesce(ps.yellow_cards_away, 0)) AS match_total_yellow_cards,
    toInt32(coalesce(ps.red_cards_home, 0) + coalesce(ps.red_cards_away, 0)) AS match_total_red_cards,

    toInt32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        coalesce(ps.yellow_cards_home, 0),
        coalesce(ps.yellow_cards_away, 0)
    )) AS triggered_team_yellow_cards,
    toInt32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        coalesce(ps.yellow_cards_away, 0),
        coalesce(ps.yellow_cards_home, 0)
    )) AS opponent_yellow_cards,
    toInt32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        coalesce(ps.yellow_cards_home, 0) - coalesce(ps.yellow_cards_away, 0),
        coalesce(ps.yellow_cards_away, 0) - coalesce(ps.yellow_cards_home, 0)
    )) AS yellow_cards_delta,
    toInt32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        coalesce(ps.red_cards_home, 0),
        coalesce(ps.red_cards_away, 0)
    )) AS triggered_team_red_cards,
    toInt32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        coalesce(ps.red_cards_away, 0),
        coalesce(ps.red_cards_home, 0)
    )) AS opponent_red_cards,
    toInt32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        coalesce(ps.red_cards_home, 0) - coalesce(ps.red_cards_away, 0),
        coalesce(ps.red_cards_away, 0) - coalesce(ps.red_cards_home, 0)
    )) AS red_cards_delta,

    toInt32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        coalesce(ps.fouls_home, 0),
        coalesce(ps.fouls_away, 0)
    )) AS triggered_team_fouls_committed,
    toInt32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        coalesce(ps.fouls_away, 0),
        coalesce(ps.fouls_home, 0)
    )) AS opponent_fouls_committed,
    toInt32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        coalesce(ps.fouls_home, 0) - coalesce(ps.fouls_away, 0),
        coalesce(ps.fouls_away, 0) - coalesce(ps.fouls_home, 0)
    )) AS fouls_committed_delta,
    toNullable(toFloat32(round(
        100.0 * if(
            (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
            coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
            coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)
        ) / nullIf(toFloat64(if(
            (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
            coalesce(ps.fouls_home, 0),
            coalesce(ps.fouls_away, 0)
        )), 0),
        2
    ))) AS triggered_team_cards_per_foul_pct,
    toNullable(toFloat32(round(
        100.0 * if(
            (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
            coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
            coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)
        ) / nullIf(toFloat64(if(
            (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
            coalesce(ps.fouls_away, 0),
            coalesce(ps.fouls_home, 0)
        )), 0),
        2
    ))) AS opponent_cards_per_foul_pct,
    toNullable(toFloat32(round(
        (
            100.0 * if(
                (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
                coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0),
                coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)
            ) / nullIf(toFloat64(if(
                (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
                coalesce(ps.fouls_home, 0),
                coalesce(ps.fouls_away, 0)
            )), 0)
        ) - (
            100.0 * if(
                (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
                coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0),
                coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)
            ) / nullIf(toFloat64(if(
                (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
                coalesce(ps.fouls_away, 0),
                coalesce(ps.fouls_home, 0)
            )), 0)
        ),
        2
    ))) AS cards_per_foul_delta_pct,

    toInt32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        coalesce(ps.duels_won_home, 0),
        coalesce(ps.duels_won_away, 0)
    )) AS triggered_team_duels_won,
    toInt32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        coalesce(ps.duels_won_away, 0),
        coalesce(ps.duels_won_home, 0)
    )) AS opponent_duels_won,
    toInt32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        coalesce(ps.tackles_succeeded_home, 0),
        coalesce(ps.tackles_succeeded_away, 0)
    )) AS triggered_team_tackles_won,
    toInt32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        coalesce(ps.tackles_succeeded_away, 0),
        coalesce(ps.tackles_succeeded_home, 0)
    )) AS opponent_tackles_won,
    toInt32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        coalesce(ps.interceptions_home, 0),
        coalesce(ps.interceptions_away, 0)
    )) AS triggered_team_interceptions,
    toInt32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        coalesce(ps.interceptions_away, 0),
        coalesce(ps.interceptions_home, 0)
    )) AS opponent_interceptions,
    toInt32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        coalesce(ps.clearances_home, 0),
        coalesce(ps.clearances_away, 0)
    )) AS triggered_team_clearances,
    toInt32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        coalesce(ps.clearances_away, 0),
        coalesce(ps.clearances_home, 0)
    )) AS opponent_clearances,
    toFloat32(coalesce(round(
        100.0 * if(
            (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
            coalesce(ps.accurate_passes_home, 0),
            coalesce(ps.accurate_passes_away, 0)
        ) / nullIf(toFloat64(if(
            (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
            coalesce(ps.pass_attempts_home, 0),
            coalesce(ps.pass_attempts_away, 0)
        )), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * if(
            (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
            coalesce(ps.accurate_passes_away, 0),
            coalesce(ps.accurate_passes_home, 0)
        ) / nullIf(toFloat64(if(
            (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
            coalesce(ps.pass_attempts_away, 0),
            coalesce(ps.pass_attempts_home, 0)
        )), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * if(
                (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
                coalesce(ps.accurate_passes_home, 0),
                coalesce(ps.accurate_passes_away, 0)
            ) / nullIf(toFloat64(if(
                (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
                coalesce(ps.pass_attempts_home, 0),
                coalesce(ps.pass_attempts_away, 0)
            )), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * if(
                (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
                coalesce(ps.accurate_passes_away, 0),
                coalesce(ps.accurate_passes_home, 0)
            ) / nullIf(toFloat64(if(
                (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
                coalesce(ps.pass_attempts_away, 0),
                coalesce(ps.pass_attempts_home, 0)
            )), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,
    toFloat32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        coalesce(ps.ball_possession_home, 0),
        coalesce(ps.ball_possession_away, 0)
    )) AS triggered_team_possession_pct,
    toFloat32(if(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
        coalesce(ps.ball_possession_away, 0),
        coalesce(ps.ball_possession_home, 0)
    )) AS opponent_possession_pct,
    toFloat32(round(
        if(
            (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
            coalesce(ps.ball_possession_home, 0),
            coalesce(ps.ball_possession_away, 0)
        ) - if(
            (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5,
            coalesce(ps.ball_possession_away, 0),
            coalesce(ps.ball_possession_home, 0)
        ),
        1
    )) AS possession_delta_pct
FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND (
      (
          (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) >= 5
          AND (coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)) = 0
      )
      OR
      (
          (coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)) >= 5
          AND (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) = 0
      )
  )
ORDER BY
    triggered_team_total_cards DESC,
    card_count_delta DESC,
    pass_accuracy_delta_pct DESC,
    m.match_date DESC,
    m.match_id DESC;
