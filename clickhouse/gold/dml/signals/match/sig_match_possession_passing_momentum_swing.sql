INSERT INTO gold.sig_match_possession_passing_momentum_swing (
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
    possession_momentum_swing_pp,
    triggered_team_possession_first_half_pct,
    triggered_team_possession_second_half_pct,
    opponent_possession_first_half_pct,
    opponent_possession_second_half_pct,
    possession_swing_delta,
    triggered_team_pass_attempts_first_half,
    triggered_team_pass_attempts_second_half,
    opponent_pass_attempts_first_half,
    opponent_pass_attempts_second_half,
    triggered_team_pass_accuracy_first_half_pct,
    triggered_team_pass_accuracy_second_half_pct,
    opponent_pass_accuracy_first_half_pct,
    opponent_pass_accuracy_second_half_pct,
    triggered_team_pass_accuracy_delta_pct,
    opponent_pass_accuracy_delta_pct,
    triggered_team_opposition_half_passes_first_half,
    triggered_team_opposition_half_passes_second_half,
    opponent_opposition_half_passes_first_half,
    opponent_opposition_half_passes_second_half,
    triggered_team_xg_first_half,
    triggered_team_xg_second_half,
    opponent_xg_first_half,
    opponent_xg_second_half,
    xg_swing_delta
)
-- ============================================================
-- Signal: sig_match_possession_passing_momentum_swing
-- Intent: Detect extreme halftime possession reversals where one side
--         shifts from clear control (>=70%) to clear inferiority (<=30%)
--         with mirrored opponent behavior, plus bilateral passing/xG context.
-- Trigger: Triggered team FirstHalf possession >= 70 and SecondHalf <= 30;
--          opponent FirstHalf <= 30 and SecondHalf >= 70.
-- ============================================================

WITH half_stats AS (
    -- Pivot FirstHalf / SecondHalf into a single row per match
    SELECT
        match_id,
        -- Possession per half
        maxIf(coalesce(ball_possession_home, 0), period = 'FirstHalf')    AS fh_poss_home,
        maxIf(coalesce(ball_possession_away, 0), period = 'FirstHalf')    AS fh_poss_away,
        maxIf(coalesce(ball_possession_home, 0), period = 'SecondHalf')   AS sh_poss_home,
        maxIf(coalesce(ball_possession_away, 0), period = 'SecondHalf')   AS sh_poss_away,
        -- Pass volume per half
        maxIf(coalesce(pass_attempts_home, 0), period = 'FirstHalf')      AS fh_pass_att_home,
        maxIf(coalesce(pass_attempts_away, 0), period = 'FirstHalf')      AS fh_pass_att_away,
        maxIf(coalesce(pass_attempts_home, 0), period = 'SecondHalf')     AS sh_pass_att_home,
        maxIf(coalesce(pass_attempts_away, 0), period = 'SecondHalf')     AS sh_pass_att_away,
        maxIf(coalesce(accurate_passes_home, 0), period = 'FirstHalf')    AS fh_acc_passes_home,
        maxIf(coalesce(accurate_passes_away, 0), period = 'FirstHalf')    AS fh_acc_passes_away,
        maxIf(coalesce(accurate_passes_home, 0), period = 'SecondHalf')   AS sh_acc_passes_home,
        maxIf(coalesce(accurate_passes_away, 0), period = 'SecondHalf')   AS sh_acc_passes_away,
        -- xG per half (outcome proxy for whether the drop was tactical or forced)
        maxIf(coalesce(expected_goals_home, 0), period = 'FirstHalf')     AS fh_xg_home,
        maxIf(coalesce(expected_goals_away, 0), period = 'FirstHalf')     AS fh_xg_away,
        maxIf(coalesce(expected_goals_home, 0), period = 'SecondHalf')    AS sh_xg_home,
        maxIf(coalesce(expected_goals_away, 0), period = 'SecondHalf')    AS sh_xg_away,
        -- Opposition half passes: ball progression proxy
        maxIf(coalesce(opposition_half_passes_home, 0), period = 'FirstHalf')  AS fh_opp_half_passes_home,
        maxIf(coalesce(opposition_half_passes_away, 0), period = 'FirstHalf')  AS fh_opp_half_passes_away,
        maxIf(coalesce(opposition_half_passes_home, 0), period = 'SecondHalf') AS sh_opp_half_passes_home,
        maxIf(coalesce(opposition_half_passes_away, 0), period = 'SecondHalf') AS sh_opp_half_passes_away
    FROM silver.period_stat FINAL
    WHERE period IN ('FirstHalf', 'SecondHalf')
    GROUP BY match_id
)

