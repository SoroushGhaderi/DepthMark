---
signal_id: sig_player_possession_passing_high_turnover_risk
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "High Turnover Risk"
trigger: "Player loses possession >25 times in a single match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_high_turnover_risk
  sql: clickhouse/gold/signal/sig_player_possession_passing_high_turnover_risk.sql
  runner: scripts/gold/signal/runners/sig_player_possession_passing_high_turnover_risk.py
---
# sig_player_possession_passing_high_turnover_risk

## Purpose

Triggers when a player loses possession more than 25 times in a single match, flagging high turnover-risk possession profiles.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_possession_losses > 25`
- Player possession losses are computed as:
  - `failed_passes + failed_dribbles + duels_lost`
  - where `failed_passes = max(total_passes - accurate_passes, 0)`
  - and `failed_dribbles = max(dribble_attempts - successful_dribbles, 0)`
- Trigger uses player-level full-match totals from `silver.player_match_stat`.
- Signal includes bilateral team/opponent passing, dribbling, and possession context from `silver.period_stat` (`period = 'All'`) to distinguish individual ball-security risk from overall match dynamics.
- Output explicitly stores both player identity (`triggered_player_*`) and triggered-team identity (`triggered_team_*`) for contract-compliant player signal traceability.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_possession_passing_high_turnover_risk.sql`
- Runner: `scripts/gold/signal/runners/sig_player_possession_passing_high_turnover_risk.py`
- Target table: `gold_signals.sig_player_possession_passing_high_turnover_risk`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_possession_passing_high_turnover_risk.py
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
| `triggered_player_possession_losses` | Estimated possession losses for triggered player (`failed_passes + failed_dribbles + duels_lost`) | Football developer: core trigger metric volume guard (`> 25`) |
| `triggered_player_failed_passes` | Triggered player failed passes | Football developer: diagnostic decomposition of turnover risk from passing errors |
| `triggered_player_failed_dribbles` | Triggered player failed dribbles | Football developer: diagnostic decomposition of turnover risk from carrying/1v1 losses |
| `triggered_player_duels_lost` | Triggered player duels lost | Football developer: diagnostic decomposition of turnover risk from physical contests |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Football developer: passing-quality context around turnover volume |
| `triggered_player_total_passes` | Total passes attempted by triggered player | Football developer: passing-load context to normalize error volume |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy percentage | Football developer: efficiency context to compare risk-taking vs retention |
| `triggered_player_successful_dribbles` | Successful dribbles by triggered player | Football developer: carrying output baseline against failed dribble losses |
| `triggered_player_dribble_attempts` | Dribble attempts by triggered player | Football developer: carrying-load context for turnover interpretation |
| `triggered_player_dribble_success_rate_pct` | Triggered player dribble success percentage | Football developer: dribbling efficiency context for ball-security profiling |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: reliability context to separate full-match load from short stints |
| `triggered_player_touches` | Total touches by triggered player | Football developer: involvement context to interpret role/load |
| `triggered_team_pass_attempts` | Total pass attempts by triggered player's team | Football developer: team possession-volume baseline around player event |
| `opponent_pass_attempts` | Total pass attempts by opponent team | Football developer: bilateral passing-volume context |
| `triggered_team_accurate_passes` | Accurate passes by triggered player's team | Football developer: team passing-quality baseline around turnover signal |
| `opponent_accurate_passes` | Accurate passes by opponent team | Football developer: bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered player's team | Football developer: contextual passing quality benchmark for player behavior |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent team | Football developer: bilateral passing-quality reference for matchup balance |
| `triggered_team_dribble_attempts` | Dribble attempts by triggered player's team | Football developer: team carrying-intent baseline around player turnover pattern |
| `opponent_dribble_attempts` | Dribble attempts by opponent team | Football developer: bilateral carrying-intent comparator |
| `triggered_team_successful_dribbles` | Successful dribbles by triggered player's team | Football developer: team carrying output context |
| `opponent_successful_dribbles` | Successful dribbles by opponent team | Football developer: bilateral carrying-output comparator |
| `triggered_team_dribble_success_pct` | Dribble success percentage of triggered side | Football developer: team-level ball-carry retention benchmark around the event |
| `opponent_dribble_success_pct` | Dribble success percentage of opponent side | Football developer: bilateral dribble-efficiency reference |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context for interpreting turnover volume |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral possession comparator |
| `player_share_of_team_passes_pct` | Triggered player pass attempts as % of team pass attempts | Football developer: quantifies centrality in team circulation relative to turnover load |
| `player_share_of_team_dribbles_pct` | Triggered player dribble attempts as % of team dribble attempts | Football developer: quantifies centrality in team carrying relative to turnover load |
