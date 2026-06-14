---
signal_id: sig_player_possession_passing_back_pass_heavy
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Back Pass Heavy"
trigger: "defender/midfielder records > 70% backward-or-sideways pass share, proxied by non-final-third passes"
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_back_pass_heavy
  sql: clickhouse/gold/dml/signals/player/sig_player_possession_passing_back_pass_heavy.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_possession_passing_back_pass_heavy

## Purpose

Triggers when a defender or midfielder has more than 70% of passes classified as backward/sideways recycling, identifying retention-heavy profiles that circulate possession more than they progress it.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_backward_sideways_pass_share_pct > 70`
  - `triggered_player_usual_playing_position_id IN (1, 2)` for defender/midfielder filtering
- Because current player schema does not provide direct backward-pass or sideways-pass counts, the signal uses:
  - `triggered_player_backward_sideways_passes_proxy = max(total_passes - passes_final_third, 0)`
  - `triggered_player_backward_sideways_pass_share_pct = proxy / total_passes * 100`
- Trigger uses player-level full-match totals from `silver.player_match_stat` and role context from `silver.match_personnel`.
- Signal includes bilateral team/opponent passing, possession, and opposition-half pass context from `silver.period_stat` (`period = 'All'`) to distinguish individual recycling from team-wide territorial style.
- Output explicitly stores both player identity (`triggered_player_*`) and triggered-team identity (`triggered_team_*`) for contract-compliant player signal traceability.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_possession_passing_back_pass_heavy.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_possession_passing_back_pass_heavy`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_possession_passing_back_pass_heavy
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
| `home_score` | Home goals at full time | Football developer: outcome context for interpreting conservative passing |
| `away_score` | Away goals at full time | Football developer: outcome context for interpreting conservative passing |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for downstream aggregation |
| `triggered_player_id` | Triggered player ID | Football developer: primary player key for joins and modeling |
| `triggered_player_name` | Triggered player name | Football developer: human-readable signal explanation |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player signal to team-level tactical clusters |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution for reporting |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral context and matchup-based features |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `triggered_player_role_group` | Defender or midfielder role group | Football developer: confirms positional scope of the trigger |
| `triggered_player_position_id` | Match-specific position ID from personnel data | Football developer: supports finer role analysis and QA of the positional filter |
| `triggered_player_usual_playing_position_id` | Usual role bucket used for defender/midfielder filtering | Football developer: direct trigger scope field for reproducible filtering |
| `triggered_player_backward_sideways_passes_proxy` | Non-final-third pass proxy (`max(total_passes - passes_final_third, 0)`) | Football developer: core trigger numerator for conservative/recycling passing |
| `triggered_player_total_passes` | Total pass attempts by triggered player | Football developer: denominator for the backward/sideways share |
| `triggered_player_passes_final_third` | Triggered player passes into final third | Football developer: progression counterweight used to derive the recycling proxy |
| `triggered_player_backward_sideways_pass_share_pct` | Proxy backward/sideways pass share percentage | Football developer: direct signal value used for filtering and ranking (`> 70`) |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Football developer: passing quality context around conservative distribution |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy percentage | Football developer: separates safe completion from inaccurate low-progression passing |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: reliability context to separate full-match load from short stints |
| `triggered_player_touches` | Total touches by triggered player | Football developer: involvement context for interpreting pass profile centrality |
| `triggered_team_pass_attempts` | Total pass attempts by triggered player's team | Football developer: team circulation baseline around player signal |
| `opponent_pass_attempts` | Total pass attempts by opponent team | Football developer: bilateral passing-volume context |
| `triggered_team_accurate_passes` | Accurate passes by triggered player's team | Football developer: team passing-quality baseline around the event |
| `opponent_accurate_passes` | Accurate passes by opponent team | Football developer: bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered player's team | Football developer: contextual passing quality benchmark for retention-heavy play |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent team | Football developer: bilateral passing-quality reference for matchup balance |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context for interpreting conservative passing volume |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral possession comparator |
| `triggered_team_opposition_half_passes` | Passes in opponent half by triggered player's team | Football developer: team territorial progression context around player recycling |
| `opponent_opposition_half_passes` | Passes in opponent half by opponent team | Football developer: bilateral territorial progression comparator |
| `player_share_of_team_passes_pct` | Triggered player pass attempts as % of team pass attempts | Football developer: quantifies player centrality in team circulation |