-- ── HOME team is the triggered side ─────────────────────────
SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,
    -- Signal identity
    'home'                                                              AS triggered_side,
    m.home_team_id                                                      AS triggered_team_id,
    m.home_team_name                                                    AS triggered_team_name,
    m.away_team_id                                                      AS opponent_team_id,
    m.away_team_name                                                    AS opponent_team_name,
    -- Core signal value
    (h.sh_poss_home - h.fh_poss_home)                                  AS possession_momentum_swing_pp,
    -- Triggered team: possession by half
    h.fh_poss_home                                                      AS triggered_team_possession_first_half_pct,
    h.sh_poss_home                                                      AS triggered_team_possession_second_half_pct,
    -- Opponent: possession by half
    h.fh_poss_away                                                      AS opponent_possession_first_half_pct,
    h.sh_poss_away                                                      AS opponent_possession_second_half_pct,
    -- Possession swing (bilateral net shift)
    (h.sh_poss_home - h.sh_poss_away) - (h.fh_poss_home - h.fh_poss_away) AS possession_swing_delta,
    -- Triggered team: pass volume by half
    h.fh_pass_att_home                                                  AS triggered_team_pass_attempts_first_half,
    h.sh_pass_att_home                                                  AS triggered_team_pass_attempts_second_half,
    -- Opponent: pass volume by half
    h.fh_pass_att_away                                                  AS opponent_pass_attempts_first_half,
    h.sh_pass_att_away                                                  AS opponent_pass_attempts_second_half,
    -- Triggered team: pass accuracy by half (%)
    if(h.fh_pass_att_home > 0,
        round(h.fh_acc_passes_home * 100.0 / h.fh_pass_att_home, 1),
        NULL)                                                           AS triggered_team_pass_accuracy_first_half_pct,
    if(h.sh_pass_att_home > 0,
        round(h.sh_acc_passes_home * 100.0 / h.sh_pass_att_home, 1),
        NULL)                                                           AS triggered_team_pass_accuracy_second_half_pct,
    -- Opponent: pass accuracy by half (%)
    if(h.fh_pass_att_away > 0,
        round(h.fh_acc_passes_away * 100.0 / h.fh_pass_att_away, 1),
        NULL)                                                           AS opponent_pass_accuracy_first_half_pct,
    if(h.sh_pass_att_away > 0,
        round(h.sh_acc_passes_away * 100.0 / h.sh_pass_att_away, 1),
        NULL)                                                           AS opponent_pass_accuracy_second_half_pct,
    -- Pass accuracy drop (triggered team only, bilateral via sign)
    if(h.sh_pass_att_home > 0 AND h.fh_pass_att_home > 0,
        round((h.sh_acc_passes_home * 100.0 / h.sh_pass_att_home)
            - (h.fh_acc_passes_home * 100.0 / h.fh_pass_att_home), 1),
        NULL)                                                           AS triggered_team_pass_accuracy_delta_pct,
    if(h.sh_pass_att_away > 0 AND h.fh_pass_att_away > 0,
        round((h.sh_acc_passes_away * 100.0 / h.sh_pass_att_away)
            - (h.fh_acc_passes_away * 100.0 / h.fh_pass_att_away), 1),
        NULL)                                                           AS opponent_pass_accuracy_delta_pct,
    -- Triggered team: opposition-half passes (territory / progression proxy)
    h.fh_opp_half_passes_home                                          AS triggered_team_opposition_half_passes_first_half,
    h.sh_opp_half_passes_home                                          AS triggered_team_opposition_half_passes_second_half,
    -- Opponent: opposition-half passes
    h.fh_opp_half_passes_away                                          AS opponent_opposition_half_passes_first_half,
    h.sh_opp_half_passes_away                                          AS opponent_opposition_half_passes_second_half,
    -- xG per half — was the possession drop punished?
    h.fh_xg_home                                                       AS triggered_team_xg_first_half,
    h.sh_xg_home                                                       AS triggered_team_xg_second_half,
    h.fh_xg_away                                                       AS opponent_xg_first_half,
    h.sh_xg_away                                                       AS opponent_xg_second_half,
    -- Net xG swing (bilateral)
    (h.sh_xg_home - h.sh_xg_away) - (h.fh_xg_home - h.fh_xg_away)    AS xg_swing_delta
