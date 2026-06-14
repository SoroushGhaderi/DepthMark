---
signal_id: sig_player_possession_passing_deep_playmaker
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Deep Playmaker"
trigger: "Center Back records >= 80 accurate passes."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_deep_playmaker
  sql: clickhouse/gold/dml/signals/player/sig_player_possession_passing_deep_playmaker.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_possession_passing_deep_playmaker

## Purpose

Triggers when a center back records at least 80 accurate passes, highlighting deep defensive distributors who dictate buildup volume.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_usual_playing_position_id = 1` (defender scope)
  - `triggered_player_position_id IN (3, 4)` (center-back proxy in lineup positions)
  - `triggered_player_accurate_passes >= 80`
- Uses `silver.player_match_stat` for player passing output and `silver.match_personnel` for positional gating.
- Adds bilateral team/opponent passing context from `silver.period_stat` (`period = 'All'`) so high center-back distribution can be interpreted against possession load and build-up style.
- Preserves player and team identity fields for contract-compliant downstream joins.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_possession_passing_deep_playmaker.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_possession_passing_deep_playmaker`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_possession_passing_deep_playmaker
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: primary join key across match/team/player signal assets |
| `match_date` | Match calendar date | Football developer: temporal ordering, backtests, and rolling windows |
| `home_team_id` | Home team ID | Football developer: fixture context and side orientation |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixture context and side orientation |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Full-time home goals | Football developer: outcome context for deep buildup interpretation |
| `away_score` | Full-time away goals | Football developer: outcome context for deep buildup interpretation |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical orientation for side-aware aggregation |
| `triggered_player_id` | Triggered player ID | Football developer: player-level feature identity key |
| `triggered_player_name` | Triggered player name | Football developer: human-readable attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player signal to team tactical profile |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup context |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_accurate_passes` | Numeric threshold used by trigger (`80`) | Football developer: explicit threshold provenance for QA and reproducibility |
| `triggered_player_role_group` | Role label for triggered player (`center_back`) | Football developer: semantic grouping for quick positional slicing |
| `triggered_player_position_id` | Match lineup position ID from personnel data | Football developer: enforces and audits center-back gating logic |
| `triggered_player_usual_playing_position_id` | Broad positional bucket from personnel data | Football developer: documents defender scope in trigger logic |
| `triggered_player_accurate_passes` | Accurate passes completed by triggered player | Football developer: core trigger metric and ranking value |
| `triggered_player_total_passes` | Total pass attempts by triggered player | Football developer: volume context and denominator for accuracy/share fields |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy (%) | Football developer: quality context on top of high accurate-pass volume |
| `triggered_player_passes_final_third` | Triggered player passes to final third | Football developer: progression context beyond deep circulation |
| `triggered_player_non_final_third_passes_proxy` | Proxy count of non-final-third passes | Football developer: characterizes deep recycling orientation |
| `triggered_player_non_final_third_pass_share_pct` | Share of triggered player passes outside final third (%) | Football developer: quantifies deep-distribution profile strength |
| `triggered_player_touches` | Triggered player total touches | Football developer: general involvement/load context |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: reliability context for raw volume interpretation |
| `triggered_team_pass_attempts` | Pass attempts by triggered player's team | Football developer: team passing load baseline |
| `opponent_pass_attempts` | Pass attempts by opponent team | Football developer: bilateral possession-tempo comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered player's team | Football developer: team completion baseline for player-share features |
| `opponent_accurate_passes` | Accurate passes by opponent team | Football developer: bilateral completion comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered side (%) | Football developer: team-level passing quality context |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent side (%) | Football developer: bilateral quality comparison |
| `triggered_team_own_half_passes` | Own-half passes by triggered side | Football developer: deep buildup territorial context |
| `opponent_own_half_passes` | Own-half passes by opponent side | Football developer: bilateral deep-buildup comparator |
| `triggered_team_own_half_pass_share_pct` | Share of triggered-team passes in own half (%) | Football developer: team buildup-depth profile feature |
| `opponent_own_half_pass_share_pct` | Share of opponent-team passes in own half (%) | Football developer: bilateral buildup-depth comparison |
| `triggered_team_possession_pct` | Possession share of triggered side (%) | Football developer: control context for high-volume center-back distribution |
| `opponent_possession_pct` | Possession share of opponent side (%) | Football developer: bilateral control comparator |
| `player_share_of_team_accurate_passes_pct` | Triggered player accurate passes as % of team accurate passes | Football developer: concentration metric for deep-playmaker centrality |
| `player_share_of_team_passes_pct` | Triggered player total passes as % of team pass attempts | Football developer: contribution share for team buildup dependency |
