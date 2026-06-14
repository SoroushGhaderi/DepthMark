-- scenario_basketball_match: high-volume shootouts ranked by composite chaos intensity
INSERT INTO gold_scenarios.scenario_basketball_match
(
    match_id,
    home_team_id,
    away_team_id,
    home_team_name,
    away_team_name,
    home_score,
    away_score,
    total_goals,
    goal_diff,
    xg_home,
    xg_away,
    combined_xg,
    xg_diff,
    total_shots_home,
    total_shots_away,
    combined_shots,
    shots_on_target_home,
    shots_on_target_away,
    combined_shots_on_target,
    shots_inside_box_home,
    shots_inside_box_away,
    big_chances_home,
    big_chances_away,
    combined_big_chances,
    ball_possession_home,
    ball_possession_away,
    xg_open_play_home,
    xg_open_play_away,
    combined_xg_open_play,
    chaos_score,
    chaos_type,
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
    g.home_score + g.away_score                             AS total_goals,
    abs(g.home_score - g.away_score)                        AS goal_diff,
    round(p.expected_goals_home, 3)                         AS xg_home,
    round(p.expected_goals_away, 3)                         AS xg_away,
    round(p.expected_goals_home
        + p.expected_goals_away, 3)                         AS combined_xg,
    round(p.expected_goals_home
        - p.expected_goals_away, 3)                         AS xg_diff,
    p.total_shots_home,
    p.total_shots_away,
    p.total_shots_home
        + p.total_shots_away                                AS combined_shots,
    p.shots_on_target_home,
    p.shots_on_target_away,
    p.shots_on_target_home
        + p.shots_on_target_away                            AS combined_shots_on_target,
    p.shots_inside_box_home,
    p.shots_inside_box_away,
    p.big_chances_home,
    p.big_chances_away,
    p.big_chances_home
        + p.big_chances_away                                AS combined_big_chances,
    p.ball_possession_home,
    p.ball_possession_away,
    round(p.expected_goals_open_play_home, 3)               AS xg_open_play_home,
    round(p.expected_goals_open_play_away, 3)               AS xg_open_play_away,
    round(p.expected_goals_open_play_home
        + p.expected_goals_open_play_away, 3)               AS combined_xg_open_play,
    round(
          (p.expected_goals_home + p.expected_goals_away) * 5.0
        + (p.total_shots_home + p.total_shots_away)   * 0.4
        + (p.big_chances_home + p.big_chances_away)   * 3.0
        + (g.home_score + g.away_score)               * 2.0
    , 2)                                                    AS chaos_score,

    CASE
        WHEN least(p.expected_goals_home, p.expected_goals_away)
            / nullIf(greatest(p.expected_goals_home, p.expected_goals_away), 0)
            >= 0.6 THEN 'balanced_shootout'
        ELSE 'lopsided_chaos'
    END AS chaos_type,

    CASE
        WHEN g.home_score > g.away_score THEN 'Home Win'
        WHEN g.away_score > g.home_score THEN 'Away Win'
        ELSE 'Draw'
    END AS match_result,
    toString(g.match_date)

FROM silver.match AS g
INNER JOIN silver.period_stat AS p
    ON g.match_id = p.match_id
    AND p.period = 'All'
WHERE
    g.match_finished = 1
    AND p.expected_goals_home + p.expected_goals_away > 4.5
    AND p.total_shots_home + p.total_shots_away > 35
    AND p.expected_goals_home > 1.5
    AND p.expected_goals_away > 1.5
ORDER BY chaos_score DESC;
