---
signal_id: sig_player_possession_passing_cross_heavy
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Cross Heavy"
trigger: "player attempts > 12 crosses in a single match"
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_cross_heavy
  sql: clickhouse/gold/dml/signals/player/sig_player_possession_passing_cross_heavy.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_possession_passing_cross_heavy

## Purpose

Triggers when a player attempts more than 12 crosses in a single match, identifying cross-heavy service profiles.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_cross_attempts > 12`
- Trigger uses player-level full-match totals from `silver.player_match_stat`.
- Signal includes bilateral team/opponent cross and pass context from `silver.period_stat` (`period = 'All'`) to separate individual crossing volume from team-wide match dynamics.
- Output explicitly stores both player identity (`triggered_player_*`) and triggered-team identity (`triggered_team_*`) for contract-compliant player signal traceability.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_possession_passing_cross_heavy.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_possession_passing_cross_heavy`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_possession_passing_cross_heavy
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
| `triggered_player_cross_attempts` | Cross attempts by triggered player | Football developer: core trigger metric volume guard (`> 12`) |
| `triggered_player_accurate_crosses` | Accurate crosses completed by triggered player | Football developer: precision diagnostic around high crossing volume |
| `triggered_player_cross_success_rate_pct` | Triggered player cross success percentage | Football developer: quality context to distinguish efficient service from low-yield volume |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: reliability context to separate starters from short stints |
| `triggered_player_touches` | Total touches by triggered player | Football developer: involvement context to interpret role/load |
| `triggered_player_total_passes` | Total pass attempts by triggered player | Football developer: contextualizes crossing load versus overall passing usage |
| `triggered_team_cross_attempts` | Cross attempts by triggered player's team | Football developer: team-level wide-service baseline around player event |
| `opponent_cross_attempts` | Cross attempts by opponent team | Football developer: bilateral wide-service comparator |
| `triggered_team_accurate_crosses` | Accurate crosses by triggered player's team | Football developer: team-level crossing quality baseline |
| `opponent_accurate_crosses` | Accurate crosses by opponent team | Football developer: bilateral crossing-quality comparator |
| `triggered_team_cross_accuracy_pct` | Triggered team cross accuracy percentage | Football developer: indicates whether high player crossing volume aligns with team execution quality |
| `opponent_cross_accuracy_pct` | Opponent team cross accuracy percentage | Football developer: bilateral crossing-quality reference for matchup balance |
| `triggered_team_pass_attempts` | Total pass attempts by triggered player's team | Football developer: volume context for player share and tactical style |
| `opponent_pass_attempts` | Total pass attempts by opponent team | Football developer: bilateral passing-volume context |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered player's team | Football developer: passing-quality baseline around triggered player event |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent team | Football developer: bilateral passing-quality comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context for interpreting crossing volume |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral possession comparator |
| `player_share_of_team_crosses_pct` | Triggered player cross attempts as % of team cross attempts | Football developer: quantifies how central the player is to wide-service delivery |
| `player_share_of_team_passes_pct` | Triggered player pass attempts as % of team pass attempts | Football developer: balances crossing specialization against overall passing responsibility |
