---
signal_id: sig_team_discipline_cards_away_hostility
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Away Team Card Hostility"
trigger: "Away team receives >= 4 more total cards than the home team."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_discipline_cards_away_hostility
  sql: clickhouse/gold/signal/sig_team_discipline_cards_away_hostility.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_discipline_cards_away_hostility

## Purpose

Flags matches where the away side's discipline burden is materially heavier than the host, based on a minimum four-card gap.

## Tactical And Statistical Logic

- Trigger condition:
  - `away_total_cards - home_total_cards >= 4`
- Total cards are computed as yellow plus red cards from `silver.period_stat` (`period = 'All'`).
- The triggered entity is fixed to the away side (`triggered_side = 'away'`) by design.
- Output preserves bilateral card composition, foul load, and defensive/control context for interpretation.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_discipline_cards_away_hostility.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_discipline_cards_away_hostility`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_discipline_cards_away_hostility
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join key and release QA anchor |
| `match_date` | Match date | Temporal slicing and partition alignment |
| `home_team_id` | Home team identifier | Fixed fixture orientation anchor |
| `home_team_name` | Home team name | Readable host context |
| `away_team_id` | Away team identifier | Fixed fixture orientation anchor |
| `away_team_name` | Away team name | Readable away context |
| `home_score` | Home full-time goals | Match outcome context |
| `away_score` | Away full-time goals | Match outcome context |
| `triggered_side` | Triggered side (`away`) | Canonical row identity orientation |
| `triggered_team_id` | Triggered team identifier | Durable triggered-entity key |
| `triggered_team_name` | Triggered team name | Readable triggered-entity context |
| `opponent_team_id` | Opponent (home) team identifier | Bilateral comparison key |
| `opponent_team_name` | Opponent (home) team name | Readable bilateral context |
| `trigger_threshold_min_card_count_delta` | Configured minimum card-gap threshold (`4`) | Explicit trigger provenance |
| `triggered_team_total_cards` | Away total cards (yellow+red) | Core trigger-side discipline load |
| `opponent_total_cards` | Home total cards (yellow+red) | Trigger comparator baseline |
| `card_count_delta` | Away minus home total cards | Core trigger metric |
| `card_count_above_threshold` | Amount by which card delta exceeds threshold | Trigger-intensity grading |
| `triggered_team_cards_share_pct` | Away share of all match cards (%) | Relative discipline burden context |
| `opponent_cards_share_pct` | Home share of all match cards (%) | Symmetric burden baseline |
| `triggered_team_yellow_cards` | Away yellow cards | Caution-level composition |
| `opponent_yellow_cards` | Home yellow cards | Symmetric caution comparator |
| `yellow_cards_delta` | Away minus home yellow cards | Net caution imbalance |
| `triggered_team_red_cards` | Away red cards | Severe-discipline component |
| `opponent_red_cards` | Home red cards | Symmetric severe-discipline comparator |
| `red_cards_delta` | Away minus home red cards | Net severe-discipline imbalance |
| `triggered_team_fouls_committed` | Away fouls committed | Aggression load context |
| `opponent_fouls_committed` | Home fouls committed | Symmetric aggression comparator |
| `fouls_committed_delta` | Away minus home fouls | Net aggression imbalance |
| `triggered_team_fouls_share_pct` | Away share of all match fouls (%) | Relative foul-burden context |
| `opponent_fouls_share_pct` | Home share of all match fouls (%) | Symmetric foul-burden baseline |
| `triggered_team_duels_won` | Away duels won | Physical contest context |
| `opponent_duels_won` | Home duels won | Symmetric physical comparator |
| `triggered_team_tackles_won` | Away successful tackles | Defensive action context |
| `opponent_tackles_won` | Home successful tackles | Symmetric defensive comparator |
| `triggered_team_interceptions` | Away interceptions | Defensive anticipation context |
| `opponent_interceptions` | Home interceptions | Symmetric anticipation comparator |
| `triggered_team_clearances` | Away clearances | Pressure-management context |
| `opponent_clearances` | Home clearances | Symmetric pressure-management comparator |
| `triggered_team_possession_pct` | Away possession share (%) | Control/style context |
| `opponent_possession_pct` | Home possession share (%) | Symmetric control comparator |
| `possession_delta_pct` | Away minus home possession (pp) | Net control differential |
