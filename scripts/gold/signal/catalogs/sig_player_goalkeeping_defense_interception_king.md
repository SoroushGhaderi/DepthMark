---
signal_id: sig_player_goalkeeping_defense_interception_king
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Interception King"
trigger: "Player records at least 7 interceptions in a single finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_interception_king
  sql: clickhouse/gold/signal/sig_player_goalkeeping_defense_interception_king.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_goalkeeping_defense_interception_king

## Purpose

Flags defender performances with extreme interception volume (`>= 7`) and preserves bilateral defensive
and control context for anticipation-driven defensive profiling.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_interceptions >= 7`
  - `triggered_player_usual_playing_position_id = 1` (defender role gate)
  - `is_goalkeeper = 0`
  - `match_finished = 1`
- Player interception and defensive-action metrics are sourced from `silver.player_match_stat`.
- Defender scope is resolved from `silver.match_personnel` (`usual_playing_position_id = 1`) and joined at
  `(match_id, player_id)` grain.
- Bilateral team context is sourced from `silver.period_stat` (`period = 'All'`) with symmetric
  `triggered_team_*` and `opponent_*` fields for interceptions, tackles, clearances, shot blocks,
  duels, fouls, possession, and pass quality.
- Similarity gate note:
  - `sig_player_goalkeeping_defense_tackle_master`: close defensive-role overlap, but trigger logic differs
    (perfect-tackle efficiency vs interception volume).
  - `sig_player_goalkeeping_defense_aerial_stronghold`: close defensive-role overlap, but trigger logic differs
    (aerial-duel wins vs interception volume).

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_goalkeeping_defense_interception_king.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_interception_king`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_goalkeeping_defense_interception_king
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Football developer: stable key for deduplication and downstream joins |
| `match_date` | Match date | Football developer: temporal slicing for trend and window analysis |
| `home_team_id` | Home team ID | Football developer: fixture orientation context |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixture orientation context |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Full-time home goals | Football developer: outcome context around defensive anticipation profile |
| `away_score` | Full-time away goals | Football developer: outcome context around defensive anticipation profile |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for downstream grouping |
| `triggered_player_id` | Triggered player ID | Football developer: player-grain identity key |
| `triggered_player_name` | Triggered player name | Football developer: readable trigger attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: linkage from player trigger to team tactical context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup context |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `triggered_player_role_group` | Triggered role group label (`defender`) | Football developer: explicit role-scope provenance for QA |
| `triggered_player_position_id` | Match-specific position ID | Football developer: deployment diagnostics for role interpretation |
| `triggered_player_usual_playing_position_id` | Usual playing position ID | Football developer: deterministic role-gate traceability |
| `trigger_threshold_min_interceptions` | Trigger threshold for interceptions (`7`) | Football developer: explicit trigger boundary for reproducibility |
| `triggered_player_interceptions` | Interceptions by triggered player | Football developer: core trigger metric for anticipation dominance |
| `triggered_player_interceptions_above_threshold` | Interceptions above threshold (`interceptions - 7`) | Football developer: trigger severity beyond binary activation |
| `triggered_player_tackles_won` | Tackles won by triggered player | Football developer: defensive-action profile context beside interceptions |
| `triggered_player_tackle_attempts` | Tackle attempts by triggered player | Football developer: tackle-volume denominator context |
| `triggered_player_tackle_success_pct` | Tackle success percentage by triggered player | Football developer: efficiency context for defensive duels |
| `triggered_player_clearances` | Clearances by triggered player | Football developer: box-protection and pressure-release context |
| `triggered_player_defensive_actions` | Defensive actions by triggered player | Football developer: total defensive workload context |
| `triggered_player_recoveries` | Ball recoveries by triggered player | Football developer: transition-defense contribution context |
| `triggered_player_duels_won` | Duels won by triggered player | Football developer: physical-control context around anticipation output |
| `triggered_player_duels_lost` | Duels lost by triggered player | Football developer: counterbalance for duel-profile interpretation |
| `triggered_player_fouls_committed` | Fouls committed by triggered player | Football developer: discipline context around aggressive defending |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure reliability context |
| `triggered_player_touches` | Touches by triggered player | Football developer: involvement baseline |
| `triggered_player_total_passes` | Pass attempts by triggered player | Football developer: possession-role context around defensive profile |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Football developer: execution context for post-recovery circulation |
| `triggered_player_pass_accuracy_pct` | Pass accuracy percentage by triggered player | Football developer: composure and retention context after regains |
| `triggered_team_interceptions` | Team interceptions by triggered side | Football developer: team anticipation baseline for player-share interpretation |
| `opponent_interceptions` | Team interceptions by opponent side | Football developer: bilateral anticipation comparator |
| `interception_delta_vs_opponent_team` | Triggered-side interceptions minus opponent interceptions | Football developer: net anticipation edge around trigger context |
| `triggered_team_tackles_won` | Team tackles won by triggered side | Football developer: team defensive-intensity context |
| `opponent_tackles_won` | Team tackles won by opponent side | Football developer: bilateral defensive-intensity comparator |
| `triggered_team_clearances` | Team clearances by triggered side | Football developer: defensive pressure-release context |
| `opponent_clearances` | Team clearances by opponent side | Football developer: bilateral pressure-release comparator |
| `triggered_team_shot_blocks` | Team shot blocks by triggered side | Football developer: box-protection context around defensive anticipation |
| `opponent_shot_blocks` | Team shot blocks by opponent side | Football developer: bilateral box-protection comparator |
| `triggered_team_duels_won` | Team duels won by triggered side | Football developer: team physical-control baseline |
| `opponent_duels_won` | Team duels won by opponent side | Football developer: bilateral physical-control comparator |
| `triggered_team_fouls` | Team fouls by triggered side | Football developer: side-level discipline context |
| `opponent_fouls` | Team fouls by opponent side | Football developer: bilateral discipline comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control-state context for interpreting interception volume |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy percentage of triggered side | Football developer: execution context around regain-and-retain profile |
| `opponent_pass_accuracy_pct` | Pass accuracy percentage of opponent side | Football developer: bilateral execution comparator |
| `player_share_of_team_interceptions_pct` | Triggered player interceptions as % of triggered-side interceptions | Football developer: concentration of interception output in one player |
