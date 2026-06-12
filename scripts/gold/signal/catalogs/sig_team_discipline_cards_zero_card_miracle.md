---
signal_id: sig_team_discipline_cards_zero_card_miracle
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Zero-Card Miracle"
trigger: "Team commits >= 20 fouls and receives 0 yellow cards."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_discipline_cards_zero_card_miracle
  sql: clickhouse/gold/signal/sig_team_discipline_cards_zero_card_miracle.sql
  runner: scripts/gold/signal/runners/sig_team_discipline_cards_zero_card_miracle.py
---
# sig_team_discipline_cards_zero_card_miracle

## Purpose

Flags team-match performances where foul volume is extreme (20 or more fouls) while the side avoids any yellow card, surfacing rare discipline-officiating anomalies under heavy contact pressure.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_fouls_committed >= 20`
  - `triggered_team_yellow_cards = 0`
- Trigger is evaluated symmetrically for home and away teams using `silver.period_stat` with `period = 'All'`.
- The signal preserves bilateral foul burden, yellow/red composition, defensive actions, and possession context so analysts can separate officiating asymmetry from match-state-driven physicality.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_discipline_cards_zero_card_miracle.sql`
- Runner: `scripts/gold/signal/runners/sig_team_discipline_cards_zero_card_miracle.py`
- Target table: `gold_signals.sig_team_discipline_cards_zero_card_miracle`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_discipline_cards_zero_card_miracle.py
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
| `home_score` | Home full-time goals | Football developer: scoreline context for discipline interpretation |
| `away_score` | Away full-time goals | Football developer: scoreline context for discipline interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical orientation key for row identity |
| `triggered_team_id` | Triggered team identifier | Football developer: triggered-entity identity for downstream attribution |
| `triggered_team_name` | Triggered team name | Football developer: human-readable triggered-entity context |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key |
| `opponent_team_name` | Opponent team name | Football developer: human-readable bilateral context |
| `trigger_threshold_min_fouls_committed` | Configured foul threshold (`20`) | Football developer: explicit trigger provenance for reproducibility |
| `trigger_threshold_max_yellow_cards` | Configured maximum yellow-card threshold (`0`) | Football developer: explicit no-yellow condition for governance and QA |
| `triggered_team_fouls_committed` | Fouls committed by triggered team | Football developer: core trigger component for aggression volume |
| `opponent_fouls_committed` | Fouls committed by opponent | Football developer: bilateral foul-volume comparator |
| `fouls_committed_above_threshold` | Fouls above trigger threshold (`fouls - 20`) | Football developer: severity measure beyond binary trigger hit |
| `triggered_team_fouls_share_pct` | Triggered-side share of total match fouls (%) | Football developer: normalizes triggered aggression against match whistle volume |
| `opponent_fouls_share_pct` | Opponent share of total match fouls (%) | Football developer: symmetric foul-share context |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net aggression imbalance metric |
| `triggered_team_yellow_cards` | Yellow cards on triggered side | Football developer: exact trigger field validating no-yellow condition |
| `opponent_yellow_cards` | Yellow cards on opponent side | Football developer: bilateral caution comparator |
| `yellow_card_count_delta` | Triggered minus opponent yellow cards | Football developer: net caution imbalance around foul-heavy behavior |
| `triggered_team_red_cards` | Red cards on triggered side | Football developer: dismissal context for no-yellow, high-foul cases |
| `opponent_red_cards` | Red cards on opponent side | Football developer: bilateral dismissal comparator |
| `red_card_count_delta` | Triggered minus opponent red cards | Football developer: severe-discipline asymmetry metric |
| `triggered_team_total_cards` | Total cards (yellow+red) on triggered side | Football developer: aggregate discipline burden alongside yellow-specific trigger |
| `opponent_total_cards` | Total cards (yellow+red) on opponent side | Football developer: opposing aggregate burden comparator |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: net card-pressure imbalance around foul-heavy behavior |
| `triggered_team_yellow_cards_per_foul_pct` | Yellow cards per foul (%) for triggered side | Football developer: sanction-conversion efficiency metric for yellow-card punishment |
| `opponent_yellow_cards_per_foul_pct` | Yellow cards per foul (%) for opponent side | Football developer: bilateral yellow-conversion comparator for officiating asymmetry |
| `yellow_cards_per_foul_delta_pct` | Triggered minus opponent yellow-cards-per-foul (percentage points) | Football developer: compact yellow-sanction asymmetry metric |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: physical contest intensity context |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral physical contest comparator |
| `triggered_team_tackles_won` | Tackles won by triggered side | Football developer: defensive-action context for foul profile interpretation |
| `opponent_tackles_won` | Tackles won by opponent side | Football developer: bilateral defensive-action comparator |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: defensive anticipation context around foul-heavy play |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-management context tied to contact-heavy phases |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-management comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control/style context for interpreting foul profile |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with discipline anomaly |
