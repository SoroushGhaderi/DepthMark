---
signal_id: sig_player_possession_passing_under_pressure_expert
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Under Pressure Expert"
trigger: "Player maintains >90% pass accuracy while under high defensive pressure."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_under_pressure_expert
  sql: clickhouse/gold/signal/sig_player_possession_passing_under_pressure_expert.sql
  runner: scripts/gold/signal/runners/sig_player_possession_passing_under_pressure_expert.py
---
# sig_player_possession_passing_under_pressure_expert

## Purpose

Flags players who keep elite pass accuracy under sustained opponent pressure, isolating high-composure passing performances in difficult game states.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_pass_accuracy_pct > 90`
- High defensive pressure is operationalized as opponent press-action intensity against the triggered player's team:
  - `opponent_press_actions >= 35`
  - `opponent_press_actions_per_100_triggered_passes >= 10.0`
- Press actions are computed as:
  - `interceptions + tackles_won + fouls`
- A pass-volume reliability guard is applied:
  - `triggered_player_total_passes >= 30`
- Team and opponent passing/territory/pressure metrics are included symmetrically (`triggered_team_*` and `opponent_*`) to separate true pressure resistance from low-tempo or low-load contexts.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_possession_passing_under_pressure_expert.sql`
- Runner: `scripts/gold/signal/runners/sig_player_possession_passing_under_pressure_expert.py`
- Target table: `gold_signals.sig_player_possession_passing_under_pressure_expert`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_possession_passing_under_pressure_expert.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for all downstream feature and narrative tables |
| `match_date` | Match calendar date | Football developer: enables temporal windows and trend analysis |
| `home_team_id` | Home team ID | Football developer: preserves bilateral match context |
| `home_team_name` | Home team name | Football developer: readable contextual labeling |
| `away_team_id` | Away team ID | Football developer: preserves bilateral match context |
| `away_team_name` | Away team name | Football developer: readable contextual labeling |
| `home_score` | Home full-time score | Football developer: outcome context for interpreting composure under pressure |
| `away_score` | Away full-time score | Football developer: outcome context for interpreting composure under pressure |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for aggregation |
| `triggered_player_id` | Triggered player ID | Football developer: primary player identity key |
| `triggered_player_name` | Triggered player name | Football developer: human-readable signal attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player behavior to team tactical environment |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: required matchup key for bilateral analysis |
| `opponent_team_name` | Opponent team name | Football developer: readable matchup attribution |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Football developer: numerator of elite passing composure under pressure |
| `triggered_player_total_passes` | Total passes attempted by triggered player | Football developer: denominator and reliability context for pass accuracy |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy percentage | Football developer: core trigger metric for under-pressure expertise |
| `triggered_player_pass_accuracy_above_threshold_pct` | Triggered player pass accuracy minus 90-point trigger threshold | Football developer: margin-above-threshold strength indicator for ranking |
| `triggered_player_passes_final_third` | Triggered player passes in final third | Football developer: territorial risk context for interpreting completion quality |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: controls for sample duration and substitution effects |
| `triggered_player_touches` | Total touches by triggered player | Football developer: involvement/load context around passing output |
| `triggered_player_was_fouled` | Fouls won by triggered player | Football developer: direct pressure-contact proxy at player level |
| `triggered_team_pass_attempts` | Pass attempts by triggered player's team | Football developer: team circulation volume baseline |
| `opponent_pass_attempts` | Pass attempts by opponent team | Football developer: bilateral passing-volume comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered player's team | Football developer: team completion baseline around player performance |
| `opponent_accurate_passes` | Accurate passes by opponent team | Football developer: bilateral completion comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered player's team | Football developer: contextual benchmark for player-vs-team composure |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent team | Football developer: bilateral technical-quality reference |
| `triggered_player_vs_team_pass_accuracy_delta_pct` | Triggered player pass accuracy minus triggered team pass accuracy | Football developer: isolates individual composure edge above team baseline |
| `triggered_team_own_half_passes` | Triggered team own-half passes | Football developer: pressure-environment build-up depth context |
| `opponent_own_half_passes` | Opponent own-half passes | Football developer: bilateral territorial circulation comparator |
| `triggered_team_own_half_pass_share_pct` | Triggered team own-half pass share percentage | Football developer: normalizes build-up depth by total passing volume |
| `opponent_own_half_pass_share_pct` | Opponent own-half pass share percentage | Football developer: bilateral normalized territory profile |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context for interpreting pressure resistance |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral possession comparator |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: pressure-action decomposition and symmetry |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: opponent pressure-action decomposition |
| `triggered_team_tackles_won` | Tackles won by triggered side | Football developer: pressure-action decomposition and symmetry |
| `opponent_tackles_won` | Tackles won by opponent side | Football developer: opponent pressure-action decomposition |
| `triggered_team_fouls` | Fouls committed by triggered side | Football developer: pressure-action decomposition and game-friction context |
| `opponent_fouls` | Fouls committed by opponent side | Football developer: opponent pressure-action decomposition and friction context |
| `triggered_team_press_actions` | Triggered team press actions (`interceptions + tackles_won + fouls`) | Football developer: symmetric pressure-intensity context around the trigger |
| `opponent_press_actions` | Opponent press actions (`interceptions + tackles_won + fouls`) | Football developer: core high-pressure gate component |
| `opponent_press_actions_per_100_triggered_passes` | Opponent press actions per 100 triggered-team pass attempts | Football developer: pace-normalized pressure intensity used in trigger logic |
| `press_actions_delta` | Opponent press actions minus triggered team press actions | Football developer: directional pressure advantage signal |
| `player_share_of_team_passes_pct` | Triggered player pass attempts as percentage of team pass attempts | Football developer: centrality and responsibility context for composure profile |
