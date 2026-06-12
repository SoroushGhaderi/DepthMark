---
signal_id: sig_team_discipline_cards_total_implosion
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Total Implosion"
trigger: "Team receives >= 2 red cards in the same half."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_discipline_cards_total_implosion
  sql: clickhouse/gold/signal/sig_team_discipline_cards_total_implosion.sql
  runner: scripts/gold/signal/runners/sig_team_discipline_cards_total_implosion.py
---
# sig_team_discipline_cards_total_implosion

## Purpose

Flags team-match rows where dismissal concentration reaches two or more red cards in one half, surfacing acute discipline collapse timing rather than only full-match totals.

## Tactical And Statistical Logic

- Trigger condition:
  - `max(triggered_team_red_cards_first_half, triggered_team_red_cards_second_half) >= 2`
- Trigger-half resolution:
  - `triggered_half = first_half` when first-half red cards are greater than or equal to second-half red cards.
  - `triggered_half = second_half` otherwise.
- Trigger is evaluated symmetrically for home and away teams from `silver.period_stat` half splits, then enriched with bilateral full-match context from `silver.period_stat` at `period = 'All'`.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_discipline_cards_total_implosion.sql`
- Runner: `scripts/gold/signal/runners/sig_team_discipline_cards_total_implosion.py`
- Target table: `gold_signals.sig_team_discipline_cards_total_implosion`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_discipline_cards_total_implosion.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key and release QA anchor |
| `match_date` | Match date | Football developer: temporal slicing and partition alignment |
| `home_team_id` | Home team identifier | Football developer: fixed fixture orientation anchor |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: fixed fixture orientation anchor |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: scoreline context for collapse interpretation |
| `away_score` | Away full-time goals | Football developer: scoreline context for collapse interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical orientation key for row identity |
| `triggered_team_id` | Triggered team identifier | Football developer: durable triggered-entity identity |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-entity context |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_min_red_cards_same_half` | Configured red-card threshold (`2`) for one half | Football developer: explicit trigger provenance for reproducibility |
| `triggered_half` | Half where the trigger is resolved (`first_half` or `second_half`) | Football developer: direct temporal localization of the implosion |
| `triggered_team_both_halves_threshold_breach` | `1` when triggered team also reaches threshold in both halves | Football developer: marks extreme bilateral-half collapse edge cases |
| `triggered_team_red_cards_first_half` | Triggered-side red cards in first half | Football developer: half-specific severity measurement |
| `triggered_team_red_cards_second_half` | Triggered-side red cards in second half | Football developer: half-specific severity measurement |
| `opponent_red_cards_first_half` | Opponent red cards in first half | Football developer: bilateral half-level comparator |
| `opponent_red_cards_second_half` | Opponent red cards in second half | Football developer: bilateral half-level comparator |
| `triggered_team_red_cards_trigger_half` | Triggered-side red cards in resolved trigger half | Football developer: core threshold value for ranking and auditing |
| `opponent_red_cards_trigger_half` | Opponent red cards in resolved trigger half | Football developer: bilateral trigger-half dismissal comparator |
| `red_cards_trigger_half_delta` | Triggered minus opponent red cards in trigger half | Football developer: net dismissal imbalance at collapse time |
| `triggered_team_yellow_cards_trigger_half` | Triggered-side yellow cards in trigger half | Football developer: caution-load context around dismissals |
| `opponent_yellow_cards_trigger_half` | Opponent yellow cards in trigger half | Football developer: bilateral caution comparator in the same window |
| `triggered_team_total_cards_trigger_half` | Triggered-side total cards (yellow+red) in trigger half | Football developer: aggregate discipline burden at trigger time |
| `opponent_total_cards_trigger_half` | Opponent total cards (yellow+red) in trigger half | Football developer: bilateral aggregate card comparator in the same window |
| `card_count_trigger_half_delta` | Triggered minus opponent total cards in trigger half | Football developer: net card-pressure differential during implosion half |
| `triggered_team_red_cards_match` | Triggered-side red cards in full match | Football developer: full-match severe-discipline context |
| `opponent_red_cards_match` | Opponent red cards in full match | Football developer: bilateral severe-discipline comparator |
| `red_cards_match_delta` | Triggered minus opponent full-match red cards | Football developer: net full-match dismissal imbalance |
| `triggered_team_yellow_cards_match` | Triggered-side yellow cards in full match | Football developer: full-match caution burden context |
| `opponent_yellow_cards_match` | Opponent yellow cards in full match | Football developer: bilateral caution comparator |
| `triggered_team_total_cards_match` | Triggered-side total cards (yellow+red) in full match | Football developer: aggregate full-match discipline load |
| `opponent_total_cards_match` | Opponent total cards (yellow+red) in full match | Football developer: bilateral aggregate full-match comparator |
| `card_count_match_delta` | Triggered minus opponent total cards in full match | Football developer: net full-match card-pressure differential |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Football developer: aggression load paired with dismissal concentration |
| `opponent_fouls_committed` | Fouls committed by opponent side | Football developer: bilateral foul-load comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls committed | Football developer: net physical-intensity imbalance |
| `triggered_team_fouls_per_card` | Triggered-side fouls per total card | Football developer: conversion intensity diagnostic for discipline profile |
| `opponent_fouls_per_card` | Opponent fouls per total card | Football developer: bilateral conversion baseline |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: physical contest context around dismissal patterns |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral physical contest comparator |
| `triggered_team_tackles_won` | Tackles won by triggered side | Football developer: defensive-action context for collapse interpretation |
| `opponent_tackles_won` | Tackles won by opponent side | Football developer: bilateral defensive-action comparator |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-management context after dismissals |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-management comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control/style context around discipline collapse |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with trigger |
