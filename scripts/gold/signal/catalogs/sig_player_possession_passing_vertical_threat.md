---
signal_id: sig_player_possession_passing_vertical_threat
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Vertical Threat"
trigger: "player directs > 50% of successful passes forward, proxied by final-third passes divided by accurate passes"
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_vertical_threat
  sql: clickhouse/gold/dml/signals/player/sig_player_possession_passing_vertical_threat.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_possession_passing_vertical_threat

## Purpose

Triggers when more than 50% of a player's successful passes are directed forward, identifying players whose completed passing profile consistently creates vertical threat.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_forward_successful_pass_share_pct > 50`
- Because current player schema does not provide direct forward-pass direction counts, the signal uses:
  - `triggered_player_forward_successful_passes_proxy = min(max(passes_final_third, 0), accurate_passes)`
  - `triggered_player_forward_successful_pass_share_pct = proxy / accurate_passes * 100`
- Trigger uses player-level full-match totals from `silver.player_match_stat`.
- Signal includes bilateral team/opponent passing, possession, and opposition-half pass context from `silver.period_stat` (`period = 'All'`) to distinguish individual verticality from team-wide territorial dominance.
- Output explicitly stores both player identity (`triggered_player_*`) and triggered-team identity (`triggered_team_*`) for contract-compliant player signal traceability.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_possession_passing_vertical_threat.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_possession_passing_vertical_threat`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_possession_passing_vertical_threat
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
| `home_score` | Home goals at full time | Football developer: outcome context for interpreting vertical passing |
| `away_score` | Away goals at full time | Football developer: outcome context for interpreting vertical passing |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for downstream aggregation |
| `triggered_player_id` | Triggered player ID | Football developer: primary player key for joins and modeling |
| `triggered_player_name` | Triggered player name | Football developer: human-readable signal explanation |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player signal to team-level tactical clusters |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution for reporting |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral context and matchup-based features |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `triggered_player_forward_successful_passes_proxy` | Forward successful pass proxy, capped final-third passes | Football developer: core trigger numerator for vertical successful passing |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Football developer: denominator for successful forward-pass share |
| `triggered_player_forward_successful_pass_share_pct` | Proxy forward successful-pass share percentage | Football developer: direct signal value used for filtering and ranking (`> 50`) |
| `triggered_player_total_passes` | Total pass attempts by triggered player | Football developer: passing load context beyond successful-pass denominator |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy percentage | Football developer: separates verticality from completion quality |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: reliability context to separate full-match load from short stints |
| `triggered_player_touches` | Total touches by triggered player | Football developer: involvement context for interpreting vertical-passing centrality |
| `triggered_player_passes_final_third` | Triggered player passes into final third | Football developer: raw progression metric behind the forward-pass proxy |
| `triggered_player_chances_created` | Chances created by triggered player | Football developer: creative-output context for vertical passing threat |
| `triggered_player_expected_assists` | Expected assists by triggered player | Football developer: chance-quality context attached to vertical passing |
| `triggered_team_pass_attempts` | Total pass attempts by triggered player's team | Football developer: team circulation baseline around player signal |
| `opponent_pass_attempts` | Total pass attempts by opponent team | Football developer: bilateral passing-volume context |
| `triggered_team_accurate_passes` | Accurate passes by triggered player's team | Football developer: team passing-quality baseline around the event |
| `opponent_accurate_passes` | Accurate passes by opponent team | Football developer: bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered player's team | Football developer: contextual passing quality benchmark for verticality |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent team | Football developer: bilateral passing-quality reference for matchup balance |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context for interpreting vertical passing volume |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral possession comparator |
| `triggered_team_opposition_half_passes` | Passes in opponent half by triggered player's team | Football developer: team territorial progression context around player verticality |
| `opponent_opposition_half_passes` | Passes in opponent half by opponent team | Football developer: bilateral territorial progression comparator |
| `player_share_of_team_passes_pct` | Triggered player pass attempts as % of team pass attempts | Football developer: quantifies player centrality in team circulation |
