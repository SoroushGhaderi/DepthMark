---
signal_id: sig_player_possession_passing_safe_outlet
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Safe Outlet"
trigger: "player completes > 50 passes with 100% pass accuracy (accurate_passes = total_passes)"
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_safe_outlet
  sql: clickhouse/gold/dml/signals/player/sig_player_possession_passing_safe_outlet.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_possession_passing_safe_outlet

## Purpose

Triggers when a player attempts more than 50 passes and completes all of them (100% accuracy), identifying high-volume safe possession outlets.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_pass_attempts > 50`
  - `triggered_player_accurate_passes = triggered_player_pass_attempts`
- Trigger uses player-level full-match totals from `silver.player_match_stat`.
- Signal includes bilateral team/opponent pass and possession context from `silver.period_stat` (`period = 'All'`) to distinguish controlled buildup from low-tempo circulation.
- Output explicitly stores both player identity (`triggered_player_*`) and triggered-team identity (`triggered_team_*`) for contract-compliant player signal traceability.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_possession_passing_safe_outlet.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_possession_passing_safe_outlet`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_possession_passing_safe_outlet
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: anchors joins across match, team, and player feature tables |
| `match_date` | Calendar date of match | Football developer: enables temporal splits and trend windows |
| `home_team_id` | Home team ID | Football developer: stable match context key for bilateral orientation |
| `home_team_name` | Home team name | Football developer: readable opponent/context labeling |
| `away_team_id` | Away team ID | Football developer: stable match context key for bilateral orientation |
| `away_team_name` | Away team name | Football developer: readable opponent/context labeling |
| `home_score` | Home goals at full time | Football developer: outcome context for interpreting passing behavior |
| `away_score` | Away goals at full time | Football developer: outcome context for interpreting passing behavior |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for downstream aggregation |
| `triggered_player_id` | Triggered player ID | Football developer: primary player key for joins and modeling |
| `triggered_player_name` | Triggered player name | Football developer: human-readable signal explanation |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player signal to team-level tactical clusters |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution for reporting |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral context and matchup-based features |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `triggered_player_pass_attempts` | Total passes attempted by triggered player | Football developer: core trigger metric volume guard (`> 50`) |
| `triggered_player_accurate_passes` | Total accurate passes by triggered player | Football developer: core trigger metric numerator for perfect completion |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy percentage | Football developer: direct signal value (`100%`) for filtering and ranking |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: reliability context to separate starters from short stints |
| `triggered_player_touches` | Total touches by triggered player | Football developer: involvement context to interpret role/load |
| `triggered_player_passes_final_third` | Triggered player passes into final third | Football developer: progression context beyond pure retention |
| `triggered_team_pass_attempts` | Team pass attempts of triggered player's side | Football developer: denominator for player share and team style context |
| `opponent_pass_attempts` | Opponent team pass attempts | Football developer: bilateral tempo control context |
| `triggered_team_accurate_passes` | Accurate passes by triggered player's team | Football developer: team-level quality baseline around player event |
| `opponent_accurate_passes` | Accurate passes by opponent team | Football developer: bilateral quality comparator |
| `triggered_team_pass_accuracy_pct` | Team pass accuracy of triggered side | Football developer: reveals whether player-level perfection sits in overall clean circulation |
| `opponent_pass_accuracy_pct` | Opponent team pass accuracy | Football developer: bilateral quality reference for matchup balance |
| `triggered_team_possession_pct` | Triggered side possession percentage | Football developer: possession control context for interpreting pass volume |
| `opponent_possession_pct` | Opponent possession percentage | Football developer: bilateral possession comparator |
| `player_share_of_team_passes_pct` | Triggered player pass attempts as % of team pass attempts | Football developer: identifies whether player is a central safe outlet or peripheral recycler |
