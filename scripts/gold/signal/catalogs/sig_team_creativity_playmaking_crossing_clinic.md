---
signal_id: sig_team_creativity_playmaking_crossing_clinic
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Crossing Clinic"
trigger: "Team completes >= 10 successful crosses in a single finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_creativity_playmaking_crossing_clinic
  sql: clickhouse/gold/signal/sig_team_creativity_playmaking_crossing_clinic.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_creativity_playmaking_crossing_clinic

## Purpose

Detect team-level crossing clinics where a side records at least 10 successful crosses in a finished match.

## Tactical And Statistical Logic

- Trigger conditions:
  - `triggered_team_successful_crosses >= 10`
  - `match_finished = 1`
  - Match-team rows are emitted by triggered side (`home`, `away`), so both teams can trigger in one match.
- Successful crosses are sourced from `silver.period_stat` (`period = 'All'`) as `accurate_crosses_*`.
- Bilateral context pairs crossing execution with passing quality, territorial pressure, and chance production to distinguish sterile crossing volume from genuinely creative wing play.
- Similarity gate note:
  - `sig_team_possession_passing_cross_accuracy_peak`: requires `>= 10` crosses and `> 40%` cross accuracy; this signal is broader and volume-first, requiring only successful-cross count.
  - `sig_team_possession_passing_cross_spam`: attempts-driven (`cross_attempts >= 35`); this signal focuses on completed crossing output rather than raw attempt load.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_creativity_playmaking_crossing_clinic.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_creativity_playmaking_crossing_clinic`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_creativity_playmaking_crossing_clinic
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable deduplication and downstream join key |
| `match_date` | Match date | Time slicing and replay reproducibility |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Outcome context |
| `away_score` | Away full-time goals | Outcome context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical row identity at match-team grain |
| `triggered_team_id` | Triggered team ID | Triggered team identity for joins and features |
| `triggered_team_name` | Triggered team name | Readable triggered team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator |
| `trigger_threshold_min_successful_crosses` | Trigger floor for successful crosses (`10`) | Explicit threshold provenance and QA traceability |
| `triggered_team_successful_crosses` | Successful crosses by triggered team | Core trigger metric |
| `opponent_successful_crosses` | Successful crosses by opponent | Bilateral core-metric comparator |
| `successful_crosses_delta` | Triggered minus opponent successful crosses | Net crossing-execution edge |
| `triggered_team_cross_attempts` | Cross attempts by triggered team | Volume denominator for interpreting completions |
| `opponent_cross_attempts` | Cross attempts by opponent | Bilateral volume comparator |
| `cross_attempts_delta` | Triggered minus opponent cross attempts | Net crossing-load edge |
| `triggered_team_cross_accuracy_pct` | Triggered-team cross accuracy (%) | Delivery efficiency context around successful-cross volume |
| `opponent_cross_accuracy_pct` | Opponent cross accuracy (%) | Bilateral efficiency comparator |
| `cross_accuracy_delta_pct` | Triggered minus opponent cross accuracy (%) | Net delivery-precision edge |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Possession-circulation baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation baseline |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Passing quality context for crossing phases |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral passing-quality comparator |
| `triggered_team_cross_share_of_passes_pct` | Triggered-team crosses as share of pass attempts (%) | Tactical style marker for wide-route concentration |
| `opponent_cross_share_of_passes_pct` | Opponent crosses as share of pass attempts (%) | Bilateral style comparator |
| `cross_share_of_passes_delta_pct` | Triggered minus opponent cross share of passes (%) | Net stylistic imbalance toward crossing |
| `triggered_team_opposition_half_passes` | Triggered-team passes completed in opposition half | Territorial-control context |
| `opponent_opposition_half_passes` | Opponent passes completed in opposition half | Bilateral territorial comparator |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Final-third penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator |
| `triggered_team_total_shots` | Triggered-team total shots | Shooting-output context |
| `opponent_total_shots` | Opponent total shots | Bilateral shooting-output comparator |
| `triggered_team_crosses_per_shot` | Triggered-team crosses per shot | Proxy for crossing-to-shot conversion efficiency |
| `opponent_crosses_per_shot` | Opponent crosses per shot | Bilateral conversion-efficiency comparator |
| `triggered_team_corners` | Triggered-team corners won | Set-piece and wide-pressure context |
| `opponent_corners` | Opponent corners won | Bilateral set-piece-pressure comparator |
| `triggered_team_xg` | Triggered-team expected goals | Shot-quality context |
| `opponent_xg` | Opponent expected goals | Bilateral shot-quality comparator |
| `xg_delta` | Triggered minus opponent xG | Net chance-quality edge |
