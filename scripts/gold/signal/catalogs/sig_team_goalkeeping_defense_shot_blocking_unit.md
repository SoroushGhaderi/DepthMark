---
signal_id: sig_team_goalkeeping_defense_shot_blocking_unit
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Shot Blocking Unit"
trigger: "Team blocks >= 10 shots in a single finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_goalkeeping_defense_shot_blocking_unit
  sql: clickhouse/gold/signal/sig_team_goalkeeping_defense_shot_blocking_unit.sql
  runner: scripts/gold/signal/runners/sig_team_goalkeeping_defense_shot_blocking_unit.py
---
# sig_team_goalkeeping_defense_shot_blocking_unit

## Purpose

Detect team-level defensive units that post extreme shot-block volume (`>= 10`) in a match, while retaining bilateral defending, control, and result context for tactical interpretation.

## Tactical And Statistical Logic

- Trigger condition: `triggered_team_shot_blocks >= 10` from `silver.period_stat` at full-match scope (`period = 'All'`) with `match_finished = 1`.
- Rows are emitted at `match_team` grain with canonical `triggered_side`, so both teams can independently trigger in the same match.
- `triggered_team_shot_blocks_above_threshold` quantifies trigger severity beyond binary activation.
- Enrichment preserves symmetric defensive workload and pressure-context fields (interceptions, clearances, tackles, duels, aerials, shots faced, shots on target faced, keeper saves), alongside possession, pass quality, and scoreline context.
- Similarity gate note:
  - `sig_team_goalkeeping_defense_parking_the_bus`: same entity/family/subfamily but distinct because that signal requires a win plus low possession and clearance threshold, while this one is pure shot-block volume.
  - `sig_team_goalkeeping_defense_offside_trap_mastery`: same entity/family/subfamily but distinct trigger dimension (offsides caught vs shot blocks).
  - `sig_player_goalkeeping_defense_shot_blocker_elite`: closest shot-block intent, but player-grain (`player >= 4`) versus team-grain (`team >= 10`).

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_goalkeeping_defense_shot_blocking_unit.sql`
- Runner: `scripts/gold/signal/runners/sig_team_goalkeeping_defense_shot_blocking_unit.py`
- Target table: `gold_signals.sig_team_goalkeeping_defense_shot_blocking_unit`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_goalkeeping_defense_shot_blocking_unit.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for downstream joins and deduplication |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills |
| `home_team_id` | Home team ID | Preserves bilateral fixture context |
| `home_team_name` | Home team name | Analyst-readable fixture attribution |
| `away_team_id` | Away team ID | Preserves bilateral fixture context |
| `away_team_name` | Away team name | Analyst-readable fixture attribution |
| `home_score` | Home full-time goals | Outcome context for defensive interpretation |
| `away_score` | Away full-time goals | Outcome context for defensive interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side orientation at `match_team` grain |
| `triggered_team_id` | Triggered team ID | Stable identity for the triggered side |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Readable opponent attribution |
| `trigger_threshold_min_shot_blocks` | Trigger threshold (`10`) | Explicit trigger provenance for reproducibility |
| `triggered_team_shot_blocks` | Shot blocks by triggered side | Core trigger metric |
| `opponent_shot_blocks` | Shot blocks by opponent side | Bilateral shot-blocking comparator |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net shot-blocking differential |
| `triggered_team_shot_blocks_above_threshold` | Shot blocks above threshold (`value - 10`) | Trigger severity beyond activation boundary |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation baseline |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_clearances` | Clearances by triggered side | Defensive pressure-release context |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release baseline |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential |
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
| `triggered_team_shots_on_target_faced` | Shots on target faced by triggered side | Shot-stopping pressure context |
| `opponent_shots_on_target_faced` | Shots on target faced by opponent side | Bilateral on-target pressure baseline |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target exposure differential |
| `triggered_team_keeper_saves` | Keeper saves by triggered side | Last-line defensive workload context |
| `opponent_keeper_saves` | Keeper saves by opponent side | Bilateral keeper-workload comparator |
| `keeper_saves_delta` | Triggered minus opponent keeper saves | Net goalkeeper workload differential |
| `triggered_team_possession_pct` | Triggered-side possession percentage | Control-state context |
| `opponent_possession_pct` | Opponent-side possession percentage | Bilateral control-state baseline |
| `possession_delta_pct` | Triggered minus opponent possession percentage | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy percentage | Ball-retention execution context |
| `opponent_pass_accuracy_pct` | Opponent-side pass accuracy percentage | Bilateral execution baseline |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy percentage | Net circulation-quality differential |
| `triggered_team_goals` | Goals scored by triggered side | Result translation context |
| `opponent_goals` | Goals scored by opponent side | Bilateral result context |
| `goal_delta` | Triggered minus opponent goals | Compact outcome differential |
| `triggered_team_clean_sheet_flag` | 1 when opponent goals = 0, else 0 | Separates defensive event intensity from clean-sheet outcome |
