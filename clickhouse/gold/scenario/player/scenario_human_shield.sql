-- scenario_human_shield: outfield defenders absorbing heavy fire via blocks, clearances, and defensive volume
INSERT INTO gold_scenarios.scenario_human_shield
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
    shots_blocked,
    clearances,
    interceptions,
    tackles_won,
    duels_won,
    duels_lost,
    aerial_duels_won,
    shield_score,
    shots_faced,
    block_share_pct,
    fotmob_rating,
    minutes_played,
    fouls_committed,
    team_side,
    xg_faced,
    match_result,
    match_time_utc_date
)
WITH team_shots_faced AS (
    SELECT
        g.match_id,
        countIf(s.team_id = g.home_team_id AND coalesce(s.is_own_goal, 0) != 1) AS home_team_shots,
        countIf(s.team_id = g.away_team_id AND coalesce(s.is_own_goal, 0) != 1) AS away_team_shots
    FROM silver.match AS g
    LEFT JOIN silver.shot AS s
        ON g.match_id = s.match_id
    GROUP BY g.match_id, g.home_team_id, g.away_team_id
)

SELECT
    g.match_id,
    g.home_team_id,
    g.away_team_id,
    g.home_team_name,
    g.away_team_name,
    g.home_score,
    g.away_score,
    p.player_id,
    p.player_name,
    p.team_id,
    p.team_name,
    p.blocked_shots                                         AS shots_blocked,
    p.clearances,
    p.interceptions,
    p.tackles_won,
    p.duels_won,
    p.duels_lost,
    p.aerial_duels_won,
    round(
          (coalesce(p.blocked_shots, 0) * 3.0)
        + (coalesce(p.clearances, 0)   * 1.5)
        + (coalesce(p.interceptions, 0) * 1.2)
        + (coalesce(p.tackles_won, 0)  * 1.0)
    , 2)                                                    AS shield_score,
    CASE
        WHEN p.team_id = g.home_team_id THEN tsf.away_team_shots
        WHEN p.team_id = g.away_team_id THEN tsf.home_team_shots
        ELSE 0
    END                                                   AS shots_faced,
    round(p.blocked_shots
        / nullIf(
            CASE
                WHEN p.team_id = g.home_team_id THEN tsf.away_team_shots
                WHEN p.team_id = g.away_team_id THEN tsf.home_team_shots
                ELSE 0
            END
        , 0) * 100, 1)                                     AS block_share_pct,
    p.fotmob_rating,
    p.minutes_played,
    p.fouls_committed,

    CASE
        WHEN p.team_id = g.home_team_id THEN 'home'
        WHEN p.team_id = g.away_team_id THEN 'away'
    END AS team_side,

    CASE
        WHEN p.team_id = g.home_team_id THEN p_period.expected_goals_away
        WHEN p.team_id = g.away_team_id THEN p_period.expected_goals_home
    END AS xg_faced,

    CASE
        WHEN g.home_score > g.away_score THEN 'Home Win'
        WHEN g.away_score > g.home_score THEN 'Away Win'
        ELSE 'Draw'
    END AS match_result,
    toString(g.match_date)

FROM silver.match AS g
INNER JOIN silver.player_match_stat AS p
    ON g.match_id = p.match_id
INNER JOIN team_shots_faced AS tsf
    ON g.match_id = tsf.match_id
INNER JOIN silver.period_stat AS p_period
    ON g.match_id = p_period.match_id
    AND p_period.period = 'All'
WHERE
    g.match_finished = 1
    AND p.is_goalkeeper = 0
    AND coalesce(p.blocked_shots, 0) >= 4
    AND coalesce(p.clearances, 0) >= 5
    AND (
        CASE
            WHEN p.team_id = g.home_team_id THEN tsf.away_team_shots
            WHEN p.team_id = g.away_team_id THEN tsf.home_team_shots
            ELSE 0
        END
    ) >= 15
    AND p.minutes_played >= 60
ORDER BY shield_score DESC, p.blocked_shots DESC;
