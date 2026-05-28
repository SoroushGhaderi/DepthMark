INSERT INTO gold.sig_match_discipline_cards_boiling_over (
    match_id, match_date, home_team_id, home_team_name, away_team_id, away_team_name,
    home_score, away_score, triggered_side, triggered_team_id, triggered_team_name,
    opponent_team_id, opponent_team_name, trigger_threshold_min_late_window_cards,
    trigger_threshold_window_start_minute, trigger_threshold_window_end_minute,
    match_late_window_cards, match_late_window_cards_above_threshold,
    home_late_window_cards, away_late_window_cards, triggered_team_late_window_cards,
    opponent_late_window_cards, late_window_cards_delta,
    triggered_team_late_window_cards_share_pct, opponent_late_window_cards_share_pct,
    late_window_cards_share_delta_pct, match_total_cards, match_total_yellow_cards,
    match_total_red_cards, triggered_team_yellow_cards, opponent_yellow_cards,
    yellow_cards_delta, triggered_team_red_cards, opponent_red_cards, red_cards_delta,
    triggered_team_total_cards, opponent_total_cards, card_count_delta,
    triggered_team_fouls_committed, opponent_fouls_committed, fouls_committed_delta,
    triggered_team_cards_per_foul_pct, opponent_cards_per_foul_pct, cards_per_foul_delta_pct,
    triggered_team_duels_won, opponent_duels_won, triggered_team_tackles_won,
    opponent_tackles_won, triggered_team_interceptions, opponent_interceptions,
    triggered_team_clearances, opponent_clearances, triggered_team_possession_pct,
    opponent_possession_pct, possession_delta_pct
)
SELECT *
FROM (
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
        toInt32(4),
        toInt32(80),
        CAST(NULL, 'Nullable(Int32)'),
        em.match_late_window_cards,
        toInt32(em.match_late_window_cards - 4),
        em.home_late_window_cards,
        em.away_late_window_cards,
        em.home_late_window_cards,
        em.away_late_window_cards,
        toInt32(em.home_late_window_cards - em.away_late_window_cards),
        toFloat32(round(100.0 * em.home_late_window_cards / nullIf(toFloat64(em.match_late_window_cards), 0), 1)),
        toFloat32(round(100.0 * em.away_late_window_cards / nullIf(toFloat64(em.match_late_window_cards), 0), 1)),
        toFloat32(round((100.0 * em.home_late_window_cards / nullIf(toFloat64(em.match_late_window_cards), 0)) - (100.0 * em.away_late_window_cards / nullIf(toFloat64(em.match_late_window_cards), 0)), 1)),
        toInt32(coalesce(ps.yellow_cards_home,0)+coalesce(ps.yellow_cards_away,0)+coalesce(ps.red_cards_home,0)+coalesce(ps.red_cards_away,0)),
        toInt32(coalesce(ps.yellow_cards_home,0)+coalesce(ps.yellow_cards_away,0)),
        toInt32(coalesce(ps.red_cards_home,0)+coalesce(ps.red_cards_away,0)),
        toInt32(coalesce(ps.yellow_cards_home,0)),
        toInt32(coalesce(ps.yellow_cards_away,0)),
        toInt32(coalesce(ps.yellow_cards_home,0)-coalesce(ps.yellow_cards_away,0)),
        toInt32(coalesce(ps.red_cards_home,0)),
        toInt32(coalesce(ps.red_cards_away,0)),
        toInt32(coalesce(ps.red_cards_home,0)-coalesce(ps.red_cards_away,0)),
        toInt32(coalesce(ps.yellow_cards_home,0)+coalesce(ps.red_cards_home,0)),
        toInt32(coalesce(ps.yellow_cards_away,0)+coalesce(ps.red_cards_away,0)),
        toInt32((coalesce(ps.yellow_cards_home,0)+coalesce(ps.red_cards_home,0))-(coalesce(ps.yellow_cards_away,0)+coalesce(ps.red_cards_away,0))),
        toInt32(coalesce(ps.fouls_home,0)), toInt32(coalesce(ps.fouls_away,0)), toInt32(coalesce(ps.fouls_home,0)-coalesce(ps.fouls_away,0)),
        toNullable(toFloat32(round(100.0*(coalesce(ps.yellow_cards_home,0)+coalesce(ps.red_cards_home,0))/nullIf(toFloat64(coalesce(ps.fouls_home,0)),0),1))),
        toNullable(toFloat32(round(100.0*(coalesce(ps.yellow_cards_away,0)+coalesce(ps.red_cards_away,0))/nullIf(toFloat64(coalesce(ps.fouls_away,0)),0),1))),
        toNullable(toFloat32(round((100.0*(coalesce(ps.yellow_cards_home,0)+coalesce(ps.red_cards_home,0))/nullIf(toFloat64(coalesce(ps.fouls_home,0)),0))-(100.0*(coalesce(ps.yellow_cards_away,0)+coalesce(ps.red_cards_away,0))/nullIf(toFloat64(coalesce(ps.fouls_away,0)),0)),1))),
        toInt32(coalesce(ps.duels_won_home,0)), toInt32(coalesce(ps.duels_won_away,0)),
        toInt32(coalesce(ps.tackles_succeeded_home,0)), toInt32(coalesce(ps.tackles_succeeded_away,0)),
        toInt32(coalesce(ps.interceptions_home,0)), toInt32(coalesce(ps.interceptions_away,0)),
        toInt32(coalesce(ps.clearances_home,0)), toInt32(coalesce(ps.clearances_away,0)),
        toFloat32(coalesce(ps.ball_possession_home,0)), toFloat32(coalesce(ps.ball_possession_away,0)),
        toFloat32(round(toFloat32(coalesce(ps.ball_possession_home,0)) - toFloat32(coalesce(ps.ball_possession_away,0)), 1))
    FROM silver.match m
    INNER JOIN silver.period_stat ps ON ps.match_id = m.match_id AND ps.period = 'All'
    INNER JOIN (
        SELECT
            z.match_id,
            toInt32(sum(if(z.card_team_side='home' AND z.card_minute>80,1,0))) AS home_late_window_cards,
            toInt32(sum(if(z.card_team_side='away' AND z.card_minute>80,1,0))) AS away_late_window_cards,
            toInt32(sum(if(z.card_team_side IN ('home','away') AND z.card_minute>80,1,0))) AS match_late_window_cards
        FROM (
            SELECT c.match_id, lowerUTF8(coalesce(c.team_side,'')) AS card_team_side, toInt32(coalesce(c.card_minute,0)) AS card_minute
            FROM silver.card c
            WHERE c.match_id > 0
              AND lowerUTF8(coalesce(c.team_side,'')) IN ('home','away')
              AND toInt32(coalesce(c.card_minute,0)) > 0
              AND (
                  positionCaseInsensitiveUTF8(coalesce(c.card_type,''), 'yellow') > 0
                  OR positionCaseInsensitiveUTF8(coalesce(c.description,''), 'yellow') > 0
                  OR positionCaseInsensitiveUTF8(coalesce(c.description,''), 'booked') > 0
                  OR positionCaseInsensitiveUTF8(coalesce(c.card_type,''), 'red') > 0
                  OR positionCaseInsensitiveUTF8(coalesce(c.description,''), 'red') > 0
              )
        ) z
        GROUP BY z.match_id
        HAVING toInt32(sum(if(z.card_team_side IN ('home','away') AND z.card_minute>80,1,0))) >= 4
    ) em ON em.match_id = m.match_id
    WHERE m.match_finished = 1 AND m.match_id > 0
) q
ORDER BY match_id, triggered_side;
