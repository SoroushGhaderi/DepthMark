---
signal_id: sig_team_physical_workrate_low_block_physicality
status: active
entity: team
family: physical
subfamily: workrate
grain: match_team
headline: "Low Block Physicality"
trigger: "Team records >= 40 clearances and >= 60 duels won while having less than 35% possession."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_physical_workrate_low_block_physicality
  sql: clickhouse/gold/dml/signals/team/sig_team_physical_workrate_low_block_physicality.sql
---
# sig_team_physical_workrate_low_block_physicality

## Purpose

Flags a physical low block, a bunker-and-battle marker.

## Tactical And Statistical Logic

- Trigger: Team records >= 40 clearances and >= 60 duels won while having less than 35% possession.
- Clearances are `clearances`, duels won are `duels_won` and possession is `ball_possession` in `fotmob_silver.period_stat`. Stats come from `fotmob_silver.period_stat` (`period = 'All'`). This is the first signal family built only from duel, aerial and recovery counts, because the loaded data has no distance or sprint tracking.
- Similarity note: Closest: `sig_team_goalkeeping_defense_parking_the_bus` (a win under 30% possession with 30+ clearances) and `sig_team_goalkeeping_defense_passive_block_success`. Different logic: 40 clearances and 60 duels won under 35% possession, whatever the result. Related physical signals in this family are built from the same duel statistics; the closest existing signals are `sig_player_discipline_cards_physical_dominance`, `sig_player_goalkeeping_defense_interception_king` and `sig_team_discipline_cards_physical_superiority`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_physical_workrate_low_block_physicality.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_physical_workrate_low_block_physicality`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_physical_workrate_low_block_physicality
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable match key for joins and QA. |
| `match_date` | Match date | Temporal slicing and partition compatibility. |
| `home_team_id` | Home team identifier | Fixture orientation anchor. |
| `home_team_name` | Home team name | Readable fixture context. |
| `away_team_id` | Away team identifier | Fixture orientation anchor. |
| `away_team_name` | Away team name | Readable fixture context. |
| `home_score` | Full-time home goals | Outcome context for the streak match. |
| `away_score` | Full-time away goals | Outcome context for the streak match. |
| `triggered_side` | Row orientation (`home` or `away`) | Canonical side identity for match-team grain. |
| `triggered_team_id` | Triggered-side team identifier | Team attribution key for downstream features. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral context. |
| `trigger_threshold_min_clearances` | Configured trigger floor (`40` clearances, 60 duels won and under 35 % possession) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_clearances` | Clearances by the team | Core signal intensity variable. |
| `triggered_team_clearances_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_team_duels_won_low_block` | Duels won by the team | Physical output. |
| `triggered_team_possession_pct` | Possession of the team (%) | Confirms the low block. |
| `triggered_team_goals` | Triggered-side goals in the match | Result context for the streak match. |
| `opponent_goals` | Opponent goals in the match | Bilateral result comparator. |
| `triggered_team_xg` | Triggered-side expected goals (xG) | Chance-quality and control context behind the streak result. |
| `opponent_xg` | Opponent expected goals (xG) | Bilateral comparator for the same match. |
| `triggered_team_total_shots` | Triggered-side total shots | Chance-quality and control context behind the streak result. |
| `opponent_total_shots` | Opponent total shots | Bilateral comparator for the same match. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Chance-quality and control context behind the streak result. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral comparator for the same match. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Chance-quality and control context behind the streak result. |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral comparator for the same match. |
