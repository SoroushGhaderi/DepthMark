---
signal_id: sig_team_goalkeeping_defense_clearance_barrage
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Clearance Barrage"
trigger: "Team records >= 40 total clearances in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_goalkeeping_defense_clearance_barrage
  sql: clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_clearance_barrage.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_goalkeeping_defense_clearance_barrage

## Purpose

Detect team-level defensive overload matches where a side produces extreme clearance volume (`>= 40`), then retain bilateral defending, control, and outcome context for interpretation.

## Tactical And Statistical Logic

- Trigger condition: `triggered_team_clearances >= 40` from `silver.period_stat` at full-match scope (`period = 'All'`) with `match_finished = 1`.
- Output grain is `match_team` with canonical `triggered_side`, so both teams can emit rows in the same match when both satisfy the threshold.
- Severity is exposed via `triggered_team_clearances_above_threshold` and bilateral deltas for clearances, interceptions, shot blocks, tackles, duels, and aerial wins.
- Pressure environment is contextualized with shots faced, possession, pass accuracy, and scoreline/clean-sheet outputs.
- Similarity gate note:
  - `sig_player_goalkeeping_defense_clearance_machine`: closest on defensive-clearance intent, but player-grain trigger (`player >= 15 clearances`) versus team-grain overload trigger (`team >= 40 clearances`).
  - `sig_team_possession_passing_low_block_frustration`: includes clearance context, but trigger is possession/passing inefficiency, not defensive-clearance overload.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_clearance_barrage.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_goalkeeping_defense_clearance_barrage`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_goalkeeping_defense_clearance_barrage
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join key for downstream QA and feature engineering |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills |
| `home_team_id` | Home team identifier | Preserves bilateral fixture context |
| `home_team_name` | Home team name | Analyst-readable fixture attribution |
| `away_team_id` | Away team identifier | Preserves bilateral fixture context |
| `away_team_name` | Away team name | Analyst-readable fixture attribution |
| `home_score` | Full-time home goals | Outcome context for defensive-load interpretation |
| `away_score` | Full-time away goals | Outcome context for defensive-load interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side orientation at match-team grain |
| `triggered_team_id` | Triggered team identifier | Primary triggered entity key |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Bilateral opponent orientation |
| `opponent_team_name` | Opponent team name | Readable bilateral opponent context |
| `trigger_threshold_min_clearances` | Fixed trigger threshold (`40`) | Explicit trigger provenance for reproducibility |
| `triggered_team_clearances` | Clearances by triggered side | Core trigger metric |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential |
| `triggered_team_clearances_above_threshold` | Triggered clearances beyond threshold (`clearances - 40`) | Trigger severity above activation boundary |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation baseline |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_shot_blocks` | Shot blocks by triggered side | Box-protection context |
| `opponent_shot_blocks` | Shot blocks by opponent side | Bilateral box-protection baseline |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net block-volume differential |
| `triggered_team_tackles_won` | Tackles won by triggered side | Ground-duel execution context |
| `opponent_tackles_won` | Tackles won by opponent side | Bilateral tackling baseline |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net tackling differential |
| `triggered_team_duels_won` | Duels won by triggered side | Physical-control context |
| `opponent_duels_won` | Duels won by opponent side | Bilateral physical-control baseline |
| `duels_won_delta` | Triggered minus opponent duels won | Net duel-control differential |
| `triggered_team_aerials_won` | Aerial duels won by triggered side | Aerial-control context |
| `opponent_aerials_won` | Aerial duels won by opponent side | Bilateral aerial-control baseline |
| `aerials_won_delta` | Triggered minus opponent aerial duels won | Net aerial-control differential |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive pressure denominator |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure baseline |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net defensive-exposure differential |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-state context |
| `opponent_possession_pct` | Opponent-side possession (%) | Bilateral control baseline |
| `possession_delta_pct` | Triggered minus opponent possession (%) | Net control differential |
| `triggered_team_pass_attempts` | Pass attempts by triggered side | Circulation-volume baseline under pressure |
| `opponent_pass_attempts` | Pass attempts by opponent side | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy (%) by triggered side | Circulation-execution context |
| `opponent_pass_accuracy_pct` | Pass accuracy (%) by opponent side | Bilateral circulation-execution baseline |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net circulation-execution differential |
| `triggered_team_goals` | Goals scored by triggered side | Result translation context |
| `opponent_goals` | Goals scored by opponent side | Bilateral result context |
| `goal_delta` | Triggered minus opponent goals | Compact result differential |
| `triggered_team_clean_sheet_flag` | 1 when opponent goals = 0 else 0 | Separates pressure absorption from clean-sheet outcome |
