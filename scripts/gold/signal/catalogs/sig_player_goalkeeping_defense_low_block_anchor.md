---
signal_id: sig_player_goalkeeping_defense_low_block_anchor
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Low-Block Anchor"
trigger: "Defender records >= 8 clearances and 0 fouls in a finished match with team possession < 35%."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_low_block_anchor
  sql: clickhouse/gold/signal/sig_player_goalkeeping_defense_low_block_anchor.sql
  runner: scripts/gold/signal/runners/sig_player_goalkeeping_defense_low_block_anchor.py
---
# sig_player_goalkeeping_defense_low_block_anchor

## Purpose

Flags defenders who anchor deep defensive phases by combining high clearance volume (`>= 8`) with clean
individual discipline (`0` fouls) while their team plays under low-possession stress (`< 35%`).

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_usual_playing_position_id = 1` (defender gate)
  - `triggered_player_clearances >= 8`
  - `triggered_player_fouls_committed = 0`
  - `triggered_team_possession_pct < 35.0`
  - `is_goalkeeper = 0`
  - `match_finished = 1`
- Defender scope is resolved from `silver.match_personnel` with starter-priority role resolution, then joined to
  `silver.player_match_stat`.
- Bilateral team context is sourced from `silver.period_stat` (`period = 'All'`) using symmetric
  `triggered_team_*` and `opponent_*` defensive/control fields with explicit deltas.
- Similarity gate note:
  - `sig_player_goalkeeping_defense_clearance_machine`: both are clearance-led defender signals, but this signal
    is stricter on discipline (`0` fouls) and contextualizes low-block pressure via possession `< 35%`.
  - `sig_player_goalkeeping_defense_no_fouls_defending`: both require zero fouls, but this signal is explicitly
    clearance-volume + low-possession anchored rather than tackle/duel-volume anchored.
  - `sig_player_goalkeeping_defense_passive_defender`: both use low-possession context, but passive-defender
    captures zero proactive actions while this signal captures high proactive clearance output.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_goalkeeping_defense_low_block_anchor.sql`
- Runner: `scripts/gold/signal/runners/sig_player_goalkeeping_defense_low_block_anchor.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_low_block_anchor`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_goalkeeping_defense_low_block_anchor.py
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
| `home_score` | Home full-time goals | Scoreline context for defensive workload interpretation |
| `away_score` | Away full-time goals | Scoreline context for defensive workload interpretation |
| `triggered_side` | Side of triggered defender (`home` or `away`) | Canonical bilateral orientation |
| `triggered_player_id` | Triggered defender ID | Durable player identity |
| `triggered_player_name` | Triggered defender name | Readable attribution |
| `triggered_team_id` | Triggered defender team ID | Player-team linkage |
| `triggered_team_name` | Triggered defender team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `triggered_player_role_group` | Role group label (`defender`) | Explicit role-scope provenance |
| `triggered_player_position_id` | Match-specific position ID | Deployment diagnostics |
| `triggered_player_usual_playing_position_id` | Usual playing position ID | Deterministic defender-gate traceability |
| `trigger_threshold_min_clearances` | Clearances threshold (`8`) | Explicit trigger-boundary provenance |
| `trigger_threshold_max_fouls_committed` | Foul ceiling (`0`) | Explicit clean-discipline boundary provenance |
| `trigger_threshold_max_possession_pct_exclusive` | Possession ceiling boundary (`< 35.0`) | Explicit low-block context boundary provenance |
| `triggered_player_clearances` | Clearances by triggered defender | Core trigger volume metric |
| `triggered_player_clearances_above_threshold` | Clearances above threshold (`clearances - 8`) | Trigger severity beyond binary activation |
| `triggered_player_fouls_committed` | Fouls committed by triggered defender | Core clean-discipline trigger metric |
| `triggered_player_interceptions` | Interceptions by triggered defender | Anticipation context around clearances |
| `triggered_player_shot_blocks` | Shot blocks by triggered defender | Box-protection context |
| `triggered_player_tackles_won` | Tackles won by triggered defender | Ground-defensive action context |
| `triggered_player_tackle_attempts` | Tackle attempts by triggered defender | Tackling denominator context |
| `triggered_player_tackle_success_pct` | Tackle success percentage | Tackling efficiency diagnostic |
| `triggered_player_duels_won` | Duels won by triggered defender | Physical-control context |
| `triggered_player_duels_lost` | Duels lost by triggered defender | Physical-balance context |
| `triggered_player_ground_duels_won` | Ground duels won by triggered defender | Ground-phase contest context |
| `triggered_player_ground_duel_attempts` | Ground duel attempts by triggered defender | Ground-phase denominator context |
| `triggered_player_ground_duel_success_pct` | Ground duel success percentage | Ground-phase efficiency context |
| `triggered_player_aerial_duels_won` | Aerial duels won by triggered defender | Aerial-control complement to clearances |
| `triggered_player_aerial_duel_attempts` | Aerial duel attempts by triggered defender | Aerial denominator context |
| `triggered_player_aerial_duel_success_pct` | Aerial duel success percentage | Aerial efficiency diagnostic |
| `triggered_player_recoveries` | Recoveries by triggered defender | Transition-regain context |
| `triggered_player_defensive_actions` | Aggregate defensive actions by triggered defender | Composite workload context |
| `triggered_player_dribbled_past` | Times dribbled past triggered defender | Vulnerability counterbalance |
| `triggered_player_minutes_played` | Minutes played by triggered defender | Exposure reliability context |
| `triggered_player_touches` | Touches by triggered defender | Involvement baseline |
| `triggered_player_total_passes` | Pass attempts by triggered defender | Distribution-load context |
| `triggered_player_accurate_passes` | Accurate passes by triggered defender | Distribution execution context |
| `triggered_player_pass_accuracy_pct` | Pass accuracy percentage | Retention/composure context under pressure |
| `triggered_team_clearances` | Team clearances by triggered side | Team pressure-release baseline |
| `opponent_clearances` | Team clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential |
| `triggered_team_interceptions` | Team interceptions by triggered side | Team anticipation baseline |
| `opponent_interceptions` | Team interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_shot_blocks` | Team shot blocks by triggered side | Team box-protection baseline |
| `opponent_shot_blocks` | Team shot blocks by opponent side | Bilateral box-protection comparator |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net shot-block differential |
| `triggered_team_tackles_won` | Team tackles won by triggered side | Team ball-winning baseline |
| `opponent_tackles_won` | Team tackles won by opponent side | Bilateral ball-winning comparator |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net ball-winning differential |
| `triggered_team_duels_won` | Team duels won by triggered side | Team physical-control baseline |
| `opponent_duels_won` | Team duels won by opponent side | Bilateral physical-control comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net physical-control differential |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive-pressure exposure context |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure-exposure comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net pressure-exposure differential |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Core low-block trigger context |
| `opponent_possession_pct` | Possession percentage of opponent side | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession percentage points | Net control-state differential |
| `triggered_team_pass_accuracy_pct` | Pass accuracy percentage of triggered side | Team circulation quality baseline |
| `opponent_pass_accuracy_pct` | Pass accuracy percentage of opponent side | Bilateral circulation quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy percentage points | Net circulation quality differential |
| `player_share_of_team_clearances_pct` | Triggered defender share of team clearances (%) | Concentration of low-block clearance burden in one player |
