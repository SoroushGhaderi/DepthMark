---
signal_id: sig_player_possession_passing_midfield_workhorse
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Midfield Workhorse"
trigger: "midfielder records >= 90 touches and >= 10 recoveries"
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_midfield_workhorse
  sql: clickhouse/gold/dml/signals/player/sig_player_possession_passing_midfield_workhorse.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_possession_passing_midfield_workhorse

## Purpose

Triggers when a midfielder combines high-volume on-ball involvement with strong ball-winning output, identifying true all-phase midfield workhorses.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_usual_playing_position_id = 2` (midfielder filter)
  - `triggered_player_total_touches >= 90`
  - `triggered_player_recoveries >= 10`
- Midfielder role scope is sourced from `silver.match_personnel` and preserved via `triggered_player_position_id` and `triggered_player_usual_playing_position_id`.
- Trigger uses full-match player totals from `silver.player_match_stat` for touches, recoveries, defensive actions, and passing output.
- Signal includes bilateral passing, own-half circulation, and possession context from `silver.period_stat` (`period = 'All'`) to separate individual workhorse behavior from team style.
- Output stores both player identity (`triggered_player_*`) and triggered-team identity (`triggered_team_*`) for contract-compliant player signal traceability.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_possession_passing_midfield_workhorse.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_possession_passing_midfield_workhorse`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_possession_passing_midfield_workhorse
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: anchors joins across match, team, and player feature tables |
| `match_date` | Calendar date of match | Football developer: enables temporal splits and trend windows |
| `home_team_id` | Home team ID | Football developer: stable match context key for bilateral orientation |
| `home_team_name` | Home team name | Football developer: readable home-side context |
| `away_team_id` | Away team ID | Football developer: stable match context key for bilateral orientation |
| `away_team_name` | Away team name | Football developer: readable away-side context |
| `home_score` | Home goals at full time | Football developer: match-state context for interpreting workload |
| `away_score` | Away goals at full time | Football developer: match-state context for interpreting workload |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical orientation for downstream aggregation |
| `triggered_player_id` | Triggered player ID | Football developer: primary player key for joins and modeling |
| `triggered_player_name` | Triggered player name | Football developer: human-readable signal explanation |
| `triggered_team_id` | Team ID of triggered player | Football developer: team attribution for player-level signal rows |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution for reporting |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup context |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral matchup context |
| `triggered_player_role_group` | Triggered player role label (`midfielder`) | Football developer: explicit semantic role scope |
| `triggered_player_position_id` | Match-specific position ID from personnel data | Football developer: role diagnostics and QA |
| `triggered_player_usual_playing_position_id` | Usual role bucket from personnel data | Football developer: reproducible midfielder filter field (`= 2`) |
| `triggered_player_total_touches` | Total touches by triggered player | Football developer: core involvement trigger metric (`>= 90`) |
| `triggered_player_recoveries` | Ball recoveries by triggered player | Football developer: core defensive-work-rate trigger metric (`>= 10`) |
| `triggered_player_defensive_actions` | Defensive actions by triggered player | Football developer: extra defensive workload context around recoveries |
| `triggered_player_passes_final_third` | Passes into final third by triggered player | Football developer: progression context alongside work-rate profile |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Football developer: passing quality context for midfield control profile |
| `triggered_player_total_passes` | Total pass attempts by triggered player | Football developer: passing load context linked to touch volume |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy percentage | Football developer: efficiency context balancing volume and security |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: reliability context for threshold interpretation |
| `triggered_team_pass_attempts` | Total pass attempts by triggered side | Football developer: team circulation baseline around player output |
| `opponent_pass_attempts` | Total pass attempts by opponent side | Football developer: bilateral passing-volume comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered side | Football developer: team passing-quality baseline |
| `opponent_accurate_passes` | Accurate passes by opponent side | Football developer: bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy percentage of triggered side | Football developer: team-level completion benchmark around the trigger |
| `opponent_pass_accuracy_pct` | Pass accuracy percentage of opponent side | Football developer: bilateral completion benchmark for matchup balance |
| `triggered_team_own_half_passes` | Own-half passes by triggered side | Football developer: territorial retention context for midfield workload |
| `opponent_own_half_passes` | Own-half passes by opponent side | Football developer: bilateral territorial retention comparator |
| `triggered_team_own_half_pass_share_pct` | Own-half pass share percentage of triggered side | Football developer: team style context for deep circulation burden |
| `opponent_own_half_pass_share_pct` | Own-half pass share percentage of opponent side | Football developer: style comparator for territorial asymmetry |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control-state context for workhorse interpretation |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control-state comparator |
| `player_share_of_team_passes_pct` | Triggered player pass attempts as % of team pass attempts | Football developer: concentration of circulation responsibility in one midfielder |
