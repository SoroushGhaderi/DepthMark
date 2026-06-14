INSERT INTO gold.sig_team_shooting_goals_shared_scoring (
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
    trigger_threshold_min_distinct_goal_scorers,
    triggered_team_distinct_goal_scorers,
    opponent_distinct_goal_scorers,
    distinct_goal_scorers_delta,
    triggered_team_non_own_goals,
    opponent_non_own_goals,
    non_own_goals_delta,
    triggered_team_single_goal_scorers,
    opponent_single_goal_scorers,
    single_goal_scorers_delta,
    triggered_team_multi_goal_scorers,
    opponent_multi_goal_scorers,
    multi_goal_scorers_delta,
    triggered_team_top_scorer_goals,
    opponent_top_scorer_goals,
    top_scorer_goals_delta,
    triggered_team_top_scorer_goal_share_pct,
    opponent_top_scorer_goal_share_pct,
    top_scorer_goal_share_delta_pct,
    triggered_team_scorer_spread_pct,
    opponent_scorer_spread_pct,
    scorer_spread_delta_pct,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_big_chances,
    opponent_big_chances,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct
)
-- Signal: sig_team_shooting_goals_shared_scoring
-- Trigger: Team has >= 4 different non-own-goal scorers in one finished match.
-- Intent: Capture team-level distributed finishing where scoring is shared across many players,
--         with bilateral context on scorer concentration and shooting control profile.
WITH goal_events AS (
    SELECT
        s.match_id,
        toInt32(s.team_id) AS team_id,
        multiIf(
            coalesce(s.player_id, 0) > 0,
            concat('id:', toString(toInt32(s.player_id))),
            length(trimBoth(coalesce(s.player_name, ''))) > 0,
            concat('name:', lowerUTF8(trimBoth(coalesce(s.player_name, '')))),
            concat('fallback_shot:', toString(toInt64(coalesce(s.shot_id, 0))))
        ) AS scorer_key
    FROM silver.shot AS s
    WHERE s.match_id > 0
      AND coalesce(s.team_id, 0) > 0
      AND coalesce(s.is_goal, 0) = 1
      AND coalesce(s.is_own_goal, 0) = 0
),
scorer_goal_counts AS (
    SELECT
        ge.match_id,
        ge.team_id,
        ge.scorer_key,
        toInt32(count()) AS goals_by_scorer
    FROM goal_events AS ge
    GROUP BY
        ge.match_id,
        ge.team_id,
        ge.scorer_key
),
team_goal_scorer_rollup AS (
    SELECT
        sgc.match_id,
        sgc.team_id,
        toInt32(count()) AS team_distinct_goal_scorers,
        toInt32(sum(sgc.goals_by_scorer)) AS team_non_own_goals,
        toInt32(countIf(sgc.goals_by_scorer = 1)) AS team_single_goal_scorers,
        toInt32(countIf(sgc.goals_by_scorer >= 2)) AS team_multi_goal_scorers,
        toInt32(max(sgc.goals_by_scorer)) AS team_top_scorer_goals,
        toFloat32(coalesce(round(
            100.0 * max(sgc.goals_by_scorer)
                / nullIf(toFloat64(sum(sgc.goals_by_scorer)), 0),
            1
        ), 0.0)) AS team_top_scorer_goal_share_pct,
        toFloat32(coalesce(round(
            100.0 * count()
                / nullIf(toFloat64(sum(sgc.goals_by_scorer)), 0),
            1
        ), 0.0)) AS team_scorer_spread_pct
    FROM scorer_goal_counts AS sgc
    GROUP BY
        sgc.match_id,
        sgc.team_id
)

