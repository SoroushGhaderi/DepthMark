INSERT INTO gold.sig_team_possession_passing_high_tempo_passing (
    match_id,
    match_date,
    home_team_id,
    home_team_name,
    away_team_id,
    away_team_name,
    home_score,
    away_score,
    home_possession_first_half_pct,
    home_possession_second_half_pct,
    away_possession_first_half_pct,
    away_possession_second_half_pct,
    home_passes_first_half,
    home_passes_second_half,
    away_passes_first_half,
    away_passes_second_half,
    home_passes_per_minute_first_half,
    home_passes_per_minute_second_half,
    away_passes_per_minute_first_half,
    away_passes_per_minute_second_half,
    home_peak_passes_per_minute,
    away_peak_passes_per_minute,
    home_accurate_passes_total,
    away_accurate_passes_total,
    home_pass_attempts_total,
    away_pass_attempts_total,
    home_pass_accuracy_pct,
    away_pass_accuracy_pct,
    home_minus_away_pass_accuracy_delta_pct,
    home_opposition_half_passes,
    away_opposition_half_passes,
    home_own_half_passes,
    away_own_half_passes,
    home_opposition_half_pass_pct,
    away_opposition_half_pass_pct,
    triggered_side
)
-- Signal: sig_team_possession_passing_high_tempo_passing
-- Trigger: peak half passing tempo >= 6.5 passes per minute for at least one side.
-- Intent: detect high-tempo passing phases and preserve bilateral half-level possession and passing context.
-- =============================================================================
-- Proxy  : (half passes ÷ 45) as passes-per-minute estimate; threshold ≥ 6.5
--          (~293 passes/half); measured symmetrically for home and away
-- Sources: silver.match + silver.period_stat (FirstHalf / SecondHalf only)

