---
signal_id: sig_player_goalkeeping_defense_dribbled_past_heavy
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Dribbled Past Heavy"
trigger: "Player is bypassed/dribbled past >= 5 times in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_dribbled_past_heavy
  sql: clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_dribbled_past_heavy.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_goalkeeping_defense_dribbled_past_heavy

## Purpose

Flags players repeatedly bypassed in one-on-one actions (`dribbled past >= 5`) to surface high-vulnerability defensive performances for tactical and player-risk analysis.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_dribbled_past >= 5`
  - `is_goalkeeper = 0`
  - `match_finished = 1`
- Player role metadata is sourced from `silver.match_personnel` with starter-priority resolution, preserving role labels (`defender`, `midfielder`, `forward`, `other`) without restricting trigger scope.
- Player outputs come from `silver.player_match_stat` and retain duel, tackle, interception, recovery, clearance, and passing diagnostics to contextualize bypass volume.
- Bilateral team context is sourced from `silver.period_stat` (`period = 'All'`) with symmetric `triggered_team_*` and `opponent_*` metrics plus explicit deltas.
- Similarity gate note:
  - `sig_player_goalkeeping_defense_passive_defender`: same family/subfamily and includes `dribbled_past`, but trigger is zero proactive actions under low possession (`90 minutes`, `0 tackles`, `0 interceptions`, possession `<= 45%`), not high bypass volume.
  - `sig_player_goalkeeping_defense_defensive_double_double`: opposite defensive profile (high tackles/interceptions) whereas this signal captures vulnerability via repeated bypass events.
  - `sig_player_goalkeeping_defense_recovery_engine`: high defensive-activity profile (`recoveries >= 12`), while this signal focuses on defensive exposure risk.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_dribbled_past_heavy.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_dribbled_past_heavy`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_goalkeeping_defense_dribbled_past_heavy
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for joins and deduplication |
| `match_date` | Match date | Temporal slicing and trend analysis |
| `home_team_id` | Home team ID | Fixture context anchor |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team ID | Fixture context anchor |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Match-state context around defensive exposure |
| `away_score` | Away full-time goals | Match-state context around defensive exposure |
| `triggered_side` | Side of triggered player (`home`/`away`) | Canonical bilateral orientation |
| `triggered_player_id` | Triggered player ID | Player identity key |
| `triggered_player_name` | Triggered player name | Readable player attribution |
| `triggered_team_id` | Triggered player's team ID | Links player trigger to team context |
| `triggered_team_name` | Triggered player's team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `triggered_player_role_group` | Derived player role group | Role interpretability and QA |
| `triggered_player_position_id` | Match-specific position ID | Tactical deployment diagnostics |
| `triggered_player_usual_playing_position_id` | Usual playing position ID | Stable role metadata for profiling |
| `trigger_threshold_min_dribbled_past` | Dribbled-past threshold (`5`) | Explicit trigger boundary provenance |
| `triggered_player_dribbled_past` | Times triggered player was dribbled past | Core trigger metric |
| `triggered_player_dribbled_past_above_threshold` | Dribbled-past count above threshold | Trigger severity above minimum boundary |
| `triggered_player_duels_won` | Duels won by triggered player | Contest success context |
| `triggered_player_duels_lost` | Duels lost by triggered player | Contest failure context |
| `triggered_player_ground_duels_won` | Ground duels won by triggered player | Ground engagement context |
| `triggered_player_ground_duel_attempts` | Ground duel attempts by triggered player | Ground duel denominator context |
| `triggered_player_ground_duel_success_pct` | Ground duel success percentage | Ground duel efficiency diagnostic |
| `triggered_player_tackles_won` | Tackles won by triggered player | Defensive intervention context |
| `triggered_player_tackle_attempts` | Tackle attempts by triggered player | Tackling denominator context |
| `triggered_player_tackle_success_pct` | Tackle success percentage | Tackling efficiency diagnostic |
| `triggered_player_interceptions` | Interceptions by triggered player | Anticipation context around bypass events |
| `triggered_player_clearances` | Clearances by triggered player | Pressure-release context |
| `triggered_player_shot_blocks` | Shot blocks by triggered player | Box-protection context |
| `triggered_player_recoveries` | Recoveries by triggered player | Ball-regain context |
| `triggered_player_defensive_actions` | Defensive actions by triggered player | Composite defensive workload context |
| `triggered_player_fouls_committed` | Fouls committed by triggered player | Discipline trade-off context |
| `triggered_player_minutes_played` | Minutes played by triggered player | Exposure/reliability context |
| `triggered_player_touches` | Touches by triggered player | On-ball involvement baseline |
| `triggered_player_total_passes` | Pass attempts by triggered player | Distribution load context |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Distribution execution context |
| `triggered_player_pass_accuracy_pct` | Pass accuracy percentage | Retention quality context |
| `triggered_team_duels_won` | Team duels won by triggered side | Team contest baseline |
| `opponent_duels_won` | Team duels won by opponent side | Bilateral contest comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net contest differential |
| `triggered_team_ground_duels_won` | Team ground duels won by triggered side | Team ground-contest baseline |
| `opponent_ground_duels_won` | Team ground duels won by opponent side | Bilateral ground-contest comparator |
| `ground_duels_won_delta` | Triggered minus opponent ground duels won | Net ground-contest differential |
| `triggered_team_tackles_won` | Team tackles won by triggered side | Team tackling baseline |
| `opponent_tackles_won` | Team tackles won by opponent side | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net tackling differential |
| `triggered_team_interceptions` | Team interceptions by triggered side | Team anticipation baseline |
| `opponent_interceptions` | Team interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_clearances` | Team clearances by triggered side | Team pressure-release baseline |
| `opponent_clearances` | Team clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential |
| `triggered_team_shot_blocks` | Team shot blocks by triggered side | Team box-protection baseline |
| `opponent_shot_blocks` | Team shot blocks by opponent side | Bilateral box-protection comparator |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net shot-block differential |
| `triggered_team_fouls` | Team fouls by triggered side | Team discipline context |
| `opponent_fouls` | Team fouls by opponent side | Bilateral discipline comparator |
| `fouls_delta` | Triggered minus opponent fouls | Net discipline differential |
| `triggered_team_possession_pct` | Triggered-side possession percentage | Team control-state context |
| `opponent_possession_pct` | Opponent-side possession percentage | Bilateral control-state comparator |
| `possession_delta_pct` | Triggered minus opponent possession percentage | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy percentage | Team execution baseline |
| `opponent_pass_accuracy_pct` | Opponent-side pass accuracy percentage | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy percentage | Net circulation-execution differential |
| `triggered_player_duel_loss_share_pct` | Triggered player duel-loss share proxy (`duels_lost / (duels_won + duels_lost)`) | Personal contest-failure intensity context alongside dribbled-past trigger |