-- Home-side trigger.
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

    toInt32(4) AS trigger_threshold_min_distinct_goal_scorers,

    toInt32(coalesce(home_sc.team_distinct_goal_scorers, 0)) AS triggered_team_distinct_goal_scorers,
    toInt32(coalesce(away_sc.team_distinct_goal_scorers, 0)) AS opponent_distinct_goal_scorers,
    toInt32(
        coalesce(home_sc.team_distinct_goal_scorers, 0)
      - coalesce(away_sc.team_distinct_goal_scorers, 0)
    ) AS distinct_goal_scorers_delta,

    toInt32(coalesce(home_sc.team_non_own_goals, 0)) AS triggered_team_non_own_goals,
    toInt32(coalesce(away_sc.team_non_own_goals, 0)) AS opponent_non_own_goals,
    toInt32(
        coalesce(home_sc.team_non_own_goals, 0)
      - coalesce(away_sc.team_non_own_goals, 0)
    ) AS non_own_goals_delta,

    toInt32(coalesce(home_sc.team_single_goal_scorers, 0)) AS triggered_team_single_goal_scorers,
    toInt32(coalesce(away_sc.team_single_goal_scorers, 0)) AS opponent_single_goal_scorers,
    toInt32(
        coalesce(home_sc.team_single_goal_scorers, 0)
      - coalesce(away_sc.team_single_goal_scorers, 0)
    ) AS single_goal_scorers_delta,

    toInt32(coalesce(home_sc.team_multi_goal_scorers, 0)) AS triggered_team_multi_goal_scorers,
    toInt32(coalesce(away_sc.team_multi_goal_scorers, 0)) AS opponent_multi_goal_scorers,
    toInt32(
        coalesce(home_sc.team_multi_goal_scorers, 0)
      - coalesce(away_sc.team_multi_goal_scorers, 0)
    ) AS multi_goal_scorers_delta,

    toInt32(coalesce(home_sc.team_top_scorer_goals, 0)) AS triggered_team_top_scorer_goals,
    toInt32(coalesce(away_sc.team_top_scorer_goals, 0)) AS opponent_top_scorer_goals,
    toInt32(
        coalesce(home_sc.team_top_scorer_goals, 0)
      - coalesce(away_sc.team_top_scorer_goals, 0)
    ) AS top_scorer_goals_delta,

    toFloat32(coalesce(home_sc.team_top_scorer_goal_share_pct, 0.0))
        AS triggered_team_top_scorer_goal_share_pct,
    toFloat32(coalesce(away_sc.team_top_scorer_goal_share_pct, 0.0))
        AS opponent_top_scorer_goal_share_pct,
    toFloat32(round(
        coalesce(home_sc.team_top_scorer_goal_share_pct, 0.0)
      - coalesce(away_sc.team_top_scorer_goal_share_pct, 0.0),
        1
    )) AS top_scorer_goal_share_delta_pct,

    toFloat32(coalesce(home_sc.team_scorer_spread_pct, 0.0)) AS triggered_team_scorer_spread_pct,
    toFloat32(coalesce(away_sc.team_scorer_spread_pct, 0.0)) AS opponent_scorer_spread_pct,
    toFloat32(round(
        coalesce(home_sc.team_scorer_spread_pct, 0.0)
      - coalesce(away_sc.team_scorer_spread_pct, 0.0),
        1
    )) AS scorer_spread_delta_pct,

    toInt32(coalesce(m.home_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.away_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.home_score, 0) - coalesce(m.away_score, 0)) AS goal_delta,

    toInt32(coalesce(ps.total_shots_home, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_away, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS opponent_shots_on_target,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_home, 0.0) - coalesce(ps.expected_goals_away, 0.0), 3))
        AS xg_delta,
    toInt32(coalesce(ps.big_chances_home, 0)) AS triggered_team_big_chances,
    toInt32(coalesce(ps.big_chances_away, 0)) AS opponent_big_chances,
    toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_home, 0.0) - coalesce(ps.ball_possession_away, 0.0), 1))
        AS possession_delta_pct

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN team_goal_scorer_rollup AS home_sc
    ON home_sc.match_id = m.match_id
   AND home_sc.team_id = m.home_team_id
LEFT JOIN team_goal_scorer_rollup AS away_sc
    ON away_sc.match_id = m.match_id
   AND away_sc.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(home_sc.team_distinct_goal_scorers, 0) >= 4

UNION ALL

