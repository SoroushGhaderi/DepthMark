---
signal_id: sig_player_goalkeeping_defense_brick_wall
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Brick Wall"
trigger: "Goalkeeper makes at least 8 saves in a single finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_brick_wall
  sql: clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_brick_wall.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_goalkeeping_defense_brick_wall

## Purpose

Flags goalkeeper performances with extreme save volume (`>= 8`) and keeps bilateral shot pressure plus
control context so analysts can separate elite shot-stopping from low-quality-volume shot environments.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_saves >= 8`
  - `is_goalkeeper = 1`
  - `match_finished = 1`
- Player save volume is derived from `silver.shot` at `(match_id, keeper_id)` grain:
  - save event: `is_on_target = 1` and `is_goal = 0`
  - shots on target faced: `is_on_target = 1`
  - goals conceded from on-target shots: `is_on_target = 1` and `is_goal = 1`
- Triggered goalkeeper identity is joined to `silver.player_match_stat` to preserve player/team context fields
  and enforce goalkeeper-only scope.
- Bilateral match context from `silver.period_stat` (`period = 'All'`) adds team/opponent saves,
  shots faced, expected goals faced, possession, and pass-accuracy context for pressure interpretation.
- Output keeps both `triggered_player_*` and `triggered_team_*` fields for player-grain traceability
  and downstream feature compatibility.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_brick_wall.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_brick_wall`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_goalkeeping_defense_brick_wall
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key across match, player, and model feature sets |
| `match_date` | Match date | Football developer: supports trend windows and temporal cohorting |
| `home_team_id` | Home team ID | Football developer: fixture orientation baseline |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixture orientation baseline |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Full-time home goals | Football developer: outcome context around high-save performances |
| `away_score` | Full-time away goals | Football developer: outcome context around high-save performances |
| `triggered_side` | Side of triggered goalkeeper (`home` or `away`) | Football developer: canonical side orientation for downstream aggregation |
| `triggered_player_id` | Triggered goalkeeper player ID | Football developer: primary player identity key |
| `triggered_player_name` | Triggered goalkeeper name | Football developer: readable signal attribution |
| `triggered_team_id` | Team ID of triggered goalkeeper | Football developer: ties player signal to team tactical context |
| `triggered_team_name` | Team name of triggered goalkeeper | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup context |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_keeper_saves` | Trigger threshold for saves (`8`) | Football developer: explicit threshold provenance for QA and audits |
| `triggered_player_saves` | Saved on-target shots by triggered goalkeeper | Football developer: primary trigger metric for elite shot-stopping volume |
| `triggered_player_shots_on_target_faced` | On-target shots faced by triggered goalkeeper | Football developer: denominator context for save-rate interpretation |
| `triggered_player_goals_conceded` | Goals conceded from on-target shots faced | Football developer: outcome severity context around high save loads |
| `triggered_player_save_rate_pct` | Save rate from on-target shots faced (%) | Football developer: quality context so high volume is not interpreted without efficiency |
| `triggered_player_minutes_played` | Minutes played by triggered goalkeeper | Football developer: exposure reliability context |
| `triggered_player_touches` | Touches by triggered goalkeeper | Football developer: involvement context beyond direct save events |
| `triggered_player_total_passes` | Pass attempts by triggered goalkeeper | Football developer: distribution-load context around defensive pressure |
| `triggered_player_accurate_passes` | Accurate passes by triggered goalkeeper | Football developer: execution context for distribution under pressure |
| `triggered_player_pass_accuracy_pct` | Pass accuracy of triggered goalkeeper (%) | Football developer: composure indicator during high defensive workload |
| `triggered_team_keeper_saves` | Team keeper saves for triggered side | Football developer: team-level consistency check against player-derived save events |
| `opponent_keeper_saves` | Team keeper saves for opponent side | Football developer: bilateral goalkeeper-workload comparator |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Football developer: pressure volume baseline beyond on-target events |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Football developer: bilateral pressure comparator |
| `triggered_team_shots_on_target_faced` | On-target shots faced by triggered side | Football developer: team-level on-target pressure baseline |
| `opponent_shots_on_target_faced` | On-target shots faced by opponent side | Football developer: bilateral on-target pressure comparator |
| `triggered_team_expected_goals_faced` | Expected goals generated by opponent against triggered side | Football developer: chance-quality-against context behind save volume |
| `opponent_expected_goals_faced` | Expected goals generated by triggered side against opponent | Football developer: bilateral chance-quality comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control-state context for interpreting defensive siege patterns |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered side (%) | Football developer: team execution context under pressure |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent side (%) | Football developer: bilateral execution comparator |
| `saves_share_of_triggered_team_keeper_saves_pct` | Triggered goalkeeper saves as % of triggered-side keeper saves | Football developer: validates concentration and identity consistency of save output |
| `save_volume_delta_vs_opponent_keeper` | Triggered goalkeeper saves minus opponent-side keeper saves | Football developer: net keeper workload differential for comparative profiling |
