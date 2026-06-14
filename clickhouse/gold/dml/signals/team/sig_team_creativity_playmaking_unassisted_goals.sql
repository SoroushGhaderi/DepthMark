INSERT INTO gold.sig_team_creativity_playmaking_unassisted_goals (
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
    trigger_threshold_min_unassisted_solo_goals,
    trigger_threshold_max_assists_on_solo_goals,
    triggered_team_unassisted_solo_goals,
    opponent_unassisted_solo_goals,
    unassisted_solo_goals_delta,
    triggered_team_unassisted_dribble_goals,
    opponent_unassisted_dribble_goals,
    unassisted_dribble_goals_delta,
    triggered_team_unassisted_long_shot_goals,
    opponent_unassisted_long_shot_goals,
    unassisted_long_shot_goals_delta,
    triggered_team_unassisted_non_own_goals,
    opponent_unassisted_non_own_goals,
    unassisted_non_own_goals_delta,
    triggered_team_non_own_goals,
    opponent_non_own_goals,
    non_own_goals_delta,
    triggered_team_unassisted_solo_goal_share_of_non_own_goals_pct,
    opponent_unassisted_solo_goal_share_of_non_own_goals_pct,
    unassisted_solo_goal_share_of_non_own_goals_delta_pct,
    triggered_team_goals,
    opponent_goals,
    goal_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    triggered_team_shots_on_target,
    opponent_shots_on_target,
    triggered_team_shot_accuracy_pct,
    opponent_shot_accuracy_pct,
    shot_accuracy_delta_pct,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_touches_opposition_box,
    opponent_touches_opposition_box,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct
)
-- Signal: sig_team_creativity_playmaking_unassisted_goals
-- Trigger: Team records >= 2 unassisted solo-effort goals (dribble-attributed or long-range)
--          in one finished match.
-- Intent: Capture self-created finishing sequences where goals come without assists through
--         individual dribble actions or long-range shooting execution.
WITH team_goal_style_rollup AS (
    SELECT
        s.match_id,
        toInt32(s.team_id) AS team_id,
        toInt32(countIf(coalesce(s.is_goal, 0) = 1 AND coalesce(s.is_own_goal, 0) = 0))
            AS team_non_own_goals,
        toInt32(countIf(
            coalesce(s.is_goal, 0) = 1
            AND coalesce(s.is_own_goal, 0) = 0
            AND coalesce(s.assist_player_id, 0) = 0
        )) AS team_unassisted_non_own_goals,
        toInt32(countIf(
            coalesce(s.is_goal, 0) = 1
            AND coalesce(s.is_own_goal, 0) = 0
            AND coalesce(s.assist_player_id, 0) = 0
            AND (
                positionCaseInsensitiveUTF8(coalesce(s.shot_type, ''), 'dribble') > 0
                OR positionCaseInsensitiveUTF8(coalesce(s.situation, ''), 'dribble') > 0
                OR positionCaseInsensitiveUTF8(coalesce(s.goal_description, ''), 'dribble') > 0
                OR positionCaseInsensitiveUTF8(coalesce(s.goal_description, ''), 'solo') > 0
                OR positionCaseInsensitiveUTF8(coalesce(s.goal_description, ''), 'individual') > 0
            )
        )) AS team_unassisted_dribble_goals,
        toInt32(countIf(
            coalesce(s.is_goal, 0) = 1
            AND coalesce(s.is_own_goal, 0) = 0
            AND coalesce(s.assist_player_id, 0) = 0
            AND NOT (
                positionCaseInsensitiveUTF8(coalesce(s.shot_type, ''), 'dribble') > 0
                OR positionCaseInsensitiveUTF8(coalesce(s.situation, ''), 'dribble') > 0
                OR positionCaseInsensitiveUTF8(coalesce(s.goal_description, ''), 'dribble') > 0
                OR positionCaseInsensitiveUTF8(coalesce(s.goal_description, ''), 'solo') > 0
                OR positionCaseInsensitiveUTF8(coalesce(s.goal_description, ''), 'individual') > 0
            )
            AND (
                coalesce(s.is_from_inside_box, 1) = 0
                OR positionCaseInsensitiveUTF8(coalesce(s.shot_type, ''), 'outside') > 0
                OR positionCaseInsensitiveUTF8(coalesce(s.shot_type, ''), 'long') > 0
                OR positionCaseInsensitiveUTF8(coalesce(s.situation, ''), 'outside') > 0
                OR positionCaseInsensitiveUTF8(coalesce(s.goal_description, ''), 'long') > 0
                OR positionCaseInsensitiveUTF8(coalesce(s.goal_description, ''), 'distance') > 0
            )
        )) AS team_unassisted_long_shot_goals
    FROM silver.shot AS s
    WHERE s.match_id > 0
      AND coalesce(s.team_id, 0) > 0
    GROUP BY
        s.match_id,
        toInt32(s.team_id)
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

    toInt32(2) AS trigger_threshold_min_unassisted_solo_goals,
    toInt32(0) AS trigger_threshold_max_assists_on_solo_goals,

    toInt32(
        coalesce(home_goal.team_unassisted_dribble_goals, 0)
      + coalesce(home_goal.team_unassisted_long_shot_goals, 0)
    ) AS triggered_team_unassisted_solo_goals,
    toInt32(
        coalesce(away_goal.team_unassisted_dribble_goals, 0)
      + coalesce(away_goal.team_unassisted_long_shot_goals, 0)
    ) AS opponent_unassisted_solo_goals,
    toInt32(
        coalesce(home_goal.team_unassisted_dribble_goals, 0)
      + coalesce(home_goal.team_unassisted_long_shot_goals, 0)
      - coalesce(away_goal.team_unassisted_dribble_goals, 0)
      - coalesce(away_goal.team_unassisted_long_shot_goals, 0)
    ) AS unassisted_solo_goals_delta,

    toInt32(coalesce(home_goal.team_unassisted_dribble_goals, 0)) AS triggered_team_unassisted_dribble_goals,
    toInt32(coalesce(away_goal.team_unassisted_dribble_goals, 0)) AS opponent_unassisted_dribble_goals,
    toInt32(
        coalesce(home_goal.team_unassisted_dribble_goals, 0)
      - coalesce(away_goal.team_unassisted_dribble_goals, 0)
    ) AS unassisted_dribble_goals_delta,

    toInt32(coalesce(home_goal.team_unassisted_long_shot_goals, 0))
        AS triggered_team_unassisted_long_shot_goals,
    toInt32(coalesce(away_goal.team_unassisted_long_shot_goals, 0))
        AS opponent_unassisted_long_shot_goals,
    toInt32(
        coalesce(home_goal.team_unassisted_long_shot_goals, 0)
      - coalesce(away_goal.team_unassisted_long_shot_goals, 0)
    ) AS unassisted_long_shot_goals_delta,

    toInt32(coalesce(home_goal.team_unassisted_non_own_goals, 0)) AS triggered_team_unassisted_non_own_goals,
    toInt32(coalesce(away_goal.team_unassisted_non_own_goals, 0)) AS opponent_unassisted_non_own_goals,
    toInt32(
        coalesce(home_goal.team_unassisted_non_own_goals, 0)
      - coalesce(away_goal.team_unassisted_non_own_goals, 0)
    ) AS unassisted_non_own_goals_delta,

    toInt32(coalesce(home_goal.team_non_own_goals, 0)) AS triggered_team_non_own_goals,
    toInt32(coalesce(away_goal.team_non_own_goals, 0)) AS opponent_non_own_goals,
    toInt32(coalesce(home_goal.team_non_own_goals, 0) - coalesce(away_goal.team_non_own_goals, 0))
        AS non_own_goals_delta,

    toFloat32(coalesce(round(
        100.0 * (
            coalesce(home_goal.team_unassisted_dribble_goals, 0)
          + coalesce(home_goal.team_unassisted_long_shot_goals, 0)
        ) / nullIf(toFloat64(coalesce(home_goal.team_non_own_goals, 0)), 0),
        1
    ), 0.0)) AS triggered_team_unassisted_solo_goal_share_of_non_own_goals_pct,
    toFloat32(coalesce(round(
        100.0 * (
            coalesce(away_goal.team_unassisted_dribble_goals, 0)
          + coalesce(away_goal.team_unassisted_long_shot_goals, 0)
        ) / nullIf(toFloat64(coalesce(away_goal.team_non_own_goals, 0)), 0),
        1
    ), 0.0)) AS opponent_unassisted_solo_goal_share_of_non_own_goals_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * (
                coalesce(home_goal.team_unassisted_dribble_goals, 0)
              + coalesce(home_goal.team_unassisted_long_shot_goals, 0)
            ) / nullIf(toFloat64(coalesce(home_goal.team_non_own_goals, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * (
                coalesce(away_goal.team_unassisted_dribble_goals, 0)
              + coalesce(away_goal.team_unassisted_long_shot_goals, 0)
            ) / nullIf(toFloat64(coalesce(away_goal.team_non_own_goals, 0)), 0),
            1
        ), 0.0),
        1
    )) AS unassisted_solo_goal_share_of_non_own_goals_delta_pct,

    toInt32(coalesce(m.home_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.away_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.home_score, 0) - coalesce(m.away_score, 0)) AS goal_delta,

    toInt32(coalesce(ps.total_shots_home, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_away, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS opponent_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_home, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        1
    ), 0.0)) AS triggered_team_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_away, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        1
    ), 0.0)) AS opponent_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.shots_on_target_home, 0)
                / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.shots_on_target_away, 0)
                / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
            1
        ), 0.0),
        1
    )) AS shot_accuracy_delta_pct,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_home, 0.0) - coalesce(ps.expected_goals_away, 0.0), 3))
        AS xg_delta,
    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS opponent_touches_opposition_box,
    toInt32(coalesce(ps.pass_attempts_home, 0)) AS triggered_team_pass_attempts,
    toInt32(coalesce(ps.pass_attempts_away, 0)) AS opponent_pass_attempts,
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
    toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_home, 0.0) - coalesce(ps.ball_possession_away, 0.0), 1))
        AS possession_delta_pct
FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN team_goal_style_rollup AS home_goal
    ON home_goal.match_id = m.match_id
   AND home_goal.team_id = m.home_team_id
LEFT JOIN team_goal_style_rollup AS away_goal
    ON away_goal.match_id = m.match_id
   AND away_goal.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND (
        coalesce(home_goal.team_unassisted_dribble_goals, 0)
      + coalesce(home_goal.team_unassisted_long_shot_goals, 0)
  ) >= 2

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

    toInt32(2) AS trigger_threshold_min_unassisted_solo_goals,
    toInt32(0) AS trigger_threshold_max_assists_on_solo_goals,

    toInt32(
        coalesce(away_goal.team_unassisted_dribble_goals, 0)
      + coalesce(away_goal.team_unassisted_long_shot_goals, 0)
    ) AS triggered_team_unassisted_solo_goals,
    toInt32(
        coalesce(home_goal.team_unassisted_dribble_goals, 0)
      + coalesce(home_goal.team_unassisted_long_shot_goals, 0)
    ) AS opponent_unassisted_solo_goals,
    toInt32(
        coalesce(away_goal.team_unassisted_dribble_goals, 0)
      + coalesce(away_goal.team_unassisted_long_shot_goals, 0)
      - coalesce(home_goal.team_unassisted_dribble_goals, 0)
      - coalesce(home_goal.team_unassisted_long_shot_goals, 0)
    ) AS unassisted_solo_goals_delta,

    toInt32(coalesce(away_goal.team_unassisted_dribble_goals, 0)) AS triggered_team_unassisted_dribble_goals,
    toInt32(coalesce(home_goal.team_unassisted_dribble_goals, 0)) AS opponent_unassisted_dribble_goals,
    toInt32(
        coalesce(away_goal.team_unassisted_dribble_goals, 0)
      - coalesce(home_goal.team_unassisted_dribble_goals, 0)
    ) AS unassisted_dribble_goals_delta,

    toInt32(coalesce(away_goal.team_unassisted_long_shot_goals, 0))
        AS triggered_team_unassisted_long_shot_goals,
    toInt32(coalesce(home_goal.team_unassisted_long_shot_goals, 0))
        AS opponent_unassisted_long_shot_goals,
    toInt32(
        coalesce(away_goal.team_unassisted_long_shot_goals, 0)
      - coalesce(home_goal.team_unassisted_long_shot_goals, 0)
    ) AS unassisted_long_shot_goals_delta,

    toInt32(coalesce(away_goal.team_unassisted_non_own_goals, 0)) AS triggered_team_unassisted_non_own_goals,
    toInt32(coalesce(home_goal.team_unassisted_non_own_goals, 0)) AS opponent_unassisted_non_own_goals,
    toInt32(
        coalesce(away_goal.team_unassisted_non_own_goals, 0)
      - coalesce(home_goal.team_unassisted_non_own_goals, 0)
    ) AS unassisted_non_own_goals_delta,

    toInt32(coalesce(away_goal.team_non_own_goals, 0)) AS triggered_team_non_own_goals,
    toInt32(coalesce(home_goal.team_non_own_goals, 0)) AS opponent_non_own_goals,
    toInt32(coalesce(away_goal.team_non_own_goals, 0) - coalesce(home_goal.team_non_own_goals, 0))
        AS non_own_goals_delta,

    toFloat32(coalesce(round(
        100.0 * (
            coalesce(away_goal.team_unassisted_dribble_goals, 0)
          + coalesce(away_goal.team_unassisted_long_shot_goals, 0)
        ) / nullIf(toFloat64(coalesce(away_goal.team_non_own_goals, 0)), 0),
        1
    ), 0.0)) AS triggered_team_unassisted_solo_goal_share_of_non_own_goals_pct,
    toFloat32(coalesce(round(
        100.0 * (
            coalesce(home_goal.team_unassisted_dribble_goals, 0)
          + coalesce(home_goal.team_unassisted_long_shot_goals, 0)
        ) / nullIf(toFloat64(coalesce(home_goal.team_non_own_goals, 0)), 0),
        1
    ), 0.0)) AS opponent_unassisted_solo_goal_share_of_non_own_goals_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * (
                coalesce(away_goal.team_unassisted_dribble_goals, 0)
              + coalesce(away_goal.team_unassisted_long_shot_goals, 0)
            ) / nullIf(toFloat64(coalesce(away_goal.team_non_own_goals, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * (
                coalesce(home_goal.team_unassisted_dribble_goals, 0)
              + coalesce(home_goal.team_unassisted_long_shot_goals, 0)
            ) / nullIf(toFloat64(coalesce(home_goal.team_non_own_goals, 0)), 0),
            1
        ), 0.0),
        1
    )) AS unassisted_solo_goal_share_of_non_own_goals_delta_pct,

    toInt32(coalesce(m.away_score, 0)) AS triggered_team_goals,
    toInt32(coalesce(m.home_score, 0)) AS opponent_goals,
    toInt32(coalesce(m.away_score, 0) - coalesce(m.home_score, 0)) AS goal_delta,

    toInt32(coalesce(ps.total_shots_away, 0)) AS triggered_team_total_shots,
    toInt32(coalesce(ps.total_shots_home, 0)) AS opponent_total_shots,
    toInt32(coalesce(ps.shots_on_target_away, 0)) AS triggered_team_shots_on_target,
    toInt32(coalesce(ps.shots_on_target_home, 0)) AS opponent_shots_on_target,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_away, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
        1
    ), 0.0)) AS triggered_team_shot_accuracy_pct,
    toFloat32(coalesce(round(
        100.0 * coalesce(ps.shots_on_target_home, 0)
            / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
        1
    ), 0.0)) AS opponent_shot_accuracy_pct,
    toFloat32(round(
        coalesce(round(
            100.0 * coalesce(ps.shots_on_target_away, 0)
                / nullIf(toFloat64(coalesce(ps.total_shots_away, 0)), 0),
            1
        ), 0.0)
      - coalesce(round(
            100.0 * coalesce(ps.shots_on_target_home, 0)
                / nullIf(toFloat64(coalesce(ps.total_shots_home, 0)), 0),
            1
        ), 0.0),
        1
    )) AS shot_accuracy_delta_pct,
    toFloat32(coalesce(ps.expected_goals_away, 0.0)) AS triggered_team_xg,
    toFloat32(coalesce(ps.expected_goals_home, 0.0)) AS opponent_xg,
    toFloat32(round(coalesce(ps.expected_goals_away, 0.0) - coalesce(ps.expected_goals_home, 0.0), 3))
        AS xg_delta,
    toInt32(coalesce(ps.touches_opp_box_away, 0)) AS triggered_team_touches_opposition_box,
    toInt32(coalesce(ps.touches_opp_box_home, 0)) AS opponent_touches_opposition_box,
    toInt32(coalesce(ps.pass_attempts_away, 0)) AS triggered_team_pass_attempts,
    toInt32(coalesce(ps.pass_attempts_home, 0)) AS opponent_pass_attempts,
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
    toFloat32(coalesce(ps.ball_possession_away, 0.0)) AS triggered_team_possession_pct,
    toFloat32(coalesce(ps.ball_possession_home, 0.0)) AS opponent_possession_pct,
    toFloat32(round(coalesce(ps.ball_possession_away, 0.0) - coalesce(ps.ball_possession_home, 0.0), 1))
        AS possession_delta_pct
FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = m.match_id
   AND ps.match_date = m.match_date
   AND ps.period = 'All'
LEFT JOIN team_goal_style_rollup AS home_goal
    ON home_goal.match_id = m.match_id
   AND home_goal.team_id = m.home_team_id
LEFT JOIN team_goal_style_rollup AS away_goal
    ON away_goal.match_id = m.match_id
   AND away_goal.team_id = m.away_team_id
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND (
        coalesce(away_goal.team_unassisted_dribble_goals, 0)
      + coalesce(away_goal.team_unassisted_long_shot_goals, 0)
  ) >= 2;
