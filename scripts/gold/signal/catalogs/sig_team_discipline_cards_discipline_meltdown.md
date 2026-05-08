---
signal_id: sig_team_discipline_cards_discipline_meltdown
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Discipline Meltdown"
trigger: "Team receives >= 2 red cards in a single match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_team_discipline_cards_discipline_meltdown
  sql: clickhouse/gold/signal/sig_team_discipline_cards_discipline_meltdown.sql
  runner: scripts/gold/signal/runners/sig_team_discipline_cards_discipline_meltdown.py
---
# sig_team_discipline_cards_discipline_meltdown

## Purpose

Flags team-match performances with multiple dismissals (two or more red cards), surfacing discipline collapse scenarios and their bilateral tactical context.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_red_cards >= 2`
- Trigger is evaluated symmetrically for home and away teams from `silver.period_stat` with `period = 'All'`.
- The signal preserves bilateral card pressure, foul load, defensive-action profile, and possession balance so analysts can separate extreme discipline breakdown from normal physical matches.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_discipline_cards_discipline_meltdown.sql`
- Runner: `scripts/gold/signal/runners/sig_team_discipline_cards_discipline_meltdown.py`
- Target table: `gold.sig_team_discipline_cards_discipline_meltdown`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_discipline_cards_discipline_meltdown.py
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
| `home_score` | Home full-time goals | Football developer: scoreline context for discipline-collapse interpretation |
| `away_score` | Away full-time goals | Football developer: scoreline context for discipline-collapse interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical orientation key for row identity |
| `triggered_team_id` | Triggered team identifier | Football developer: triggered-entity identity for downstream attribution |
| `triggered_team_name` | Triggered team name | Football developer: human-readable triggered-entity context |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key |
| `opponent_team_name` | Opponent team name | Football developer: human-readable bilateral context |
| `trigger_threshold_min_red_cards` | Configured red-card threshold (`2`) | Football developer: explicit trigger provenance for reproducibility |
| `triggered_team_red_cards` | Red cards on triggered side | Football developer: core trigger metric |
| `opponent_red_cards` | Red cards on opponent side | Football developer: bilateral dismissal comparator |
| `red_cards_delta` | Triggered minus opponent red cards | Football developer: net dismissal imbalance |
| `triggered_team_yellow_cards` | Yellow cards on triggered side | Football developer: caution-level context around dismissals |
| `opponent_yellow_cards` | Yellow cards on opponent side | Football developer: bilateral caution comparator |
| `triggered_team_total_cards` | Total cards (yellow+red) on triggered side | Football developer: aggregate discipline burden around trigger |
| `opponent_total_cards` | Total cards (yellow+red) on opponent side | Football developer: bilateral aggregate discipline comparator |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: net card-pressure imbalance |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Football developer: aggression load associated with dismissals |
| `opponent_fouls_committed` | Fouls committed by opponent side | Football developer: bilateral foul-load comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net foul imbalance tied to discipline collapse |
| `triggered_team_fouls_per_card` | Triggered-side fouls per total card | Football developer: card-conversion intensity diagnostic |
| `opponent_fouls_per_card` | Opponent fouls per total card | Football developer: bilateral conversion baseline |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: physical contest intensity context |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral physical contest comparator |
| `triggered_team_tackles_won` | Tackles won by triggered side | Football developer: defensive-action context for foul/card profile interpretation |
| `opponent_tackles_won` | Tackles won by opponent side | Football developer: bilateral defensive-action comparator |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: defensive anticipation context around discipline collapse |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-management context after dismissals |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-management comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control/style context for interpreting meltdown dynamics |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with dismissal signal |
