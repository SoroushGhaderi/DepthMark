INSERT INTO gold.sig_match_discipline_cards_card_heavy_substitutions (
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
    trigger_threshold_min_distinct_substitute_yellow_carded_players,
    match_distinct_substitute_yellow_carded_players,
    match_distinct_substitute_yellow_carded_players_above_threshold,
    home_distinct_substitute_yellow_carded_players,
    away_distinct_substitute_yellow_carded_players,
    triggered_team_distinct_substitute_yellow_carded_players,
    opponent_distinct_substitute_yellow_carded_players,
    distinct_substitute_yellow_carded_players_delta,
    triggered_team_substitute_yellow_card_events,
    opponent_substitute_yellow_card_events,
    substitute_yellow_card_events_delta,
    triggered_team_first_substitute_yellow_card_minute,
    opponent_first_substitute_yellow_card_minute,
    triggered_team_substitute_yellow_carded_share_pct,
    opponent_substitute_yellow_carded_share_pct,
    substitute_yellow_carded_share_delta_pct,
    triggered_team_yellow_cards,
    opponent_yellow_cards,
    yellow_cards_delta,
    triggered_team_red_cards,
    opponent_red_cards,
    red_cards_delta,
    triggered_team_total_cards,
    opponent_total_cards,
    card_count_delta,
    triggered_team_fouls_committed,
    opponent_fouls_committed,
    fouls_committed_delta,
    triggered_team_cards_per_foul_pct,
    opponent_cards_per_foul_pct,
    cards_per_foul_delta_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct
)
-- Signal: sig_match_discipline_cards_card_heavy_substitutions
-- Trigger: at least 4 distinct substitute players are yellow-carded in the same finished match.
-- Intent: detect substitute-driven discipline collapse with bilateral team and control context.
WITH yellow_card_events AS (
    SELECT
        c.match_id,
        lowerUTF8(coalesce(c.team_side, '')) AS card_side,
        toInt32(assumeNotNull(c.player_id)) AS player_id,
        toInt32(coalesce(c.card_minute, 0)) AS card_minute
    FROM silver.card AS c
    WHERE c.match_id > 0
      AND c.player_id IS NOT NULL
      AND lowerUTF8(coalesce(c.team_side, '')) IN ('home', 'away')
      AND (
            positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'yellow') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'yellow') > 0
            OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'booked') > 0
      )
),
substitute_personnel AS (
    SELECT
        mp.match_id,
        lowerUTF8(coalesce(mp.team_side, '')) AS substitute_side,
        toInt32(mp.person_id) AS player_id
    FROM silver.match_personnel AS mp
    WHERE mp.match_id > 0
      AND mp.person_id > 0
      AND lowerUTF8(coalesce(mp.role, '')) = 'substitute'
      AND toInt32(coalesce(mp.substitution_time, 0)) > 0
      AND lowerUTF8(coalesce(mp.team_side, '')) IN ('home', 'away')
    GROUP BY
        mp.match_id,
        substitute_side,
        toInt32(mp.person_id)
),
substitute_yellow_cards AS (
    SELECT
        sp.match_id,
        sp.substitute_side,
        sp.player_id,
        min(yce.card_minute) AS first_substitute_yellow_card_minute,
        count() AS substitute_yellow_card_events
    FROM substitute_personnel AS sp
    INNER JOIN yellow_card_events AS yce
        ON yce.match_id = sp.match_id
       AND yce.card_side = sp.substitute_side
       AND yce.player_id = sp.player_id
    GROUP BY
        sp.match_id,
        sp.substitute_side,
        sp.player_id
),
substitute_side_rollup AS (
    SELECT
        syc.match_id,
        syc.substitute_side,
        toInt32(count()) AS distinct_substitute_yellow_carded_players,
        toInt32(sum(syc.substitute_yellow_card_events)) AS substitute_yellow_card_events,
        toNullable(toInt32(min(syc.first_substitute_yellow_card_minute)))
            AS first_substitute_yellow_card_minute
    FROM substitute_yellow_cards AS syc
    GROUP BY
        syc.match_id,
        syc.substitute_side
),
eligible_matches AS (
    SELECT
        ssr.match_id,
        toInt32(sum(ssr.distinct_substitute_yellow_carded_players))
            AS match_distinct_substitute_yellow_carded_players,
        toInt32(sum(if(ssr.substitute_side = 'home', ssr.distinct_substitute_yellow_carded_players, 0)))
            AS home_distinct_substitute_yellow_carded_players,
        toInt32(sum(if(ssr.substitute_side = 'away', ssr.distinct_substitute_yellow_carded_players, 0)))
            AS away_distinct_substitute_yellow_carded_players,
        toInt32(sum(if(ssr.substitute_side = 'home', ssr.substitute_yellow_card_events, 0)))
            AS home_substitute_yellow_card_events,
        toInt32(sum(if(ssr.substitute_side = 'away', ssr.substitute_yellow_card_events, 0)))
            AS away_substitute_yellow_card_events,
        toNullable(toInt32(minIf(ssr.first_substitute_yellow_card_minute, ssr.substitute_side = 'home')))
            AS home_first_substitute_yellow_card_minute,
        toNullable(toInt32(minIf(ssr.first_substitute_yellow_card_minute, ssr.substitute_side = 'away')))
            AS away_first_substitute_yellow_card_minute
    FROM substitute_side_rollup AS ssr
    GROUP BY ssr.match_id
    HAVING sum(ssr.distinct_substitute_yellow_carded_players) >= 4
),
base_stats AS (
    SELECT
        m.match_id AS match_id,
        m.match_date AS match_date,
        m.home_team_id AS home_team_id,
        m.home_team_name AS home_team_name,
        m.away_team_id AS away_team_id,
        m.away_team_name AS away_team_name,
        m.home_score AS home_score,
        m.away_score AS away_score,
        coalesce(ps.yellow_cards_home, 0) AS yellow_cards_home,
        coalesce(ps.yellow_cards_away, 0) AS yellow_cards_away,
        coalesce(ps.red_cards_home, 0) AS red_cards_home,
        coalesce(ps.red_cards_away, 0) AS red_cards_away,
        coalesce(ps.fouls_home, 0) AS fouls_home,
        coalesce(ps.fouls_away, 0) AS fouls_away,
        toFloat32(coalesce(ps.ball_possession_home, 0)) AS possession_home_pct,
        toFloat32(coalesce(ps.ball_possession_away, 0)) AS possession_away_pct,
        toFloat32(coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0)
            / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
            1
        ), 0.0)) AS pass_accuracy_home_pct,
        toFloat32(coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0)
            / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
            1
        ), 0.0)) AS pass_accuracy_away_pct,
        em.match_distinct_substitute_yellow_carded_players AS match_distinct_substitute_yellow_carded_players,
        em.home_distinct_substitute_yellow_carded_players AS home_distinct_substitute_yellow_carded_players,
        em.away_distinct_substitute_yellow_carded_players AS away_distinct_substitute_yellow_carded_players,
        em.home_substitute_yellow_card_events AS home_substitute_yellow_card_events,
        em.away_substitute_yellow_card_events AS away_substitute_yellow_card_events,
        em.home_first_substitute_yellow_card_minute AS home_first_substitute_yellow_card_minute,
        em.away_first_substitute_yellow_card_minute AS away_first_substitute_yellow_card_minute
    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON ps.match_id = m.match_id
       AND ps.period = 'All'
    INNER JOIN eligible_matches AS em
        ON em.match_id = m.match_id
    WHERE m.match_finished = 1
      AND m.match_id > 0
 )
