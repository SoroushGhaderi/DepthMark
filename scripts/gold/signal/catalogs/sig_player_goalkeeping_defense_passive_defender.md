---
signal_id: sig_player_goalkeeping_defense_passive_defender
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Passive Defender"
trigger: "Defender plays exactly 90 minutes with 0 tackles won and 0 interceptions while team possession is <= 45%."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_passive_defender
  sql: clickhouse/gold/signal/sig_player_goalkeeping_defense_passive_defender.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_goalkeeping_defense_passive_defender

## Purpose

Flags full-match defender appearances with no tackles won and no interceptions under low-possession conditions, surfacing potentially passive out-of-possession profiles for tactical review.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_minutes_played = 90`
  - `triggered_player_tackles_won = 0`
  - `triggered_player_interceptions = 0`
  - `triggered_team_possession_pct <= 45.0`
  - `triggered_player_usual_playing_position_id = 1` (defender scope)
  - `is_goalkeeper = 0`
  - `match_finished = 1`
- Defender scope comes from `silver.match_personnel` with starter-priority position resolution per `(match_id, person_id)`.
- Player-level outputs come from `silver.player_match_stat`, retaining defensive workload diagnostics (clearances, blocks, duels, recoveries) so zero tackles/interceptions can be interpreted in context.
- Bilateral team context comes from `silver.period_stat` (`period = 'All'`) using symmetric `triggered_team_*` and `opponent_*` metrics with explicit deltas.
- Similarity gate note:
  - `sig_player_goalkeeping_defense_tackle_master`: same defender scope but opposite trigger intent (elite tackle output vs. zero tackles/interceptions under low possession).
  - `sig_player_goalkeeping_defense_interception_king`: same family/subfamily with interceptions focus, but this signal captures zero-interception outcomes instead of high-interception peaks.
  - `sig_player_goalkeeping_defense_recovery_engine`: same defensive context family, but recovery-engine detects high-activity profiles while this signal isolates low proactive-defensive activity.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_goalkeeping_defense_passive_defender.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_passive_defender`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_goalkeeping_defense_passive_defender
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable join key for downstream feature and scenario layers |
| `match_date` | Match date | Supports recency and time-window analysis |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Match-state context for interpreting defensive profiles |
| `away_score` | Away full-time goals | Match-state context for interpreting defensive profiles |
| `triggered_side` | Triggered player side (`home` or `away`) | Canonical side orientation for bilateral comparisons |
| `triggered_player_id` | Triggered player ID | Durable player-grain identity |
| `triggered_player_name` | Triggered player name | Readable player attribution |
| `triggered_team_id` | Team ID of triggered player | Connects player event to team context |
| `triggered_team_name` | Team name of triggered player | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup identity |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `triggered_player_role_group` | Role label for trigger scope (`defender`) | Makes role gating explicit for QA and audits |
| `triggered_player_position_id` | Match-specific position ID | Position deployment diagnostics |
| `triggered_player_usual_playing_position_id` | Usual playing position ID | Deterministic defender filter provenance |
| `trigger_threshold_exact_minutes_played` | Minutes trigger threshold (`90`) | Documents exact exposure requirement |
| `trigger_threshold_max_tackles_won` | Tackle-won trigger ceiling (`0`) | Documents zero-tackle condition |
| `trigger_threshold_max_interceptions` | Interception trigger ceiling (`0`) | Documents zero-interception condition |
| `trigger_threshold_max_possession_pct` | Possession trigger ceiling (`45.0`) | Documents low-possession stress condition |
| `triggered_player_minutes_played` | Minutes played by triggered defender | Confirms full-match eligibility |
| `triggered_player_tackles_won` | Tackles won by triggered defender | Core trigger metric |
| `triggered_player_tackle_attempts` | Tackle attempts by triggered defender | Distinguishes no-wins from attempted engagement |
| `triggered_player_tackle_success_pct` | Tackle success percentage | Efficiency context around tackle inactivity |
| `triggered_player_interceptions` | Interceptions by triggered defender | Core trigger metric |
| `triggered_player_clearances` | Clearances by triggered defender | Defensive emergency workload context |
| `triggered_player_shot_blocks` | Shot blocks by triggered defender | Box-protection context despite passive trigger metrics |
| `triggered_player_recoveries` | Recoveries by triggered defender | Ball-regain context outside tackles/interceptions |
| `triggered_player_defensive_actions` | Total defensive actions by triggered defender | Composite defensive workload context |
| `triggered_player_duels_won` | Duels won by triggered defender | Contest success context |
| `triggered_player_duels_lost` | Duels lost by triggered defender | Contest failure context |
| `triggered_player_dribbled_past` | Times triggered defender was dribbled past | Vulnerability context for low-intervention profiles |
| `triggered_player_fouls_committed` | Fouls committed by triggered defender | Discipline trade-off context |
| `triggered_player_touches` | Touches by triggered defender | On-ball involvement baseline |
| `triggered_player_total_passes` | Pass attempts by triggered defender | Circulation role context |
| `triggered_player_accurate_passes` | Accurate passes by triggered defender | Passing execution context |
| `triggered_player_pass_accuracy_pct` | Pass accuracy percentage | Ball-retention quality context |
| `triggered_team_tackles_won` | Team tackles won by triggered side | Team tackling baseline |
| `opponent_tackles_won` | Team tackles won by opponent side | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net tackling differential context |
| `triggered_team_interceptions` | Team interceptions by triggered side | Team anticipation baseline |
| `opponent_interceptions` | Team interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential context |
| `triggered_team_clearances` | Team clearances by triggered side | Team pressure-release baseline |
| `opponent_clearances` | Team clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential context |
| `triggered_team_shot_blocks` | Team shot blocks by triggered side | Team box-protection baseline |
| `opponent_shot_blocks` | Team shot blocks by opponent side | Bilateral box-protection comparator |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net shot-block differential context |
| `triggered_team_duels_won` | Team duels won by triggered side | Team contest-control baseline |
| `opponent_duels_won` | Team duels won by opponent side | Bilateral contest-control comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net duel-control differential context |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive pressure exposure context |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure exposure comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net pressure-exposure differential context |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Core low-possession trigger context |
| `opponent_possession_pct` | Possession percentage of opponent side | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession percentage | Net control-state differential context |
| `triggered_team_pass_accuracy_pct` | Pass accuracy percentage of triggered side | Team circulation quality baseline |
| `opponent_pass_accuracy_pct` | Pass accuracy percentage of opponent side | Bilateral circulation quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy percentage | Net circulation quality differential context |
