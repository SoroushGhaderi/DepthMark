---
signal_id: sig_player_possession_passing_impact_sub_passing
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Impact Sub Passing"
trigger: "Substituted player completes >15 passes in less than 20 minutes of play."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_impact_sub_passing
  sql: clickhouse/gold/dml/signals/player/sig_player_possession_passing_impact_sub_passing.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_possession_passing_impact_sub_passing

## Purpose

Identifies substitute appearances where a player contributes unusually high completed-pass volume in a short cameo window.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_accurate_passes > 15`
  - `triggered_player_minutes_played < 20`
- Substituted-player scope is enforced by joining `silver.match_personnel` with:
  - `role = 'substitute'`
- Reliability guard:
  - `triggered_player_minutes_played > 0`
- Signal enriches with bilateral passing, possession, and own-half pass-share context (`triggered_team_*` and `opponent_*`) to separate true tempo impact from overall team game state.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_possession_passing_impact_sub_passing.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_possession_passing_impact_sub_passing`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_possession_passing_impact_sub_passing
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: primary join key for downstream feature pipelines |
| `match_date` | Match date | Football developer: supports temporal analysis and recency filters |
| `home_team_id` | Home team ID | Football developer: bilateral match context key |
| `home_team_name` | Home team name | Football developer: readable context for analyst-facing outputs |
| `away_team_id` | Away team ID | Football developer: bilateral match context key |
| `away_team_name` | Away team name | Football developer: readable context for analyst-facing outputs |
| `home_score` | Home full-time goals | Football developer: score-state context for substitute impact interpretation |
| `away_score` | Away full-time goals | Football developer: score-state context for substitute impact interpretation |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical orientation field for aggregation |
| `triggered_player_id` | Triggered player ID | Football developer: stable player identity key |
| `triggered_player_name` | Triggered player name | Football developer: human-readable signal attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player cameo impact to team-level structures |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: matchup context key |
| `opponent_team_name` | Opponent team name | Football developer: readable matchup context |
| `triggered_player_substitution_time` | Substitution event minute for triggered player | Football developer: validates substitute entry context and cameo timing |
| `triggered_player_accurate_passes` | Completed passes by triggered player | Football developer: core trigger metric (`>15`) for high-impact substitute passing |
| `triggered_player_total_passes` | Total pass attempts by triggered player | Football developer: denominator for completion quality and risk profile |
| `triggered_player_pass_accuracy_pct` | Pass accuracy percentage of triggered player | Football developer: quality context around high-volume short-minute passing |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: core trigger metric (`<20`) and sample-size guardrail |
| `triggered_player_touches` | Total touches by triggered player | Football developer: involvement context for cameo impact |
| `triggered_player_passes_final_third` | Final-third passes by triggered player | Football developer: territorial aggression context in short-window impact |
| `triggered_player_accurate_passes_per_minute` | Completed passes per minute by triggered player | Football developer: normalizes cameo passing output by time played |
| `triggered_team_pass_attempts` | Pass attempts by triggered player's team | Football developer: team circulation baseline around the cameo |
| `opponent_pass_attempts` | Pass attempts by opponent team | Football developer: bilateral passing-volume comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered player's team | Football developer: team-level completion context |
| `opponent_accurate_passes` | Accurate passes by opponent team | Football developer: bilateral completion context |
| `triggered_team_pass_accuracy_pct` | Pass accuracy percentage of triggered player's team | Football developer: team passing benchmark for player-level interpretation |
| `opponent_pass_accuracy_pct` | Pass accuracy percentage of opponent team | Football developer: bilateral technical-level comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context around substitute contribution |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
| `triggered_team_own_half_passes` | Own-half passes by triggered side | Football developer: build-up depth context around cameo passing |
| `opponent_own_half_passes` | Own-half passes by opponent side | Football developer: bilateral depth comparator |
| `triggered_team_own_half_pass_share_pct` | Own-half pass share percentage of triggered side | Football developer: normalized territorial profile of triggered side |
| `opponent_own_half_pass_share_pct` | Own-half pass share percentage of opponent side | Football developer: normalized bilateral territorial comparator |
| `player_share_of_team_passes_pct` | Triggered player pass-attempt share of team attempts | Football developer: measures share of circulation responsibility in cameo window |
| `triggered_player_vs_team_pass_accuracy_delta_pct` | Triggered player pass accuracy minus triggered-team pass accuracy | Football developer: isolates individual passing quality relative to team baseline |
