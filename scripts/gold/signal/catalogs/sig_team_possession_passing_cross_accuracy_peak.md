---
signal_id: sig_team_possession_passing_cross_accuracy_peak
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Cross Accuracy Peak"
trigger: "Team completes >= 10 crosses with > 40% cross accuracy in a single match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_cross_accuracy_peak
  sql: clickhouse/gold/dml/signals/team/sig_team_possession_passing_cross_accuracy_peak.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_possession_passing_cross_accuracy_peak

## Purpose

Detect teams that pair meaningful crossing volume with high delivery precision, then profile whether that accurate crossing phase also translated into territorial control and chance-quality edge.

## Tactical And Statistical Logic

- Signal name source: `-- Signal: sig_team_possession_passing_cross_accuracy_peak`
- Trigger condition source: `-- Trigger: Team completes >= 10 crosses with > 40% cross accuracy.`
- Trigger checks both conditions on full-match stats (`period = 'All'`) for each side independently.
- Closest existing signal is `sig_team_possession_passing_cross_spam` (high crossing volume regardless of quality); this signal instead emphasizes efficient crossing execution and can coexist as a quality-oriented counterpart.
- Output remains bilateral (`triggered_team_*` and `opponent_*`) to preserve tactical interpretation beyond one-sided volume counts.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_possession_passing_cross_accuracy_peak.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_possession_passing_cross_accuracy_peak`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_possession_passing_cross_accuracy_peak
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for downstream joins across signal and scenario features |
| `match_date` | Match date | Football developer: enables time-based slicing and release QA |
| `home_team_id` | Home team ID | Football developer: fixture identity and side reconstruction |
| `home_team_name` | Home team name | Football developer: analyst-readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixture identity and side reconstruction |
| `away_team_name` | Away team name | Football developer: analyst-readable fixture context |
| `home_score` | Full-time home goals | Football developer: outcome context for interpreting crossing performance |
| `away_score` | Full-time away goals | Football developer: outcome context for interpreting crossing performance |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: preserves side orientation for bilateral interpretation |
| `triggered_team_id` | Triggered team ID | Football developer: core team identity for team-level feature generation |
| `triggered_team_name` | Triggered team name | Football developer: readable team identity in analyst outputs |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral comparator identity |
| `opponent_team_name` | Opponent team name | Football developer: bilateral comparator identity |
| `trigger_threshold_cross_attempts` | Constant trigger threshold for minimum cross attempts (`10`) | Football developer: explicit threshold improves auditability and QA checks |
| `trigger_threshold_cross_accuracy_pct` | Constant trigger threshold for cross accuracy (`40`) | Football developer: explicit threshold improves auditability and QA checks |
| `triggered_team_cross_attempts` | Cross attempts by triggered team | Football developer: direct trigger metric for crossing volume |
| `opponent_cross_attempts` | Cross attempts by opponent team | Football developer: bilateral baseline for crossing-load symmetry |
| `cross_attempts_delta` | Triggered minus opponent cross attempts | Football developer: quantifies crossing-load dominance gap |
| `triggered_team_accurate_crosses` | Accurate crosses by triggered team | Football developer: execution-quality numerator for trigger qualification |
| `opponent_accurate_crosses` | Accurate crosses by opponent team | Football developer: bilateral execution comparator |
| `triggered_team_cross_accuracy_pct` | Triggered-team cross accuracy (%) | Football developer: direct trigger quality metric for peak crossing execution |
| `opponent_cross_accuracy_pct` | Opponent cross accuracy (%) | Football developer: bilateral execution comparator |
| `cross_accuracy_delta_pct` | Triggered minus opponent cross accuracy (%) | Football developer: net delivery-quality edge under crossing play |
| `triggered_team_pass_attempts` | Pass attempts by triggered team | Football developer: denominator context for circulation style |
| `opponent_pass_attempts` | Pass attempts by opponent team | Football developer: bilateral circulation baseline |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: passing-quality context around crossing behavior |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral passing-quality comparator |
| `triggered_team_cross_share_of_passes_pct` | Triggered-team crosses as share of all pass attempts (%) | Football developer: tactical style marker for route concentration into crosses |
| `opponent_cross_share_of_passes_pct` | Opponent crosses as share of all pass attempts (%) | Football developer: bilateral style comparator |
| `cross_share_of_passes_delta_pct` | Triggered minus opponent cross share of passes (%) | Football developer: quantifies stylistic imbalance in crossing dependence |
| `triggered_team_opposition_half_passes` | Triggered-team passes in opponent half | Football developer: territorial control context behind crossing efficiency |
| `opponent_opposition_half_passes` | Opponent passes in triggered-team half | Football developer: bilateral territorial comparator |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opponent box | Football developer: final-third penetration context for crossing output |
| `opponent_touches_opposition_box` | Opponent touches in triggered-team box | Football developer: bilateral penetration comparator |
| `triggered_team_total_shots` | Triggered-team total shots | Football developer: output-volume context for whether accurate crosses created attempts |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral output comparator |
| `triggered_team_crosses_per_shot` | Triggered-team crosses per shot | Football developer: efficiency proxy for conversion of crossing phases into attempts |
| `opponent_crosses_per_shot` | Opponent crosses per shot | Football developer: bilateral efficiency comparator |
| `triggered_team_corners` | Triggered-team corners won | Football developer: set-piece pressure context often correlated with crossing momentum |
| `opponent_corners` | Opponent corners won | Football developer: bilateral set-piece pressure comparator |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: chance-quality context beyond shot counts |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent xG | Football developer: net chance-quality edge under high-accuracy crossing behavior |
