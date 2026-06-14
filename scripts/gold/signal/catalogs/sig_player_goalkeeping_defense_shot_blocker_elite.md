---
signal_id: sig_player_goalkeeping_defense_shot_blocker_elite
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Shot Blocker Elite"
trigger: "Defender blocks >= 4 shots in a single finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_shot_blocker_elite
  sql: clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_shot_blocker_elite.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_goalkeeping_defense_shot_blocker_elite

## Purpose

Flags defenders with elite match-level shot-block volume (`>= 4`), capturing front-foot box protection and preserving bilateral defensive-pressure context.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_usual_playing_position_id = 1` (defender role gate)
  - `triggered_player_shot_blocks >= 4`
  - `match_finished = 1`
- Defender scope is resolved from `silver.match_personnel` and joined to `silver.player_match_stat`.
- Player diagnostics retain clearances, interceptions, tackles, duel profiles, recoveries, defensive actions, and passing context to distinguish pure shot-block volume from broader defensive quality.
- Bilateral team context is sourced from `silver.period_stat` (`period = 'All'`) using symmetric `triggered_team_*` and `opponent_*` defensive and control metrics.
- Similarity gate note:
  - `sig_player_goalkeeping_defense_clearance_machine`: closest defensive-family overlap; this signal remains distinct because it triggers on blocked shots (`>= 4`) rather than clearances (`>= 15`).
  - `sig_player_shooting_goals_blocked_shot_frustration`: shares blocked-shot vocabulary but models attacker shot suppression (shots blocked against a shooter), while this signal models defender shot-block production.
  - `sig_player_goalkeeping_defense_tackle_master`: same family/subfamily but tackle-efficiency trigger, not shot-block volume.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_shot_blocker_elite.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_shot_blocker_elite`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_goalkeeping_defense_shot_blocker_elite
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable player-grain join key |
| `match_date` | Match date | Temporal slicing for trends and backfills |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Outcome context around defensive output |
| `away_score` | Away full-time goals | Outcome context around defensive output |
| `triggered_side` | Side of triggered defender (`home` or `away`) | Canonical side orientation |
| `triggered_player_id` | Triggered defender ID | Durable player identity |
| `triggered_player_name` | Triggered defender name | Readable attribution |
| `triggered_team_id` | Triggered defender team ID | Player-to-team linkage |
| `triggered_team_name` | Triggered defender team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `triggered_player_role_group` | Derived role label (`defender`) | Trigger-scope provenance for QA |
| `triggered_player_position_id` | Match-specific position ID | Positional diagnostics for interpretation |
| `triggered_player_usual_playing_position_id` | Usual position bucket used for defender gate | Reproducible role filter contract |
| `trigger_threshold_min_shot_blocks` | Trigger threshold (`4`) | Explicit trigger provenance and QA traceability |
| `triggered_player_shot_blocks` | Shot blocks by triggered defender | Core trigger metric |
| `triggered_player_shot_blocks_above_threshold` | Shot blocks above threshold (`shot_blocks - 4`) | Trigger severity ranking beyond binary activation |
| `triggered_player_clearances` | Clearances by triggered defender | Box-defense workload context |
| `triggered_player_interceptions` | Interceptions by triggered defender | Anticipation and reading-of-play context |
| `triggered_player_tackles_won` | Tackles won by triggered defender | Ball-winning context beyond shot blocks |
| `triggered_player_tackle_attempts` | Tackle attempts by triggered defender | Tackle denominator context |
| `triggered_player_tackle_success_pct` | Tackle success percentage | Defensive efficiency context |
| `triggered_player_duels_won` | Duels won by triggered defender | Physical-contest dominance context |
| `triggered_player_duels_lost` | Duels lost by triggered defender | Defensive balance context |
| `triggered_player_ground_duels_won` | Ground duels won by triggered defender | Ground-phase defensive profile context |
| `triggered_player_ground_duel_attempts` | Ground duel attempts by triggered defender | Ground-phase denominator context |
| `triggered_player_ground_duel_success_pct` | Ground duel success percentage | Ground-phase efficiency context |
| `triggered_player_aerial_duels_won` | Aerial duels won by triggered defender | Aerial-control context |
| `triggered_player_aerial_duel_attempts` | Aerial duel attempts by triggered defender | Aerial denominator context |
| `triggered_player_aerial_duel_success_pct` | Aerial duel success percentage | Aerial efficiency context |
| `triggered_player_recoveries` | Recoveries by triggered defender | Transition-defense contribution context |
| `triggered_player_defensive_actions` | Aggregate defensive actions by triggered defender | Composite defensive workload context |
| `triggered_player_fouls_committed` | Fouls committed by triggered defender | Discipline context around aggressive defending |
| `triggered_player_dribbled_past` | Times dribbled past | Defensive vulnerability counterbalance |
| `triggered_player_minutes_played` | Minutes played | Exposure context for comparing match outputs |
| `triggered_player_touches` | Touches by triggered defender | Involvement baseline context |
| `triggered_player_total_passes` | Pass attempts by triggered defender | Distribution-load context |
| `triggered_player_accurate_passes` | Accurate passes by triggered defender | Distribution execution context |
| `triggered_player_pass_accuracy_pct` | Pass accuracy percentage | Composure/retention context under pressure |
| `triggered_team_shot_blocks` | Team shot blocks by triggered side | Team-level shot-suppression baseline |
| `opponent_shot_blocks` | Team shot blocks by opponent side | Bilateral shot-suppression comparator |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net shot-suppression differential |
| `triggered_team_clearances` | Team clearances by triggered side | Team pressure-release context |
| `opponent_clearances` | Team clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential |
| `triggered_team_interceptions` | Team interceptions by triggered side | Team anticipation and pressing context |
| `opponent_interceptions` | Team interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_tackles_won` | Team tackles won by triggered side | Team ball-winning context |
| `opponent_tackles_won` | Team tackles won by opponent side | Bilateral ball-winning comparator |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net ball-winning differential |
| `triggered_team_duels_won` | Team duels won by triggered side | Team physical-control context |
| `opponent_duels_won` | Team duels won by opponent side | Bilateral physical-control comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net physical-control differential |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive-pressure volume context |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure-volume comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net pressure-volume differential |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Control-state context |
| `opponent_possession_pct` | Possession percentage of opponent side | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession percentage points | Net control differential |
| `triggered_team_pass_accuracy_pct` | Pass accuracy percentage of triggered side | Team execution context |
| `opponent_pass_accuracy_pct` | Pass accuracy percentage of opponent side | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy percentage points | Net execution differential |
| `player_share_of_team_shot_blocks_pct` | Triggered defender share of team shot blocks (%) | Concentration of shot-suppression burden in one player |
