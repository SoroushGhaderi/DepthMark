---
signal_id: sig_match_possession_passing_counter_vs_bus
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Possession Passing Counter vs Bus"
trigger: "One team records >70% possession while the opponent records >5 counter-attacks (proxy from shot situations containing 'counter' or 'fast')."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_possession_passing_counter_vs_bus
  sql: clickhouse/gold/dml/signals/match/sig_match_possession_passing_counter_vs_bus.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_match_possession_passing_counter_vs_bus

## Purpose

Triggers when a match shows an extreme territorial split: one side monopolizes possession (>70%) while the other side still produces frequent counter-attacking threat (>5 proxy events).

## Tactical And Statistical Logic

- Trigger condition: one side has `ball_possession > 70` and the opposing side has `counter_attacks_proxy > 5`.
- Because `silver.period_stat` has no native counter-attack count, `counter_attacks_proxy` is computed from `silver.shot.situation` text patterns matching `counter|fast`.
- Signal emits two rows per qualifying match (`triggered_side in {'home','away'}`) for bilateral side-oriented analysis.
- Output preserves role identity (`possession_dominant_side`, `counter_attacking_side`) so downstream users can separate controller and transition side explicitly.
- Adds passing quality, shot threat, box touches, clearances, and xG context to distinguish sterile dominance from dangerous transition games.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_possession_passing_counter_vs_bus.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_match_possession_passing_counter_vs_bus`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_match_possession_passing_counter_vs_bus
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins and deduplication |
| `match_date` | Match calendar date | Football developer: enables time-series analysis |
| `home_team_id` | Home team ID | Football developer: bilateral orientation key |
| `home_team_name` | Home team name | Football developer: readable match context |
| `away_team_id` | Away team ID | Football developer: bilateral orientation key |
| `away_team_name` | Away team name | Football developer: readable match context |
| `home_score` | Full-time home goals | Football developer: outcome context for trigger interpretation |
| `away_score` | Full-time away goals | Football developer: outcome context for trigger interpretation |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: canonical side identity at match-team grain |
| `triggered_team_id` | Triggered-side team ID | Football developer: side-scoped join key |
| `triggered_team_name` | Triggered-side team name | Football developer: readable side context |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral context key |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `possession_dominant_side` | Side with possession >70% (`home`/`away`) | Football developer: identifies controller role independent of row orientation |
| `possession_dominant_team_id` | Team ID of possession-dominant side | Football developer: stable role identity for downstream role-based features |
| `possession_dominant_team_name` | Team name of possession-dominant side | Football developer: readable role identity |
| `counter_attacking_side` | Side that exceeded counter proxy threshold | Football developer: identifies transition-threat role independent of row orientation |
| `counter_attacking_team_id` | Team ID of counter-attacking side | Football developer: stable role identity for transition modeling |
| `counter_attacking_team_name` | Team name of counter-attacking side | Football developer: readable role identity |
| `possession_dominant_team_possession_pct` | Possession percentage of dominant side | Football developer: stores exact trigger-side possession intensity |
| `counter_attacking_team_counter_attacks_proxy` | Counter-attack proxy count for transition side | Football developer: stores exact trigger-side transition intensity |
| `triggered_team_possession_pct` | Possession percentage for triggered side | Football developer: side-oriented control context |
| `opponent_possession_pct` | Possession percentage for opponent side | Football developer: bilateral control comparator |
| `triggered_team_counter_attacks_proxy` | Counter-attack proxy count for triggered side | Football developer: side-oriented transition context |
| `opponent_counter_attacks_proxy` | Counter-attack proxy count for opponent side | Football developer: bilateral transition comparator |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Football developer: circulation volume baseline |
| `opponent_pass_attempts` | Opponent-side pass attempts | Football developer: bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass completion rate | Football developer: pass-quality context |
| `opponent_pass_accuracy_pct` | Opponent-side pass completion rate | Football developer: bilateral pass-quality comparator |
| `triggered_team_total_shots` | Triggered-side total shots | Football developer: output threat context |
| `opponent_total_shots` | Opponent-side total shots | Football developer: bilateral output comparator |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opponent box | Football developer: penetration context for possession quality |
| `opponent_touches_opposition_box` | Opponent-side touches in opponent box | Football developer: bilateral penetration comparator |
| `triggered_team_clearances` | Triggered-side clearances | Football developer: defensive-load context (bus behavior proxy) |
| `opponent_clearances` | Opponent-side clearances | Football developer: bilateral defensive-load comparator |
| `triggered_team_xg` | Triggered-side expected goals | Football developer: chance-quality context |
| `opponent_xg` | Opponent-side expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent xG | Football developer: net attacking threat edge |
| `possession_gap_pct` | Absolute possession gap between sides | Football developer: quantifies territorial imbalance magnitude |
| `counter_attack_gap_proxy` | Absolute counter-attack proxy gap between sides | Football developer: quantifies transition imbalance magnitude |
