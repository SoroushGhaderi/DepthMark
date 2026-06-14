INSERT INTO gold.sig_team_discipline_cards_aggression_spike (
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
    trigger_threshold_foul_multiplier,
    trigger_threshold_min_first_half_fouls,
    triggered_team_fouls_first_half,
    triggered_team_fouls_second_half,
    opponent_fouls_first_half,
    opponent_fouls_second_half,
    triggered_team_fouls_second_half_minus_first_half,
    opponent_fouls_second_half_minus_first_half,
    foul_escalation_delta,
    triggered_team_second_half_to_first_half_foul_ratio,
    opponent_second_half_to_first_half_foul_ratio,
    foul_ratio_delta,
    triggered_team_second_half_fouls_share_pct,
    opponent_second_half_fouls_share_pct,
    second_half_fouls_share_delta_pct,
    triggered_team_yellow_cards,
    opponent_yellow_cards,
    triggered_team_red_cards,
    opponent_red_cards,
    triggered_team_total_cards,
    opponent_total_cards,
    card_count_delta,
    triggered_team_fouls_committed,
    opponent_fouls_committed,
    fouls_committed_delta,
    triggered_team_duels_won,
    opponent_duels_won,
    triggered_team_tackles_won,
    opponent_tackles_won,
    triggered_team_interceptions,
    opponent_interceptions,
    triggered_team_clearances,
    opponent_clearances,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct
)
WITH half_foul_stats AS (
    SELECT
        ps.match_id,
        maxIf(coalesce(ps.fouls_home, 0), ps.period = 'FirstHalf') AS home_fouls_first_half,
        maxIf(coalesce(ps.fouls_home, 0), ps.period = 'SecondHalf') AS home_fouls_second_half,
        maxIf(coalesce(ps.fouls_away, 0), ps.period = 'FirstHalf') AS away_fouls_first_half,
        maxIf(coalesce(ps.fouls_away, 0), ps.period = 'SecondHalf') AS away_fouls_second_half
    FROM silver.period_stat AS ps
    WHERE ps.period IN ('FirstHalf', 'SecondHalf')
    GROUP BY ps.match_id
)
-- Signal: sig_team_discipline_cards_aggression_spike
-- Trigger: second-half fouls >= 2x first-half fouls (with first-half fouls >= 1).
-- Intent: detect teams that become materially more aggressive after halftime and preserve bilateral discipline context.

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

    'home' AS triggered_side,
    m.home_team_id AS triggered_team_id,
    m.home_team_name AS triggered_team_name,
    m.away_team_id AS opponent_team_id,
    m.away_team_name AS opponent_team_name,

    toFloat32(2.0) AS trigger_threshold_foul_multiplier,
    toInt32(1) AS trigger_threshold_min_first_half_fouls,
    toInt32(coalesce(hfs.home_fouls_first_half, 0)) AS triggered_team_fouls_first_half,
    toInt32(coalesce(hfs.home_fouls_second_half, 0)) AS triggered_team_fouls_second_half,
    toInt32(coalesce(hfs.away_fouls_first_half, 0)) AS opponent_fouls_first_half,
    toInt32(coalesce(hfs.away_fouls_second_half, 0)) AS opponent_fouls_second_half,
    toInt32(coalesce(hfs.home_fouls_second_half, 0) - coalesce(hfs.home_fouls_first_half, 0)) AS triggered_team_fouls_second_half_minus_first_half,
    toInt32(coalesce(hfs.away_fouls_second_half, 0) - coalesce(hfs.away_fouls_first_half, 0)) AS opponent_fouls_second_half_minus_first_half,
    toInt32(
        (coalesce(hfs.home_fouls_second_half, 0) - coalesce(hfs.home_fouls_first_half, 0))
        - (coalesce(hfs.away_fouls_second_half, 0) - coalesce(hfs.away_fouls_first_half, 0))
    ) AS foul_escalation_delta,
    toNullable(toFloat32(round(
        coalesce(hfs.home_fouls_second_half, 0) / nullIf(toFloat64(coalesce(hfs.home_fouls_first_half, 0)), 0),
        2
    ))) AS triggered_team_second_half_to_first_half_foul_ratio,
    toNullable(toFloat32(round(
        coalesce(hfs.away_fouls_second_half, 0) / nullIf(toFloat64(coalesce(hfs.away_fouls_first_half, 0)), 0),
        2
    ))) AS opponent_second_half_to_first_half_foul_ratio,
    toNullable(toFloat32(round(
        (
            coalesce(hfs.home_fouls_second_half, 0) / nullIf(toFloat64(coalesce(hfs.home_fouls_first_half, 0)), 0)
        )
        - (
            coalesce(hfs.away_fouls_second_half, 0) / nullIf(toFloat64(coalesce(hfs.away_fouls_first_half, 0)), 0)
        ),
        2
    ))) AS foul_ratio_delta,
    toNullable(toFloat32(round(
        100.0 * coalesce(hfs.home_fouls_second_half, 0)
        / nullIf(coalesce(hfs.home_fouls_first_half, 0) + coalesce(hfs.home_fouls_second_half, 0), 0),
        1
    ))) AS triggered_team_second_half_fouls_share_pct,
    toNullable(toFloat32(round(
        100.0 * coalesce(hfs.away_fouls_second_half, 0)
        / nullIf(coalesce(hfs.away_fouls_first_half, 0) + coalesce(hfs.away_fouls_second_half, 0), 0),
        1
    ))) AS opponent_second_half_fouls_share_pct,
    toNullable(toFloat32(round(
        (
            100.0 * coalesce(hfs.home_fouls_second_half, 0)
            / nullIf(coalesce(hfs.home_fouls_first_half, 0) + coalesce(hfs.home_fouls_second_half, 0), 0)
        )
        - (
            100.0 * coalesce(hfs.away_fouls_second_half, 0)
            / nullIf(coalesce(hfs.away_fouls_first_half, 0) + coalesce(hfs.away_fouls_second_half, 0), 0)
        ),
        1
    ))) AS second_half_fouls_share_delta_pct,

    toInt32(coalesce(ps.yellow_cards_home, 0)) AS triggered_team_yellow_cards,
    toInt32(coalesce(ps.yellow_cards_away, 0)) AS opponent_yellow_cards,
    toInt32(coalesce(ps.red_cards_home, 0)) AS triggered_team_red_cards,
    toInt32(coalesce(ps.red_cards_away, 0)) AS opponent_red_cards,
    toInt32(coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) AS triggered_team_total_cards,
    toInt32(coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)) AS opponent_total_cards,
    toInt32(
        (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0))
        - (coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0))
    ) AS card_count_delta,
    toInt32(coalesce(ps.fouls_home, 0)) AS triggered_team_fouls_committed,
    toInt32(coalesce(ps.fouls_away, 0)) AS opponent_fouls_committed,
    toInt32(coalesce(ps.fouls_home, 0) - coalesce(ps.fouls_away, 0)) AS fouls_committed_delta,
    toInt32(coalesce(ps.duels_won_home, 0)) AS triggered_team_duels_won,
    toInt32(coalesce(ps.duels_won_away, 0)) AS opponent_duels_won,
    toInt32(coalesce(ps.tackles_succeeded_home, 0)) AS triggered_team_tackles_won,
    toInt32(coalesce(ps.tackles_succeeded_away, 0)) AS opponent_tackles_won,
    toInt32(coalesce(ps.interceptions_home, 0)) AS triggered_team_interceptions,
    toInt32(coalesce(ps.interceptions_away, 0)) AS opponent_interceptions,
    toInt32(coalesce(ps.clearances_home, 0)) AS triggered_team_clearances,
    toInt32(coalesce(ps.clearances_away, 0)) AS opponent_clearances,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_home, 0) - coalesce(ps.ball_possession_away, 0), 1)) AS possession_delta_pct

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
INNER JOIN half_foul_stats AS hfs
    ON hfs.match_id = m.match_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(hfs.home_fouls_first_half, 0) >= 1
  AND coalesce(hfs.home_fouls_second_half, 0) >= 2 * coalesce(hfs.home_fouls_first_half, 0)

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

    'away' AS triggered_side,
    m.away_team_id AS triggered_team_id,
    m.away_team_name AS triggered_team_name,
    m.home_team_id AS opponent_team_id,
    m.home_team_name AS opponent_team_name,

    toFloat32(2.0) AS trigger_threshold_foul_multiplier,
    toInt32(1) AS trigger_threshold_min_first_half_fouls,
    toInt32(coalesce(hfs.away_fouls_first_half, 0)) AS triggered_team_fouls_first_half,
    toInt32(coalesce(hfs.away_fouls_second_half, 0)) AS triggered_team_fouls_second_half,
    toInt32(coalesce(hfs.home_fouls_first_half, 0)) AS opponent_fouls_first_half,
    toInt32(coalesce(hfs.home_fouls_second_half, 0)) AS opponent_fouls_second_half,
    toInt32(coalesce(hfs.away_fouls_second_half, 0) - coalesce(hfs.away_fouls_first_half, 0)) AS triggered_team_fouls_second_half_minus_first_half,
    toInt32(coalesce(hfs.home_fouls_second_half, 0) - coalesce(hfs.home_fouls_first_half, 0)) AS opponent_fouls_second_half_minus_first_half,
    toInt32(
        (coalesce(hfs.away_fouls_second_half, 0) - coalesce(hfs.away_fouls_first_half, 0))
        - (coalesce(hfs.home_fouls_second_half, 0) - coalesce(hfs.home_fouls_first_half, 0))
    ) AS foul_escalation_delta,
    toNullable(toFloat32(round(
        coalesce(hfs.away_fouls_second_half, 0) / nullIf(toFloat64(coalesce(hfs.away_fouls_first_half, 0)), 0),
        2
    ))) AS triggered_team_second_half_to_first_half_foul_ratio,
    toNullable(toFloat32(round(
        coalesce(hfs.home_fouls_second_half, 0) / nullIf(toFloat64(coalesce(hfs.home_fouls_first_half, 0)), 0),
        2
    ))) AS opponent_second_half_to_first_half_foul_ratio,
    toNullable(toFloat32(round(
        (
            coalesce(hfs.away_fouls_second_half, 0) / nullIf(toFloat64(coalesce(hfs.away_fouls_first_half, 0)), 0)
        )
        - (
            coalesce(hfs.home_fouls_second_half, 0) / nullIf(toFloat64(coalesce(hfs.home_fouls_first_half, 0)), 0)
        ),
        2
    ))) AS foul_ratio_delta,
    toNullable(toFloat32(round(
        100.0 * coalesce(hfs.away_fouls_second_half, 0)
        / nullIf(coalesce(hfs.away_fouls_first_half, 0) + coalesce(hfs.away_fouls_second_half, 0), 0),
        1
    ))) AS triggered_team_second_half_fouls_share_pct,
    toNullable(toFloat32(round(
        100.0 * coalesce(hfs.home_fouls_second_half, 0)
        / nullIf(coalesce(hfs.home_fouls_first_half, 0) + coalesce(hfs.home_fouls_second_half, 0), 0),
        1
    ))) AS opponent_second_half_fouls_share_pct,
    toNullable(toFloat32(round(
        (
            100.0 * coalesce(hfs.away_fouls_second_half, 0)
            / nullIf(coalesce(hfs.away_fouls_first_half, 0) + coalesce(hfs.away_fouls_second_half, 0), 0)
        )
        - (
            100.0 * coalesce(hfs.home_fouls_second_half, 0)
            / nullIf(coalesce(hfs.home_fouls_first_half, 0) + coalesce(hfs.home_fouls_second_half, 0), 0)
        ),
        1
    ))) AS second_half_fouls_share_delta_pct,

    toInt32(coalesce(ps.yellow_cards_away, 0)) AS triggered_team_yellow_cards,
    toInt32(coalesce(ps.yellow_cards_home, 0)) AS opponent_yellow_cards,
    toInt32(coalesce(ps.red_cards_away, 0)) AS triggered_team_red_cards,
    toInt32(coalesce(ps.red_cards_home, 0)) AS opponent_red_cards,
    toInt32(coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0)) AS triggered_team_total_cards,
    toInt32(coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0)) AS opponent_total_cards,
    toInt32(
        (coalesce(ps.yellow_cards_away, 0) + coalesce(ps.red_cards_away, 0))
        - (coalesce(ps.yellow_cards_home, 0) + coalesce(ps.red_cards_home, 0))
    ) AS card_count_delta,
    toInt32(coalesce(ps.fouls_away, 0)) AS triggered_team_fouls_committed,
    toInt32(coalesce(ps.fouls_home, 0)) AS opponent_fouls_committed,
    toInt32(coalesce(ps.fouls_away, 0) - coalesce(ps.fouls_home, 0)) AS fouls_committed_delta,
    toInt32(coalesce(ps.duels_won_away, 0)) AS triggered_team_duels_won,
    toInt32(coalesce(ps.duels_won_home, 0)) AS opponent_duels_won,
    toInt32(coalesce(ps.tackles_succeeded_away, 0)) AS triggered_team_tackles_won,
    toInt32(coalesce(ps.tackles_succeeded_home, 0)) AS opponent_tackles_won,
    toInt32(coalesce(ps.interceptions_away, 0)) AS triggered_team_interceptions,
    toInt32(coalesce(ps.interceptions_home, 0)) AS opponent_interceptions,
    toInt32(coalesce(ps.clearances_away, 0)) AS triggered_team_clearances,
    toInt32(coalesce(ps.clearances_home, 0)) AS opponent_clearances,
    toFloat32(coalesce(ps.ball_possession_away, 0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_away, 0) - coalesce(ps.ball_possession_home, 0), 1)) AS possession_delta_pct

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.period = 'All'
INNER JOIN half_foul_stats AS hfs
    ON hfs.match_id = m.match_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(hfs.away_fouls_first_half, 0) >= 1
  AND coalesce(hfs.away_fouls_second_half, 0) >= 2 * coalesce(hfs.away_fouls_first_half, 0)

ORDER BY
    triggered_team_second_half_to_first_half_foul_ratio DESC,
    foul_escalation_delta DESC,
    card_count_delta DESC,
    m.match_date DESC,
    m.match_id DESC;
