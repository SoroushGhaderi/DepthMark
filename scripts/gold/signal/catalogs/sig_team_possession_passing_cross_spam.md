---
signal_id: sig_team_possession_passing_cross_spam
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Cross Spam"
trigger: "Team attempts >= 35 crosses in a single match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_cross_spam
  sql: clickhouse/gold/dml/signals/team/sig_team_possession_passing_cross_spam.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_possession_passing_cross_spam

## Purpose

Detect teams that repeatedly force wide delivery routes through extreme crossing volume, then profile whether this crossing spam produced meaningful territorial and chance-quality outcomes.

## Tactical And Statistical Logic

- Signal name source: `-- Signal: sig_team_possession_passing_cross_spam`
- Trigger condition source: `-- Trigger: Team attempts >= 35 crosses in a single match.`
- Signal emits one row per triggered side (`home` / `away`) and keeps bilateral opponent context to avoid one-sided interpretation.
- Enrichment separates raw spam behavior from execution quality (`cross_accuracy`, `cross_share_of_passes`) and final outcomes (`shots`, `crosses_per_shot`, `xg`).

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_possession_passing_cross_spam.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_possession_passing_cross_spam`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_possession_passing_cross_spam
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
| `home_score` | Full-time home goals | Football developer: outcome context for interpreting crossing spam productivity |
| `away_score` | Full-time away goals | Football developer: outcome context for interpreting crossing spam productivity |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: preserves side orientation for bilateral interpretation |
| `triggered_team_id` | Triggered team ID | Football developer: core team identity for team-level feature generation |
| `triggered_team_name` | Triggered team name | Football developer: readable team identity in analyst outputs |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral comparator identity |
| `opponent_team_name` | Opponent team name | Football developer: bilateral comparator identity |
| `trigger_threshold_cross_attempts` | Constant trigger threshold used by the signal (`35`) | Football developer: explicit trigger constant improves auditability and QA checks |
| `triggered_team_cross_attempts` | Cross attempts by triggered team | Football developer: direct trigger metric that defines crossing spam |
| `opponent_cross_attempts` | Cross attempts by opponent team | Football developer: bilateral baseline for whether crossing load is asymmetric |
| `cross_attempts_delta` | Triggered minus opponent cross attempts | Football developer: quantifies crossing-load dominance gap |
| `triggered_team_accurate_crosses` | Accurate crosses by triggered team | Football developer: execution-quality context for high crossing volume |
| `opponent_accurate_crosses` | Accurate crosses by opponent team | Football developer: bilateral execution comparator |
| `triggered_team_cross_accuracy_pct` | Triggered-team cross accuracy (%) | Football developer: distinguishes effective wide delivery from low-quality spam |
| `opponent_cross_accuracy_pct` | Opponent cross accuracy (%) | Football developer: bilateral execution comparator |
| `cross_accuracy_delta_pct` | Triggered minus opponent cross accuracy (%) | Football developer: net delivery-quality edge under crossing-heavy behavior |
| `triggered_team_pass_attempts` | Pass attempts by triggered team | Football developer: denominator context for how much of circulation is routed wide |
| `opponent_pass_attempts` | Pass attempts by opponent team | Football developer: bilateral circulation baseline |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: passing-quality context around spammed crossing strategy |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral passing-quality comparator |
| `triggered_team_cross_share_of_passes_pct` | Triggered-team crosses as share of all pass attempts (%) | Football developer: tactical style marker for route concentration into crosses |
| `opponent_cross_share_of_passes_pct` | Opponent crosses as share of all pass attempts (%) | Football developer: bilateral style comparator |
| `cross_share_of_passes_delta_pct` | Triggered minus opponent cross share of passes (%) | Football developer: quantifies stylistic imbalance in crossing dependence |
| `triggered_team_opposition_half_passes` | Triggered-team passes in opponent half | Football developer: territorial control context for high crossing volume |
| `opponent_opposition_half_passes` | Opponent passes in triggered-team half | Football developer: bilateral territorial comparator |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opponent box | Football developer: final-third penetration context behind crossing spam |
| `opponent_touches_opposition_box` | Opponent touches in triggered-team box | Football developer: bilateral penetration comparator |
| `triggered_team_total_shots` | Triggered-team total shots | Football developer: output-volume context for whether crosses generated attempts |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral output comparator |
| `triggered_team_crosses_per_shot` | Triggered-team crosses per shot | Football developer: efficiency proxy for conversion of crosses into shot volume |
| `opponent_crosses_per_shot` | Opponent crosses per shot | Football developer: bilateral efficiency comparator |
| `triggered_team_corners` | Triggered-team corners won | Football developer: set-piece pressure context often correlated with cross-heavy attacks |
| `opponent_corners` | Opponent corners won | Football developer: bilateral set-piece pressure comparator |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: chance-quality context beyond shot counts |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent xG | Football developer: net chance-quality edge produced under crossing spam behavior |