SELECT
    x.match_id,
    x.match_date,
    x.home_team_id,
    x.home_team_name,
    x.away_team_id,
    x.away_team_name,
    x.home_score,
    x.away_score,

    'home' AS triggered_side,
    x.home_team_id AS triggered_team_id,
    x.home_team_name AS triggered_team_name,
    x.away_team_id AS opponent_team_id,
    x.away_team_name AS opponent_team_name,

    toInt32(4) AS trigger_threshold_min_distinct_substitute_yellow_carded_players,
    toInt32(match_distinct_substitute_yellow_carded_players) AS match_distinct_substitute_yellow_carded_players,
    toInt32(match_distinct_substitute_yellow_carded_players - 4)
        AS match_distinct_substitute_yellow_carded_players_above_threshold,
    toInt32(home_distinct_substitute_yellow_carded_players) AS home_distinct_substitute_yellow_carded_players,
    toInt32(away_distinct_substitute_yellow_carded_players) AS away_distinct_substitute_yellow_carded_players,
    toInt32(home_distinct_substitute_yellow_carded_players)
        AS triggered_team_distinct_substitute_yellow_carded_players,
    toInt32(away_distinct_substitute_yellow_carded_players)
        AS opponent_distinct_substitute_yellow_carded_players,
    toInt32(
        home_distinct_substitute_yellow_carded_players - away_distinct_substitute_yellow_carded_players
    ) AS distinct_substitute_yellow_carded_players_delta,

    toInt32(home_substitute_yellow_card_events) AS triggered_team_substitute_yellow_card_events,
    toInt32(away_substitute_yellow_card_events) AS opponent_substitute_yellow_card_events,
    toInt32(home_substitute_yellow_card_events - away_substitute_yellow_card_events)
        AS substitute_yellow_card_events_delta,
    toNullable(toInt32(home_first_substitute_yellow_card_minute))
        AS triggered_team_first_substitute_yellow_card_minute,
    toNullable(toInt32(away_first_substitute_yellow_card_minute))
        AS opponent_first_substitute_yellow_card_minute,

    toFloat32(coalesce(round(
        100.0 * home_distinct_substitute_yellow_carded_players
        / nullIf(toFloat64(match_distinct_substitute_yellow_carded_players), 0),
        1
    ), 0.0)) AS triggered_team_substitute_yellow_carded_share_pct,
    toFloat32(coalesce(round(
        100.0 * away_distinct_substitute_yellow_carded_players
        / nullIf(toFloat64(match_distinct_substitute_yellow_carded_players), 0),
        1
    ), 0.0)) AS opponent_substitute_yellow_carded_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * home_distinct_substitute_yellow_carded_players
            / nullIf(toFloat64(match_distinct_substitute_yellow_carded_players), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * away_distinct_substitute_yellow_carded_players
            / nullIf(toFloat64(match_distinct_substitute_yellow_carded_players), 0),
            1
        ), 0.0),
        1
    )) AS substitute_yellow_carded_share_delta_pct,

    toInt32(yellow_cards_home) AS triggered_team_yellow_cards,
    toInt32(yellow_cards_away) AS opponent_yellow_cards,
    toInt32(yellow_cards_home - yellow_cards_away) AS yellow_cards_delta,
    toInt32(red_cards_home) AS triggered_team_red_cards,
    toInt32(red_cards_away) AS opponent_red_cards,
    toInt32(red_cards_home - red_cards_away) AS red_cards_delta,
    toInt32(yellow_cards_home + red_cards_home) AS triggered_team_total_cards,
    toInt32(yellow_cards_away + red_cards_away) AS opponent_total_cards,
    toInt32((yellow_cards_home + red_cards_home) - (yellow_cards_away + red_cards_away))
        AS card_count_delta,

    toInt32(fouls_home) AS triggered_team_fouls_committed,
    toInt32(fouls_away) AS opponent_fouls_committed,
    toInt32(fouls_home - fouls_away) AS fouls_committed_delta,
    toNullable(toFloat32(round(
        100.0 * (yellow_cards_home + red_cards_home) / nullIf(toFloat64(fouls_home), 0),
        1
    ))) AS triggered_team_cards_per_foul_pct,
    toNullable(toFloat32(round(
        100.0 * (yellow_cards_away + red_cards_away) / nullIf(toFloat64(fouls_away), 0),
        1
    ))) AS opponent_cards_per_foul_pct,
    toNullable(toFloat32(round(
        (
            100.0 * (yellow_cards_home + red_cards_home) / nullIf(toFloat64(fouls_home), 0)
        ) - (
            100.0 * (yellow_cards_away + red_cards_away) / nullIf(toFloat64(fouls_away), 0)
        ),
        1
    ))) AS cards_per_foul_delta_pct,

    toFloat32(possession_home_pct) AS triggered_team_possession_pct,
    toFloat32(possession_away_pct) AS opponent_possession_pct,
    toFloat32(round(possession_home_pct - possession_away_pct, 1)) AS possession_delta_pct,
    toFloat32(pass_accuracy_home_pct) AS triggered_team_pass_accuracy_pct,
    toFloat32(pass_accuracy_away_pct) AS opponent_pass_accuracy_pct,
    toFloat32(round(pass_accuracy_home_pct - pass_accuracy_away_pct, 1)) AS pass_accuracy_delta_pct

