---
signal_id: sig_player_goalkeeping_defense_sub_defensive_stability
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Sub Defensive Stability"
trigger: "Defensive substitute records >= 3 clearances and >= 2 tackles in < 15 minutes of play."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold.sig_player_goalkeeping_defense_sub_defensive_stability
  sql: clickhouse/gold/signal/sig_player_goalkeeping_defense_sub_defensive_stability.sql
  runner: scripts/gold/signal/runners/sig_player_goalkeeping_defense_sub_defensive_stability.py
---
# sig_player_goalkeeping_defense_sub_defensive_stability

## Purpose

Flags defender substitute cameos where short-minute players (`< 15` minutes) immediately provide defensive
stability through both clearance volume (`>= 3`) and tackle-winning output (`>= 2`).

## Tactical And Statistical Logic

- Trigger condition:
  - substitute scope: `role = 'substitute'` from `silver.match_personnel`
  - defender gate: `triggered_player_usual_playing_position_id = 1`
  - `triggered_player_minutes_played > 0`
  - `triggered_player_minutes_played < 15`
  - `triggered_player_clearances >= 3`
  - `triggered_player_tackles_won >= 2`
  - `is_goalkeeper = 0`
  - `match_finished = 1`
- Substitute-defender scope is resolved through a dedicated personnel CTE keyed on `(match_id, person_id)`, preserving substitution timing in output.
- Player diagnostics retain tackle, interception, duel, recovery, and passing context to distinguish stable cameo defending from noisy late-match events.
- Bilateral team context comes from `silver.period_stat` (`period = 'All'`) as symmetric `triggered_team_*` and `opponent_*` features with explicit deltas.
- Similarity gate note:
  - `sig_player_possession_passing_impact_sub_passing`: both are substitute cameo signals, but this signal is defender-only and defensive-output driven (clearances+tackles), not passing-volume driven.
  - `sig_player_goalkeeping_defense_clearance_machine`: both include clearance emphasis, but this signal focuses on short-minute substitutes with a lower threshold and additional tackle requirement.
  - `sig_player_goalkeeping_defense_tackle_master`: both include tackle quality/volume context, but this signal targets substitute cameo stabilization (`< 15` mins) instead of full-match elite tackle peaks.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_goalkeeping_defense_sub_defensive_stability.sql`
- Runner: `scripts/gold/signal/runners/sig_player_goalkeeping_defense_sub_defensive_stability.py`
- Target table: `gold.sig_player_goalkeeping_defense_sub_defensive_stability`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_goalkeeping_defense_sub_defensive_stability.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable player-grain join key |
| `match_date` | Match date | Temporal slicing and reproducible backfills |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Scoreline context for cameo defending interpretation |
| `away_score` | Away full-time goals | Scoreline context for cameo defending interpretation |
| `triggered_side` | Side of triggered substitute (`home` or `away`) | Canonical bilateral orientation |
| `triggered_player_id` | Triggered substitute player ID | Durable player identity |
| `triggered_player_name` | Triggered substitute player name | Readable attribution |
| `triggered_team_id` | Triggered player's team ID | Player-team linkage |
| `triggered_team_name` | Triggered player's team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `triggered_player_role_group` | Role group label (`defender`) | Explicit role-scope provenance |
| `triggered_player_position_id` | Match-specific position ID | Deployment diagnostics |
| `triggered_player_usual_playing_position_id` | Usual playing position ID | Deterministic defender gate traceability |
| `triggered_player_substitution_time` | Substitution minute from personnel records | Verifies substitute-entry context |
| `trigger_threshold_min_clearances` | Clearances threshold (`3`) | Explicit trigger-boundary provenance |
| `trigger_threshold_min_tackles_won` | Tackles-won threshold (`2`) | Explicit trigger-boundary provenance |
| `trigger_threshold_max_minutes_played_exclusive` | Maximum cameo minutes boundary (`< 15`) | Explicit short-window trigger provenance |
| `triggered_player_clearances` | Clearances by triggered substitute | Core trigger defensive-volume metric |
| `triggered_player_clearances_above_threshold` | Clearances above threshold (`clearances - 3`) | Trigger severity context beyond activation |
| `triggered_player_tackles_won` | Tackles won by triggered substitute | Core trigger ball-winning metric |
| `triggered_player_tackles_won_above_threshold` | Tackles won above threshold (`tackles_won - 2`) | Trigger severity context beyond activation |
| `triggered_player_minutes_played` | Minutes played by triggered substitute | Core cameo-window trigger metric |
| `triggered_player_interceptions` | Interceptions by triggered substitute | Anticipation context around cameo stability |
| `triggered_player_shot_blocks` | Shot blocks by triggered substitute | Box-protection context |
| `triggered_player_tackle_attempts` | Tackle attempts by triggered substitute | Tackling denominator context |
| `triggered_player_tackle_success_pct` | Tackle success percentage | Tackling efficiency diagnostic |
| `triggered_player_duels_won` | Duels won by triggered substitute | Physical-control context |
| `triggered_player_duels_lost` | Duels lost by triggered substitute | Physical-balance context |
| `triggered_player_recoveries` | Recoveries by triggered substitute | Transition-regain context |
| `triggered_player_defensive_actions` | Aggregate defensive actions by triggered substitute | Composite cameo workload context |
| `triggered_player_fouls_committed` | Fouls committed by triggered substitute | Discipline context |
| `triggered_player_dribbled_past` | Times dribbled past triggered substitute | Vulnerability counterbalance |
| `triggered_player_touches` | Touches by triggered substitute | Involvement baseline |
| `triggered_player_total_passes` | Pass attempts by triggered substitute | Distribution-load context |
| `triggered_player_accurate_passes` | Accurate passes by triggered substitute | Distribution execution context |
| `triggered_player_pass_accuracy_pct` | Pass accuracy percentage | Retention/composure context |
| `triggered_team_clearances` | Team clearances by triggered side | Team pressure-release baseline |
| `opponent_clearances` | Team clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential |
| `triggered_team_tackles_won` | Team tackles won by triggered side | Team ball-winning baseline |
| `opponent_tackles_won` | Team tackles won by opponent side | Bilateral ball-winning comparator |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net ball-winning differential |
| `triggered_team_interceptions` | Team interceptions by triggered side | Team anticipation baseline |
| `opponent_interceptions` | Team interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_shot_blocks` | Team shot blocks by triggered side | Team box-protection baseline |
| `opponent_shot_blocks` | Team shot blocks by opponent side | Bilateral box-protection comparator |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net shot-block differential |
| `triggered_team_duels_won` | Team duels won by triggered side | Team physical-control baseline |
| `opponent_duels_won` | Team duels won by opponent side | Bilateral physical-control comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net physical-control differential |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive-pressure exposure context |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure-exposure comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net pressure-exposure differential |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Control-state context |
| `opponent_possession_pct` | Possession percentage of opponent side | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession percentage points | Net control-state differential |
| `triggered_team_pass_accuracy_pct` | Pass accuracy percentage of triggered side | Team circulation-quality baseline |
| `opponent_pass_accuracy_pct` | Pass accuracy percentage of opponent side | Bilateral circulation-quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy percentage points | Net circulation-quality differential |
| `player_share_of_team_clearances_pct` | Triggered substitute share of team clearances (%) | Concentration of defensive-release burden in cameo window |
| `player_share_of_team_tackles_won_pct` | Triggered substitute share of team tackles won (%) | Concentration of ball-winning burden in cameo window |
