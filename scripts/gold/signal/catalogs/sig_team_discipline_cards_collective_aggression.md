---
signal_id: sig_team_discipline_cards_collective_aggression
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Collective Aggression"
trigger: "Team commits >= 20 fouls in a single match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_discipline_cards_collective_aggression
  sql: clickhouse/gold/dml/signals/team/sig_team_discipline_cards_collective_aggression.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_discipline_cards_collective_aggression

## Purpose

Flags team-match performances with very high foul volume (20 or more fouls), surfacing collective aggressive behavior and related disciplinary pressure.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_fouls_committed >= 20`
- Trigger is evaluated symmetrically for home and away teams from `silver.period_stat` with `period = 'All'`.
- The signal keeps bilateral context for foul share, card load, defensive duel profile, and possession balance to separate pure foul volume from broader match-state behavior.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_discipline_cards_collective_aggression.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_discipline_cards_collective_aggression`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_discipline_cards_collective_aggression
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins and release QA |
| `match_date` | Match date | Football developer: supports temporal analysis and partition-aligned checks |
| `home_team_id` | Home team identifier | Football developer: fixed fixture orientation anchor |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: fixed fixture orientation anchor |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: scoreline context for aggression interpretation |
| `away_score` | Away full-time goals | Football developer: scoreline context for aggression interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical orientation key for row identity |
| `triggered_team_id` | Triggered team identifier | Football developer: triggered-entity identity for downstream attribution |
| `triggered_team_name` | Triggered team name | Football developer: human-readable triggered-entity context |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key |
| `opponent_team_name` | Opponent team name | Football developer: human-readable bilateral context |
| `trigger_threshold_min_fouls_committed` | Configured foul threshold (`20`) | Football developer: explicit trigger provenance for reproducibility |
| `triggered_team_fouls_committed` | Fouls committed by triggered team | Football developer: core trigger metric |
| `opponent_fouls_committed` | Fouls committed by opponent | Football developer: bilateral foul-volume comparator |
| `fouls_committed_above_threshold` | Fouls above trigger threshold (`fouls - 20`) | Football developer: trigger severity beyond binary hit |
| `triggered_team_fouls_share_pct` | Triggered-side share of total match fouls (%) | Football developer: normalizes aggression load by match whistle volume |
| `opponent_fouls_share_pct` | Opponent share of total match fouls (%) | Football developer: symmetric foul-share context |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net aggression imbalance metric |
| `triggered_team_yellow_cards` | Yellow cards on triggered side | Football developer: caution-level disciplinary conversion context |
| `opponent_yellow_cards` | Yellow cards on opponent side | Football developer: bilateral caution comparator |
| `triggered_team_red_cards` | Red cards on triggered side | Football developer: severe discipline escalation context |
| `opponent_red_cards` | Red cards on opponent side | Football developer: bilateral dismissal comparator |
| `triggered_team_total_cards` | Total cards (yellow+red) on triggered side | Football developer: aggregate discipline burden around trigger |
| `opponent_total_cards` | Total cards (yellow+red) on opponent side | Football developer: bilateral aggregate discipline comparator |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: net card-pressure imbalance |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: physical contest intensity context |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral physical contest comparator |
| `triggered_team_tackles_won` | Tackles won by triggered side | Football developer: defensive-action context for foul profile interpretation |
| `opponent_tackles_won` | Tackles won by opponent side | Football developer: bilateral defensive-action comparator |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: defensive anticipation context around aggression |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-management context tied to foul-heavy phases |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-management comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control/style context for interpreting foul load |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with aggression signal |
