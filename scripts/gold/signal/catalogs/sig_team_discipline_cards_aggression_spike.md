---
signal_id: sig_team_discipline_cards_aggression_spike
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Aggression Spike"
trigger: "Team second-half fouls are >= 2x first-half fouls (with first-half fouls >= 1)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_discipline_cards_aggression_spike
  sql: clickhouse/gold/signal/sig_team_discipline_cards_aggression_spike.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_discipline_cards_aggression_spike

## Purpose

Flags team-match performances where a side's foul count jumps sharply after halftime (second half fouls at least double first half fouls), surfacing aggressive second-half behavioral shifts.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_fouls_first_half >= 1`
  - `triggered_team_fouls_second_half >= 2 * triggered_team_fouls_first_half`
- Trigger is evaluated symmetrically for home and away from `silver.period_stat` half splits (`period IN ('FirstHalf', 'SecondHalf')`).
- The signal preserves bilateral foul-escalation ratios plus full-match discipline and defensive context (`period = 'All'`) to separate genuine aggression spikes from balanced physical matches.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_discipline_cards_aggression_spike.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_discipline_cards_aggression_spike`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_discipline_cards_aggression_spike
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
| `trigger_threshold_foul_multiplier` | Configured second-half-to-first-half foul multiplier threshold (`2.0`) | Football developer: explicit trigger provenance for reproducibility |
| `trigger_threshold_min_first_half_fouls` | Configured minimum first-half foul floor (`1`) | Football developer: guards ratio trigger against zero-denominator edge cases |
| `triggered_team_fouls_first_half` | Triggered-side fouls in the first half | Football developer: trigger baseline aggression load |
| `triggered_team_fouls_second_half` | Triggered-side fouls in the second half | Football developer: core trigger intensity metric |
| `opponent_fouls_first_half` | Opponent fouls in the first half | Football developer: bilateral first-half comparator |
| `opponent_fouls_second_half` | Opponent fouls in the second half | Football developer: bilateral second-half comparator |
| `triggered_team_fouls_second_half_minus_first_half` | Triggered-side foul change from first half to second half | Football developer: absolute escalation magnitude beyond ratio |
| `opponent_fouls_second_half_minus_first_half` | Opponent foul change from first half to second half | Football developer: bilateral escalation comparator |
| `foul_escalation_delta` | Triggered-side escalation minus opponent escalation | Football developer: net second-half aggression shift imbalance |
| `triggered_team_second_half_to_first_half_foul_ratio` | Triggered-side second-half/first-half foul ratio | Football developer: direct trigger ratio for ranking severity |
| `opponent_second_half_to_first_half_foul_ratio` | Opponent second-half/first-half foul ratio | Football developer: bilateral ratio comparator |
| `foul_ratio_delta` | Triggered minus opponent foul-ratio change | Football developer: compact asymmetry metric for aggression spikes |
| `triggered_team_second_half_fouls_share_pct` | Share of triggered-side fouls that occurred in second half (%) | Football developer: concentration metric for post-break aggression |
| `opponent_second_half_fouls_share_pct` | Share of opponent fouls that occurred in second half (%) | Football developer: bilateral concentration comparator |
| `second_half_fouls_share_delta_pct` | Triggered minus opponent second-half foul share (percentage points) | Football developer: net half-distribution asymmetry signal |
| `triggered_team_yellow_cards` | Triggered-side total yellow cards in match | Football developer: caution burden context around foul spike |
| `opponent_yellow_cards` | Opponent total yellow cards in match | Football developer: bilateral caution comparator |
| `triggered_team_red_cards` | Triggered-side total red cards in match | Football developer: severe-discipline escalation context |
| `opponent_red_cards` | Opponent total red cards in match | Football developer: bilateral severe-discipline comparator |
| `triggered_team_total_cards` | Triggered-side total cards (yellow+red) | Football developer: aggregate discipline burden context |
| `opponent_total_cards` | Opponent total cards (yellow+red) | Football developer: bilateral aggregate comparator |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: net discipline-pressure differential |
| `triggered_team_fouls_committed` | Triggered-side total fouls in match | Football developer: full-match aggression volume context |
| `opponent_fouls_committed` | Opponent total fouls in match | Football developer: bilateral foul-volume comparator |
| `fouls_committed_delta` | Triggered minus opponent total fouls | Football developer: net contact-intensity imbalance |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: physical contest context for foul patterns |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral physical contest comparator |
| `triggered_team_tackles_won` | Tackles won by triggered side | Football developer: defensive-action profile around escalation |
| `opponent_tackles_won` | Tackles won by opponent side | Football developer: bilateral defensive-action comparator |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-management context |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-management comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control/style context for aggression interpretation |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with spike trigger |
