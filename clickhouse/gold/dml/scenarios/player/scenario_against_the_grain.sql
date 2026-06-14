-- scenario_against_the_grain: high-control passing performances delivered under adverse possession contexts
INSERT INTO gold_scenarios.scenario_against_the_grain
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
    accurate_passes,
    total_passes,
    pass_accuracy,
    passes_final_third,
    accurate_long_balls,
    long_ball_attempts,
    long_ball_success_rate,
    accurate_crosses,
    cross_attempts,
    chances_created,
    team_possession,
    opponent_possession,
    possession_gap,
    against_grain_score,
    passes_per_possession_unit,
    touches,
    touches_opp_box,
    successful_dribbles,
    goals,
    assists,
    xg,
    xa,
    fotmob_rating,
    minutes_played,
    team_side,
    match_result,
    match_time_utc_date
)
WITH team_possession AS (
    SELECT
        match_id,
        ball_possession_home,
        ball_possession_away
    FROM silver.period_stat
    WHERE period = 'All'
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
    p.accurate_passes,
    p.total_passes,
    round(p.pass_accuracy, 2)                           AS pass_accuracy,
    p.passes_final_third,
    p.accurate_long_balls,
    p.long_ball_attempts,
    round(p.long_ball_success_rate, 1)                  AS long_ball_success_rate,
    p.accurate_crosses,
    p.cross_attempts,
    p.chances_created,

    CASE
        WHEN p.team_id = g.home_team_id THEN tp.ball_possession_home
        WHEN p.team_id = g.away_team_id THEN tp.ball_possession_away
    END AS team_possession,

    CASE
        WHEN p.team_id = g.home_team_id THEN tp.ball_possession_away
        WHEN p.team_id = g.away_team_id THEN tp.ball_possession_home
    END AS opponent_possession,

    CASE
        WHEN p.team_id = g.home_team_id
        THEN tp.ball_possession_away - tp.ball_possession_home
        WHEN p.team_id = g.away_team_id
        THEN tp.ball_possession_home - tp.ball_possession_away
    END AS possession_gap,

    round(
          (coalesce(p.accurate_passes, 0)     * 1.5)
        + (coalesce(p.pass_accuracy, 0)       * 0.8)
        + (coalesce(p.passes_final_third, 0)  * 2.0)
        + (coalesce(p.accurate_long_balls, 0) * 1.8)
        + (coalesce(p.chances_created, 0)     * 3.0)
        + (
            CASE
                WHEN p.team_id = g.home_team_id
                THEN (tp.ball_possession_away - tp.ball_possession_home) * 0.5
                WHEN p.team_id = g.away_team_id
                THEN (tp.ball_possession_home - tp.ball_possession_away) * 0.5
                ELSE 0
            END
          )
    , 2)                                                AS against_grain_score,

    round(
        coalesce(p.accurate_passes, 0)
        / nullIf(
            CASE
                WHEN p.team_id = g.home_team_id THEN tp.ball_possession_home
                WHEN p.team_id = g.away_team_id THEN tp.ball_possession_away
            END
        , 0) * 100
    , 2)                                                AS passes_per_possession_unit,
    p.touches,
    p.touches_opp_box,
    p.successful_dribbles,
    p.goals,
    p.assists,
    round(p.expected_goals, 3)                          AS xg,
    round(p.expected_assists, 3)                        AS xa,
    p.fotmob_rating,
    p.minutes_played,

    CASE
        WHEN p.team_id = g.home_team_id THEN 'home'
        WHEN p.team_id = g.away_team_id THEN 'away'
    END AS team_side,

    CASE
        WHEN g.home_score > g.away_score THEN 'home_win'
        WHEN g.away_score > g.home_score THEN 'away_win'
        ELSE 'draw'
    END AS match_result,
    toString(g.match_date)

FROM silver.match AS g
INNER JOIN silver.player_match_stat AS p
    ON g.match_id = p.match_id
INNER JOIN team_possession AS tp
    ON g.match_id = tp.match_id
WHERE
    g.match_finished = 1
    AND p.minutes_played >= 60
    AND coalesce(p.accurate_passes, 0) >= 50
    AND coalesce(p.pass_accuracy, 0) >= 95
    AND (
        (p.team_id = g.home_team_id AND tp.ball_possession_home < 45)
        OR
        (p.team_id = g.away_team_id AND tp.ball_possession_away < 45)
    )
ORDER BY against_grain_score DESC, p.accurate_passes DESC;
