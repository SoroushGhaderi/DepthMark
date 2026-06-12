---
signal_id: sig_match_discipline_cards_one_sided_discipline
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Match Discipline Cards One-Sided Discipline"
trigger: "One team has >= 5 total cards while the opponent has exactly 0 total cards."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_discipline_cards_one_sided_discipline
  sql: clickhouse/gold/signal/sig_match_discipline_cards_one_sided_discipline.sql
  runner: scripts/gold/signal/runners/sig_match_discipline_cards_one_sided_discipline.py
---
# sig_match_discipline_cards_one_sided_discipline

## Purpose

Flags matches with extreme disciplinary asymmetry, where one side accumulates at least five cards and the other side remains card-free.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_total_cards >= 5`
  - `opponent_total_cards = 0`
- Total cards are computed as `yellow_cards + red_cards` from `silver.period_stat` (`period = 'All'`).
- Trigger orientation (`triggered_side`) is selected dynamically as the side meeting the `>= 5` condition.
- Output preserves bilateral card composition, fouls, defensive actions, passing quality, and possession context to explain whether the sanction asymmetry tracked tactical imbalance or match-state volatility.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_discipline_cards_one_sided_discipline.sql`
- Runner: `scripts/gold/signal/runners/sig_match_discipline_cards_one_sided_discipline.py`
- Target table: `gold_signals.sig_match_discipline_cards_one_sided_discipline`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_discipline_cards_one_sided_discipline.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for deterministic feature generation and QA. |
| `match_date` | Match date | Football developer: enables temporal slicing and partition-aligned backtests. |
| `home_team_id` | Home team identifier | Football developer: fixture orientation anchor. |
| `home_team_name` | Home team name | Football developer: readable fixture context. |
| `away_team_id` | Away team identifier | Football developer: fixture orientation anchor. |
| `away_team_name` | Away team name | Football developer: readable fixture context. |
| `home_score` | Home full-time goals | Football developer: scoreline context for discipline asymmetry interpretation. |
| `away_score` | Away full-time goals | Football developer: scoreline context for discipline asymmetry interpretation. |
| `triggered_side` | Side that satisfies the one-sided-discipline trigger (`home` or `away`) | Football developer: canonical side identity for match-team grain. |
| `triggered_team_id` | Triggered-side team identifier | Football developer: durable triggered entity key. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered entity attribution. |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context. |
| `trigger_threshold_min_triggered_team_total_cards` | Configured minimum triggered-side total cards threshold (`5`) | Football developer: explicit trigger provenance and governance traceability. |
| `trigger_threshold_max_opponent_total_cards` | Configured maximum opponent total cards threshold (`0`) | Football developer: explicit card-free opponent condition for audits. |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: core trigger metric for disciplinary burden. |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: confirms one-sided sanction baseline. |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: net disciplinary imbalance magnitude. |
| `triggered_team_cards_above_threshold` | Triggered-side total cards above the minimum threshold (`triggered_team_total_cards - 5`) | Football developer: trigger intensity grading beyond binary qualification. |
| `triggered_team_cards_share_pct` | Triggered-side share of all match cards (%) | Football developer: normalized sanction burden concentration. |
| `opponent_cards_share_pct` | Opponent share of all match cards (%) | Football developer: symmetric concentration baseline. |
| `match_total_cards` | Combined match cards (yellow + red across both sides) | Football developer: global discipline intensity context. |
| `match_total_yellow_cards` | Combined match yellow cards | Football developer: card-color composition context. |
| `match_total_red_cards` | Combined match red cards | Football developer: severe-sanction composition context. |
| `triggered_team_yellow_cards` | Triggered-side yellow cards | Football developer: caution-level trigger decomposition. |
| `opponent_yellow_cards` | Opponent yellow cards | Football developer: bilateral caution comparator (expected zero under trigger). |
| `yellow_cards_delta` | Triggered minus opponent yellow cards | Football developer: net caution imbalance detail. |
| `triggered_team_red_cards` | Triggered-side red cards | Football developer: dismissal contribution to one-sided discipline load. |
| `opponent_red_cards` | Opponent red cards | Football developer: bilateral dismissal comparator (expected zero under trigger). |
| `red_cards_delta` | Triggered minus opponent red cards | Football developer: net dismissal imbalance detail. |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Football developer: aggression context behind sanction accumulation. |
| `opponent_fouls_committed` | Fouls committed by opponent side | Football developer: bilateral aggression baseline. |
| `fouls_committed_delta` | Triggered minus opponent fouls committed | Football developer: net foul-load asymmetry paired with card imbalance. |
| `triggered_team_cards_per_foul_pct` | Triggered-side cards per foul (%) | Football developer: sanction conversion intensity on the punished side. |
| `opponent_cards_per_foul_pct` | Opponent cards per foul (%) | Football developer: officiating and discipline asymmetry comparator. |
| `cards_per_foul_delta_pct` | Triggered minus opponent cards-per-foul (percentage points) | Football developer: compact sanction-efficiency imbalance metric. |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: physical contest context around one-sided sanctions. |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral physical contest comparator. |
| `triggered_team_tackles_won` | Successful tackles by triggered side | Football developer: defensive engagement context tied to card burden. |
| `opponent_tackles_won` | Successful tackles by opponent side | Football developer: bilateral defensive engagement comparator. |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: defensive anticipation profile around sanction pressure. |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator. |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-management context for disciplined stress states. |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-management comparator. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Football developer: technical execution context for the heavily sanctioned side. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral technical comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: net technical edge/deficit alongside disciplinary asymmetry. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control-share context for one-sided sanction dynamics. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with discipline imbalance. |