FROM base_stats AS x

UNION ALL

SELECT
    x.match_id,
    x.match_date,
    x.home_team_id,
    x.home_team_name,
    x.away_team_id,
    x.away_team_name,
    x.home_score,
    x.away_score,

    'away' AS triggered_side,
    x.away_team_id AS triggered_team_id,
    x.away_team_name AS triggered_team_name,
    x.home_team_id AS opponent_team_id,
    x.home_team_name AS opponent_team_name,

    toInt32(4) AS trigger_threshold_min_distinct_substitute_yellow_carded_players,
    toInt32(match_distinct_substitute_yellow_carded_players) AS match_distinct_substitute_yellow_carded_players,
    toInt32(match_distinct_substitute_yellow_carded_players - 4)
        AS match_distinct_substitute_yellow_carded_players_above_threshold,
    toInt32(home_distinct_substitute_yellow_carded_players) AS home_distinct_substitute_yellow_carded_players,
    toInt32(away_distinct_substitute_yellow_carded_players) AS away_distinct_substitute_yellow_carded_players,
    toInt32(away_distinct_substitute_yellow_carded_players)
        AS triggered_team_distinct_substitute_yellow_carded_players,
    toInt32(home_distinct_substitute_yellow_carded_players)
        AS opponent_distinct_substitute_yellow_carded_players,
    toInt32(
        away_distinct_substitute_yellow_carded_players - home_distinct_substitute_yellow_carded_players
    ) AS distinct_substitute_yellow_carded_players_delta,

    toInt32(away_substitute_yellow_card_events) AS triggered_team_substitute_yellow_card_events,
    toInt32(home_substitute_yellow_card_events) AS opponent_substitute_yellow_card_events,
    toInt32(away_substitute_yellow_card_events - home_substitute_yellow_card_events)
        AS substitute_yellow_card_events_delta,
    toNullable(toInt32(away_first_substitute_yellow_card_minute))
        AS triggered_team_first_substitute_yellow_card_minute,
    toNullable(toInt32(home_first_substitute_yellow_card_minute))
        AS opponent_first_substitute_yellow_card_minute,

    toFloat32(coalesce(round(
        100.0 * away_distinct_substitute_yellow_carded_players
        / nullIf(toFloat64(match_distinct_substitute_yellow_carded_players), 0),
        1
    ), 0.0)) AS triggered_team_substitute_yellow_carded_share_pct,
    toFloat32(coalesce(round(
        100.0 * home_distinct_substitute_yellow_carded_players
        / nullIf(toFloat64(match_distinct_substitute_yellow_carded_players), 0),
        1
    ), 0.0)) AS opponent_substitute_yellow_carded_share_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * away_distinct_substitute_yellow_carded_players
            / nullIf(toFloat64(match_distinct_substitute_yellow_carded_players), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * home_distinct_substitute_yellow_carded_players
            / nullIf(toFloat64(match_distinct_substitute_yellow_carded_players), 0),
            1
        ), 0.0),
        1
    )) AS substitute_yellow_carded_share_delta_pct,

    toInt32(yellow_cards_away) AS triggered_team_yellow_cards,
    toInt32(yellow_cards_home) AS opponent_yellow_cards,
    toInt32(yellow_cards_away - yellow_cards_home) AS yellow_cards_delta,
    toInt32(red_cards_away) AS triggered_team_red_cards,
    toInt32(red_cards_home) AS opponent_red_cards,
    toInt32(red_cards_away - red_cards_home) AS red_cards_delta,
    toInt32(yellow_cards_away + red_cards_away) AS triggered_team_total_cards,
    toInt32(yellow_cards_home + red_cards_home) AS opponent_total_cards,
    toInt32((yellow_cards_away + red_cards_away) - (yellow_cards_home + red_cards_home))
        AS card_count_delta,

    toInt32(fouls_away) AS triggered_team_fouls_committed,
    toInt32(fouls_home) AS opponent_fouls_committed,
    toInt32(fouls_away - fouls_home) AS fouls_committed_delta,
    toNullable(toFloat32(round(
        100.0 * (yellow_cards_away + red_cards_away) / nullIf(toFloat64(fouls_away), 0),
        1
    ))) AS triggered_team_cards_per_foul_pct,
    toNullable(toFloat32(round(
        100.0 * (yellow_cards_home + red_cards_home) / nullIf(toFloat64(fouls_home), 0),
        1
    ))) AS opponent_cards_per_foul_pct,
    toNullable(toFloat32(round(
        (
            100.0 * (yellow_cards_away + red_cards_away) / nullIf(toFloat64(fouls_away), 0)
        ) - (
            100.0 * (yellow_cards_home + red_cards_home) / nullIf(toFloat64(fouls_home), 0)
        ),
        1
    ))) AS cards_per_foul_delta_pct,

    toFloat32(possession_away_pct) AS triggered_team_possession_pct,
    toFloat32(possession_home_pct) AS opponent_possession_pct,
    toFloat32(round(possession_away_pct - possession_home_pct, 1)) AS possession_delta_pct,
    toFloat32(pass_accuracy_away_pct) AS triggered_team_pass_accuracy_pct,
    toFloat32(pass_accuracy_home_pct) AS opponent_pass_accuracy_pct,
    toFloat32(round(pass_accuracy_away_pct - pass_accuracy_home_pct, 1)) AS pass_accuracy_delta_pct

FROM base_stats AS x

ORDER BY
    x.match_distinct_substitute_yellow_carded_players DESC,
    match_id,
    triggered_side;
