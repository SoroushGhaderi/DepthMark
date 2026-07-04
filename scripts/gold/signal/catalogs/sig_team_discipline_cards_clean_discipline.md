---
signal_id: sig_team_discipline_cards_clean_discipline
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Clean Discipline"
trigger: "Team finishes a match with 0 cards and <= 7 fouls committed."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_discipline_cards_clean_discipline
  sql: clickhouse/gold/dml/signals/team/sig_team_discipline_cards_clean_discipline.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_discipline_cards_clean_discipline

## Purpose

Flags team-match performances with both zero total cards and low foul volume (seven or fewer fouls), surfacing controlled defensive behavior and clean discipline execution.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_total_cards = 0`
  - `triggered_team_fouls_committed <= 7`
- Trigger is evaluated symmetrically for home and away teams from `silver.period_stat` with `period = 'All'`.
- The signal preserves bilateral context for foul share, card contrast, defensive action profile, and possession balance to distinguish clean discipline from passive or low-engagement match states.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_discipline_cards_clean_discipline.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_discipline_cards_clean_discipline`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_discipline_cards_clean_discipline
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
| `home_score` | Home full-time goals | Football developer: scoreline context for interpreting clean discipline in match state |
| `away_score` | Away full-time goals | Football developer: scoreline context for interpreting clean discipline in match state |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical orientation key for row identity |
| `triggered_team_id` | Triggered team identifier | Football developer: triggered-entity identity for downstream attribution |
| `triggered_team_name` | Triggered team name | Football developer: human-readable triggered-entity context |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key |
| `opponent_team_name` | Opponent team name | Football developer: human-readable bilateral context |
| `trigger_threshold_max_total_cards` | Configured maximum card threshold (`0`) | Football developer: explicit card-condition provenance for reproducibility |
| `trigger_threshold_max_fouls_committed` | Configured maximum foul threshold (`7`) | Football developer: explicit foul-condition provenance for reproducibility |
| `triggered_team_fouls_committed` | Fouls committed by triggered team | Football developer: core trigger metric for clean discipline |
| `opponent_fouls_committed` | Fouls committed by opponent | Football developer: bilateral foul-volume comparator |
| `fouls_committed_below_threshold` | Foul headroom below threshold (`7 - fouls`) | Football developer: signal severity from cleaner-than-required discipline |
| `triggered_team_fouls_share_pct` | Triggered-side share of total match fouls (%) | Football developer: normalizes discipline load by whistle volume |
| `opponent_fouls_share_pct` | Opponent share of total match fouls (%) | Football developer: symmetric foul-share context |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net foul imbalance for tactical interpretation |
| `triggered_team_yellow_cards` | Yellow cards on triggered side | Football developer: card-color decomposition for discipline QA |
| `opponent_yellow_cards` | Yellow cards on opponent side | Football developer: bilateral caution comparator |
| `triggered_team_red_cards` | Red cards on triggered side | Football developer: severe-discipline decomposition and QA |
| `opponent_red_cards` | Red cards on opponent side | Football developer: bilateral dismissal comparator |
| `triggered_team_total_cards` | Total cards (yellow+red) on triggered side | Football developer: direct trigger-validation field in final output |
| `opponent_total_cards` | Total cards (yellow+red) on opponent side | Football developer: bilateral aggregate discipline comparator |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: net disciplinary pressure imbalance |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: physical contest context around low-infringement play |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral physical contest comparator |
| `triggered_team_tackles_won` | Tackles won by triggered side | Football developer: defensive-action context for clean-discipline profile |
| `opponent_tackles_won` | Tackles won by opponent side | Football developer: bilateral defensive-action comparator |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: defensive anticipation context with low fouling |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-management context around clean discipline |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-management comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control/style context for interpreting low foul and card counts |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with discipline signal |
