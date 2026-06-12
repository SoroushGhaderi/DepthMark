---
signal_id: sig_player_possession_passing_overloaded_possession
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Overloaded Possession"
trigger: "player records > 120 touches in a single match"
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_overloaded_possession
  sql: clickhouse/gold/signal/sig_player_possession_passing_overloaded_possession.sql
  runner: scripts/gold/signal/runners/sig_player_possession_passing_overloaded_possession.py
---
# sig_player_possession_passing_overloaded_possession

## Purpose

Triggers when a player records more than 120 touches in a single match, identifying overloaded possession hubs with extreme on-ball involvement.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_total_touches > 120`
- Trigger uses player-level full-match totals from `silver.player_match_stat`.
- Signal includes bilateral team/opponent passing, possession, and opposition-box-touch context from `silver.period_stat` (`period = 'All'`) to separate individual overload from broader team game state.
- Output explicitly stores both player identity (`triggered_player_*`) and triggered-team identity (`triggered_team_*`) for contract-compliant player signal traceability.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_possession_passing_overloaded_possession.sql`
- Runner: `scripts/gold/signal/runners/sig_player_possession_passing_overloaded_possession.py`
- Target table: `gold_signals.sig_player_possession_passing_overloaded_possession`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_possession_passing_overloaded_possession.py
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
| `home_score` | Home goals at full time | Football developer: outcome context for interpreting overloaded possession behavior |
| `away_score` | Away goals at full time | Football developer: outcome context for interpreting overloaded possession behavior |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for downstream aggregation |
| `triggered_player_id` | Triggered player ID | Football developer: primary player key for joins and modeling |
| `triggered_player_name` | Triggered player name | Football developer: human-readable signal explanation |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player signal to team-level tactical clusters |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution for reporting |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral context and matchup-based features |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `triggered_player_total_touches` | Total touches by triggered player | Football developer: core trigger metric volume guard (`> 120`) |
| `triggered_player_touches_per90` | Triggered player touches normalized to 90 minutes | Football developer: normalizes overload intensity across unequal playing time |
| `triggered_player_touches_opposition_box` | Triggered player touches in opponent box | Football developer: territorial split between deep circulation and advanced involvement |
| `triggered_player_passes_final_third` | Triggered player passes into final third | Football developer: progression context to profile how overload volume is used |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Football developer: passing quality context around high-touch load |
| `triggered_player_total_passes` | Total pass attempts by triggered player | Football developer: passing-load context for overloaded possession role |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy percentage | Football developer: efficiency context to balance volume against retention quality |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: reliability context to separate full-match load from short stints |
| `triggered_team_pass_attempts` | Total pass attempts by triggered player's team | Football developer: team circulation baseline around player overload signal |
| `opponent_pass_attempts` | Total pass attempts by opponent team | Football developer: bilateral passing-volume context |
| `triggered_team_accurate_passes` | Accurate passes by triggered player's team | Football developer: team passing-quality baseline around the event |
| `opponent_accurate_passes` | Accurate passes by opponent team | Football developer: bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered player's team | Football developer: contextual passing-quality benchmark for overloaded possession interpretation |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent team | Football developer: bilateral passing-quality reference for matchup balance |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context for interpreting touch overload |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral possession comparator |
| `triggered_team_touches_opposition_box` | Opponent-box touches by triggered player's team | Football developer: territorial team context around player overload |
| `opponent_touches_opposition_box` | Opponent-box touches by opponent team | Football developer: bilateral territorial comparator |
| `player_share_of_team_passes_pct` | Triggered player pass attempts as % of team pass attempts | Football developer: quantifies whether possession load is concentrated in one player |
| `player_share_of_team_opposition_box_touches_pct` | Triggered player opponent-box touches as % of team opponent-box touches | Football developer: contrasts overall possession load with final-third attacking footprint |
