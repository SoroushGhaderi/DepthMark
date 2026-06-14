---
signal_id: sig_player_goalkeeping_defense_high_line_trapper
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "High Line Trapper"
trigger: "Defender triggers at least 3 opponent offsides in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_high_line_trapper
  sql: clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_high_line_trapper.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_goalkeeping_defense_high_line_trapper

## Purpose

Flags defenders in matches where their team's defensive line repeatedly catches the opposition offside
(`opponent offsides caught >= 3`) and preserves player defensive profile plus bilateral team context.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_usual_playing_position_id = 1` (defender role gate)
  - `triggered_player_offsides_forced_proxy >= 3`
  - `is_goalkeeper = 0`
  - `match_finished = 1`
- Offside forcing is derived from `silver.period_stat` at team level (`period = 'All'`):
  - for home defenders: `offsides_away`
  - for away defenders: `offsides_home`
- Due current source-grain constraints, this signal uses a team-level proxy for per-defender offside forcing
  and emits one row per qualifying defender in the triggered team.
- Defender scope is sourced from `silver.match_personnel` (`usual_playing_position_id = 1`) and joined at
  `(match_id, player_id)` grain to `silver.player_match_stat`.
- Similarity gate note:
  - `sig_match_discipline_cards_stop_start_hell`: contains offside volume but models match-level whistle chaos.
  - `scenario_high_line_trap`: close tactical family at team grain; this signal is defender-attributed/player grain.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_high_line_trapper.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_high_line_trapper`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_goalkeeping_defense_high_line_trapper
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Football developer: stable join and deduplication key |
| `match_date` | Match date | Football developer: temporal slicing and window analysis |
| `home_team_id` | Home team ID | Football developer: fixture context anchor |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixture context anchor |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Full-time home goals | Football developer: outcome context for high-line behavior |
| `away_score` | Full-time away goals | Football developer: outcome context for high-line behavior |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation |
| `triggered_player_id` | Triggered defender ID | Football developer: player-grain identity key |
| `triggered_player_name` | Triggered defender name | Football developer: readable attribution |
| `triggered_team_id` | Team ID of triggered defender | Football developer: player-to-team linkage |
| `triggered_team_name` | Team name of triggered defender | Football developer: readable team linkage |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup context |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `triggered_player_role_group` | Role scope label (`defender`) | Football developer: explicit role-gate provenance |
| `triggered_player_position_id` | Match-specific position ID | Football developer: deployment diagnostics |
| `triggered_player_usual_playing_position_id` | Usual position bucket used for gating | Football developer: deterministic role filter traceability |
| `trigger_threshold_min_opponent_offsides_caught` | Trigger threshold (`3`) | Football developer: explicit trigger boundary |
| `triggered_player_offsides_forced_proxy` | Team-derived offside-trap count proxy attributed to triggered defender | Football developer: core trigger metric under available source granularity |
| `triggered_player_offsides_forced_above_threshold_proxy` | Proxy value above threshold (`proxy - 3`) | Football developer: trigger severity context |
| `triggered_player_minutes_played` | Minutes played by triggered defender | Football developer: exposure reliability context |
| `triggered_player_interceptions` | Interceptions by triggered defender | Football developer: anticipation context beside high-line trap events |
| `triggered_player_clearances` | Clearances by triggered defender | Football developer: pressure-release context |
| `triggered_player_tackles_won` | Tackles won by triggered defender | Football developer: duel-winning context |
| `triggered_player_tackle_attempts` | Tackle attempts by triggered defender | Football developer: tackle-volume denominator context |
| `triggered_player_tackle_success_pct` | Tackle success percentage by triggered defender | Football developer: tackling efficiency diagnostic |
| `triggered_player_recoveries` | Ball recoveries by triggered defender | Football developer: regain-and-reset context for high-line systems |
| `triggered_player_defensive_actions` | Aggregate defensive actions by triggered defender | Football developer: total defensive workload context |
| `triggered_player_duels_won` | Duels won by triggered defender | Football developer: physical-control context |
| `triggered_player_duels_lost` | Duels lost by triggered defender | Football developer: balance against duel wins |
| `triggered_player_aerial_duels_won` | Aerial duels won by triggered defender | Football developer: aerial profile context in advanced line play |
| `triggered_player_aerial_duel_attempts` | Aerial duel attempts by triggered defender | Football developer: aerial-volume denominator context |
| `triggered_player_aerial_duel_success_pct` | Aerial duel success percentage by triggered defender | Football developer: aerial efficiency diagnostic |
| `triggered_player_ground_duels_won` | Ground duels won by triggered defender | Football developer: defensive stance profile beyond aerial phase |
| `triggered_player_ground_duel_attempts` | Ground duel attempts by triggered defender | Football developer: ground-duel denominator context |
| `triggered_player_ground_duel_success_pct` | Ground duel success percentage by triggered defender | Football developer: ground-duel efficiency diagnostic |
| `triggered_player_dribbled_past` | Times dribbled past for triggered defender | Football developer: vulnerability counterbalance in high-line setups |
| `triggered_player_fouls_committed` | Fouls committed by triggered defender | Football developer: risk profile while defending aggressively |
| `triggered_player_touches` | Touches by triggered defender | Football developer: involvement baseline |
| `triggered_player_total_passes` | Pass attempts by triggered defender | Football developer: build-up contribution context |
| `triggered_player_accurate_passes` | Accurate passes by triggered defender | Football developer: execution context in circulation |
| `triggered_player_pass_accuracy_pct` | Pass accuracy percentage by triggered defender | Football developer: retention/composure context |
| `triggered_team_offsides_caught` | Opponent offsides drawn by triggered side | Football developer: side-level offside-trap output baseline |
| `opponent_offsides_caught` | Opponent side offsides drawn against triggered side | Football developer: bilateral offside-trap comparator |
| `offsides_caught_delta` | Triggered-side offsides caught minus opponent-side offsides caught | Football developer: net offside-trap edge |
| `triggered_team_offsides_committed` | Offsides committed by triggered side | Football developer: attacking timing cost context |
| `opponent_offsides_committed` | Offsides committed by opponent side | Football developer: bilateral attacking-timing comparator |
| `offsides_committed_delta` | Triggered-side offsides committed minus opponent offsides committed | Football developer: net timing-discipline comparator |
| `triggered_team_interceptions` | Team interceptions by triggered side | Football developer: side-level anticipation context |
| `opponent_interceptions` | Team interceptions by opponent side | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Team clearances by triggered side | Football developer: side-level pressure-release context |
| `opponent_clearances` | Team clearances by opponent side | Football developer: bilateral pressure-release comparator |
| `triggered_team_tackles_won` | Team tackles won by triggered side | Football developer: side-level tackling output context |
| `opponent_tackles_won` | Team tackles won by opponent side | Football developer: bilateral tackling comparator |
| `triggered_team_shot_blocks` | Team shot blocks by triggered side | Football developer: box-protection context |
| `opponent_shot_blocks` | Team shot blocks by opponent side | Football developer: bilateral box-protection comparator |
| `triggered_team_duels_won` | Team duels won by triggered side | Football developer: side-level physical-control context |
| `opponent_duels_won` | Team duels won by opponent side | Football developer: bilateral physical-control comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control-state context around high-line usage |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy percentage of triggered side | Football developer: side-level execution context |
| `opponent_pass_accuracy_pct` | Pass accuracy percentage of opponent side | Football developer: bilateral execution comparator |