-- Away-side trigger.
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

    toInt32(4) AS trigger_threshold_min_distinct_goal_scorers,

    toInt32(coalesce(away_sc.team_distinct_goal_scorers, 0)) AS triggered_team_distinct_goal_scorers,
    toInt32(coalesce(home_sc.team_distinct_goal_scorers, 0)) AS opponent_distinct_goal_scorers,
    toInt32(
        coalesce(away_sc.team_distinct_goal_scorers, 0)
      - coalesce(home_sc.team_distinct_goal_scorers, 0)
    ) AS distinct_goal_scorers_delta,

    toInt32(coalesce(away_sc.team_non_own_goals, 0)) AS triggered_team_non_own_goals,
    toInt32(coalesce(home_sc.team_non_own_goals, 0)) AS opponent_non_own_goals,
    toInt32(
        coalesce(away_sc.team_non_own_goals, 0)
      - coalesce(home_sc.team_non_own_goals, 0)
    ) AS non_own_goals_delta,

    toInt32(coalesce(away_sc.team_single_goal_scorers, 0)) AS triggered_team_single_goal_scorers,
    toInt32(coalesce(home_sc.team_single_goal_scorers, 0)) AS opponent_single_goal_scorers,
    toInt32(
        coalesce(away_sc.team_single_goal_scorers, 0)
      - coalesce(home_sc.team_single_goal_scorers, 0)
    ) AS single_goal_scorers_delta,

    toInt32(coalesce(away_sc.team_multi_goal_scorers, 0)) AS triggered_team_multi_goal_scorers,
    toInt32(coalesce(home_sc.team_multi_goal_scorers, 0)) AS opponent_multi_goal_scorers,
    toInt32(
        coalesce(away_sc.team_multi_goal_scorers, 0)
      - coalesce(home_sc.team_multi_goal_scorers, 0)
    ) AS multi_goal_scorers_delta,

    toInt32(coalesce(away_sc.team_top_scorer_goals, 0)) AS triggered_team_top_scorer_goals,
    toInt32(coalesce(home_sc.team_top_scorer_goals, 0)) AS opponent_top_scorer_goals,
    toInt32(
        coalesce(away_sc.team_top_scorer_goals, 0)
      - coalesce(home_sc.team_top_scorer_goals, 0)
    ) AS top_scorer_goals_delta,

    toFloat32(coalesce(away_sc.team_top_scorer_goal_share_pct, 0.0))
        AS triggered_team_top_scorer_goal_share_pct,
    toFloat32(coalesce(home_sc.team_top_scorer_goal_share_pct, 0.0))
        AS opponent_top_scorer_goal_share_pct,
    toFloat32(round(
        coalesce(away_sc.team_top_scorer_goal_share_pct, 0.0)
      - coalesce(home_sc.team_top_scorer_goal_share_pct, 0.0),
        1
    )) AS top_scorer_goal_share_delta_pct,

    toFloat32(coalesce(away_sc.team_scorer_spread_pct, 0.0)) AS triggered_team_scorer_spread_pct,
    toFloat32(coalesce(home_sc.team_scorer_spread_pct, 0.0)) AS opponent_scorer_spread_pct,
    toFloat32(round(
        coalesce(away_sc.team_scorer_spread_pct, 0.0)
      - coalesce(home_sc.team_scorer_spread_pct, 0.0),
        1
    )) AS scorer_spread_delta_pct,

    toInt32(coalesce(m.away_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.home_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.away_score, 0) - coalesce(m.home_score, 0)) AS goal_delta,

    toInt32(coalesce(ps.total_shots_away, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_home, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS opponent_shots_on_target,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_away, 0.0) - coalesce(ps.expected_goals_home, 0.0), 3))
        AS xg_delta,
    toInt32(coalesce(ps.big_chances_away, 0)) AS triggered_team_big_chances,
    toInt32(coalesce(ps.big_chances_home, 0)) AS opponent_big_chances,
    toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_away, 0.0) - coalesce(ps.ball_possession_home, 0.0), 1))
        AS possession_delta_pct

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN team_goal_scorer_rollup AS home_sc
    ON home_sc.match_id = m.match_id
   AND home_sc.team_id = m.home_team_id
LEFT JOIN team_goal_scorer_rollup AS away_sc
    ON away_sc.match_id = m.match_id
   AND away_sc.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(away_sc.team_distinct_goal_scorers, 0) >= 4

ORDER BY
    triggered_team_distinct_goal_scorers DESC,
    triggered_team_non_own_goals DESC,
    scorer_spread_delta_pct DESC,
    m.match_date DESC,
    m.match_id DESC;
