---
signal_id: sig_player_possession_passing_redundant_possession
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Redundant Possession"
trigger: "player records >= 80 total passes with 0 passes into the final third"
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_redundant_possession
  sql: clickhouse/gold/dml/signals/player/sig_player_possession_passing_redundant_possession.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_possession_passing_redundant_possession

## Purpose

Triggers when a player has high passing volume but no final-third progression, identifying redundant circulation profiles that keep possession without advancing attacking territory.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_total_passes >= 80`
  - `triggered_player_passes_final_third = 0`
- Current player schema does not expose directional backward/sideways pass tags per match row, so the signal uses:
  - `triggered_player_non_final_third_passes_proxy = max(total_passes - passes_final_third, 0)`
  - `triggered_player_non_final_third_pass_share_pct = proxy / total_passes * 100`
- Triggered player role context is preserved from `silver.match_personnel` via `triggered_player_position_id`, `triggered_player_usual_playing_position_id`, and a derived `triggered_player_role_group`.
- Signal includes bilateral team passing, own-half, opposition-half, and possession context from `silver.period_stat` (`period = 'All'`) so analysts can distinguish individual redundancy from team-level tactical design.
- Output stores both player identity (`triggered_player_*`) and triggered-team identity (`triggered_team_*`) for contract-compliant player traceability.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_possession_passing_redundant_possession.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_possession_passing_redundant_possession`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_possession_passing_redundant_possession
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: anchors joins across match, team, and player feature tables |
| `match_date` | Calendar date of match | Football developer: enables temporal splits and form-window studies |
| `home_team_id` | Home team ID | Football developer: stable bilateral match context key |
| `home_team_name` | Home team name | Football developer: readable home-context labeling |
| `away_team_id` | Away team ID | Football developer: stable bilateral match context key |
| `away_team_name` | Away team name | Football developer: readable away-context labeling |
| `home_score` | Home goals at full time | Football developer: scoreboard context around circulation behavior |
| `away_score` | Away goals at full time | Football developer: scoreboard context around circulation behavior |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical orientation for downstream grouping |
| `triggered_player_id` | Triggered player ID | Football developer: primary player entity key |
| `triggered_player_name` | Triggered player name | Football developer: human-readable signal explanation |
| `triggered_team_id` | Team ID of triggered player | Football developer: team attribution for player-level signal rows |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution for reports |
| `opponent_team_id` | Opponent team ID | Football developer: matchup context for tactical interpretation |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral matchup context |
| `triggered_player_role_group` | Derived broad role group (`defender`, `midfielder`, `forward`, `other`) | Football developer: supports segmentation of redundant passing by role profile |
| `triggered_player_position_id` | Match-specific position ID from personnel data | Football developer: role QA and positional diagnostics |
| `triggered_player_usual_playing_position_id` | Usual role bucket from personnel data | Football developer: stable role bucket for feature engineering |
| `triggered_player_total_passes` | Total pass attempts by triggered player | Football developer: core trigger volume threshold (`>= 80`) |
| `triggered_player_passes_final_third` | Passes into final third by triggered player | Football developer: direct progression trigger field (`= 0`) |
| `triggered_player_non_final_third_passes_proxy` | Non-final-third pass proxy (`max(total_passes - passes_final_third, 0)`) | Football developer: numerator for non-progressive circulation intensity |
| `triggered_player_non_final_third_pass_share_pct` | Non-final-third pass share percentage | Football developer: normalized signal strength for cross-player comparison |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Football developer: passing quality context around redundant circulation |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy percentage | Football developer: separates redundant but precise distribution from noisy recycling |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: sample reliability context for the trigger |
| `triggered_player_touches` | Total touches by triggered player | Football developer: involvement context beyond passing attempts |
| `triggered_team_pass_attempts` | Total pass attempts by triggered side | Football developer: team baseline for circulation environment |
| `opponent_pass_attempts` | Total pass attempts by opponent side | Football developer: bilateral passing-volume comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered side | Football developer: team passing-quality baseline |
| `opponent_accurate_passes` | Accurate passes by opponent side | Football developer: bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy percentage of triggered side | Football developer: team-level completion benchmark around the player event |
| `opponent_pass_accuracy_pct` | Pass accuracy percentage of opponent side | Football developer: bilateral completion benchmark for matchup balance |
| `triggered_team_own_half_passes` | Own-half passes by triggered side | Football developer: territorial retention context around the trigger |
| `opponent_own_half_passes` | Own-half passes by opponent side | Football developer: bilateral territorial retention comparator |
| `triggered_team_own_half_pass_share_pct` | Own-half pass share percentage of triggered side | Football developer: team tendency toward deeper circulation |
| `opponent_own_half_pass_share_pct` | Own-half pass share percentage of opponent side | Football developer: comparator for territorial style asymmetry |
| `triggered_team_opposition_half_passes` | Opposition-half passes by triggered side | Football developer: team progression context despite player non-progression |
| `opponent_opposition_half_passes` | Opposition-half passes by opponent side | Football developer: bilateral territorial progression benchmark |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control-state context for interpreting redundancy |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control-state comparator |
| `player_share_of_team_passes_pct` | Triggered player pass attempts as % of team pass attempts | Football developer: concentration of redundant circulation in one player |
