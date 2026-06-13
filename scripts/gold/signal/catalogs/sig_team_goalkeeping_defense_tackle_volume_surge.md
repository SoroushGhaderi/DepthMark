---
signal_id: sig_team_goalkeeping_defense_tackle_volume_surge
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Tackle Volume Surge"
trigger: "Team wins >= 25 tackles in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_goalkeeping_defense_tackle_volume_surge
  sql: clickhouse/gold/signal/sig_team_goalkeeping_defense_tackle_volume_surge.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_goalkeeping_defense_tackle_volume_surge

## Purpose

Detects team-level defensive intensity matches where a side produces extreme successful tackle volume, while preserving bilateral defensive workload, pressure, control, and result context.

## Tactical And Statistical Logic

- Trigger condition: `triggered_team_tackles_won >= 25` from `silver.period_stat` at full-match scope (`period = 'All'`) with `match_finished = 1`.
- Rows are emitted at `match_team` grain using canonical `triggered_side`, so both teams can trigger in the same match if both exceed the threshold.
- `triggered_team_tackles_won` maps to successful tackles (`tackles_succeeded_home/away`) and severity is captured by `triggered_team_tackles_won_above_threshold`.
- Output includes bilateral deltas for tackles, interceptions, clearances, blocks, duels, aerials, shots faced, keeper saves, and fouls to frame defensive trade-offs.
- Similarity gate note:
  - `sig_player_goalkeeping_defense_tackle_master`: closest intent overlap on tackle output, but player-grain trigger (`player tackles`) versus this team-grain defensive volume trigger (`team >= 25 successful tackles`).
  - `sig_team_goalkeeping_defense_clearance_barrage`: same team-goalkeeping-defense family and bilateral defensive context style, but trigger axis is clearances (`>= 40`) rather than tackles.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_goalkeeping_defense_tackle_volume_surge.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_goalkeeping_defense_tackle_volume_surge`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_goalkeeping_defense_tackle_volume_surge
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
| `trigger_threshold_min_tackles_won` | Trigger threshold (`25`) | Explicit trigger provenance for reproducibility |
| `triggered_team_tackles_won` | Successful tackles by triggered side | Core trigger metric for defensive intensity |
| `opponent_tackles_won` | Successful tackles by opponent side | Bilateral tackling baseline |
| `tackles_won_delta` | Triggered minus opponent successful tackles | Net tackling differential |
| `triggered_team_tackles_won_above_threshold` | Tackle value above threshold (`value - 25`) | Trigger severity beyond activation boundary |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation baseline |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_clearances` | Clearances by triggered side | Pressure-release context |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release baseline |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential |
| `triggered_team_shot_blocks` | Shot blocks by triggered side | Box-protection context |
| `opponent_shot_blocks` | Shot blocks by opponent side | Bilateral block-volume baseline |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net block differential |
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
| `opponent_shots_on_target_faced` | Shots on target faced by opponent side | Bilateral shot-stopping baseline |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target exposure differential |
| `triggered_team_keeper_saves` | Goalkeeper saves by triggered side | Last-line defensive workload context |
| `opponent_keeper_saves` | Goalkeeper saves by opponent side | Bilateral keeper workload comparator |
| `keeper_saves_delta` | Triggered minus opponent goalkeeper saves | Net keeper workload differential |
| `triggered_team_fouls` | Fouls committed by triggered side | Defensive aggression and discipline trade-off context |
| `opponent_fouls` | Fouls committed by opponent side | Bilateral discipline baseline |
| `fouls_delta` | Triggered minus opponent fouls | Net discipline differential |
| `triggered_team_possession_pct` | Triggered-side possession percentage | Control-state context |
| `opponent_possession_pct` | Opponent-side possession percentage | Bilateral control-state baseline |
| `possession_delta_pct` | Triggered minus opponent possession percentage | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy percentage | Ball-retention execution context |
| `opponent_pass_accuracy_pct` | Opponent-side pass accuracy percentage | Bilateral execution baseline |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy percentage | Net circulation-quality differential |
| `triggered_team_goals` | Goals scored by triggered side | Result translation context |
| `opponent_goals` | Goals scored by opponent side | Bilateral result context |
| `goal_delta` | Triggered minus opponent goals | Compact outcome differential |
| `triggered_team_clean_sheet_flag` | 1 when opponent goals = 0, else 0 | Separates tackle intensity from clean-sheet outcome |