FROM silver.match AS m FINAL
JOIN half_stats h USING (match_id)
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND h.fh_poss_home >= 70
  AND h.sh_poss_home <= 30
  AND h.fh_poss_away <= 30
  AND h.sh_poss_away >= 70

UNION ALL

-- ── AWAY team is the triggered side ─────────────────────────
SELECT
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,
    'away'                                                              AS triggered_side,
    m.away_team_id                                                      AS triggered_team_id,
    m.away_team_name                                                    AS triggered_team_name,
    m.home_team_id                                                      AS opponent_team_id,
    m.home_team_name                                                    AS opponent_team_name,
    (h.sh_poss_away - h.fh_poss_away)                                  AS possession_momentum_swing_pp,
    h.fh_poss_away                                                      AS triggered_team_possession_first_half_pct,
    h.sh_poss_away                                                      AS triggered_team_possession_second_half_pct,
    h.fh_poss_home                                                      AS opponent_possession_first_half_pct,
    h.sh_poss_home                                                      AS opponent_possession_second_half_pct,
    (h.sh_poss_away - h.sh_poss_home) - (h.fh_poss_away - h.fh_poss_home) AS possession_swing_delta,
    h.fh_pass_att_away                                                  AS triggered_team_pass_attempts_first_half,
    h.sh_pass_att_away                                                  AS triggered_team_pass_attempts_second_half,
    h.fh_pass_att_home                                                  AS opponent_pass_attempts_first_half,
    h.sh_pass_att_home                                                  AS opponent_pass_attempts_second_half,
    if(h.fh_pass_att_away > 0,
        round(h.fh_acc_passes_away * 100.0 / h.fh_pass_att_away, 1),
        NULL)                                                           AS triggered_team_pass_accuracy_first_half_pct,
    if(h.sh_pass_att_away > 0,
        round(h.sh_acc_passes_away * 100.0 / h.sh_pass_att_away, 1),
        NULL)                                                           AS triggered_team_pass_accuracy_second_half_pct,
    if(h.fh_pass_att_home > 0,
        round(h.fh_acc_passes_home * 100.0 / h.fh_pass_att_home, 1),
        NULL)                                                           AS opponent_pass_accuracy_first_half_pct,
    if(h.sh_pass_att_home > 0,
        round(h.sh_acc_passes_home * 100.0 / h.sh_pass_att_home, 1),
        NULL)                                                           AS opponent_pass_accuracy_second_half_pct,
    if(h.sh_pass_att_away > 0 AND h.fh_pass_att_away > 0,
        round((h.sh_acc_passes_away * 100.0 / h.sh_pass_att_away)
            - (h.fh_acc_passes_away * 100.0 / h.fh_pass_att_away), 1),
        NULL)                                                           AS triggered_team_pass_accuracy_delta_pct,
    if(h.sh_pass_att_home > 0 AND h.fh_pass_att_home > 0,
        round((h.sh_acc_passes_home * 100.0 / h.sh_pass_att_home)
            - (h.fh_acc_passes_home * 100.0 / h.fh_pass_att_home), 1),
        NULL)                                                           AS opponent_pass_accuracy_delta_pct,
    h.fh_opp_half_passes_away                                          AS triggered_team_opposition_half_passes_first_half,
    h.sh_opp_half_passes_away                                          AS triggered_team_opposition_half_passes_second_half,
    h.fh_opp_half_passes_home                                          AS opponent_opposition_half_passes_first_half,
    h.sh_opp_half_passes_home                                          AS opponent_opposition_half_passes_second_half,
    h.fh_xg_away                                                       AS triggered_team_xg_first_half,
    h.sh_xg_away                                                       AS triggered_team_xg_second_half,
    h.fh_xg_home                                                       AS opponent_xg_first_half,
    h.sh_xg_home                                                       AS opponent_xg_second_half,
    (h.sh_xg_away - h.sh_xg_home) - (h.fh_xg_away - h.fh_xg_home)    AS xg_swing_delta
FROM silver.match AS m FINAL
JOIN half_stats h USING (match_id)
WHERE m.match_finished = 1
  AND m.match_id > 0
  AND h.fh_poss_away >= 70
  AND h.sh_poss_away <= 30
  AND h.fh_poss_home <= 30
  AND h.sh_poss_home >= 70

ORDER BY assumeNotNull(possession_momentum_swing_pp) ASC;
