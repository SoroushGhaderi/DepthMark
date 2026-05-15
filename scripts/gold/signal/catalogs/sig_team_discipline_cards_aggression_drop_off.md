---
signal_id: sig_team_discipline_cards_aggression_drop_off
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Aggression Drop-Off"
trigger: "Team first-half fouls are >= 10 and second-half fouls are <= 2."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_team_discipline_cards_aggression_drop_off
  sql: clickhouse/gold/signal/sig_team_discipline_cards_aggression_drop_off.sql
  runner: scripts/gold/signal/runners/sig_team_discipline_cards_aggression_drop_off.py
---
# sig_team_discipline_cards_aggression_drop_off

## Purpose

Flags team-match performances where a side is highly foul-heavy before halftime (>=10 fouls) but commits very few fouls after the break (<=2), surfacing strong discipline de-escalation patterns.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_fouls_first_half >= 10`
  - `triggered_team_fouls_second_half <= 2`
- Trigger is evaluated symmetrically for home and away from `silver.period_stat` half splits (`period IN ('FirstHalf', 'SecondHalf')`).
- The signal preserves bilateral half-split foul dynamics plus full-match discipline and defensive context (`period = 'All'`) to separate genuine de-escalation from broadly low-contact games.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_discipline_cards_aggression_drop_off.sql`
- Runner: `scripts/gold/signal/runners/sig_team_discipline_cards_aggression_drop_off.py`
- Target table: `gold.sig_team_discipline_cards_aggression_drop_off`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_discipline_cards_aggression_drop_off.py
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
| `home_score` | Home full-time goals | Football developer: outcome context for discipline interpretation |
| `away_score` | Away full-time goals | Football developer: outcome context for discipline interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical orientation key for row identity |
| `triggered_team_id` | Triggered team identifier | Football developer: durable triggered-entity identity |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-entity context |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_min_first_half_fouls` | Configured minimum first-half foul threshold (`10`) | Football developer: explicit trigger provenance for reproducibility |
| `trigger_threshold_max_second_half_fouls` | Configured maximum second-half foul threshold (`2`) | Football developer: explicit de-escalation ceiling for QA and reproducibility |
| `triggered_team_fouls_first_half` | Triggered-side fouls in the first half | Football developer: trigger baseline aggression load |
| `triggered_team_fouls_second_half` | Triggered-side fouls in the second half | Football developer: core de-escalation target metric |
| `opponent_fouls_first_half` | Opponent fouls in the first half | Football developer: bilateral first-half comparator |
| `opponent_fouls_second_half` | Opponent fouls in the second half | Football developer: bilateral second-half comparator |
| `triggered_team_fouls_first_half_minus_second_half` | Triggered-side foul drop from first half to second half | Football developer: absolute de-escalation magnitude |
| `opponent_fouls_first_half_minus_second_half` | Opponent foul drop from first half to second half | Football developer: bilateral de-escalation comparator |
| `foul_de_escalation_delta` | Triggered-side de-escalation minus opponent de-escalation | Football developer: net drop-off imbalance metric |
| `triggered_team_second_half_to_first_half_foul_ratio` | Triggered-side second-half/first-half foul ratio | Football developer: normalized de-escalation severity metric |
| `opponent_second_half_to_first_half_foul_ratio` | Opponent second-half/first-half foul ratio | Football developer: bilateral ratio comparator |
| `foul_ratio_delta` | Triggered minus opponent foul ratio | Football developer: compact normalized asymmetry indicator |
| `triggered_team_foul_drop_pct` | Triggered-side foul drop percentage from first to second half | Football developer: scale-invariant de-escalation intensity |
| `opponent_foul_drop_pct` | Opponent foul drop percentage from first to second half | Football developer: bilateral scale-invariant comparator |
| `foul_drop_delta_pct` | Triggered minus opponent foul-drop percentage points | Football developer: net normalized de-escalation edge |
| `triggered_team_first_half_fouls_share_pct` | Share of triggered-side fouls occurring in first half (%) | Football developer: concentration metric for front-loaded aggression |
| `opponent_first_half_fouls_share_pct` | Share of opponent fouls occurring in first half (%) | Football developer: bilateral concentration comparator |
| `first_half_fouls_share_delta_pct` | Triggered minus opponent first-half foul share (percentage points) | Football developer: normalized half-distribution asymmetry |
| `triggered_team_yellow_cards` | Triggered-side total yellow cards in match | Football developer: caution burden context around foul profile |
| `opponent_yellow_cards` | Opponent total yellow cards in match | Football developer: bilateral caution comparator |
| `triggered_team_red_cards` | Triggered-side total red cards in match | Football developer: severe-discipline context |
| `opponent_red_cards` | Opponent total red cards in match | Football developer: bilateral severe-discipline comparator |
| `triggered_team_total_cards` | Triggered-side total cards (yellow+red) | Football developer: aggregate discipline burden context |
| `opponent_total_cards` | Opponent total cards (yellow+red) | Football developer: bilateral aggregate comparator |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: net discipline-pressure differential |
| `triggered_team_fouls_committed` | Triggered-side total fouls in match | Football developer: full-match aggression volume context |
| `opponent_fouls_committed` | Opponent total fouls in match | Football developer: bilateral foul-volume comparator |
| `fouls_committed_delta` | Triggered minus opponent total fouls | Football developer: net contact-intensity imbalance |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: physical contest context for foul dynamics |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral physical contest comparator |
| `triggered_team_tackles_won` | Tackles won by triggered side | Football developer: defensive-action profile around de-escalation |
| `opponent_tackles_won` | Tackles won by opponent side | Football developer: bilateral defensive-action comparator |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-management context |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-management comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control/style context for interpretation |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with trigger |
