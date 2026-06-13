---
signal_id: sig_player_goalkeeping_defense_defensive_double_double
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Defensive Double Double"
trigger: "Player records >= 5 tackles and >= 5 interceptions in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_defensive_double_double
  sql: clickhouse/gold/signal/sig_player_goalkeeping_defense_defensive_double_double.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_goalkeeping_defense_defensive_double_double

## Purpose

Flags outfield players who deliver a dual defensive peak in both tackling and interception volume (`>= 5` each), surfacing high-impact all-around defensive disruption.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_tackles_won >= 5`
  - `triggered_player_interceptions >= 5`
  - `is_goalkeeper = 0`
  - `match_finished = 1`
- Player position metadata is resolved from `silver.match_personnel` (starter-priority role resolution) to retain interpretable role context (`defender`, `midfielder`, `forward`, `other`) without restricting trigger scope.
- Player diagnostics are sourced from `silver.player_match_stat`, combining tackle/interception core trigger metrics with defensive actions, duels, recoveries, and passing context.
- Bilateral team context is sourced from `silver.period_stat` (`period = 'All'`) with symmetric `triggered_team_*` and `opponent_*` fields plus explicit delta columns.
- Similarity gate note:
  - `sig_player_goalkeeping_defense_tackle_master`: overlaps on tackle volume but requires perfect tackle efficiency and defender-only scope; this signal uses dual-threshold volume logic and no role restriction beyond non-goalkeeper.
  - `sig_player_goalkeeping_defense_interception_king`: overlaps on interceptions but uses a higher single-metric threshold (`>= 7`) and defender-only scope; this signal requires both tackles and interceptions together.
  - `sig_player_goalkeeping_defense_recovery_engine`: adjacent defensive-intensity profile but trigger is recoveries (`>= 12`) rather than the tackles+interceptions double condition.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_goalkeeping_defense_defensive_double_double.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_defensive_double_double`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_goalkeeping_defense_defensive_double_double
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
| `home_score` | Home full-time goals | Match-state context for defensive output |
| `away_score` | Away full-time goals | Match-state context for defensive output |
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
| `trigger_threshold_min_tackles_won` | Tackle threshold (`5`) | Explicit trigger boundary provenance |
| `trigger_threshold_min_interceptions` | Interception threshold (`5`) | Explicit trigger boundary provenance |
| `triggered_player_tackles_won` | Tackles won by triggered player | Core trigger metric |
| `triggered_player_tackle_attempts` | Tackle attempts by triggered player | Tackling denominator context |
| `triggered_player_tackle_success_pct` | Tackle success percentage | Tackling efficiency diagnostic |
| `triggered_player_interceptions` | Interceptions by triggered player | Core trigger metric |
| `triggered_player_tackles_won_above_threshold` | Tackles won above threshold | Trigger intensity above minimum boundary |
| `triggered_player_interceptions_above_threshold` | Interceptions above threshold | Trigger intensity above minimum boundary |
| `triggered_player_defensive_actions` | Defensive actions by triggered player | Composite defensive workload context |
| `triggered_player_recoveries` | Recoveries by triggered player | Regain volume context beyond trigger |
| `triggered_player_clearances` | Clearances by triggered player | Pressure-release context |
| `triggered_player_shot_blocks` | Shot blocks by triggered player | Box-protection context |
| `triggered_player_duels_won` | Duels won by triggered player | Physical contest-control context |
| `triggered_player_duels_lost` | Duels lost by triggered player | Physical contest balance context |
| `triggered_player_fouls_committed` | Fouls committed by triggered player | Discipline trade-off context |
| `triggered_player_dribbled_past` | Times dribbled past | Defensive vulnerability counter-signal |
| `triggered_player_minutes_played` | Minutes played by triggered player | Exposure/reliability context |
| `triggered_player_touches` | Touches by triggered player | Involvement baseline |
| `triggered_player_total_passes` | Pass attempts by triggered player | Distribution load context |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Distribution execution context |
| `triggered_player_pass_accuracy_pct` | Pass accuracy percentage | Retention quality context |
| `triggered_team_tackles_won` | Team tackles won by triggered side | Team tackling baseline |
| `opponent_tackles_won` | Team tackles won by opponent side | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net tackling differential |
| `triggered_team_interceptions` | Team interceptions by triggered side | Team anticipation baseline |
| `opponent_interceptions` | Team interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_clearances` | Team clearances by triggered side | Team pressure-release baseline |
| `opponent_clearances` | Team clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential |
| `triggered_team_duels_won` | Team duels won by triggered side | Team contest-control baseline |
| `opponent_duels_won` | Team duels won by opponent side | Bilateral contest-control comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net contest differential |
| `triggered_team_fouls` | Team fouls by triggered side | Team discipline context |
| `opponent_fouls` | Team fouls by opponent side | Bilateral discipline comparator |
| `fouls_delta` | Triggered minus opponent fouls | Net discipline differential |
| `triggered_team_possession_pct` | Triggered-side possession percentage | Team control-state context |
| `opponent_possession_pct` | Opponent-side possession percentage | Bilateral control-state comparator |
| `possession_delta_pct` | Triggered minus opponent possession percentage | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy percentage | Team execution baseline |
| `opponent_pass_accuracy_pct` | Opponent-side pass accuracy percentage | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy percentage | Net circulation-execution differential |
| `player_share_of_team_tackles_won_pct` | Triggered player tackles won as share of triggered-side tackles won | Concentration of team tackling burden |
| `player_share_of_team_interceptions_pct` | Triggered player interceptions as share of triggered-side interceptions | Concentration of team anticipation burden |
