---
signal_id: sig_player_possession_passing_keeper_distributor
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Keeper Distributor"
trigger: "Goalkeeper completes >= 25 short passes (proxied as accurate_passes - accurate_long_balls)."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_keeper_distributor
  sql: clickhouse/gold/signal/sig_player_possession_passing_keeper_distributor.sql
  runner: scripts/gold/signal/runners/sig_player_possession_passing_keeper_distributor.py
---
# sig_player_possession_passing_keeper_distributor

## Purpose

Triggers when a goalkeeper records high short-distribution completion volume (`>= 25`) in a finished match, surfacing keeper-led build-up control profiles.

## Tactical And Statistical Logic

- Trigger condition: `triggered_player_accurate_short_passes_proxy >= 25`.
- Because `silver.player_match_stat` does not expose direct short-pass completion fields, short passes are proxied as:
  - `triggered_player_accurate_short_passes_proxy = max(accurate_passes - accurate_long_balls, 0)`
  - `triggered_player_short_pass_attempts_proxy = max(total_passes - long_ball_attempts, 0)`
- The signal restricts scope to goalkeepers only (`is_goalkeeper = 1`) and enriches each row with symmetric team/opponent pass volume, pass accuracy, own-half pass volume, and possession context from `silver.period_stat` (`period = 'All'`).
- Output stores both triggered player identity and triggered team identity for contract-compliant player-grain traceability.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_possession_passing_keeper_distributor.sql`
- Runner: `scripts/gold/signal/runners/sig_player_possession_passing_keeper_distributor.py`
- Target table: `gold_signals.sig_player_possession_passing_keeper_distributor`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_possession_passing_keeper_distributor.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key across player, team, and match-grain features |
| `match_date` | Match calendar date | Football developer: enables temporal filtering and trend analysis |
| `home_team_id` | Home team ID | Football developer: fixture orientation context for bilateral metrics |
| `home_team_name` | Home team display name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixture orientation context for bilateral metrics |
| `away_team_name` | Away team display name | Football developer: readable fixture context |
| `home_score` | Full-time home goals | Football developer: outcome context around keeper passing behavior |
| `away_score` | Full-time away goals | Football developer: outcome context around keeper passing behavior |
| `triggered_side` | Side of triggered goalkeeper (`home` or `away`) | Football developer: canonical side orientation for downstream aggregation |
| `triggered_player_id` | Triggered goalkeeper player ID | Football developer: primary player identity key for model features |
| `triggered_player_name` | Triggered goalkeeper player name | Football developer: human-readable tactical interpretation |
| `triggered_team_id` | Team ID of triggered goalkeeper | Football developer: ties player signal to team tactical context |
| `triggered_team_name` | Team name of triggered goalkeeper | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral opponent context for matchup analysis |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_accurate_short_passes` | Trigger threshold for short-pass completions (`25`) | Football developer: explicit threshold provenance for QA and reproducibility |
| `triggered_player_accurate_short_passes_proxy` | Proxy short-pass completions (`max(accurate_passes - accurate_long_balls, 0)`) | Football developer: direct trigger value for keeper short-distribution load |
| `triggered_player_short_pass_attempts_proxy` | Proxy short-pass attempts (`max(total_passes - long_ball_attempts, 0)`) | Football developer: denominator for short-pass completion quality |
| `triggered_player_short_pass_accuracy_pct` | Proxy short-pass completion rate (%) | Football developer: separates high-volume short build-up from inefficient short circulation |
| `triggered_player_total_passes` | Total pass attempts by triggered goalkeeper | Football developer: passing involvement baseline around the trigger |
| `triggered_player_accurate_passes` | Total accurate passes by triggered goalkeeper | Football developer: quality context for total distribution profile |
| `triggered_player_accurate_long_balls` | Accurate long balls by triggered goalkeeper | Football developer: clarifies long-distribution share within passing mix |
| `triggered_player_long_ball_attempts` | Long-ball attempts by triggered goalkeeper | Football developer: distinguishes short-build-up profile from launch-heavy style |
| `triggered_player_minutes_played` | Minutes played by triggered goalkeeper | Football developer: reliability context for full-load versus partial-match events |
| `triggered_player_touches` | Total touches by triggered goalkeeper | Football developer: involvement context around passing centrality |
| `triggered_team_pass_attempts` | Pass attempts by triggered goalkeeper's team | Football developer: team circulation baseline and denominator for player share |
| `opponent_pass_attempts` | Pass attempts by opponent team | Football developer: bilateral passing-volume comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered goalkeeper's team | Football developer: team execution baseline around keeper distribution |
| `opponent_accurate_passes` | Accurate passes by opponent team | Football developer: bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy (%) of triggered side | Football developer: contextualizes keeper short-distribution within team quality |
| `opponent_pass_accuracy_pct` | Pass accuracy (%) of opponent side | Football developer: bilateral quality reference |
| `triggered_team_own_half_passes` | Own-half passes by triggered side | Football developer: build-up depth context for keeper-led circulation |
| `opponent_own_half_passes` | Own-half passes by opponent side | Football developer: bilateral build-up depth comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context for interpreting keeper distribution role |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
| `player_share_of_team_passes_pct` | Triggered goalkeeper pass attempts as % of team pass attempts | Football developer: quantifies how central the keeper is to team circulation |
| `player_share_of_team_accurate_passes_pct` | Triggered goalkeeper accurate passes as % of team accurate passes | Football developer: measures keeper contribution to team pass completion output |
| `triggered_player_short_pass_share_of_accurate_passes_pct` | Proxy short-pass completions as % of goalkeeper accurate passes | Football developer: exposes short-versus-long distribution mix for tactical profiling |
