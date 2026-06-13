---
signal_id: sig_player_possession_passing_long_ball_specialist
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Long Ball Specialist"
trigger: "player completes > 8 accurate long balls with > 80% long-ball success rate"
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_long_ball_specialist
  sql: clickhouse/gold/signal/sig_player_possession_passing_long_ball_specialist.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_possession_passing_long_ball_specialist

## Purpose

Triggers when a player completes more than 8 accurate long balls with more than 80% long-ball success rate, identifying high-precision long-ball specialists.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_accurate_long_balls > 8`
  - `triggered_player_long_ball_success_rate_pct > 80`
- Trigger is computed from player-level full-match passing totals in `silver.player_match_stat`.
- Signal includes bilateral team/opponent long-ball and pass-quality context from `silver.period_stat` (`period = 'All'`) to distinguish isolated player quality from broader team directness.
- Output explicitly stores both player identity (`triggered_player_*`) and triggered-team identity (`triggered_team_*`) for contract-compliant player signal traceability.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_possession_passing_long_ball_specialist.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_possession_passing_long_ball_specialist`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_possession_passing_long_ball_specialist
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
| `triggered_player_long_ball_attempts` | Long-ball attempts by triggered player | Football developer: trigger denominator and directness volume context |
| `triggered_player_accurate_long_balls` | Accurate long balls completed by triggered player | Football developer: core trigger metric volume guard (`> 8`) |
| `triggered_player_long_ball_success_rate_pct` | Triggered player long-ball success percentage | Football developer: core trigger metric precision guard (`> 80%`) |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: reliability context to separate starters from short stints |
| `triggered_player_touches` | Total touches by triggered player | Football developer: involvement context to interpret role/load |
| `triggered_player_total_passes` | Total pass attempts by triggered player | Football developer: contextualizes long-ball profile versus total passing load |
| `triggered_team_long_ball_attempts` | Long-ball attempts by triggered player's team | Football developer: team-level directness baseline around player event |
| `opponent_long_ball_attempts` | Long-ball attempts by opponent team | Football developer: bilateral directness comparator |
| `triggered_team_accurate_long_balls` | Accurate long balls by triggered player's team | Football developer: team-level long-ball quality baseline |
| `opponent_accurate_long_balls` | Accurate long balls by opponent team | Football developer: bilateral long-ball quality comparator |
| `triggered_team_long_ball_accuracy_pct` | Triggered team long-ball accuracy percentage | Football developer: indicates whether player precision reflects a team-wide direct-play pattern |
| `opponent_long_ball_accuracy_pct` | Opponent team long-ball accuracy percentage | Football developer: bilateral precision reference for matchup balance |
| `triggered_team_pass_attempts` | Total pass attempts by triggered player's team | Football developer: volume context for player share and tactical style |
| `opponent_pass_attempts` | Total pass attempts by opponent team | Football developer: bilateral passing-volume context |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered player's team | Football developer: passing-quality baseline around triggered player event |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent team | Football developer: bilateral passing-quality comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context for interpreting direct play choices |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral possession comparator |
| `player_share_of_team_long_balls_pct` | Triggered player long-ball attempts as % of team long-ball attempts | Football developer: quantifies whether player is primary long-ball outlet |
| `player_share_of_team_passes_pct` | Triggered player pass attempts as % of team pass attempts | Football developer: balances direct-specialist interpretation against overall passing responsibility |
