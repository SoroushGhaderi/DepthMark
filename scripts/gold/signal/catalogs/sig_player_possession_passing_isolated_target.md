---
signal_id: sig_player_possession_passing_isolated_target
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Isolated Target"
trigger: "forward records < 5 touches despite playing > 45 minutes"
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_isolated_target
  sql: clickhouse/gold/dml/signals/player/sig_player_possession_passing_isolated_target.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_possession_passing_isolated_target

## Purpose

Triggers when a forward records fewer than 5 touches while playing more than 45 minutes, identifying isolated attacking targets who were on the pitch long enough to matter but barely entered the possession chain.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_usual_playing_position_id = 3`
  - `triggered_player_minutes_played > 45`
  - `triggered_player_touches < 5`
- Forward classification uses `silver.match_personnel.usual_playing_position_id = 3`, with the match-specific `position_id` also stored for formation diagnostics.
- Trigger uses player-level full-match totals from `silver.player_match_stat`.
- Signal includes bilateral team/opponent pass, possession, box-touch, xG, and shot context from `silver.period_stat` (`period = 'All'`) to distinguish tactical isolation from general team scarcity.
- Output explicitly stores both player identity (`triggered_player_*`) and triggered-team identity (`triggered_team_*`) for contract-compliant player signal traceability.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_possession_passing_isolated_target.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_possession_passing_isolated_target`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_possession_passing_isolated_target
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
| `home_score` | Home goals at full time | Football developer: outcome context for interpreting isolated forward usage |
| `away_score` | Away goals at full time | Football developer: outcome context for interpreting isolated forward usage |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for downstream aggregation |
| `triggered_player_id` | Triggered player ID | Football developer: primary player key for joins and modeling |
| `triggered_player_name` | Triggered player name | Football developer: human-readable signal explanation |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player signal to team-level tactical clusters |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution for reporting |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral context and matchup-based features |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `triggered_player_position_id` | Match-specific lineup position ID for the triggered player | Football developer: formation diagnostic for whether the isolation came from a central or wide forward role |
| `triggered_player_usual_playing_position_id` | Broad player-position bucket used for forward filtering | Football developer: documents the forward-role gate used by the trigger |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: core trigger guard (`> 45`) to remove cameo noise |
| `triggered_player_touches` | Total touches by triggered player | Football developer: core signal value and trigger metric (`< 5`) |
| `triggered_player_touches_per90` | Triggered player touches normalized to 90 minutes | Football developer: compares isolation severity across unequal playing time |
| `triggered_player_total_passes` | Total passes attempted by triggered player | Football developer: confirms whether the player entered buildup circulation at all |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Football developer: completion context for limited passing involvement |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy percentage | Football developer: quality context when touch volume is extremely low |
| `triggered_player_touches_opposition_box` | Triggered player touches inside opposition box | Football developer: identifies whether rare involvement occurred in high-value zones |
| `triggered_player_expected_goals` | Triggered player expected goals | Football developer: separates pure isolation from low-touch, high-shot poacher profiles |
| `triggered_player_total_shots` | Triggered player total shots | Football developer: finishing-volume context for minimal-touch forwards |
| `triggered_team_pass_attempts` | Team pass attempts of triggered player's side | Football developer: denominator for player share and team style context |
| `opponent_pass_attempts` | Opponent team pass attempts | Football developer: bilateral tempo control context |
| `triggered_team_accurate_passes` | Accurate passes by triggered player's team | Football developer: team-level passing quality baseline around player isolation |
| `opponent_accurate_passes` | Accurate passes by opponent team | Football developer: bilateral quality comparator |
| `triggered_team_pass_accuracy_pct` | Team pass accuracy of triggered side | Football developer: shows whether isolation happened despite clean circulation |
| `opponent_pass_accuracy_pct` | Opponent team pass accuracy | Football developer: bilateral quality reference for matchup balance |
| `triggered_team_possession_pct` | Triggered side possession percentage | Football developer: distinguishes low-team-possession isolation from role-specific exclusion |
| `opponent_possession_pct` | Opponent possession percentage | Football developer: bilateral possession comparator |
| `triggered_team_touches_opposition_box` | Triggered team touches inside opposition box | Football developer: team territorial threat context for forward starvation |
| `opponent_touches_opposition_box` | Opponent touches inside the triggered team's box | Football developer: symmetric territorial threat comparator |
| `triggered_team_expected_goals` | Triggered team expected goals | Football developer: chance-quality context for whether the isolated forward still benefited from team threat |
| `opponent_expected_goals` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `triggered_team_total_shots` | Triggered team total shots | Football developer: shot-volume context around forward involvement |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral shot-volume comparator |
| `player_share_of_team_passes_pct` | Triggered player pass attempts as % of team pass attempts | Football developer: measures how absent the forward was from possession circulation |
| `player_share_of_team_opposition_box_touches_pct` | Triggered player opposition-box touches as % of team opposition-box touches | Football developer: measures whether team entries bypassed the forward target |
