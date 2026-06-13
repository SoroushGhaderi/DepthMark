---
signal_id: sig_team_discipline_cards_hostile_territory
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Hostile Territory"
trigger: "Team total cards (yellow + red) are greater than team shots on target."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_discipline_cards_hostile_territory
  sql: clickhouse/gold/signal/sig_team_discipline_cards_hostile_territory.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_discipline_cards_hostile_territory

## Purpose

Flags team-match performances where disciplinary events outnumber on-target shots, capturing aggressive or frustrated matches with limited attacking precision.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_total_cards > triggered_team_shots_on_target`
  - Equivalent threshold form: `triggered_team_cards_minus_shots_on_target >= 1`
- Total cards are computed as yellow plus red cards from `silver.period_stat` (`period = 'All'`).
- Trigger is evaluated symmetrically for home and away sides.
- Output preserves bilateral card, shooting, fouling, defensive, and possession context for interpretation.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_discipline_cards_hostile_territory.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_discipline_cards_hostile_territory`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_discipline_cards_hostile_territory
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join key and release-QA anchor |
| `match_date` | Match date | Temporal slicing and partition alignment |
| `home_team_id` | Home team identifier | Fixed fixture orientation anchor |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team identifier | Fixed fixture orientation anchor |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Match outcome context |
| `away_score` | Away full-time goals | Match outcome context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical row orientation and identity key |
| `triggered_team_id` | Triggered team identifier | Durable triggered-entity key |
| `triggered_team_name` | Triggered team name | Human-readable triggered-entity context |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key |
| `opponent_team_name` | Opponent team name | Human-readable bilateral context |
| `trigger_threshold_min_card_minus_shots_on_target` | Minimum trigger gap threshold (`1`) | Explicit trigger provenance in output rows |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Core trigger numerator and discipline burden context |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Bilateral discipline baseline |
| `card_count_delta` | Triggered minus opponent total cards | Net disciplinary imbalance context |
| `triggered_team_total_shots` | Triggered-side total shots | Attacking volume context for shot-quality interpretation |
| `opponent_total_shots` | Opponent total shots | Bilateral attacking-volume baseline |
| `total_shots_delta` | Triggered minus opponent total shots | Net attacking volume differential |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Core trigger denominator and attacking-precision context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral on-target baseline |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Net precision differential in final delivery |
| `triggered_team_cards_minus_shots_on_target` | Triggered-side cards minus shots on target | Core trigger metric for this signal |
| `opponent_cards_minus_shots_on_target` | Opponent cards minus shots on target | Bilateral comparator for trigger-shape asymmetry |
| `cards_minus_shots_on_target_delta` | Triggered minus opponent (cards minus shots on target) | Net contextual gap between both teams' trigger metric |
| `cards_minus_shots_on_target_above_threshold` | Triggered-side trigger metric minus threshold (`1`) | Trigger-intensity grading beyond minimum qualification |
| `triggered_team_shots_on_target_rate_pct` | Triggered-side shots-on-target rate (%) | Precision normalization against shot volume |
| `opponent_shots_on_target_rate_pct` | Opponent shots-on-target rate (%) | Bilateral precision baseline |
| `shots_on_target_rate_delta_pct` | Triggered minus opponent shots-on-target rate (pp) | Net precision differential companion to trigger |
| `triggered_team_fouls_committed` | Triggered-side fouls committed | Aggression/contact context behind discipline load |
| `opponent_fouls_committed` | Opponent fouls committed | Bilateral aggression comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls | Net contact imbalance around trigger |
| `triggered_team_duels_won` | Triggered-side duels won | Physical contest context |
| `opponent_duels_won` | Opponent duels won | Bilateral physical contest comparator |
| `triggered_team_tackles_won` | Triggered-side successful tackles | Defensive action context |
| `opponent_tackles_won` | Opponent successful tackles | Bilateral defensive action comparator |
| `triggered_team_interceptions` | Triggered-side interceptions | Defensive anticipation context |
| `opponent_interceptions` | Opponent interceptions | Bilateral anticipation comparator |
| `triggered_team_clearances` | Triggered-side clearances | Pressure-management context |
| `opponent_clearances` | Opponent clearances | Bilateral pressure-management comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Game-control context for triggered behavior |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control baseline |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential paired with discipline trigger |
