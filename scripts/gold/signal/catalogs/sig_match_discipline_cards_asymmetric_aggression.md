---
signal_id: sig_match_discipline_cards_asymmetric_aggression
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Match Discipline Cards Asymmetric Aggression"
trigger: "One team commits at least 3x the opponent fouls but receives fewer total cards."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_match_discipline_cards_asymmetric_aggression
  sql: clickhouse/gold/signal/sig_match_discipline_cards_asymmetric_aggression.sql
  runner: scripts/gold/signal/runners/sig_match_discipline_cards_asymmetric_aggression.py
---
# sig_match_discipline_cards_asymmetric_aggression

## Purpose

Flags matches where physical contact burden is heavily one-sided, but disciplinary sanctions lean the other way.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_fouls_committed >= 3 * opponent_fouls_committed`
  - `triggered_team_total_cards < opponent_total_cards`
  - `opponent_fouls_committed > 0`
- Foul and card counts are sourced from `silver.period_stat` at `period = 'All'`.
- Trigger orientation (`triggered_side`) is assigned to the side with higher foul count, then filtered by the aggression-plus-fewer-cards predicate.
- Output preserves bilateral discipline, card-conversion, defensive workload, passing quality, and possession context for interpretation.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_discipline_cards_asymmetric_aggression.sql`
- Runner: `scripts/gold/signal/runners/sig_match_discipline_cards_asymmetric_aggression.py`
- Target table: `gold.sig_match_discipline_cards_asymmetric_aggression`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_discipline_cards_asymmetric_aggression.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for QA and downstream features. |
| `match_date` | Match date | Football developer: temporal slicing and partition alignment. |
| `home_team_id` | Home team identifier | Football developer: fixture orientation anchor. |
| `home_team_name` | Home team name | Football developer: readable fixture context. |
| `away_team_id` | Away team identifier | Football developer: fixture orientation anchor. |
| `away_team_name` | Away team name | Football developer: readable fixture context. |
| `home_score` | Home full-time goals | Football developer: scoreline context for discipline asymmetry interpretation. |
| `away_score` | Away full-time goals | Football developer: scoreline context for discipline asymmetry interpretation. |
| `triggered_side` | Side that satisfies the asymmetric-aggression trigger (`home` or `away`) | Football developer: canonical row identity orientation. |
| `triggered_team_id` | Triggered-side team identifier | Football developer: durable triggered entity key. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered attribution. |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context. |
| `trigger_threshold_min_fouls_multiplier` | Configured minimum foul multiplier threshold (`3.0`) | Football developer: explicit trigger governance and provenance. |
| `trigger_threshold_max_card_count_delta` | Configured maximum allowed card delta for triggered side (`-1`, meaning fewer cards) | Football developer: explicit sanction-side trigger governance. |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Football developer: core trigger numerator. |
| `opponent_fouls_committed` | Fouls committed by opponent side | Football developer: core trigger denominator component. |
| `match_total_fouls_committed` | Combined fouls in match | Football developer: match-level intensity anchor. |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net contact imbalance magnitude. |
| `triggered_team_fouls_share_pct` | Triggered-side share of total match fouls (%) | Football developer: normalized physical-burden metric. |
| `opponent_fouls_share_pct` | Opponent share of total match fouls (%) | Football developer: symmetric normalized comparator. |
| `fouls_share_delta_pct` | Triggered minus opponent foul share (percentage points) | Football developer: compact normalized asymmetry measure. |
| `triggered_team_fouls_multiplier` | Triggered-side fouls divided by opponent fouls | Football developer: direct aggressor-intensity multiplier behind the 3x rule. |
| `fouls_multiplier_above_threshold` | Excess of foul multiplier above threshold (`triggered_team_fouls_multiplier - 3.0`) | Football developer: trigger intensity grading beyond binary qualification. |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: sanction load attached to foul-heavy side. |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: bilateral sanction comparator. |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: confirms negative sanction imbalance required by trigger. |
| `match_total_cards` | Combined match cards (yellow + red) | Football developer: global sanction intensity context. |
| `match_total_yellow_cards` | Combined match yellow cards | Football developer: caution composition context. |
| `match_total_red_cards` | Combined match red cards | Football developer: dismissal composition context. |
| `triggered_team_yellow_cards` | Triggered-side yellow cards | Football developer: caution-level decomposition for the foul-heavy side. |
| `opponent_yellow_cards` | Opponent yellow cards | Football developer: bilateral caution comparator. |
| `yellow_cards_delta` | Triggered minus opponent yellow cards | Football developer: net caution imbalance detail. |
| `triggered_team_red_cards` | Triggered-side red cards | Football developer: dismissal contribution on triggered side. |
| `opponent_red_cards` | Opponent red cards | Football developer: bilateral dismissal comparator. |
| `red_cards_delta` | Triggered minus opponent red cards | Football developer: net dismissal imbalance detail. |
| `triggered_team_cards_per_foul_pct` | Triggered-side cards per foul (%) | Football developer: sanction-conversion intensity for triggered side. |
| `opponent_cards_per_foul_pct` | Opponent cards per foul (%) | Football developer: bilateral sanction-conversion comparator. |
| `cards_per_foul_delta_pct` | Triggered minus opponent cards-per-foul (percentage points) | Football developer: officiating/discipline asymmetry summary metric. |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: physical contest context for foul concentration. |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral physicality comparator. |
| `triggered_team_tackles_won` | Successful tackles by triggered side | Football developer: defensive engagement context. |
| `opponent_tackles_won` | Successful tackles by opponent side | Football developer: bilateral defensive engagement comparator. |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: defensive anticipation profile around trigger. |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator. |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-management context. |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-management comparator. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Football developer: technical execution context for foul-heavy side. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral technical comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: net technical differential paired with discipline imbalance. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control-share context for interpreting foul asymmetry. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential aligned with foul concentration. |
