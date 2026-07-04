---
signal_id: sig_player_possession_passing_midfield_general
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Midfield General"
trigger: "player records > 100 total touches in the middle third"
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_midfield_general
  sql: clickhouse/gold/dml/signals/player/sig_player_possession_passing_midfield_general.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_possession_passing_midfield_general

## Purpose

Triggers when a player records more than 100 touches in the middle third, identifying high-involvement midfield generals.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_middle_third_touches_proxy > 100`
- Because current player schema does not provide a direct `middle_third_touches` field, the signal uses:
  - `triggered_player_middle_third_touches_proxy = max(touches - touches_opp_box, 0)`
- Trigger uses player-level full-match totals from `silver.player_match_stat`.
- Signal includes bilateral team/opponent passing and possession context from `silver.period_stat` (`period = 'All'`) to separate individual central involvement from match-state effects.
- Output explicitly stores both player identity (`triggered_player_*`) and triggered-team identity (`triggered_team_*`) for contract-compliant player signal traceability.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_possession_passing_midfield_general.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_possession_passing_midfield_general`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_possession_passing_midfield_general
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
| `triggered_player_middle_third_touches_proxy` | Middle-third touch proxy (`max(touches - touches_opp_box, 0)`) | Football developer: core trigger metric proxy for central-zone involvement (`> 100`) |
| `triggered_player_total_touches` | Total touches by triggered player | Football developer: raw involvement denominator behind the proxy metric |
| `triggered_player_touches_opposition_box` | Triggered player touches in opponent box | Football developer: final-third component removed from proxy construction |
| `triggered_player_passes_final_third` | Triggered player passes into final third | Football developer: progression context to profile midfield role style |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Football developer: passing quality context around midfield control volume |
| `triggered_player_total_passes` | Total pass attempts by triggered player | Football developer: passing load context for controller profile |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy percentage | Football developer: efficiency context to balance volume and security |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: reliability context to separate full-match load from short stints |
| `triggered_team_pass_attempts` | Total pass attempts by triggered player's team | Football developer: team circulation baseline around player signal |
| `opponent_pass_attempts` | Total pass attempts by opponent team | Football developer: bilateral passing-volume context |
| `triggered_team_accurate_passes` | Accurate passes by triggered player's team | Football developer: team passing-quality baseline around the event |
| `opponent_accurate_passes` | Accurate passes by opponent team | Football developer: bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered player's team | Football developer: contextual passing quality benchmark for midfield influence |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent team | Football developer: bilateral passing-quality reference for matchup balance |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context for interpreting central involvement |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral possession comparator |
| `triggered_team_touches_opposition_box` | Opponent-box touches by triggered player's team | Football developer: territorial attacking context around midfield control |
| `opponent_touches_opposition_box` | Opponent-box touches by opponent team | Football developer: bilateral territorial context comparator |
| `player_share_of_team_passes_pct` | Triggered player pass attempts as % of team pass attempts | Football developer: quantifies player centrality in team circulation |
| `player_share_of_team_opposition_box_touches_pct` | Triggered player opponent-box touches as % of team opponent-box touches | Football developer: contrasts midfield control profile with final-third presence |
