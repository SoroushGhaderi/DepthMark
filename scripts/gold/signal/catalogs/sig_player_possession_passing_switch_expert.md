---
signal_id: sig_player_possession_passing_switch_expert
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Switch Expert"
trigger: "player completes > 5 successful switches of play, proxied by accurate_long_balls from silver.player_match_stat"
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_switch_expert
  sql: clickhouse/gold/dml/signals/player/sig_player_possession_passing_switch_expert.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_possession_passing_switch_expert

## Purpose

Triggers when a player completes more than 5 successful switches of play, using `accurate_long_balls` from `silver.player_match_stat` as the diagonal long-ball proxy.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_successful_switches_proxy > 5`
- Trigger is computed from player-level full-match passing totals in `silver.player_match_stat`.
- Because explicit switch-of-play events are not available, `accurate_long_balls` is used as a diagonal switch proxy.
- Signal includes bilateral team/opponent long-ball and pass-quality context from `silver.period_stat` (`period = 'All'`) to distinguish isolated player switching behavior from broader team directness.
- Output explicitly stores both player identity (`triggered_player_*`) and triggered-team identity (`triggered_team_*`) for contract-compliant player signal traceability.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_possession_passing_switch_expert.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_possession_passing_switch_expert`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_possession_passing_switch_expert
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
| `triggered_player_long_ball_attempts` | Long-ball attempts by triggered player | Football developer: denominator context for the switch proxy |
| `triggered_player_successful_switches_proxy` | Accurate long balls completed by triggered player, used as successful switch proxy | Football developer: core trigger metric volume guard (`> 5`) |
| `triggered_player_long_ball_success_rate_pct` | Triggered player long-ball success percentage | Football developer: precision context for interpreting switch reliability |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: reliability context to separate starters from short stints |
| `triggered_player_touches` | Total touches by triggered player | Football developer: involvement context to interpret role/load |
| `triggered_player_total_passes` | Total pass attempts by triggered player | Football developer: contextualizes switching profile versus total passing load |
| `triggered_team_long_ball_attempts` | Long-ball attempts by triggered player's team | Football developer: team-level directness baseline around player event |
| `opponent_long_ball_attempts` | Long-ball attempts by opponent team | Football developer: bilateral directness comparator |
| `triggered_team_successful_switches_proxy` | Accurate long balls by triggered player's team, used as successful switch proxy | Football developer: team-level switching proxy baseline |
| `opponent_successful_switches_proxy` | Accurate long balls by opponent team, used as successful switch proxy | Football developer: bilateral switch-proxy comparator |
| `triggered_team_long_ball_accuracy_pct` | Triggered team long-ball accuracy percentage | Football developer: indicates whether player switching reflects a team-wide direct-play pattern |
| `opponent_long_ball_accuracy_pct` | Opponent team long-ball accuracy percentage | Football developer: bilateral precision reference for matchup balance |
| `triggered_team_pass_attempts` | Total pass attempts by triggered player's team | Football developer: volume context for player share and tactical style |
| `opponent_pass_attempts` | Total pass attempts by opponent team | Football developer: bilateral passing-volume context |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered player's team | Football developer: passing-quality baseline around triggered player event |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent team | Football developer: bilateral passing-quality comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context for interpreting switch opportunities |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral possession comparator |
| `player_share_of_team_switches_proxy_pct` | Triggered player's accurate long balls as % of team accurate long balls | Football developer: quantifies whether player is a primary switch-of-play outlet |
| `player_share_of_team_passes_pct` | Triggered player pass attempts as % of team pass attempts | Football developer: balances switch-expert interpretation against overall passing responsibility |
