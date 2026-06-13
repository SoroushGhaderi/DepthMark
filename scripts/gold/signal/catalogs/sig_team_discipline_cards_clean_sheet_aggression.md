---
signal_id: sig_team_discipline_cards_clean_sheet_aggression
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Clean Sheet Aggression"
trigger: "Team wins with a clean sheet and receives >= 5 yellow cards."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_discipline_cards_clean_sheet_aggression
  sql: clickhouse/gold/signal/sig_team_discipline_cards_clean_sheet_aggression.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_discipline_cards_clean_sheet_aggression

## Purpose

Flags team-match performances where a side wins to nil while accumulating a heavy yellow-card load, surfacing disciplined-risk tradeoffs between defensive control and aggressive behavior.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_yellow_cards >= 5`
  - `opponent_goals = 0` (clean sheet)
  - `triggered_team_goals > opponent_goals` (match win)
- Trigger is evaluated symmetrically for home and away teams using `silver.match` and `silver.period_stat` (`period = 'All'`).
- Output keeps bilateral card, foul, defensive-action, and possession context to separate productive aggression from chaotic card-heavy performances.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_discipline_cards_clean_sheet_aggression.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_discipline_cards_clean_sheet_aggression`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_discipline_cards_clean_sheet_aggression
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for joins, QA, and downstream modeling |
| `match_date` | Match date | Temporal slicing and partition-aligned validations |
| `home_team_id` | Home team identifier | Fixed fixture orientation anchor |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team identifier | Fixed fixture orientation anchor |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Outcome context for interpreting trigger severity |
| `away_score` | Away full-time goals | Outcome context for interpreting trigger severity |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical orientation key in row identity |
| `triggered_team_id` | Triggered team identifier | Durable triggered-entity key |
| `triggered_team_name` | Triggered team name | Human-readable triggered-entity context |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key |
| `opponent_team_name` | Opponent team name | Human-readable bilateral context |
| `trigger_threshold_min_yellow_cards` | Configured minimum yellow-card threshold (`5`) | Explicit trigger provenance for reproducibility |
| `trigger_threshold_max_opponent_goals` | Configured maximum opponent-goals threshold (`0`) | Encodes clean-sheet condition explicitly |
| `triggered_team_yellow_cards` | Yellow cards received by triggered side | Core trigger metric for aggression load |
| `opponent_yellow_cards` | Yellow cards received by opponent | Bilateral caution comparator |
| `yellow_cards_delta` | Triggered minus opponent yellow cards | Net caution imbalance for tactical interpretation |
| `yellow_cards_above_threshold` | Amount by which triggered yellows exceed threshold | Trigger-intensity grading |
| `triggered_team_red_cards` | Red cards received by triggered side | Severe-discipline decomposition around trigger |
| `opponent_red_cards` | Red cards received by opponent | Bilateral severe-discipline comparator |
| `red_cards_delta` | Triggered minus opponent red cards | Net dismissal imbalance context |
| `triggered_team_total_cards` | Triggered-side total cards (yellow+red) | Full discipline burden for triggered side |
| `opponent_total_cards` | Opponent total cards (yellow+red) | Bilateral total-card baseline |
| `card_count_delta` | Triggered minus opponent total cards | Net disciplinary pressure differential |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Contact-intensity context behind card accumulation |
| `opponent_fouls_committed` | Fouls committed by opponent | Bilateral foul-volume comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls | Net aggression imbalance signal |
| `triggered_team_fouls_share_pct` | Triggered-side share of total match fouls (%) | Normalizes foul load by whistle volume |
| `opponent_fouls_share_pct` | Opponent share of total match fouls (%) | Symmetric foul-load baseline |
| `triggered_team_win_margin` | Triggered goals minus opponent goals | Result-margin context for card-heavy clean-sheet wins |
| `triggered_team_goals` | Goals scored by triggered side | Offensive output context for triggered result |
| `opponent_goals` | Goals scored by opponent side | Explicit clean-sheet validation field |
| `triggered_team_clean_sheet_flag` | Clean-sheet indicator for triggered side (`1`) | Direct trigger-validation field in final output |
| `triggered_team_duels_won` | Duels won by triggered side | Physical contest context around aggressive wins |
| `opponent_duels_won` | Duels won by opponent side | Bilateral physical contest comparator |
| `triggered_team_tackles_won` | Successful tackles by triggered side | Defensive-execution context for clean-sheet outcome |
| `opponent_tackles_won` | Successful tackles by opponent side | Bilateral defensive-action comparator |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context with high caution load |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `triggered_team_clearances` | Clearances by triggered side | Pressure-management context behind shutout wins |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-management comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Control/style context for interpreting aggressive discipline |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential paired with discipline signal |