SELECT
    -- ── Identifiers ──────────────────────────────────────────────────────────
    m.match_id,
    m.match_date,
    m.home_team_id,
    m.home_team_name,
    m.away_team_id,
    m.away_team_name,
    m.home_score,
    m.away_score,

    -- ── Possession context — both halves, symmetric ───────────────────────
    sumIf(coalesce(ps.ball_possession_home, 0), ps.period = 'FirstHalf')  AS home_possession_first_half_pct,
    sumIf(coalesce(ps.ball_possession_home, 0), ps.period = 'SecondHalf') AS home_possession_second_half_pct,
    sumIf(coalesce(ps.ball_possession_away, 0), ps.period = 'FirstHalf')  AS away_possession_first_half_pct,
    sumIf(coalesce(ps.ball_possession_away, 0), ps.period = 'SecondHalf') AS away_possession_second_half_pct,

    -- ── Raw pass volume per half — symmetric ──────────────────────────────
    sumIf(coalesce(ps.passes_home, 0), ps.period = 'FirstHalf')  AS home_passes_first_half,
    sumIf(coalesce(ps.passes_home, 0), ps.period = 'SecondHalf') AS home_passes_second_half,
    sumIf(coalesce(ps.passes_away, 0), ps.period = 'FirstHalf')  AS away_passes_first_half,
    sumIf(coalesce(ps.passes_away, 0), ps.period = 'SecondHalf') AS away_passes_second_half,

    -- ── Passes-per-minute proxy (÷ 45) — signal metric, symmetric ─────────
    round(sumIf(coalesce(ps.passes_home, 0), ps.period = 'FirstHalf')  / 45.0, 2) AS home_passes_per_minute_first_half,
    round(sumIf(coalesce(ps.passes_home, 0), ps.period = 'SecondHalf') / 45.0, 2) AS home_passes_per_minute_second_half,
    round(sumIf(coalesce(ps.passes_away, 0), ps.period = 'FirstHalf')  / 45.0, 2) AS away_passes_per_minute_first_half,
    round(sumIf(coalesce(ps.passes_away, 0), ps.period = 'SecondHalf') / 45.0, 2) AS away_passes_per_minute_second_half,

    -- ── Peak-half passes-per-min (single trigger value per side) ─────────
    round(greatest(
        sumIf(coalesce(ps.passes_home, 0), ps.period = 'FirstHalf'),
        sumIf(coalesce(ps.passes_home, 0), ps.period = 'SecondHalf')
    ) / 45.0, 2) AS home_peak_passes_per_minute,
    round(greatest(
        sumIf(coalesce(ps.passes_away, 0), ps.period = 'FirstHalf'),
        sumIf(coalesce(ps.passes_away, 0), ps.period = 'SecondHalf')
    ) / 45.0, 2) AS away_peak_passes_per_minute,

    -- ── Pass quality — accurate + attempts totals, symmetric ─────────────
    sumIf(coalesce(ps.accurate_passes_home, 0), ps.period IN ('FirstHalf', 'SecondHalf')) AS home_accurate_passes_total,
    sumIf(coalesce(ps.accurate_passes_away, 0), ps.period IN ('FirstHalf', 'SecondHalf')) AS away_accurate_passes_total,
    sumIf(coalesce(ps.pass_attempts_home, 0),   ps.period IN ('FirstHalf', 'SecondHalf')) AS home_pass_attempts_total,
    sumIf(coalesce(ps.pass_attempts_away, 0),   ps.period IN ('FirstHalf', 'SecondHalf')) AS away_pass_attempts_total,

    -- ── Pass accuracy % — enrichment, symmetric ───────────────────────────
    round(100.0
        * sumIf(coalesce(ps.accurate_passes_home, 0), ps.period IN ('FirstHalf', 'SecondHalf'))
        / nullIf(sumIf(coalesce(ps.pass_attempts_home, 0), ps.period IN ('FirstHalf', 'SecondHalf')), 0),
    1) AS home_pass_accuracy_pct,
    round(100.0
        * sumIf(coalesce(ps.accurate_passes_away, 0), ps.period IN ('FirstHalf', 'SecondHalf'))
        / nullIf(sumIf(coalesce(ps.pass_attempts_away, 0), ps.period IN ('FirstHalf', 'SecondHalf')), 0),
    1) AS away_pass_accuracy_pct,

    -- ── Pass accuracy delta — bilateral net (home − away) ─────────────────
    round(
          100.0 * sumIf(coalesce(ps.accurate_passes_home, 0), ps.period IN ('FirstHalf', 'SecondHalf'))
                / nullIf(sumIf(coalesce(ps.pass_attempts_home, 0), ps.period IN ('FirstHalf', 'SecondHalf')), 0)
        - 100.0 * sumIf(coalesce(ps.accurate_passes_away, 0), ps.period IN ('FirstHalf', 'SecondHalf'))
                / nullIf(sumIf(coalesce(ps.pass_attempts_away, 0), ps.period IN ('FirstHalf', 'SecondHalf')), 0),
    1) AS home_minus_away_pass_accuracy_delta_pct,

    -- ── Territorial split — opposition-half passes, symmetric ─────────────
    sumIf(coalesce(ps.opposition_half_passes_home, 0), ps.period IN ('FirstHalf', 'SecondHalf')) AS home_opposition_half_passes,
    sumIf(coalesce(ps.opposition_half_passes_away, 0), ps.period IN ('FirstHalf', 'SecondHalf')) AS away_opposition_half_passes,

    -- ── Build-up orientation — own-half passes, symmetric ─────────────────
    sumIf(coalesce(ps.own_half_passes_home, 0), ps.period IN ('FirstHalf', 'SecondHalf')) AS home_own_half_passes,
    sumIf(coalesce(ps.own_half_passes_away, 0), ps.period IN ('FirstHalf', 'SecondHalf')) AS away_own_half_passes,

    -- ── Progressive intent — % of passes in opp half, symmetric ──────────
    round(100.0
        * sumIf(coalesce(ps.opposition_half_passes_home, 0), ps.period IN ('FirstHalf', 'SecondHalf'))
        / nullIf(sumIf(coalesce(ps.passes_home, 0), ps.period IN ('FirstHalf', 'SecondHalf')), 0),
    1) AS home_opposition_half_pass_pct,
    round(100.0
        * sumIf(coalesce(ps.opposition_half_passes_away, 0), ps.period IN ('FirstHalf', 'SecondHalf'))
        / nullIf(sumIf(coalesce(ps.passes_away, 0), ps.period IN ('FirstHalf', 'SecondHalf')), 0),
    1) AS away_opposition_half_pass_pct,

    -- ── Triggered team — which side(s) fired the signal ───────────────────
    multiIf(
        greatest(sumIf(coalesce(ps.passes_home,0), ps.period='FirstHalf'), sumIf(coalesce(ps.passes_home,0), ps.period='SecondHalf')) / 45.0 >= 6.5
        AND
        greatest(sumIf(coalesce(ps.passes_away,0), ps.period='FirstHalf'), sumIf(coalesce(ps.passes_away,0), ps.period='SecondHalf')) / 45.0 >= 6.5,
        'both',
        greatest(sumIf(coalesce(ps.passes_home,0), ps.period='FirstHalf'), sumIf(coalesce(ps.passes_home,0), ps.period='SecondHalf')) / 45.0 >= 6.5,
        'home',
        'away'
    ) AS triggered_side

FROM silver.match AS m
INNER JOIN silver.period_stat AS ps
    ON  m.match_id   = ps.match_id
    AND ps.match_date = m.match_date     -- explicit partition pruning

WHERE
    m.match_finished = 1
    AND m.match_id > 0
    AND ps.period IN ('FirstHalf', 'SecondHalf')

GROUP BY
    m.match_id, m.match_date,
    m.home_team_id, m.home_team_name,
    m.away_team_id, m.away_team_name,
    m.home_score,   m.away_score

HAVING
    -- Either side peaks above 6.5 passes/min in their stronger half
    greatest(
        sumIf(coalesce(ps.passes_home, 0), ps.period = 'FirstHalf'),
        sumIf(coalesce(ps.passes_home, 0), ps.period = 'SecondHalf')
    ) / 45.0 >= 6.5
    OR
    greatest(
        sumIf(coalesce(ps.passes_away, 0), ps.period = 'FirstHalf'),
        sumIf(coalesce(ps.passes_away, 0), ps.period = 'SecondHalf')
    ) / 45.0 >= 6.5

ORDER BY
    greatest(
        assumeNotNull(home_peak_passes_per_minute),
        assumeNotNull(away_peak_passes_per_minute)
    ) DESC;
