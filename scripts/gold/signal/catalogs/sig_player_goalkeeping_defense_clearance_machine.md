---
signal_id: sig_player_goalkeeping_defense_clearance_machine
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Clearance Machine"
trigger: "Defender records >= 15 clearances in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_clearance_machine
  sql: clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_clearance_machine.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_goalkeeping_defense_clearance_machine

## Purpose

Flags defenders with extreme clearance volume (`>= 15`) in finished matches, surfacing sustained
box-protection and pressure-release performances.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_clearances >= 15`
  - `triggered_player_usual_playing_position_id = 1` (defender gate)
  - `is_goalkeeper = 0`
  - `match_finished = 1`
- Defender scope is derived from `silver.match_personnel` using starter-priority role resolution, then joined to `silver.player_match_stat` for per-player defensive outputs.
- Player diagnostics retain clearances plus interception/tackle/duel/aerial/recovery and passing context to distinguish pure emergency defending from all-around defensive dominance.
- Bilateral team/opponent context is sourced from `silver.period_stat` (`period = 'All'`) with symmetric defensive, control, and circulation fields.
- Similarity gate note:
  - `sig_player_goalkeeping_defense_tackle_master`: same entity/family/subfamily and defender scope, but trigger logic is tackle-perfection (`>= 6` tackles, `100%` success), not clearance volume.
  - `sig_player_goalkeeping_defense_aerial_stronghold`: same entity/family/subfamily and defender scope, but trigger logic is aerial dominance (`>= 10` aerials won), not clearances.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_clearance_machine.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_clearance_machine`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_goalkeeping_defense_clearance_machine
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for joins and deduplication |
| `match_date` | Match date | Temporal slicing and reproducible backfills |
| `home_team_id` | Home team ID | Fixture context anchor |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team ID | Fixture context anchor |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Full-time home goals | Scoreline context for defensive pressure interpretation |
| `away_score` | Full-time away goals | Scoreline context for defensive pressure interpretation |
| `triggered_side` | Side of triggered defender (`home`/`away`) | Canonical side orientation |
| `triggered_player_id` | Triggered defender ID | Durable player identity key |
| `triggered_player_name` | Triggered defender name | Readable attribution |
| `triggered_team_id` | Triggered defender team ID | Links player trigger to side context |
| `triggered_team_name` | Triggered defender team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `triggered_player_role_group` | Derived role label (`defender`) | Explicit role provenance for QA |
| `triggered_player_position_id` | Match-specific position ID | Positional QA for defender attribution |
| `triggered_player_usual_playing_position_id` | Usual playing position ID | Deterministic defender-scope gate |
| `trigger_threshold_min_clearances` | Trigger threshold (`15`) | Explicit trigger boundary provenance |
| `triggered_player_clearances` | Clearances by triggered defender | Core trigger volume metric |
| `triggered_player_clearances_above_threshold` | Clearances above threshold (`clearances - 15`) | Trigger severity beyond binary activation |
| `triggered_player_interceptions` | Interceptions by triggered defender | Anticipation/reading-of-play context |
| `triggered_player_shot_blocks` | Blocked shots by triggered defender | Box-protection contribution context |
| `triggered_player_tackles_won` | Tackles won by triggered defender | Ground duel execution context |
| `triggered_player_tackle_attempts` | Tackle attempts by triggered defender | Tackling denominator context |
| `triggered_player_tackle_success_pct` | Tackle success (%) by triggered defender | Tackling efficiency diagnostic |
| `triggered_player_duels_won` | Total duels won by triggered defender | Physical contest context |
| `triggered_player_duels_lost` | Total duels lost by triggered defender | Physical contest balance context |
| `triggered_player_ground_duels_won` | Ground duels won by triggered defender | Ground contest output context |
| `triggered_player_ground_duel_attempts` | Ground duel attempts by triggered defender | Ground duel denominator context |
| `triggered_player_ground_duel_success_pct` | Ground duel success (%) by triggered defender | Ground duel efficiency diagnostic |
| `triggered_player_aerial_duels_won` | Aerial duels won by triggered defender | Aerial contest complement to clearance load |
| `triggered_player_aerial_duel_attempts` | Aerial duel attempts by triggered defender | Aerial denominator context |
| `triggered_player_aerial_duel_success_pct` | Aerial duel success (%) by triggered defender | Aerial efficiency diagnostic |
| `triggered_player_recoveries` | Recoveries by triggered defender | Defensive transition control context |
| `triggered_player_defensive_actions` | Aggregate defensive actions by triggered defender | Composite defensive workload context |
| `triggered_player_fouls_committed` | Fouls committed by triggered defender | Discipline trade-off context |
| `triggered_player_dribbled_past` | Times dribbled past triggered defender | Defensive vulnerability counterbalance |
| `triggered_player_minutes_played` | Minutes played by triggered defender | Exposure reliability context |
| `triggered_player_touches` | Touches by triggered defender | Involvement baseline |
| `triggered_player_total_passes` | Pass attempts by triggered defender | Distribution-load context |
| `triggered_player_accurate_passes` | Accurate passes by triggered defender | Distribution execution context |
| `triggered_player_pass_accuracy_pct` | Pass accuracy (%) by triggered defender | Composure/retention context |
| `triggered_team_clearances` | Team clearances by triggered side | Team-level pressure-release baseline |
| `opponent_clearances` | Team clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent team clearances | Net pressure-release differential |
| `triggered_team_interceptions` | Team interceptions by triggered side | Team anticipation context |
| `opponent_interceptions` | Team interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net interception differential |
| `triggered_team_shot_blocks` | Team shot blocks by triggered side | Team box-protection context |
| `opponent_shot_blocks` | Team shot blocks by opponent side | Bilateral box-protection comparator |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net shot-block differential |
| `triggered_team_tackles_won` | Team tackles won by triggered side | Team tackling output context |
| `opponent_tackles_won` | Team tackles won by opponent side | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net tackling differential |
| `triggered_team_duels_won` | Team duels won by triggered side | Team physical control context |
| `opponent_duels_won` | Team duels won by opponent side | Bilateral physical control comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net duel-control differential |
| `triggered_team_aerials_won` | Team aerial duels won by triggered side | Team aerial-control context |
| `opponent_aerials_won` | Team aerial duels won by opponent side | Bilateral aerial-control comparator |
| `aerials_won_delta` | Triggered minus opponent aerials won | Net aerial-control differential |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive pressure denominator context |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure denominator comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net pressure differential |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-state context |
| `opponent_possession_pct` | Opponent-side possession (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (%) | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Team execution context |
| `opponent_pass_accuracy_pct` | Opponent-side pass accuracy (%) | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net circulation-execution differential |
| `player_share_of_team_clearances_pct` | Triggered defender share of team clearances (%) | Concentration of clearance burden in one player |
