---
signal_id: sig_player_possession_passing_dribble_threat
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Dribble Threat"
trigger: "player completes > 5 successful dribbles in a single match"
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_dribble_threat
  sql: clickhouse/gold/signal/sig_player_possession_passing_dribble_threat.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_possession_passing_dribble_threat

## Purpose

Triggers when a player completes more than 5 successful dribbles in a single match, identifying high-impact ball carriers who repeatedly beat opponents 1v1.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_successful_dribbles > 5`
- Trigger uses player-level full-match totals from `silver.player_match_stat`.
- Signal includes player dribble attempts, failed dribbles, success rate, touches, box involvement, creation, shooting, and passing context to separate pure carrying threat from sterile volume.
- Signal includes bilateral team/opponent dribbling, passing, possession, and opposition-box context from `silver.period_stat` (`period = 'All'`) to distinguish individual superiority from team-wide carrying dominance.
- Output explicitly stores both player identity (`triggered_player_*`) and triggered-team identity (`triggered_team_*`) for contract-compliant player signal traceability.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_possession_passing_dribble_threat.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_possession_passing_dribble_threat`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_possession_passing_dribble_threat
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
| `home_score` | Home goals at full time | Football developer: outcome context for interpreting dribble threat |
| `away_score` | Away goals at full time | Football developer: outcome context for interpreting dribble threat |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for downstream aggregation |
| `triggered_player_id` | Triggered player ID | Football developer: primary player key for joins and modeling |
| `triggered_player_name` | Triggered player name | Football developer: human-readable signal explanation |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player signal to team-level tactical clusters |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution for reporting |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral context and matchup-based features |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `triggered_player_successful_dribbles` | Successful dribbles by triggered player | Football developer: core trigger metric volume guard (`> 5`) |
| `triggered_player_dribble_attempts` | Dribble attempts by triggered player | Football developer: carrying-load context for the successful dribble volume |
| `triggered_player_failed_dribbles` | Failed dribbles by triggered player | Football developer: risk context for how often carrying broke possession |
| `triggered_player_dribble_success_rate_pct` | Triggered player dribble success percentage | Football developer: efficiency context for separating threat from speculative take-ons |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: reliability context to separate sustained threat from short-stint spikes |
| `triggered_player_touches` | Total touches by triggered player | Football developer: involvement baseline for interpreting carrying centrality |
| `triggered_player_touches_opposition_box` | Triggered player touches inside opposition box | Football developer: danger-zone context for whether carries translated into box presence |
| `triggered_player_chances_created` | Chances created by triggered player | Football developer: creation context for dribble threat becoming final action |
| `triggered_player_expected_assists` | Expected assists by triggered player | Football developer: chance-quality context for post-dribble service |
| `triggered_player_expected_goals` | Expected goals by triggered player | Football developer: shooting-threat context around carries into scoring areas |
| `triggered_player_total_shots` | Total shots by triggered player | Football developer: finishing-volume context for ball-carrying threat |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Football developer: passing-quality context alongside carrying output |
| `triggered_player_total_passes` | Total passes attempted by triggered player | Football developer: passing-load context to profile carry-versus-pass role balance |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy percentage | Football developer: ball-security context beyond dribble outcomes |
| `triggered_team_dribble_attempts` | Dribble attempts by triggered player's team | Football developer: team carrying-intent baseline around the player event |
| `opponent_dribble_attempts` | Dribble attempts by opponent team | Football developer: bilateral carrying-intent comparator |
| `triggered_team_successful_dribbles` | Successful dribbles by triggered player's team | Football developer: team carrying output context |
| `opponent_successful_dribbles` | Successful dribbles by opponent team | Football developer: bilateral carrying-output comparator |
| `triggered_team_dribble_success_pct` | Dribble success percentage of triggered side | Football developer: team-level ball-carry benchmark around the player signal |
| `opponent_dribble_success_pct` | Dribble success percentage of opponent side | Football developer: bilateral dribble-efficiency reference |
| `triggered_team_pass_attempts` | Team pass attempts of triggered player's side | Football developer: denominator for player share and team style context |
| `opponent_pass_attempts` | Opponent team pass attempts | Football developer: bilateral tempo control context |
| `triggered_team_accurate_passes` | Accurate passes by triggered player's team | Football developer: team-level passing quality baseline around player carrying |
| `opponent_accurate_passes` | Accurate passes by opponent team | Football developer: bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Team pass accuracy of triggered side | Football developer: shows whether dribble threat complemented clean circulation |
| `opponent_pass_accuracy_pct` | Opponent team pass accuracy | Football developer: bilateral quality reference for matchup balance |
| `triggered_team_possession_pct` | Triggered side possession percentage | Football developer: control context for interpreting dribble volume |
| `opponent_possession_pct` | Opponent possession percentage | Football developer: bilateral possession comparator |
| `triggered_team_touches_opposition_box` | Triggered team touches inside opposition box | Football developer: team territorial threat context around carries |
| `opponent_touches_opposition_box` | Opponent touches inside the triggered team's box | Football developer: symmetric territorial threat comparator |
| `player_share_of_team_dribbles_pct` | Triggered player dribble attempts as % of team dribble attempts | Football developer: quantifies centrality in team carrying |
| `player_share_of_team_passes_pct` | Triggered player pass attempts as % of team pass attempts | Football developer: profiles whether the threat is primarily a carrier or circulation hub |
| `player_share_of_team_opposition_box_touches_pct` | Triggered player opposition-box touches as % of team opposition-box touches | Football developer: measures whether carrying threat translated into team box presence |
