---
signal_id: sig_player_goalkeeping_defense_recovery_engine
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Recovery Engine"
trigger: "Midfielder/Defender records >= 12 recoveries in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_recovery_engine
  sql: clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_recovery_engine.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_goalkeeping_defense_recovery_engine

## Purpose

Flags defender and midfielder performances with elite ball-recovery volume (`>= 12`) to capture players who repeatedly regain possession and stabilize defensive phases.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_recoveries >= 12`
  - `triggered_player_usual_playing_position_id IN (1, 2)` (defender or midfielder scope)
  - `is_goalkeeper = 0`
  - `match_finished = 1`
- Player role scope is resolved from `silver.match_personnel` with starter-priority position resolution per `(match_id, person_id)`.
- Player-level defensive diagnostics are sourced from `silver.player_match_stat`, including recoveries, tackles, duels, interceptions, clearances, and defensive actions.
- Bilateral team context is sourced from `silver.period_stat` (`period = 'All'`) with symmetric `triggered_team_*` and `opponent_*` metrics, plus explicit deltas.
- Similarity gate note:
  - `sig_player_goalkeeping_defense_interception_king`: same entity/family/subfamily and defensive profile context, but trigger metric is interceptions (`>= 7`) rather than recoveries.
  - `sig_player_goalkeeping_defense_clearance_machine`: same defensive package shape, but trigger metric is clearances (`>= 15`) and defender-only scope.
  - `sig_player_possession_passing_midfield_workhorse`: includes a recoveries threshold but requires very high touches and belongs to possession/passing; this signal focuses on pure defensive recovery output with bilateral defensive context.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_recovery_engine.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_recovery_engine`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_goalkeeping_defense_recovery_engine
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable join key for signal, scenario, and feature pipelines |
| `match_date` | Match date | Time-slicing and recency analysis |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Match-state context around defensive workload |
| `away_score` | Away full-time goals | Match-state context around defensive workload |
| `triggered_side` | Side of triggered player (`home` or `away`) | Canonical bilateral orientation key |
| `triggered_player_id` | Triggered player ID | Durable player-grain identity |
| `triggered_player_name` | Triggered player name | Readable player attribution |
| `triggered_team_id` | Triggered player's team ID | Links player signal to team context |
| `triggered_team_name` | Triggered player's team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `triggered_player_role_group` | Role label (`defender` or `midfielder`) | Explicit trigger-scope provenance |
| `triggered_player_position_id` | Match-specific position ID | Deployment diagnostics and QA |
| `triggered_player_usual_playing_position_id` | Usual playing position ID | Deterministic role filter traceability |
| `trigger_threshold_min_recoveries` | Trigger threshold (`12`) | Reproducible trigger boundary |
| `triggered_player_recoveries` | Recoveries by triggered player | Core trigger metric |
| `triggered_player_recoveries_above_threshold` | Recoveries above threshold (`recoveries - 12`) | Trigger severity beyond binary activation |
| `triggered_player_recoveries_per_90` | Recoveries per 90 minutes | Exposure-normalized recovery intensity |
| `triggered_player_defensive_actions` | Defensive actions by triggered player | Composite defensive load context |
| `triggered_player_interceptions` | Interceptions by triggered player | Anticipation context around recoveries |
| `triggered_player_clearances` | Clearances by triggered player | Pressure-release context |
| `triggered_player_shot_blocks` | Shot blocks by triggered player | Box-protection context |
| `triggered_player_tackles_won` | Tackles won by triggered player | Ground-duel execution context |
| `triggered_player_tackle_attempts` | Tackle attempts by triggered player | Tackling denominator context |
| `triggered_player_tackle_success_pct` | Tackle success percentage | Tackling efficiency diagnostic |
| `triggered_player_duels_won` | Duels won by triggered player | Physical-control context |
| `triggered_player_duels_lost` | Duels lost by triggered player | Physical-control counterbalance |
| `triggered_player_fouls_committed` | Fouls committed by triggered player | Discipline trade-off context |
| `triggered_player_dribbled_past` | Times triggered player was dribbled past | Defensive vulnerability counter-signal |
| `triggered_player_minutes_played` | Minutes played by triggered player | Exposure and reliability context |
| `triggered_player_touches` | Touches by triggered player | On-ball involvement baseline |
| `triggered_player_total_passes` | Pass attempts by triggered player | Circulation load context |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Passing execution context |
| `triggered_player_pass_accuracy_pct` | Pass accuracy percentage | Retention/composure context |
| `triggered_team_interceptions` | Interceptions by triggered side | Team anticipation baseline |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_clearances` | Clearances by triggered side | Team pressure-release baseline |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential |
| `triggered_team_tackles_won` | Tackles won by triggered side | Team tackling baseline |
| `opponent_tackles_won` | Tackles won by opponent side | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net tackling differential |
| `triggered_team_duels_won` | Duels won by triggered side | Team contest-control baseline |
| `opponent_duels_won` | Duels won by opponent side | Bilateral contest-control comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net contest-control differential |
| `triggered_team_fouls` | Fouls committed by triggered side | Team discipline context |
| `opponent_fouls` | Fouls committed by opponent side | Bilateral discipline comparator |
| `fouls_delta` | Triggered minus opponent fouls | Net discipline differential |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Control-state context |
| `opponent_possession_pct` | Possession percentage of opponent side | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession percentage | Net control differential |
| `triggered_team_pass_accuracy_pct` | Pass accuracy percentage of triggered side | Team execution baseline |
| `opponent_pass_accuracy_pct` | Pass accuracy percentage of opponent side | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy percentage | Net circulation-execution differential |
| `player_share_of_team_duels_won_pct` | Triggered player duels won as share of triggered-side duels won | Concentration of duel-winning responsibility |
