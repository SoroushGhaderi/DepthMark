INSERT INTO gold.sig_team_creativity_playmaking_total_fluidity (
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
    trigger_threshold_min_distinct_key_pass_players,
    triggered_team_distinct_key_pass_players,
    triggered_team_distinct_key_pass_players_above_threshold,
    opponent_distinct_key_pass_players,
    distinct_key_pass_players_delta,
    triggered_team_total_key_passes,
    opponent_total_key_passes,
    total_key_passes_delta,
    triggered_team_key_passes_per_creator,
    opponent_key_passes_per_creator,
    key_passes_per_creator_delta,
    triggered_team_multi_key_pass_creators,
    opponent_multi_key_pass_creators,
    multi_key_pass_creators_delta,
    triggered_team_top_creator_key_passes,
    opponent_top_creator_key_passes,
    top_creator_key_passes_delta,
    triggered_team_top_creator_share_pct,
    opponent_top_creator_share_pct,
    top_creator_share_delta_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_accurate_passes,
    opponent_accurate_passes,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_opposition_half_passes,
    opponent_opposition_half_passes,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct
)
-- Signal: sig_team_creativity_playmaking_total_fluidity
-- Trigger: Team has >= 6 different players record at least one key pass proxy
--          (player_match_stat.chances_created >= 1) in one finished match.
-- Intent: Detect distributed team-level chance creation where playmaking load is shared
--         across many players instead of concentrated in one or two creators.
WITH player_key_pass_creators AS (
    SELECT
        p.match_id,
        toInt32(p.team_id) AS team_id,
        toInt32(p.player_id) AS player_id,
        toInt32(max(coalesce(p.chances_created, 0))) AS player_key_passes
    FROM silver.player_match_stat AS p
    WHERE p.match_id > 0
      AND p.team_id > 0
      AND p.player_id > 0
    GROUP BY
        p.match_id,
        team_id,
        player_id
    HAVING player_key_passes >= 1
), team_key_pass_rollup AS (
    SELECT
        pk.match_id,
        pk.team_id,
        toInt32(count()) AS team_distinct_key_pass_players,
        toInt32(sum(pk.player_key_passes)) AS team_total_key_passes,
        toFloat32(coalesce(round(sum(pk.player_key_passes) / nullIf(toFloat64(count()), 0), 2), 0.0))
            AS team_key_passes_per_creator,
        toInt32(countIf(pk.player_key_passes >= 2)) AS team_multi_key_pass_creators,
        toInt32(max(pk.player_key_passes)) AS team_top_creator_key_passes,
        toFloat32(coalesce(round(
            100.0 * max(pk.player_key_passes)
                / nullIf(toFloat64(sum(pk.player_key_passes)), 0),
            1
        ), 0.0)) AS team_top_creator_share_pct
    FROM player_key_pass_creators AS pk
    GROUP BY
        pk.match_id,
        pk.team_id
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

    toInt32(6) AS trigger_threshold_min_distinct_key_pass_players,
    toInt32(coalesce(home_roll.team_distinct_key_pass_players, 0))
        AS triggered_team_distinct_key_pass_players,
    toInt32(coalesce(home_roll.team_distinct_key_pass_players, 0) - 6)
        AS triggered_team_distinct_key_pass_players_above_threshold,
    toInt32(coalesce(away_roll.team_distinct_key_pass_players, 0))
        AS opponent_distinct_key_pass_players,
    toInt32(
        coalesce(home_roll.team_distinct_key_pass_players, 0)
      - coalesce(away_roll.team_distinct_key_pass_players, 0)
    ) AS distinct_key_pass_players_delta,

    toInt32(coalesce(home_roll.team_total_key_passes, 0)) AS triggered_team_total_key_passes,
    toInt32(coalesce(away_roll.team_total_key_passes, 0)) AS opponent_total_key_passes,
    toInt32(coalesce(home_roll.team_total_key_passes, 0) - coalesce(away_roll.team_total_key_passes, 0))
        AS total_key_passes_delta,

    toFloat32(coalesce(home_roll.team_key_passes_per_creator, 0.0))
        AS triggered_team_key_passes_per_creator,
    toFloat32(coalesce(away_roll.team_key_passes_per_creator, 0.0))
        AS opponent_key_passes_per_creator,
    toFloat32(round(
        coalesce(home_roll.team_key_passes_per_creator, 0.0)
      - coalesce(away_roll.team_key_passes_per_creator, 0.0),
        2
    )) AS key_passes_per_creator_delta,

    toInt32(coalesce(home_roll.team_multi_key_pass_creators, 0))
        AS triggered_team_multi_key_pass_creators,
    toInt32(coalesce(away_roll.team_multi_key_pass_creators, 0))
        AS opponent_multi_key_pass_creators,
    toInt32(
        coalesce(home_roll.team_multi_key_pass_creators, 0)
      - coalesce(away_roll.team_multi_key_pass_creators, 0)
    ) AS multi_key_pass_creators_delta,

    toInt32(coalesce(home_roll.team_top_creator_key_passes, 0))
        AS triggered_team_top_creator_key_passes,
    toInt32(coalesce(away_roll.team_top_creator_key_passes, 0))
        AS opponent_top_creator_key_passes,
    toInt32(
        coalesce(home_roll.team_top_creator_key_passes, 0)
      - coalesce(away_roll.team_top_creator_key_passes, 0)
    ) AS top_creator_key_passes_delta,

    toFloat32(coalesce(home_roll.team_top_creator_share_pct, 0.0))
        AS triggered_team_top_creator_share_pct,
    toFloat32(coalesce(away_roll.team_top_creator_share_pct, 0.0))
        AS opponent_top_creator_share_pct,
    toFloat32(round(
        coalesce(home_roll.team_top_creator_share_pct, 0.0)
      - coalesce(away_roll.team_top_creator_share_pct, 0.0),
        1
    )) AS top_creator_share_delta_pct,

    toInt32(coalesce(ps.pass_attempts_home, 0)) AS triggered_team_pass_attempts,
    toInt32(coalesce(ps.pass_attempts_away, 0)) AS opponent_pass_attempts,
    toInt32(coalesce(ps.accurate_passes_home, 0)) AS triggered_team_accurate_passes,
    toInt32(coalesce(ps.accurate_passes_away, 0)) AS opponent_accurate_passes,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0)
            / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0)
            / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0)
                / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0)
                / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    toInt32(coalesce(ps.opposition_half_passes_home, 0)) AS triggered_team_opposition_half_passes,
    toInt32(coalesce(ps.opposition_half_passes_away, 0)) AS opponent_opposition_half_passes,
    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS opponent_touches_opposition_box,
    toInt32(coalesce(ps.total_shots_home, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_away, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS opponent_shots_on_target,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_home, 0.0) - coalesce(ps.expected_goals_away, 0.0), 3))
        AS xg_delta,
    toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_home, 0.0) - coalesce(ps.ball_possession_away, 0.0), 1))
        AS possession_delta_pct
FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN team_key_pass_rollup AS home_roll
    ON home_roll.match_id = m.match_id
   AND home_roll.team_id = m.home_team_id
LEFT JOIN team_key_pass_rollup AS away_roll
    ON away_roll.match_id = m.match_id
   AND away_roll.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(home_roll.team_distinct_key_pass_players, 0) >= 6

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

    toInt32(6) AS trigger_threshold_min_distinct_key_pass_players,
    toInt32(coalesce(away_roll.team_distinct_key_pass_players, 0))
        AS triggered_team_distinct_key_pass_players,
    toInt32(coalesce(away_roll.team_distinct_key_pass_players, 0) - 6)
        AS triggered_team_distinct_key_pass_players_above_threshold,
    toInt32(coalesce(home_roll.team_distinct_key_pass_players, 0))
        AS opponent_distinct_key_pass_players,
    toInt32(
        coalesce(away_roll.team_distinct_key_pass_players, 0)
      - coalesce(home_roll.team_distinct_key_pass_players, 0)
    ) AS distinct_key_pass_players_delta,

    toInt32(coalesce(away_roll.team_total_key_passes, 0)) AS triggered_team_total_key_passes,
    toInt32(coalesce(home_roll.team_total_key_passes, 0)) AS opponent_total_key_passes,
    toInt32(coalesce(away_roll.team_total_key_passes, 0) - coalesce(home_roll.team_total_key_passes, 0))
        AS total_key_passes_delta,

    toFloat32(coalesce(away_roll.team_key_passes_per_creator, 0.0))
        AS triggered_team_key_passes_per_creator,
    toFloat32(coalesce(home_roll.team_key_passes_per_creator, 0.0))
        AS opponent_key_passes_per_creator,
    toFloat32(round(
        coalesce(away_roll.team_key_passes_per_creator, 0.0)
      - coalesce(home_roll.team_key_passes_per_creator, 0.0),
        2
    )) AS key_passes_per_creator_delta,

    toInt32(coalesce(away_roll.team_multi_key_pass_creators, 0))
        AS triggered_team_multi_key_pass_creators,
    toInt32(coalesce(home_roll.team_multi_key_pass_creators, 0))
        AS opponent_multi_key_pass_creators,
    toInt32(
        coalesce(away_roll.team_multi_key_pass_creators, 0)
      - coalesce(home_roll.team_multi_key_pass_creators, 0)
    ) AS multi_key_pass_creators_delta,

    toInt32(coalesce(away_roll.team_top_creator_key_passes, 0))
        AS triggered_team_top_creator_key_passes,
    toInt32(coalesce(home_roll.team_top_creator_key_passes, 0))
        AS opponent_top_creator_key_passes,
    toInt32(
        coalesce(away_roll.team_top_creator_key_passes, 0)
      - coalesce(home_roll.team_top_creator_key_passes, 0)
    ) AS top_creator_key_passes_delta,

    toFloat32(coalesce(away_roll.team_top_creator_share_pct, 0.0))
        AS triggered_team_top_creator_share_pct,
    toFloat32(coalesce(home_roll.team_top_creator_share_pct, 0.0))
        AS opponent_top_creator_share_pct,
    toFloat32(round(
        coalesce(away_roll.team_top_creator_share_pct, 0.0)
      - coalesce(home_roll.team_top_creator_share_pct, 0.0),
        1
    )) AS top_creator_share_delta_pct,

    toInt32(coalesce(ps.pass_attempts_away, 0)) AS triggered_team_pass_attempts,
    toInt32(coalesce(ps.pass_attempts_home, 0)) AS opponent_pass_attempts,
    toInt32(coalesce(ps.accurate_passes_away, 0)) AS triggered_team_accurate_passes,
    toInt32(coalesce(ps.accurate_passes_home, 0)) AS opponent_accurate_passes,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_away, 0)
            / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_pass_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.accurate_passes_home, 0)
            / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
        1
    ), 0.0)) AS opponent_pass_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.accurate_passes_away, 0)
                / nullIf(toFloat64(coalesce(ps.pass_attempts_away, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.accurate_passes_home, 0)
                / nullIf(toFloat64(coalesce(ps.pass_attempts_home, 0)), 0),
            1
        ), 0.0),
        1
    )) AS pass_accuracy_delta_pct,

    toInt32(coalesce(ps.opposition_half_passes_away, 0)) AS triggered_team_opposition_half_passes,
    toInt32(coalesce(ps.opposition_half_passes_home, 0)) AS opponent_opposition_half_passes,
    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS opponent_touches_opposition_box,
    toInt32(coalesce(ps.total_shots_away, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_home, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS opponent_shots_on_target,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_away, 0.0) - coalesce(ps.expected_goals_home, 0.0), 3))
        AS xg_delta,
    toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_away, 0.0) - coalesce(ps.ball_possession_home, 0.0), 1))
        AS possession_delta_pct
FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN team_key_pass_rollup AS home_roll
    ON home_roll.match_id = m.match_id
   AND home_roll.team_id = m.home_team_id
LEFT JOIN team_key_pass_rollup AS away_roll
    ON away_roll.match_id = m.match_id
   AND away_roll.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND coalesce(away_roll.team_distinct_key_pass_players, 0) >= 6;
