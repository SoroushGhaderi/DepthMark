INSERT INTO gold.sig_team_discipline_cards_red_card_neutralizer (
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
    trigger_threshold_minutes_after_red,
    triggered_team_first_red_card_minute,
    triggered_team_first_red_card_added_time,
    triggered_team_first_red_card_effective_minute,
    triggered_team_neutralizing_goal_minute,
    triggered_team_neutralizing_goal_added_time,
    triggered_team_neutralizing_goal_effective_minute,
    minutes_from_red_to_goal,
    triggered_team_score_at_first_red,
    opponent_score_at_first_red,
    score_margin_at_first_red,
    triggered_team_score_after_neutralizing_goal,
    opponent_score_after_neutralizing_goal,
    score_margin_after_neutralizing_goal,
    score_margin_swing_after_goal,
    triggered_team_neutralizing_goal_scorer_id,
    triggered_team_neutralizing_goal_scorer_name,
    triggered_team_neutralizing_goal_is_own_goal,
    triggered_team_red_cards_match,
    opponent_red_cards_match,
    red_cards_match_delta,
    triggered_team_yellow_cards_match,
    opponent_yellow_cards_match,
    triggered_team_total_cards_match,
    opponent_total_cards_match,
    card_count_match_delta,
    triggered_team_fouls_committed,
    opponent_fouls_committed,
    fouls_committed_delta,
    triggered_team_total_shots,
    opponent_total_shots,
    shot_delta,
    triggered_team_xg,
    opponent_xg,
    xg_delta,
    triggered_team_possession_pct,
    opponent_possession_pct,
    possession_delta_pct,
    triggered_team_pass_attempts,
    opponent_pass_attempts,
    triggered_team_pass_accuracy_pct,
    opponent_pass_accuracy_pct,
    triggered_team_duels_won,
    opponent_duels_won,
    triggered_team_tackles_won,
    opponent_tackles_won,
    triggered_team_interceptions,
    opponent_interceptions,
    triggered_team_clearances,
    opponent_clearances
)
-- Signal: sig_team_discipline_cards_red_card_neutralizer
-- Intent: identify teams that answer a red-card reduction immediately by scoring, preserving score-state, discipline, and match-control context.
-- Trigger: team scores a goal within five effective minutes of its first red card.
WITH red_events AS (
    SELECT
        c.match_id,
        lowerUTF8(coalesce(c.team_side, '')) AS card_team_side,
        toInt32OrZero(c.card_minute) AS card_minute,
        toInt32(coalesce(c.added_time, 0)) AS card_added_time,
        toInt32OrZero(c.card_minute) + toInt32(coalesce(c.added_time, 0)) AS card_effective_minute,
        toInt64(c.event_id) AS event_id,
        toInt32OrZero(c.score_home_at_time) AS score_home_at_red,
        toInt32OrZero(c.score_away_at_time) AS score_away_at_red
    FROM silver.card AS c
    WHERE c.match_id > 0
      AND lowerUTF8(coalesce(c.team_side, '')) IN ('home', 'away')
      AND toInt32OrZero(c.card_minute) > 0
      AND (
          positionCaseInsensitiveUTF8(coalesce(c.card_type, ''), 'red') > 0
          OR positionCaseInsensitiveUTF8(coalesce(c.description, ''), 'red') > 0
      )
),
first_red_events AS (
    SELECT
        re.match_id,
        re.card_team_side,
        count() AS red_cards_match,
        argMin(re.card_minute, tuple(re.card_effective_minute, re.event_id)) AS first_red_card_minute,
        argMin(re.card_added_time, tuple(re.card_effective_minute, re.event_id)) AS first_red_card_added_time,
        min(re.card_effective_minute) AS first_red_card_effective_minute,
        argMin(re.score_home_at_red, tuple(re.card_effective_minute, re.event_id)) AS score_home_at_first_red,
        argMin(re.score_away_at_red, tuple(re.card_effective_minute, re.event_id)) AS score_away_at_first_red
    FROM red_events AS re
    GROUP BY
        re.match_id,
        re.card_team_side
),
goal_events AS (
    SELECT
        s.match_id,
        if(coalesce(s.is_home_goal, 0) = 1, 'home', 'away') AS goal_team_side,
        toInt32OrZero(s.goal_time) AS goal_minute,
        toInt32(coalesce(s.goal_overload_time, 0)) AS goal_added_time,
        toInt32OrZero(s.goal_time) + toInt32(coalesce(s.goal_overload_time, 0)) AS goal_effective_minute,
        toInt64(s.shot_id) AS shot_id,
        toInt32(coalesce(s.home_score_after, 0)) AS home_score_after,
        toInt32(coalesce(s.away_score_after, 0)) AS away_score_after,
        s.player_id AS scorer_id,
        s.player_name AS scorer_name,
        toUInt8(coalesce(s.is_own_goal, 0)) AS is_own_goal
    FROM silver.shot AS s
    WHERE s.match_id > 0
      AND coalesce(s.is_goal, 0) = 1
      AND toInt32OrZero(s.goal_time) > 0
      AND isNotNull(s.is_home_goal)
),
trigger_goal_candidates AS (
    SELECT
        fre.match_id,
        fre.card_team_side AS triggered_side,
        fre.red_cards_match,
        fre.first_red_card_minute,
        fre.first_red_card_added_time,
        fre.first_red_card_effective_minute,
        fre.score_home_at_first_red,
        fre.score_away_at_first_red,
        ge.goal_minute,
        ge.goal_added_time,
        ge.goal_effective_minute,
        ge.home_score_after,
        ge.away_score_after,
        ge.scorer_id,
        ge.scorer_name,
        ge.is_own_goal,
        row_number() OVER (
            PARTITION BY fre.match_id, fre.card_team_side
            ORDER BY ge.goal_effective_minute ASC, ge.goal_minute ASC, ge.shot_id ASC
        ) AS rn
    FROM first_red_events AS fre
    INNER JOIN goal_events AS ge
        ON ge.match_id = fre.match_id
       AND ge.goal_team_side = fre.card_team_side
       AND ge.goal_effective_minute >= fre.first_red_card_effective_minute
       AND ge.goal_effective_minute <= fre.first_red_card_effective_minute + 5
       AND (
           (fre.card_team_side = 'home' AND ge.home_score_after > fre.score_home_at_first_red)
           OR (fre.card_team_side = 'away' AND ge.away_score_after > fre.score_away_at_first_red)
       )
)
SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    tgc.triggered_side,
    if(tgc.triggered_side = 'home', m.home_team_id, m.away_team_id) AS triggered_team_id,
    if(tgc.triggered_side = 'home', m.home_team_name, m.away_team_name) AS triggered_team_name,
    if(tgc.triggered_side = 'home', m.away_team_id, m.home_team_id) AS opponent_team_id,
    if(tgc.triggered_side = 'home', m.away_team_name, m.home_team_name) AS opponent_team_name,

    toInt32(5) AS trigger_threshold_minutes_after_red,
    toInt32(tgc.first_red_card_minute) AS triggered_team_first_red_card_minute,
    toInt32(tgc.first_red_card_added_time) AS triggered_team_first_red_card_added_time,
    toInt32(tgc.first_red_card_effective_minute) AS triggered_team_first_red_card_effective_minute,
    toInt32(tgc.goal_minute) AS triggered_team_neutralizing_goal_minute,
    toInt32(tgc.goal_added_time) AS triggered_team_neutralizing_goal_added_time,
    toInt32(tgc.goal_effective_minute) AS triggered_team_neutralizing_goal_effective_minute,
    toInt32(tgc.goal_effective_minute - tgc.first_red_card_effective_minute) AS minutes_from_red_to_goal,
    toInt32(if(tgc.triggered_side = 'home', tgc.score_home_at_first_red, tgc.score_away_at_first_red)) AS triggered_team_score_at_first_red,
    toInt32(if(tgc.triggered_side = 'home', tgc.score_away_at_first_red, tgc.score_home_at_first_red)) AS opponent_score_at_first_red,
    toInt32(
        if(tgc.triggered_side = 'home', tgc.score_home_at_first_red, tgc.score_away_at_first_red)
        - if(tgc.triggered_side = 'home', tgc.score_away_at_first_red, tgc.score_home_at_first_red)
    ) AS score_margin_at_first_red,
    toInt32(if(tgc.triggered_side = 'home', tgc.home_score_after, tgc.away_score_after)) AS triggered_team_score_after_neutralizing_goal,
    toInt32(if(tgc.triggered_side = 'home', tgc.away_score_after, tgc.home_score_after)) AS opponent_score_after_neutralizing_goal,
    toInt32(
        if(tgc.triggered_side = 'home', tgc.home_score_after, tgc.away_score_after)
        - if(tgc.triggered_side = 'home', tgc.away_score_after, tgc.home_score_after)
    ) AS score_margin_after_neutralizing_goal,
    toInt32(
        (
            if(tgc.triggered_side = 'home', tgc.home_score_after, tgc.away_score_after)
            - if(tgc.triggered_side = 'home', tgc.away_score_after, tgc.home_score_after)
        )
        - (
            if(tgc.triggered_side = 'home', tgc.score_home_at_first_red, tgc.score_away_at_first_red)
            - if(tgc.triggered_side = 'home', tgc.score_away_at_first_red, tgc.score_home_at_first_red)
        )
    ) AS score_margin_swing_after_goal,
    tgc.scorer_id AS triggered_team_neutralizing_goal_scorer_id,
    tgc.scorer_name AS triggered_team_neutralizing_goal_scorer_name,
    tgc.is_own_goal AS triggered_team_neutralizing_goal_is_own_goal,

    toInt32(tgc.red_cards_match) AS triggered_team_red_cards_match,
    toInt32(coalesce(ofre.red_cards_match, 0)) AS opponent_red_cards_match,
    toInt32(tgc.red_cards_match - coalesce(ofre.red_cards_match, 0)) AS red_cards_match_delta,
    toInt32(if(tgc.triggered_side = 'home', coalesce(ps.yellow_cards_home, 0), coalesce(ps.yellow_cards_away, 0))) AS triggered_team_yellow_cards_match,
    toInt32(if(tgc.triggered_side = 'home', coalesce(ps.yellow_cards_away, 0), coalesce(ps.yellow_cards_home, 0))) AS opponent_yellow_cards_match,
    toInt32(
        if(tgc.triggered_side = 'home', coalesce(ps.yellow_cards_home, 0), coalesce(ps.yellow_cards_away, 0))
        + tgc.red_cards_match
    ) AS triggered_team_total_cards_match,
    toInt32(
        if(tgc.triggered_side = 'home', coalesce(ps.yellow_cards_away, 0), coalesce(ps.yellow_cards_home, 0))
        + coalesce(ofre.red_cards_match, 0)
    ) AS opponent_total_cards_match,
    toInt32(
        (
            if(tgc.triggered_side = 'home', coalesce(ps.yellow_cards_home, 0), coalesce(ps.yellow_cards_away, 0))
            + tgc.red_cards_match
        )
        - (
            if(tgc.triggered_side = 'home', coalesce(ps.yellow_cards_away, 0), coalesce(ps.yellow_cards_home, 0))
            + coalesce(ofre.red_cards_match, 0)
        )
    ) AS card_count_match_delta,
    toInt32(if(tgc.triggered_side = 'home', coalesce(ps.fouls_home, 0), coalesce(ps.fouls_away, 0))) AS triggered_team_fouls_committed,
    toInt32(if(tgc.triggered_side = 'home', coalesce(ps.fouls_away, 0), coalesce(ps.fouls_home, 0))) AS opponent_fouls_committed,
    toInt32(
        if(tgc.triggered_side = 'home', coalesce(ps.fouls_home, 0), coalesce(ps.fouls_away, 0))
        - if(tgc.triggered_side = 'home', coalesce(ps.fouls_away, 0), coalesce(ps.fouls_home, 0))
    ) AS fouls_committed_delta,
    toInt32(if(tgc.triggered_side = 'home', coalesce(ps.total_shots_home, 0), coalesce(ps.total_shots_away, 0))) AS triggered_team_total_shots,
    toInt32(if(tgc.triggered_side = 'home', coalesce(ps.total_shots_away, 0), coalesce(ps.total_shots_home, 0))) AS opponent_total_shots,
    toInt32(
        if(tgc.triggered_side = 'home', coalesce(ps.total_shots_home, 0), coalesce(ps.total_shots_away, 0))
        - if(tgc.triggered_side = 'home', coalesce(ps.total_shots_away, 0), coalesce(ps.total_shots_home, 0))
    ) AS shot_delta,
    toFloat32(if(tgc.triggered_side = 'home', coalesce(ps.expected_goals_home, 0), coalesce(ps.expected_goals_away, 0))) AS triggered_team_xg,
    toFloat32(if(tgc.triggered_side = 'home', coalesce(ps.expected_goals_away, 0), coalesce(ps.expected_goals_home, 0))) AS opponent_xg,
    toFloat32(round(
        if(tgc.triggered_side = 'home', coalesce(ps.expected_goals_home, 0), coalesce(ps.expected_goals_away, 0))
        - if(tgc.triggered_side = 'home', coalesce(ps.expected_goals_away, 0), coalesce(ps.expected_goals_home, 0)),
        3
    )) AS xg_delta,
    toFloat32(if(tgc.triggered_side = 'home', coalesce(ps.ball_possession_home, 0), coalesce(ps.ball_possession_away, 0))) AS triggered_team_possession_pct,
    toFloat32(if(tgc.triggered_side = 'home', coalesce(ps.ball_possession_away, 0), coalesce(ps.ball_possession_home, 0))) AS opponent_possession_pct,
    toFloat32(round(
        if(tgc.triggered_side = 'home', coalesce(ps.ball_possession_home, 0), coalesce(ps.ball_possession_away, 0))
        - if(tgc.triggered_side = 'home', coalesce(ps.ball_possession_away, 0), coalesce(ps.ball_possession_home, 0)),
        1
    )) AS possession_delta_pct,
    toInt32(if(tgc.triggered_side = 'home', coalesce(ps.pass_attempts_home, 0), coalesce(ps.pass_attempts_away, 0))) AS triggered_team_pass_attempts,
    toInt32(if(tgc.triggered_side = 'home', coalesce(ps.pass_attempts_away, 0), coalesce(ps.pass_attempts_home, 0))) AS opponent_pass_attempts,
    toNullable(toFloat32(round(
        100.0 * if(tgc.triggered_side = 'home', coalesce(ps.accurate_passes_home, 0), coalesce(ps.accurate_passes_away, 0))
        / nullIf(if(tgc.triggered_side = 'home', coalesce(ps.pass_attempts_home, 0), coalesce(ps.pass_attempts_away, 0)), 0),
        1
    ))) AS triggered_team_pass_accuracy_pct,
    toNullable(toFloat32(round(
        100.0 * if(tgc.triggered_side = 'home', coalesce(ps.accurate_passes_away, 0), coalesce(ps.accurate_passes_home, 0))
        / nullIf(if(tgc.triggered_side = 'home', coalesce(ps.pass_attempts_away, 0), coalesce(ps.pass_attempts_home, 0)), 0),
        1
    ))) AS opponent_pass_accuracy_pct,
    toInt32(if(tgc.triggered_side = 'home', coalesce(ps.duels_won_home, 0), coalesce(ps.duels_won_away, 0))) AS triggered_team_duels_won,
    toInt32(if(tgc.triggered_side = 'home', coalesce(ps.duels_won_away, 0), coalesce(ps.duels_won_home, 0))) AS opponent_duels_won,
    toInt32(if(tgc.triggered_side = 'home', coalesce(ps.tackles_succeeded_home, 0), coalesce(ps.tackles_succeeded_away, 0))) AS triggered_team_tackles_won,
    toInt32(if(tgc.triggered_side = 'home', coalesce(ps.tackles_succeeded_away, 0), coalesce(ps.tackles_succeeded_home, 0))) AS opponent_tackles_won,
    toInt32(if(tgc.triggered_side = 'home', coalesce(ps.interceptions_home, 0), coalesce(ps.interceptions_away, 0))) AS triggered_team_interceptions,
    toInt32(if(tgc.triggered_side = 'home', coalesce(ps.interceptions_away, 0), coalesce(ps.interceptions_home, 0))) AS opponent_interceptions,
    toInt32(if(tgc.triggered_side = 'home', coalesce(ps.clearances_home, 0), coalesce(ps.clearances_away, 0))) AS triggered_team_clearances,
    toInt32(if(tgc.triggered_side = 'home', coalesce(ps.clearances_away, 0), coalesce(ps.clearances_home, 0))) AS opponent_clearances

FROM trigger_goal_candidates AS tgc
INNER JOIN silver.match AS m
    ON m.match_id = tgc.match_id
INNER JOIN silver.period_stat AS ps
    ON ps.match_id = tgc.match_id
   AND ps.period = 'All'
LEFT JOIN first_red_events AS ofre
    ON ofre.match_id = tgc.match_id
   AND ofre.card_team_side = if(tgc.triggered_side = 'home', 'away', 'home')
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND tgc.rn = 1

ORDER BY
    minutes_from_red_to_goal ASC,
    score_margin_swing_after_goal DESC,
    triggered_team_first_red_card_effective_minute ASC,
    m.match_date DESC,
    m.match_id DESC;
