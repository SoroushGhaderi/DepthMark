---
signal_id: sig_player_goalkeeping_defense_unbeaten_in_air
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Unbeaten In Air"
trigger: "Player wins 100% of aerial duels with at least 5 attempts in a single finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_unbeaten_in_air
  sql: clickhouse/gold/signal/sig_player_goalkeeping_defense_unbeaten_in_air.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_goalkeeping_defense_unbeaten_in_air

## Purpose

Flags defender performances with perfect aerial-duel efficiency at meaningful volume
(`aerial_duels_won = aerial_duel_attempts` and `aerial_duel_attempts >= 5`) while preserving bilateral
duel, defensive-action, and control context.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_usual_playing_position_id = 1` (defender role gate)
  - `triggered_player_aerial_duel_attempts >= 5`
  - `triggered_player_aerial_duels_won = triggered_player_aerial_duel_attempts`
  - `is_goalkeeper = 0`
  - `match_finished = 1`
- Defender scope is sourced from `silver.match_personnel` (`usual_playing_position_id = 1`) and joined to
  `silver.player_match_stat` at `(match_id, player_id)` grain.
- Player diagnostics preserve aerial, ground-duel, tackle, interception, clearance, recovery, and passing
  context to separate true aerial perfection from narrow low-involvement cases.
- Bilateral team/opponent context is sourced from `silver.period_stat` (`period = 'All'`) using symmetric
  `triggered_team_*` and `opponent_*` aerial and defensive columns.
- Similarity gate note:
  - `sig_player_goalkeeping_defense_aerial_stronghold`: same defensive role family, but trigger is
    high aerial-win volume (`>= 10 wins`) rather than perfect efficiency.
  - `sig_player_possession_passing_target_man_aerials`: aerial focus overlap, but that signal targets
    forwards (`usual_playing_position_id = 3`) in possession/route-play context.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_goalkeeping_defense_unbeaten_in_air.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_unbeaten_in_air`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_goalkeeping_defense_unbeaten_in_air
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Football developer: stable join and deduplication key |
| `match_date` | Match date | Football developer: temporal slicing for trend/backfill analysis |
| `home_team_id` | Home team ID | Football developer: fixture-side context anchor |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixture-side context anchor |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Full-time home goals | Football developer: outcome context around aerial dominance |
| `away_score` | Full-time away goals | Football developer: outcome context around aerial dominance |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for downstream grouping |
| `triggered_player_id` | Triggered player ID | Football developer: player-grain identity key |
| `triggered_player_name` | Triggered player name | Football developer: readable signal attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player trigger to team context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup context |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_min_aerial_duel_attempts` | Minimum aerial attempts threshold (`5`) | Football developer: explicit trigger provenance for QA and auditability |
| `trigger_threshold_min_aerial_duel_success_pct` | Minimum aerial success threshold (`100`) | Football developer: explicit efficiency trigger boundary |
| `triggered_player_position_id` | Match-specific position ID | Football developer: deployment diagnostics |
| `triggered_player_usual_playing_position_id` | Usual position bucket used for defender gate | Football developer: role-filter traceability |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure reliability context |
| `triggered_player_aerial_duels_won` | Aerial duels won by triggered player | Football developer: numerator for perfect-aerial trigger |
| `triggered_player_aerial_duel_attempts` | Aerial duel attempts by triggered player | Football developer: denominator and minimum-volume guardrail |
| `triggered_player_aerial_duel_success_pct` | Aerial duel success percentage | Football developer: efficiency evidence for the trigger |
| `triggered_player_perfect_aerial_duel_flag` | Flag indicating perfect aerial record at trigger volume | Football developer: explicit boolean trigger-state marker |
| `triggered_player_duels_won` | Total duels won by triggered player | Football developer: broader physical-control context |
| `triggered_player_duels_lost` | Total duels lost by triggered player | Football developer: counterbalance for duel-profile interpretation |
| `triggered_player_ground_duels_won` | Ground duels won by triggered player | Football developer: non-aerial defensive profile context |
| `triggered_player_ground_duel_attempts` | Ground duel attempts by triggered player | Football developer: denominator for ground-duel interpretation |
| `triggered_player_ground_duel_success_pct` | Ground duel success percentage | Football developer: defensive-duel quality context beyond aerials |
| `triggered_player_tackles_won` | Tackles won by triggered player | Football developer: tackling effectiveness context |
| `triggered_player_tackle_attempts` | Tackle attempts by triggered player | Football developer: tackle-volume denominator context |
| `triggered_player_tackle_success_pct` | Tackle success percentage | Football developer: tackling efficiency diagnostic |
| `triggered_player_interceptions` | Interceptions by triggered player | Football developer: anticipation context alongside aerial dominance |
| `triggered_player_clearances` | Clearances by triggered player | Football developer: box-protection and pressure-release context |
| `triggered_player_defensive_actions` | Aggregate defensive actions by triggered player | Football developer: total defensive workload context |
| `triggered_player_recoveries` | Ball recoveries by triggered player | Football developer: regain-and-transition context |
| `triggered_player_dribbled_past` | Times dribbled past for triggered player | Football developer: vulnerability counterbalance for defensive profile |
| `triggered_player_touches` | Touches by triggered player | Football developer: involvement baseline |
| `triggered_player_total_passes` | Pass attempts by triggered player | Football developer: distribution-load context |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Football developer: distribution execution context |
| `triggered_player_pass_accuracy_pct` | Pass accuracy percentage by triggered player | Football developer: retention/composure context |
| `triggered_team_aerials_won` | Team aerial duels won by triggered side | Football developer: team aerial-control baseline |
| `opponent_aerials_won` | Team aerial duels won by opponent side | Football developer: bilateral aerial-control comparator |
| `triggered_team_aerial_attempts` | Team aerial attempts by triggered side | Football developer: side-level aerial-volume context |
| `opponent_aerial_attempts` | Team aerial attempts by opponent side | Football developer: bilateral aerial-volume comparator |
| `triggered_team_aerial_success_pct` | Triggered-side aerial success percentage | Football developer: team aerial efficiency context |
| `opponent_aerial_success_pct` | Opponent-side aerial success percentage | Football developer: bilateral efficiency comparator |
| `triggered_team_duels_won` | Team duels won by triggered side | Football developer: team physical-control baseline |
| `opponent_duels_won` | Team duels won by opponent side | Football developer: bilateral physical-control comparator |
| `triggered_team_interceptions` | Team interceptions by triggered side | Football developer: side-level anticipation context |
| `opponent_interceptions` | Team interceptions by opponent side | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Team clearances by triggered side | Football developer: defensive-pressure-release context |
| `opponent_clearances` | Team clearances by opponent side | Football developer: bilateral pressure-release comparator |
| `triggered_team_tackles_won` | Team tackles won by triggered side | Football developer: side-level tackling output context |
| `opponent_tackles_won` | Team tackles won by opponent side | Football developer: bilateral tackling comparator |
| `triggered_team_shot_blocks` | Team shot blocks by triggered side | Football developer: box-protection context |
| `opponent_shot_blocks` | Team shot blocks by opponent side | Football developer: bilateral box-protection comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control-state context around aerial-defense workload |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy percentage of triggered side | Football developer: side-level execution context |
| `opponent_pass_accuracy_pct` | Pass accuracy percentage of opponent side | Football developer: bilateral execution comparator |
| `player_share_of_team_aerials_won_pct` | Triggered player aerial wins as % of side aerial wins | Football developer: concentration metric for aerial dominance attribution |
