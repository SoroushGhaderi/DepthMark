INSERT INTO gold.sig_team_possession_passing_high_press_victim (
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
    triggered_team_pass_accuracy_pct,
    home_pass_accuracy_pct,
    away_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    pass_attempts_home,
    pass_attempts_away,
    own_half_pass_share_home_pct,
    own_half_pass_share_away_pct
)
-- ============================================================
-- Signal: sig_team_possession_passing_high_press_victim
-- Intent: Detect teams whose full-match pass accuracy falls
--         below 70%, a marker of high-press disruption and
--         build-up breakdown, enriched with bilateral pass
--         volume, accuracy gap, and own-half share context.
-- ============================================================

SELECT
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
    triggered_team_pass_accuracy_pct,
    home_pass_accuracy_pct,
    away_pass_accuracy_pct,
    pass_accuracy_delta_pct,
    pass_attempts_home,
    pass_attempts_away,
    own_half_pass_share_home_pct,
    own_half_pass_share_away_pct
FROM (
    -- sig_team_possession_passing_high_press_victim
    -- Triggers when a team's pass accuracy drops below 70% — proxy for defensive-third breakdown under high press
    -- Enriched with pass volume, accuracy delta, and own-half pass share to contextualise press vulnerability
    SELECT
        m.match_id,
        m.match_date,

        -- Match identifiers
        m.home_team_id,
        m.home_team_name,
        m.away_team_id,
        m.away_team_name,
        m.home_score,
        m.away_score,

        -- Triggered side resolution
        multiIf(
            coalesce(ps.accurate_passes_home, 0) / coalesce(ps.pass_attempts_home, 1) < 0.70
                AND coalesce(ps.accurate_passes_away, 0) / coalesce(ps.pass_attempts_away, 1) < 0.70, 'both',
            coalesce(ps.accurate_passes_home, 0) / coalesce(ps.pass_attempts_home, 1) < 0.70, 'home',
            'away'
        ) AS triggered_side,
        multiIf(
            coalesce(ps.accurate_passes_home, 0) / coalesce(ps.pass_attempts_home, 1) < 0.70
                AND coalesce(ps.accurate_passes_away, 0) / coalesce(ps.pass_attempts_away, 1) < 0.70, NULL,
            coalesce(ps.accurate_passes_home, 0) / coalesce(ps.pass_attempts_home, 1) < 0.70, m.home_team_id,
            m.away_team_id
        ) AS triggered_team_id,
        multiIf(
            coalesce(ps.accurate_passes_home, 0) / coalesce(ps.pass_attempts_home, 1) < 0.70
                AND coalesce(ps.accurate_passes_away, 0) / coalesce(ps.pass_attempts_away, 1) < 0.70, NULL,
            coalesce(ps.accurate_passes_home, 0) / coalesce(ps.pass_attempts_home, 1) < 0.70, m.home_team_name,
            m.away_team_name
        ) AS triggered_team_name,

        -- Signal value: pass accuracy of the triggered team
        round(multiIf(
            coalesce(ps.accurate_passes_home, 0) / coalesce(ps.pass_attempts_home, 1) < 0.70
                AND coalesce(ps.accurate_passes_away, 0) / coalesce(ps.pass_attempts_away, 1) < 0.70, NULL,
            coalesce(ps.accurate_passes_home, 0) / coalesce(ps.pass_attempts_home, 1) < 0.70,
                coalesce(ps.accurate_passes_home, 0) / coalesce(ps.pass_attempts_home, 1) * 100,
            coalesce(ps.accurate_passes_away, 0) / coalesce(ps.pass_attempts_away, 1) * 100
        ), 1) AS triggered_team_pass_accuracy_pct,

        -- Enrichment: raw pass accuracy both sides
        round(coalesce(ps.accurate_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0) * 100, 1) AS home_pass_accuracy_pct,
        round(coalesce(ps.accurate_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0) * 100, 1) AS away_pass_accuracy_pct,

        -- Enrichment: accuracy gap between sides — large delta suggests one team imposed the press
        round(
            abs(
                coalesce(ps.accurate_passes_home, 0) / coalesce(ps.pass_attempts_home, 1) -
                coalesce(ps.accurate_passes_away, 0) / coalesce(ps.pass_attempts_away, 1)
            ) * 100, 1
        ) AS pass_accuracy_delta_pct,

        -- Enrichment: pass volume both sides — low volume + low accuracy = severe press domination
        coalesce(ps.pass_attempts_home, 0) AS pass_attempts_home,
        coalesce(ps.pass_attempts_away, 0) AS pass_attempts_away,

        -- Enrichment: own-half pass share — high ratio suggests team was pinned back, unable to progress
        round(coalesce(ps.own_half_passes_home, 0) / nullIf(coalesce(ps.pass_attempts_home, 0), 0) * 100, 1) AS own_half_pass_share_home_pct,
        round(coalesce(ps.own_half_passes_away, 0) / nullIf(coalesce(ps.pass_attempts_away, 0), 0) * 100, 1) AS own_half_pass_share_away_pct

    FROM silver.match AS m
    INNER JOIN silver.period_stat AS ps
        ON m.match_id = ps.match_id
    WHERE m.match_finished = 1
  AND m.match_id > 0                                                                              -- completed matches only
      AND ps.period = 'All'                                                                                 -- full-match totals
      AND (
          (coalesce(ps.pass_attempts_home, 0) > 0
              AND coalesce(ps.accurate_passes_home, 0) / coalesce(ps.pass_attempts_home, 1) < 0.70)        -- home team below accuracy threshold
          OR
          (coalesce(ps.pass_attempts_away, 0) > 0
              AND coalesce(ps.accurate_passes_away, 0) / coalesce(ps.pass_attempts_away, 1) < 0.70)        -- away team below accuracy threshold
      )
    ORDER BY triggered_team_pass_accuracy_pct ASC                                                                -- worst accuracy first
);
