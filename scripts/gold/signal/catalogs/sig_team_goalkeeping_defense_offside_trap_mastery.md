---
signal_id: sig_team_goalkeeping_defense_offside_trap_mastery
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Offside Trap Mastery"
trigger: "Team catches opposition offside >= 6 times in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_goalkeeping_defense_offside_trap_mastery
  sql: clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_offside_trap_mastery.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_goalkeeping_defense_offside_trap_mastery

## Purpose

Detects team-level high-line defensive execution where a side repeatedly catches the opposition offside and captures bilateral defending, control, and result context for tactical interpretation.

## Tactical And Statistical Logic

- Trigger condition: `triggered_team_offsides_caught >= 6` from `silver.period_stat` at full-match scope (`period = 'All'`) with `match_finished = 1`.
- Rows are emitted at `match_team` grain with canonical `triggered_side`, so either home or away side can independently trigger.
- `triggered_team_offsides_caught` is modeled as opponent offsides committed against the triggered side (`home -> offsides_away`, `away -> offsides_home`).
- Severity is exposed with `triggered_team_offsides_caught_above_threshold` and bilateral offside deltas (`offsides_caught_delta`, `offsides_committed_delta`).
- Signal is enriched with symmetric defensive workload (interceptions, clearances, tackles, blocks, duels, aerial wins), pressure faced (shots, shots on target, saves), plus control and outcome context.
- Similarity gate note:
  - `sig_player_goalkeeping_defense_high_line_trapper`: closest overlap in offside-trap intent, but that signal is player-grain and uses a defender proxy (`>= 3`) while this is team-grain with direct side-level threshold (`>= 6`).
  - `sig_match_discipline_cards_stop_start_hell`: contains offside volume but models overall whistle interruption tempo, not targeted offside-trap mastery.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_offside_trap_mastery.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_goalkeeping_defense_offside_trap_mastery`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_goalkeeping_defense_offside_trap_mastery
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
| `trigger_threshold_min_opponent_offsides_caught` | Trigger threshold (`6`) | Explicit trigger provenance for reproducibility |
| `triggered_team_offsides_caught` | Opponent offsides committed against triggered side | Core offside-trap output metric |
| `opponent_offsides_caught` | Opponent side's offsides-caught count | Bilateral offside-trap comparator |
| `offsides_caught_delta` | Triggered minus opponent offsides-caught count | Net offside-trap edge |
| `triggered_team_offsides_caught_above_threshold` | Offsides-caught value above threshold (`value - 6`) | Trigger severity beyond activation boundary |
| `triggered_team_offsides_committed` | Offsides committed by triggered side | Attacking timing cost context |
| `opponent_offsides_committed` | Offsides committed by opponent side | Bilateral attacking timing comparator |
| `offsides_committed_delta` | Triggered minus opponent offsides committed | Net attacking timing differential |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation baseline |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_clearances` | Clearances by triggered side | Defensive pressure-release context |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release baseline |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential |
| `triggered_team_tackles_won` | Tackles won by triggered side | Ground-duel execution context |
| `opponent_tackles_won` | Tackles won by opponent side | Bilateral tackling baseline |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net tackling differential |
| `triggered_team_shot_blocks` | Shot blocks by triggered side | Box-protection context |
| `opponent_shot_blocks` | Shot blocks by opponent side | Bilateral box-protection baseline |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net block-volume differential |
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
| `opponent_shots_on_target_faced` | Shots on target faced by opponent side | Bilateral shot-stopping pressure baseline |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target exposure differential |
| `triggered_team_keeper_saves` | Goalkeeper saves by triggered side | Last-line defensive workload context |
| `opponent_keeper_saves` | Goalkeeper saves by opponent side | Bilateral keeper workload comparator |
| `keeper_saves_delta` | Triggered minus opponent goalkeeper saves | Net keeper workload differential |
| `triggered_team_possession_pct` | Triggered-side possession percentage | Control-state context |
| `opponent_possession_pct` | Opponent-side possession percentage | Bilateral control-state baseline |
| `possession_delta_pct` | Triggered minus opponent possession percentage | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy percentage | Ball-retention execution context |
| `opponent_pass_accuracy_pct` | Opponent-side pass accuracy percentage | Bilateral execution baseline |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy percentage | Net circulation-quality differential |
| `triggered_team_goals` | Goals scored by triggered side | Result translation context |
| `opponent_goals` | Goals scored by opponent side | Bilateral result context |
| `goal_delta` | Triggered minus opponent goals | Compact outcome differential |
| `triggered_team_clean_sheet_flag` | 1 when opponent goals = 0, else 0 | Separates offside-trap execution from clean-sheet outcome |
