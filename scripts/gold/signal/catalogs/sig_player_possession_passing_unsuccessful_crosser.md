---
signal_id: sig_player_possession_passing_unsuccessful_crosser
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Unsuccessful Crosser"
trigger: "player attempts > 8 crosses with 0% crossing accuracy in a single match"
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_unsuccessful_crosser
  sql: clickhouse/gold/signal/sig_player_possession_passing_unsuccessful_crosser.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_possession_passing_unsuccessful_crosser

## Purpose

Triggers when a player attempts more than 8 crosses in a single match but records 0 accurate crosses, identifying high-volume unsuccessful crossing profiles.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_cross_attempts > 8`
  - `triggered_player_accurate_crosses = 0`
- Trigger uses player-level full-match totals from `silver.player_match_stat`.
- Signal includes bilateral team/opponent cross and pass context from `silver.period_stat` (`period = 'All'`) to separate individual crossing inefficiency from team-wide match dynamics.
- Output explicitly stores both player identity (`triggered_player_*`) and triggered-team identity (`triggered_team_*`) for contract-compliant player signal traceability.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_possession_passing_unsuccessful_crosser.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_possession_passing_unsuccessful_crosser`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_possession_passing_unsuccessful_crosser
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
| `home_score` | Home goals at full time | Football developer: outcome context for interpreting player behavior |
| `away_score` | Away goals at full time | Football developer: outcome context for interpreting player behavior |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for downstream aggregation |
| `triggered_player_id` | Triggered player ID | Football developer: primary player key for joins and modeling |
| `triggered_player_name` | Triggered player name | Football developer: human-readable signal explanation |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player signal to team-level tactical clusters |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution for reporting |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral context and matchup-based features |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `triggered_player_cross_attempts` | Cross attempts by triggered player | Football developer: core trigger volume guard (`> 8`) |
| `triggered_player_accurate_crosses` | Accurate crosses completed by triggered player | Football developer: core trigger quality guard (`= 0`) |
| `triggered_player_cross_success_rate_pct` | Triggered player cross success percentage | Football developer: explicit efficiency diagnostic for unsuccessful high-volume crossing |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: reliability context to separate starters from short stints |
| `triggered_player_touches` | Total touches by triggered player | Football developer: involvement context to interpret role/load |
| `triggered_player_total_passes` | Total pass attempts by triggered player | Football developer: contextualizes crossing load versus overall passing usage |
| `triggered_team_cross_attempts` | Cross attempts by triggered player's team | Football developer: team-level wide-service baseline around player event |
| `opponent_cross_attempts` | Cross attempts by opponent team | Football developer: bilateral wide-service comparator |
| `triggered_team_accurate_crosses` | Accurate crosses by triggered player's team | Football developer: team-level crossing quality baseline |
| `opponent_accurate_crosses` | Accurate crosses by opponent team | Football developer: bilateral crossing-quality comparator |
| `triggered_team_cross_accuracy_pct` | Triggered team cross accuracy percentage | Football developer: indicates whether the player's inefficiency is isolated or team-wide |
| `opponent_cross_accuracy_pct` | Opponent team cross accuracy percentage | Football developer: bilateral crossing-quality reference for matchup balance |
| `triggered_team_pass_attempts` | Total pass attempts by triggered player's team | Football developer: volume context for player share and tactical style |
| `opponent_pass_attempts` | Total pass attempts by opponent team | Football developer: bilateral passing-volume context |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered player's team | Football developer: passing-quality baseline around triggered player event |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent team | Football developer: bilateral passing-quality comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context for interpreting crossing inefficiency |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral possession comparator |
| `player_share_of_team_crosses_pct` | Triggered player cross attempts as % of team cross attempts | Football developer: quantifies how much failed crossing load is concentrated in one player |
| `player_share_of_team_passes_pct` | Triggered player pass attempts as % of team pass attempts | Football developer: balances crossing inefficiency against overall passing responsibility |
