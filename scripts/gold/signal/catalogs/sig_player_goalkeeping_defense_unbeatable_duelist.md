---
signal_id: sig_player_goalkeeping_defense_unbeatable_duelist
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Unbeatable Duelist"
trigger: "Player wins >= 12 total duels (ground + aerial) with > 80% success in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_unbeatable_duelist
  sql: clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_unbeatable_duelist.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_goalkeeping_defense_unbeatable_duelist

## Purpose

Flags defender performances with high-volume and high-efficiency combined duel output (`ground + aerial`) so physical dominance can be tracked with player-level and bilateral team context.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_total_duels_won = coalesce(ground_duels_won, 0) + coalesce(aerial_duels_won, 0) >= 12`
  - `triggered_player_total_duel_success_pct = 100 * total_duels_won / total_duel_attempts > 80`
  - `triggered_player_total_duel_attempts = coalesce(ground_duel_attempts, 0) + coalesce(aerial_duel_attempts, 0)`
  - `triggered_player_usual_playing_position_id = 1` (defender scope)
  - `is_goalkeeper = 0`
  - `match_finished = 1`
- Defender scope is resolved from `silver.match_personnel` with starter-priority position selection per `(match_id, player_id)`.
- Player diagnostics preserve duel splits (ground vs aerial), tackling, interceptions, clearances, defensive actions, recoveries, and passing context.
- Bilateral team context is sourced from `silver.period_stat` (`period = 'All'`) with symmetric `triggered_team_*` and `opponent_*` metrics.
- Similarity gate note:
  - `sig_player_goalkeeping_defense_aerial_stronghold`: close overlap in defender duel profile, but that signal triggers on aerial wins only (`>= 10`) and not combined duel efficiency.
  - `sig_player_goalkeeping_defense_unbeaten_in_air`: close aerial-efficiency overlap, but it requires perfect aerial record (`100%`, aerial-only) rather than total duel profile (`ground + aerial`, `> 80%`).
  - `sig_player_goalkeeping_defense_tackle_master`: same family/subfamily and defender role, but trigger axis is perfect tackling (`>= 6` tackles at `100%`), not combined duel dominance.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_unbeatable_duelist.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_unbeatable_duelist`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_goalkeeping_defense_unbeatable_duelist
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for deduplication and downstream joins |
| `match_date` | Match date | Temporal slicing and reproducible backfills |
| `home_team_id` | Home team ID | Fixture context anchor |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Fixture context anchor |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Outcome context for duel output |
| `away_score` | Away full-time goals | Outcome context for duel output |
| `triggered_side` | Side of triggered player (`home` or `away`) | Canonical side orientation |
| `triggered_player_id` | Triggered player ID | Player-grain identity key |
| `triggered_player_name` | Triggered player name | Readable signal attribution |
| `triggered_team_id` | Team ID of triggered player | Links player trigger to team context |
| `triggered_team_name` | Team name of triggered player | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup key |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `triggered_player_role_group` | Derived role label (`defender`) | Explicit trigger scope provenance |
| `triggered_player_position_id` | Match-specific position ID | Positional QA context |
| `triggered_player_usual_playing_position_id` | Usual position bucket used for defender gate | Deterministic scope traceability |
| `trigger_threshold_min_total_duels_won` | Minimum combined duel wins threshold (`12`) | Explicit trigger boundary |
| `trigger_threshold_min_total_duel_success_pct` | Minimum combined duel success threshold (`80`) | Explicit efficiency trigger boundary |
| `triggered_player_minutes_played` | Minutes played by triggered defender | Exposure and reliability context |
| `triggered_player_total_duels_won` | Combined duel wins (`ground + aerial`) | Core trigger volume metric |
| `triggered_player_total_duel_attempts` | Combined duel attempts (`ground + aerial`) | Core trigger denominator |
| `triggered_player_total_duel_success_pct` | Combined duel success percentage | Core trigger efficiency metric |
| `triggered_player_total_duels_won_above_threshold` | Duel wins above threshold (`wins - 12`) | Trigger severity context |
| `triggered_player_total_duel_success_above_threshold_pct` | Duel success above threshold in percentage points (`success - 80`) | Efficiency margin beyond activation |
| `triggered_player_ground_duels_won` | Ground duels won by triggered player | Ground-contest component context |
| `triggered_player_ground_duel_attempts` | Ground duel attempts by triggered player | Ground-contest denominator |
| `triggered_player_ground_duel_success_pct` | Ground duel success percentage | Ground-contest efficiency context |
| `triggered_player_aerial_duels_won` | Aerial duels won by triggered player | Aerial-contest component context |
| `triggered_player_aerial_duel_attempts` | Aerial duel attempts by triggered player | Aerial-contest denominator |
| `triggered_player_aerial_duel_success_pct` | Aerial duel success percentage | Aerial-contest efficiency context |
| `triggered_player_duels_lost` | Duels lost by triggered player | Counterbalance for duel profile interpretation |
| `triggered_player_tackles_won` | Tackles won by triggered player | Additional defensive engagement context |
| `triggered_player_tackle_attempts` | Tackle attempts by triggered player | Tackle denominator context |
| `triggered_player_tackle_success_pct` | Tackle success percentage | Tackle efficiency context |
| `triggered_player_interceptions` | Interceptions by triggered player | Anticipation context |
| `triggered_player_clearances` | Clearances by triggered player | Pressure-release context |
| `triggered_player_defensive_actions` | Aggregate defensive actions | Defensive workload context |
| `triggered_player_recoveries` | Ball recoveries by triggered player | Regain-and-transition context |
| `triggered_player_dribbled_past` | Times dribbled past | Vulnerability counterbalance |
| `triggered_player_fouls_committed` | Fouls committed by triggered player | Discipline context |
| `triggered_player_touches` | Touches by triggered player | Involvement baseline |
| `triggered_player_total_passes` | Pass attempts by triggered player | Distribution-load context |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Distribution execution context |
| `triggered_player_pass_accuracy_pct` | Pass accuracy percentage by triggered player | Retention/composure context |
| `triggered_team_duels_won` | Team duels won by triggered side | Team physical-control baseline |
| `opponent_duels_won` | Team duels won by opponent side | Bilateral physical-control comparator |
| `triggered_team_ground_duels_won` | Team ground duels won by triggered side | Team ground-contest context |
| `opponent_ground_duels_won` | Team ground duels won by opponent side | Bilateral ground-contest comparator |
| `triggered_team_aerials_won` | Team aerial duels won by triggered side | Team aerial-contest context |
| `opponent_aerials_won` | Team aerial duels won by opponent side | Bilateral aerial-contest comparator |
| `triggered_team_tackles_won` | Team tackles won by triggered side | Team tackling context |
| `opponent_tackles_won` | Team tackles won by opponent side | Bilateral tackling comparator |
| `triggered_team_interceptions` | Team interceptions by triggered side | Team anticipation context |
| `opponent_interceptions` | Team interceptions by opponent side | Bilateral anticipation comparator |
| `triggered_team_clearances` | Team clearances by triggered side | Team pressure-release context |
| `opponent_clearances` | Team clearances by opponent side | Bilateral release comparator |
| `triggered_team_shot_blocks` | Team shot blocks by triggered side | Box-protection context |
| `opponent_shot_blocks` | Team shot blocks by opponent side | Bilateral box-protection comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Control-state context |
| `opponent_possession_pct` | Possession percentage of opponent side | Bilateral control comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy percentage of triggered side | Team execution context |
| `opponent_pass_accuracy_pct` | Pass accuracy percentage of opponent side | Bilateral execution comparator |
| `player_share_of_team_total_duels_won_pct` | Triggered player total duel wins as % of triggered-side team total duels won | Concentration metric for duel dominance attribution |
