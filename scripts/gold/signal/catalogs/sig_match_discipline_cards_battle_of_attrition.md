---
signal_id: sig_match_discipline_cards_battle_of_attrition
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Battle of Attrition"
trigger: "Combined match fouls are >= 35."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_discipline_cards_battle_of_attrition
  sql: clickhouse/gold/signal/sig_match_discipline_cards_battle_of_attrition.sql
  runner: scripts/gold/signal/runners/sig_match_discipline_cards_battle_of_attrition.py
---
# sig_match_discipline_cards_battle_of_attrition

## Purpose

Flags high-friction matches where total whistle volume is extreme (35+ combined fouls), surfacing attritional game states with sustained contact intensity.

## Tactical And Statistical Logic

- Trigger condition:
  - `fouls_home + fouls_away >= 35` from `silver.period_stat` at `period = 'All'`.
- Trigger is match-level and emitted as two side-oriented rows (`home` and `away`) so downstream team pipelines can consume bilateral context consistently.
- Signal keeps foul share, card conversion, defensive action load, and possession balance to separate mutual attrition from one-sided over-aggression.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_discipline_cards_battle_of_attrition.sql`
- Runner: `scripts/gold/signal/runners/sig_match_discipline_cards_battle_of_attrition.py`
- Target table: `gold_signals.sig_match_discipline_cards_battle_of_attrition`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_discipline_cards_battle_of_attrition.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable identity key for joins, QA, and feature lineage |
| `match_date` | Match date | Football developer: temporal slicing and partition alignment |
| `home_team_id` | Home team identifier | Football developer: fixed fixture orientation |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: fixed fixture orientation |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: outcome context for attrition interpretation |
| `away_score` | Away full-time goals | Football developer: outcome context for attrition interpretation |
| `triggered_side` | Triggered row orientation (`home` or `away`) | Football developer: canonical side-oriented identity for match-team grain |
| `triggered_team_id` | Triggered-side team identifier | Football developer: downstream team attribution |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered-side context |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_min_combined_fouls` | Configured minimum combined fouls threshold (`35`) | Football developer: explicit trigger provenance and reproducibility |
| `match_total_fouls_committed` | Total fouls in the match (home + away) | Football developer: core attrition intensity variable |
| `match_total_fouls_above_threshold` | Foul count above threshold (`match_total_fouls_committed - 35`) | Football developer: trigger severity beyond binary activation |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Football developer: side-level contribution to match attrition |
| `opponent_fouls_committed` | Fouls committed by opponent side | Football developer: bilateral foul-load comparator |
| `triggered_team_fouls_share_pct` | Triggered-side share of total match fouls (%) | Football developer: normalized side burden in high-foul matches |
| `opponent_fouls_share_pct` | Opponent share of total match fouls (%) | Football developer: symmetric normalized comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net whistle-pressure imbalance |
| `triggered_team_yellow_cards` | Triggered-side yellow cards | Football developer: caution burden context in attritional games |
| `opponent_yellow_cards` | Opponent yellow cards | Football developer: bilateral caution comparator |
| `triggered_team_red_cards` | Triggered-side red cards | Football developer: severe discipline escalation context |
| `opponent_red_cards` | Opponent red cards | Football developer: bilateral severe-discipline comparator |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: aggregate discipline load for triggered side |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: bilateral aggregate comparator |
| `match_total_cards` | Combined total cards in the match | Football developer: overall sanction intensity alongside foul volume |
| `triggered_team_cards_per_foul_pct` | Triggered-side cards per foul (%) | Football developer: discipline conversion efficiency for side-level profiling |
| `opponent_cards_per_foul_pct` | Opponent cards per foul (%) | Football developer: bilateral sanction-conversion comparator |
| `cards_per_foul_delta_pct` | Triggered minus opponent cards-per-foul (percentage points) | Football developer: compact asymmetry metric for officiating and discipline interpretation |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: physical contest context around attrition load |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral physicality comparator |
| `triggered_team_tackles_won` | Tackles won by triggered side | Football developer: defensive action profile in contact-heavy matches |
| `opponent_tackles_won` | Tackles won by opponent side | Football developer: bilateral defensive-action comparator |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: anticipation/pressing context under attrition |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-release context in whistle-heavy phases |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-release comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control/style context for attritional interpretation |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with attrition signal |
