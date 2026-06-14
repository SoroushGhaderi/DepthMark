-- scenario_chaos_engine: disruptor profiles with defensive aggression, attacking-zone presence, and team shot context
INSERT INTO gold_scenarios.scenario_chaos_engine
(
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    player_id,
    player_name,
    team_id,
    team_name,
    tackles_won,
    interceptions,
    defensive_actions,
    touches_opp_box,
    fouls_committed,
    was_fouled,
    recoveries,
    duels_won,
    duels_lost,
    duel_win_pct,
    disruption_score,
    team_total_shots,
    team_shots_on_target,
    team_xg,
    fotmob_rating,
    minutes_played,
    passes_final_third,
    team_side,
    match_result,
    match_time_utc_date
)
WITH team_shots AS (
    SELECT
        match_id,
        team_id,
        count()                                             AS team_total_shots,
        countIf(is_on_target = 1)                          AS team_shots_on_target,
        round(sum(expected_goals), 3)                      AS team_xg
    FROM silver.shot
    WHERE
        is_own_goal != 1
        AND expected_goals IS NOT NULL
    GROUP BY match_id, team_id
),

player_disruption AS (
    SELECT
        p.match_id,
        p.player_id,
        p.player_name,
        p.team_id,
        p.team_name,

        coalesce(p.tackles_won, 0)                         AS tackles_won,
        coalesce(p.interceptions, 0)                       AS interceptions,
        coalesce(p.tackles_won, 0)
            + coalesce(p.interceptions, 0)                 AS defensive_actions,

        coalesce(p.touches_opp_box, 0)                     AS touches_opp_box,
        coalesce(p.fouls_committed, 0)                     AS fouls_committed,
        coalesce(p.was_fouled, 0)                          AS was_fouled,
        coalesce(p.recoveries, 0)                          AS recoveries,

        coalesce(p.duels_won, 0)                           AS duels_won,
        coalesce(p.duels_lost, 0)                          AS duels_lost,
        round(
            coalesce(p.duels_won, 0)
            / nullIf(coalesce(p.duels_won, 0)
                   + coalesce(p.duels_lost, 0), 0) * 100
        , 1)                                               AS duel_win_pct,

        (coalesce(p.tackles_won, 0) + coalesce(p.interceptions, 0))
            + (coalesce(p.touches_opp_box, 0) * 0.5)
            + (coalesce(p.fouls_committed, 0) * 0.8)
            + (coalesce(p.recoveries, 0) * 0.6)           AS disruption_score,

        p.fotmob_rating,
        p.minutes_played,
        p.passes_final_third
    FROM silver.player_match_stat AS p
    WHERE
        p.minutes_played >= 45
        AND (
            coalesce(p.tackles_won, 0)
          + coalesce(p.interceptions, 0)
        ) >= 5
        AND coalesce(p.fouls_committed, 0) >= 3
        AND coalesce(p.touches_opp_box, 0) >= 1
)

SELECT
    g.match_id,
    g.home_team_id,
    g.away_team_id,
    g.home_team_name,
    g.away_team_name,
    g.home_score,
    g.away_score,
    pd.player_id,
    pd.player_name,
    pd.team_id,
    pd.team_name,
    pd.tackles_won,
    pd.interceptions,
    pd.defensive_actions,
    pd.touches_opp_box,
    pd.fouls_committed,
    pd.was_fouled,
    pd.recoveries,
    pd.duels_won,
    pd.duels_lost,
    pd.duel_win_pct,
    pd.disruption_score,
    ts.team_total_shots,
    ts.team_shots_on_target,
    ts.team_xg,
    pd.fotmob_rating,
    pd.minutes_played,
    pd.passes_final_third,

    CASE
        WHEN pd.team_id = g.home_team_id THEN 'home'
        WHEN pd.team_id = g.away_team_id THEN 'away'
    END AS team_side,

    CASE
        WHEN g.home_score > g.away_score THEN 'Home Win'
        WHEN g.away_score > g.home_score THEN 'Away Win'
        ELSE 'Draw'
    END AS match_result,
    toString(g.match_date)

FROM silver.match AS g
INNER JOIN player_disruption AS pd
    ON g.match_id = pd.match_id
INNER JOIN team_shots AS ts
    ON g.match_id = ts.match_id
    AND pd.team_id = ts.team_id
WHERE
    g.match_finished = 1
    AND ts.team_total_shots >= 1
ORDER BY pd.disruption_score DESC, pd.defensive_actions DESC;
