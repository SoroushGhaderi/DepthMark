---
signal_id: sig_team_possession_passing_press_resistance
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Press Resistance"
trigger: "triggered team pass accuracy > 85 with >= 300 pass attempts while opponent high-press proxy (interceptions + tackles won + fouls) >= 35 and >= 10.0 per 100 triggered-team pass attempts"
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_press_resistance
  sql: clickhouse/gold/dml/signals/team/sig_team_possession_passing_press_resistance.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_possession_passing_press_resistance

## Purpose

Triggers when a team keeps pass accuracy above 85% under a high-press proxy from the opponent, indicating press resistance in possession.

## Tactical And Statistical Logic

- Trigger condition (per side, full match period `All`):
  - `triggered_team_pass_accuracy_pct > 85`
  - `triggered_team_pass_attempts >= 300`
  - `opponent_press_actions >= 35`
  - `opponent_press_actions_per_100_triggered_passes >= 10.0`
- High-press proxy uses opponent defensive disruption volume:
  - `interceptions + tackles_succeeded + fouls`
- Signal keeps bilateral context fields so analysts can compare triggered team control quality against opponent pressure intensity and territory profile.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_possession_passing_press_resistance.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_possession_passing_press_resistance`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_possession_passing_press_resistance
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: anchors joins across match, team, and downstream feature tables |
| `match_date` | Calendar date of the match | Football developer: anchors joins across match, team, and downstream feature tables |
| `home_team_id` | Numeric ID of the home team | Football developer: anchors joins across match, team, and downstream feature tables |
| `home_team_name` | Display name of the home team | Football developer: anchors joins across match, team, and downstream feature tables |
| `away_team_id` | Numeric ID of the away team | Football developer: anchors joins across match, team, and downstream feature tables |
| `away_team_name` | Display name of the away team | Football developer: anchors joins across match, team, and downstream feature tables |
| `home_score` | Full-time goals scored by home team | Football developer: match result context for tactical interpretation |
| `away_score` | Full-time goals scored by away team | Football developer: match result context for tactical interpretation |
| `triggered_side` | Side that fired the signal (`home` or `away`) | Football developer: direct trigger ownership for downstream team-level grouping |
| `triggered_team_id` | Team ID of triggered side | Football developer: direct entity key for model features and cohorting |
| `triggered_team_name` | Team name of triggered side | Football developer: human-readable tactical labeling |
| `opponent_team_id` | Team ID of opponent | Football developer: preserves bilateral orientation for comparative analysis |
| `opponent_team_name` | Team name of opponent | Football developer: preserves bilateral orientation for comparative analysis |
| `triggered_team_pass_attempts` | Triggered team total pass attempts | Football developer: guards sample size and contextualizes pass-accuracy stability |
| `opponent_pass_attempts` | Opponent total pass attempts | Football developer: tempo and possession context for bilateral pacing |
| `triggered_team_accurate_passes` | Triggered team accurate passes | Football developer: raw numerator for the core accuracy trigger metric |
| `opponent_accurate_passes` | Opponent accurate passes | Football developer: bilateral passing-quality context |
| `triggered_team_pass_accuracy_pct` | Triggered team pass accuracy percentage | Football developer: core trigger metric for press-resistance classification |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy percentage | Football developer: control comparator to detect one-sided resistance quality |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy percentage points | Football developer: directional quality gap useful for style dominance tagging |
| `triggered_team_own_half_passes` | Triggered team passes in own half | Football developer: own-half circulation context under pressure |
| `opponent_own_half_passes` | Opponent passes in own half | Football developer: bilateral territory/shape context |
| `triggered_team_own_half_pass_share_pct` | Share of triggered team passes in own half | Football developer: indicates depth of build-up while resisting pressure |
| `opponent_own_half_pass_share_pct` | Share of opponent passes in own half | Football developer: comparator for territorial asymmetry |
| `triggered_team_possession_pct` | Triggered team possession percentage | Football developer: possession baseline for interpreting pass-volume behavior |
| `opponent_possession_pct` | Opponent possession percentage | Football developer: bilateral possession context for signal quality checks |
| `triggered_team_interceptions` | Triggered team interceptions | Football developer: triggered-side disruption context for reciprocal pressing intensity |
| `opponent_interceptions` | Opponent interceptions | Football developer: component of high-press proxy used in trigger logic |
| `triggered_team_tackles_won` | Triggered team successful tackles | Football developer: triggered-side defensive disruption context |
| `opponent_tackles_won` | Opponent successful tackles | Football developer: component of high-press proxy used in trigger logic |
| `triggered_team_fouls` | Triggered team fouls committed | Football developer: physicality context for triggered side |
| `opponent_fouls` | Opponent fouls committed | Football developer: component of high-press proxy used in trigger logic |
| `triggered_team_press_actions` | Triggered team press-action proxy (`interceptions + tackles + fouls`) | Football developer: bilateral symmetry for evaluating whether pressure was one-sided |
| `opponent_press_actions` | Opponent press-action proxy (`interceptions + tackles + fouls`) | Football developer: high-press volume gate for the trigger |
| `opponent_press_actions_per_100_triggered_passes` | Opponent press actions normalized per 100 triggered-team pass attempts | Football developer: normalizes pressure intensity by passing workload to avoid pace bias |
| `press_actions_delta` | Opponent minus triggered-team press actions | Football developer: directional pressure advantage metric for tactical profiling |
