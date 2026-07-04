---
signal_id: sig_player_possession_passing_recycling_specialist
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Recycling Specialist"
trigger: "midfielder records > 95% pass accuracy with > 95% non-final-third pass share (own-half recycling proxy)"
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_recycling_specialist
  sql: clickhouse/gold/dml/signals/player/sig_player_possession_passing_recycling_specialist.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_possession_passing_recycling_specialist

## Purpose

Triggers when a midfielder records elite pass retention from deep circulation zones, identifying defensive-midfield recycling specialists.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_pass_accuracy_pct > 95`
  - `triggered_player_non_final_third_pass_share_pct > 95`
  - `triggered_player_usual_playing_position_id = 2` (midfielder role scope)
- Current player schema does not expose direct own-half pass counts/accuracy by player, so this signal uses:
  - `triggered_player_non_final_third_passes_proxy = max(total_passes - passes_final_third, 0)`
  - `triggered_player_non_final_third_pass_share_pct = proxy / total_passes * 100`
- Midfielder role context comes from `silver.match_personnel` and is preserved via both `triggered_player_position_id` and `triggered_player_usual_playing_position_id`.
- Signal includes bilateral passing, possession, and team own-half pass context from `silver.period_stat` (`period = 'All'`) to separate individual deep recycling from team-wide style.
- Output explicitly stores both player identity (`triggered_player_*`) and triggered-team identity (`triggered_team_*`) for contract-compliant player signal traceability.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_possession_passing_recycling_specialist.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_possession_passing_recycling_specialist`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_possession_passing_recycling_specialist
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
| `home_score` | Home goals at full time | Football developer: outcome context for interpreting deep recycling usage |
| `away_score` | Away goals at full time | Football developer: outcome context for interpreting deep recycling usage |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for downstream aggregation |
| `triggered_player_id` | Triggered player ID | Football developer: primary player key for joins and modeling |
| `triggered_player_name` | Triggered player name | Football developer: human-readable signal explanation |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player signal to team-level tactical clusters |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution for reporting |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral context and matchup-based features |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `triggered_player_role_group` | Role label for triggered player (`defensive_midfielder`) | Football developer: explicit semantic label for downstream segmentation |
| `triggered_player_position_id` | Match-specific position ID from personnel data | Football developer: supports role diagnostics and QA for trigger scope |
| `triggered_player_usual_playing_position_id` | Broad role bucket from personnel data | Football developer: reproducible midfielder trigger scope (`= 2`) |
| `triggered_player_total_passes` | Total pass attempts by triggered player | Football developer: denominator and volume context for recycling profile |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Football developer: passing quality numerator for elite-retention profile |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy percentage | Football developer: direct trigger metric for completion quality (`> 95`) |
| `triggered_player_passes_final_third` | Triggered player passes into final third | Football developer: progression counterweight used in the deep-recycling proxy |
| `triggered_player_non_final_third_passes_proxy` | Non-final-third pass proxy (`max(total_passes - passes_final_third, 0)`) | Football developer: available-data proxy for own-half/deep circulation volume |
| `triggered_player_non_final_third_pass_share_pct` | Non-final-third pass share percentage | Football developer: direct trigger metric approximating own-half recycling (`> 95`) |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: reliability context to separate full-match behavior from short stints |
| `triggered_player_touches` | Total touches by triggered player | Football developer: involvement context for the recycling role |
| `triggered_player_defensive_actions` | Defensive actions by triggered player | Football developer: confirms defensive-phase involvement around passing profile |
| `triggered_player_recoveries` | Ball recoveries by triggered player | Football developer: regain context expected from deeper midfield roles |
| `triggered_team_pass_attempts` | Total pass attempts by triggered player's team | Football developer: team circulation baseline around player signal |
| `opponent_pass_attempts` | Total pass attempts by opponent team | Football developer: bilateral passing-volume context |
| `triggered_team_accurate_passes` | Accurate passes by triggered player's team | Football developer: team passing-quality baseline around the event |
| `opponent_accurate_passes` | Accurate passes by opponent team | Football developer: bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered player's team | Football developer: contextual passing-quality benchmark for recycling-heavy play |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent team | Football developer: bilateral passing-quality reference for matchup balance |
| `triggered_team_own_half_passes` | Team own-half pass count of triggered side | Football developer: team territorial retention context around player trigger |
| `opponent_own_half_passes` | Team own-half pass count of opponent side | Football developer: bilateral own-half circulation comparator |
| `triggered_team_own_half_pass_share_pct` | Triggered side own-half pass share percentage | Football developer: team-level territorial control profile around player event |
| `opponent_own_half_pass_share_pct` | Opponent own-half pass share percentage | Football developer: bilateral territorial style comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context for interpreting recycling volume |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral possession comparator |
| `player_share_of_team_passes_pct` | Triggered player pass attempts as % of team pass attempts | Football developer: quantifies whether recycling is concentrated in a single pivot |
