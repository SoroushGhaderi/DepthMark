---
signal_id: sig_player_possession_passing_keeper_launch_heavy
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Keeper Launch Heavy"
trigger: "goalkeeper attempts >= 20 long balls in a finished match"
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_keeper_launch_heavy
  sql: clickhouse/gold/signal/sig_player_possession_passing_keeper_launch_heavy.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_possession_passing_keeper_launch_heavy

## Purpose

Triggers when a goalkeeper attempts at least 20 long balls, highlighting matches where distribution is heavily routed through launch-heavy keeper passing.

## Tactical And Statistical Logic

- Trigger condition:
  - `p.is_goalkeeper = 1`
  - `triggered_player_long_ball_attempts >= 20`
- Trigger is computed from player-level full-match passing totals in `silver.player_match_stat`.
- Signal includes bilateral team/opponent long-ball and pass-quality context from `silver.period_stat` (`period = 'All'`) to separate isolated goalkeeper behavior from wider team directness.
- Output explicitly stores both player identity (`triggered_player_*`) and triggered-team identity (`triggered_team_*`) for contract-compliant player signal traceability.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_possession_passing_keeper_launch_heavy.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_possession_passing_keeper_launch_heavy`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_possession_passing_keeper_launch_heavy
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
| `home_score` | Home goals at full time | Football developer: outcome context for interpreting goalkeeper distribution behavior |
| `away_score` | Away goals at full time | Football developer: outcome context for interpreting goalkeeper distribution behavior |
| `triggered_side` | Side of triggered goalkeeper (`home` or `away`) | Football developer: canonical side orientation for downstream aggregation |
| `triggered_player_id` | Triggered goalkeeper ID | Football developer: primary player key for joins and modeling |
| `triggered_player_name` | Triggered goalkeeper name | Football developer: human-readable signal explanation |
| `triggered_team_id` | Team ID of triggered goalkeeper | Football developer: links goalkeeper signal to team-level tactical clusters |
| `triggered_team_name` | Team name of triggered goalkeeper | Football developer: readable team attribution for reporting |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral context and matchup-based features |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `triggered_player_long_ball_attempts` | Long-ball attempts by triggered goalkeeper | Football developer: core trigger metric volume guard (`>= 20`) |
| `triggered_player_accurate_long_balls` | Accurate long balls completed by triggered goalkeeper | Football developer: quality context for whether launch-heavy behavior is effective |
| `triggered_player_long_ball_success_rate_pct` | Triggered goalkeeper long-ball success percentage | Football developer: precision context for launch-heavy distribution decisions |
| `triggered_player_minutes_played` | Minutes played by triggered goalkeeper | Football developer: reliability context to separate full-match behavior from partial appearances |
| `triggered_player_touches` | Total touches by triggered goalkeeper | Football developer: involvement context around distribution volume |
| `triggered_player_total_passes` | Total pass attempts by triggered goalkeeper | Football developer: contextualizes long-ball share versus overall passing load |
| `triggered_team_long_ball_attempts` | Long-ball attempts by triggered goalkeeper's team | Football developer: team-level directness baseline around goalkeeper behavior |
| `opponent_long_ball_attempts` | Long-ball attempts by opponent team | Football developer: bilateral directness comparator |
| `triggered_team_accurate_long_balls` | Accurate long balls by triggered goalkeeper's team | Football developer: team-level long-ball quality baseline |
| `opponent_accurate_long_balls` | Accurate long balls by opponent team | Football developer: bilateral long-ball quality comparator |
| `triggered_team_long_ball_accuracy_pct` | Triggered team long-ball accuracy percentage | Football developer: indicates whether keeper launch-heavy behavior aligns with team-wide direct-play execution |
| `opponent_long_ball_accuracy_pct` | Opponent team long-ball accuracy percentage | Football developer: bilateral precision reference for matchup balance |
| `triggered_team_pass_attempts` | Total pass attempts by triggered goalkeeper's team | Football developer: volume context for tactical style and player share |
| `opponent_pass_attempts` | Total pass attempts by opponent team | Football developer: bilateral passing-volume context |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered goalkeeper's team | Football developer: passing-quality baseline around triggered behavior |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent team | Football developer: bilateral passing-quality comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context for interpreting direct play choices |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral possession comparator |
| `player_share_of_team_long_balls_pct` | Triggered goalkeeper long-ball attempts as % of team long-ball attempts | Football developer: quantifies how strongly launch volume is concentrated in the goalkeeper |
| `player_share_of_team_passes_pct` | Triggered goalkeeper pass attempts as % of team pass attempts | Football developer: balances launch-heavy interpretation against overall passing responsibility |
