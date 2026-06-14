-- scenario_hollow_dominance: high-volume siege performances that fail to turn dominance into a win
INSERT INTO gold_scenarios.scenario_hollow_dominance
(
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    siege_team,
    siege_side,
    total_shots_home,
    total_shots_away,
    shots_on_target_home,
    shots_on_target_away,
    shots_inside_box_home,
    shots_inside_box_away,
    blocked_shots_home,
    blocked_shots_away,
    big_chances_home,
    big_chances_away,
    big_chances_missed_home,
    big_chances_missed_away,
    xg_home,
    xg_away,
    npxg_home,
    npxg_away,
    xg_open_play_home,
    xg_open_play_away,
    siege_shots,
    siege_xg,
    siege_big_chances_missed,
    xg_underperformance,
    ball_possession_home,
    ball_possession_away,
    match_result,
    match_time_utc_date
)
SELECT
    g.match_id,
    g.home_team_id,
    g.away_team_id,
    g.home_team_name,
    g.away_team_name,
    g.home_score,
    g.away_score,

    CASE
        WHEN p.total_shots_home >= 20
         AND p.expected_goals_home >= 2.5
         AND g.home_score <= 1
         AND g.home_score <= g.away_score THEN g.home_team_name
        WHEN p.total_shots_away >= 20
         AND p.expected_goals_away >= 2.5
         AND g.away_score <= 1
         AND g.away_score <= g.home_score THEN g.away_team_name
    END AS siege_team,

    CASE
        WHEN p.total_shots_home >= 20
         AND p.expected_goals_home >= 2.5
         AND g.home_score <= 1
         AND g.home_score <= g.away_score THEN 'home'
        WHEN p.total_shots_away >= 20
         AND p.expected_goals_away >= 2.5
         AND g.away_score <= 1
         AND g.away_score <= g.home_score THEN 'away'
    END AS siege_side,

    p.total_shots_home,
    p.total_shots_away,
    p.shots_on_target_home,
    p.shots_on_target_away,
    p.shots_inside_box_home,
    p.shots_inside_box_away,
    p.blocked_shots_home,
    p.blocked_shots_away,
    p.big_chances_home,
    p.big_chances_away,
    p.big_chances_missed_home,
    p.big_chances_missed_away,
    round(p.expected_goals_home, 3)                     AS xg_home,
    round(p.expected_goals_away, 3)                     AS xg_away,
    round(p.expected_goals_non_penalty_home, 3)         AS npxg_home,
    round(p.expected_goals_non_penalty_away, 3)         AS npxg_away,
    round(p.expected_goals_open_play_home, 3)           AS xg_open_play_home,
    round(p.expected_goals_open_play_away, 3)           AS xg_open_play_away,

    CASE
        WHEN p.total_shots_home >= 20
         AND p.expected_goals_home >= 2.5
         AND g.home_score <= 1
         AND g.home_score <= g.away_score THEN p.total_shots_home
        WHEN p.total_shots_away >= 20
         AND p.expected_goals_away >= 2.5
         AND g.away_score <= 1
         AND g.away_score <= g.home_score THEN p.total_shots_away
    END AS siege_shots,

    CASE
        WHEN p.total_shots_home >= 20
         AND p.expected_goals_home >= 2.5
         AND g.home_score <= 1
         AND g.home_score <= g.away_score THEN round(p.expected_goals_home, 3)
        WHEN p.total_shots_away >= 20
         AND p.expected_goals_away >= 2.5
         AND g.away_score <= 1
         AND g.away_score <= g.home_score THEN round(p.expected_goals_away, 3)
    END AS siege_xg,

    CASE
        WHEN p.total_shots_home >= 20
         AND p.expected_goals_home >= 2.5
         AND g.home_score <= 1
         AND g.home_score <= g.away_score THEN p.big_chances_missed_home
        WHEN p.total_shots_away >= 20
         AND p.expected_goals_away >= 2.5
         AND g.away_score <= 1
         AND g.away_score <= g.home_score THEN p.big_chances_missed_away
    END AS siege_big_chances_missed,

    CASE
        WHEN p.total_shots_home >= 20
         AND p.expected_goals_home >= 2.5
         AND g.home_score <= 1
         AND g.home_score <= g.away_score
        THEN round(p.expected_goals_home - g.home_score, 3)
        WHEN p.total_shots_away >= 20
         AND p.expected_goals_away >= 2.5
         AND g.away_score <= 1
         AND g.away_score <= g.home_score
        THEN round(p.expected_goals_away - g.away_score, 3)
    END AS xg_underperformance,

    p.ball_possession_home,
    p.ball_possession_away,

    CASE
        WHEN g.home_score > g.away_score THEN 'home_win'
        WHEN g.away_score > g.home_score THEN 'away_win'
        ELSE 'draw'
    END AS match_result,
    toString(g.match_date)

FROM silver.match AS g
INNER JOIN silver.period_stat AS p
    ON g.match_id = p.match_id
    AND p.period = 'All'
WHERE
    g.match_finished = 1
    AND (
        (
            p.total_shots_home >= 20
            AND p.expected_goals_home >= 2.5
            AND g.home_score <= 1
            AND g.home_score <= g.away_score
        )
        OR
        (
            p.total_shots_away >= 20
            AND p.expected_goals_away >= 2.5
            AND g.away_score <= 1
            AND g.away_score <= g.home_score
        )
    )
ORDER BY siege_xg DESC, siege_shots DESC;
