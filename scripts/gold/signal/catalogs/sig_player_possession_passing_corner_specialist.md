---
signal_id: sig_player_possession_passing_corner_specialist
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Corner Specialist"
trigger: "player creates > 1 chances from corner-kick deliveries in a single match"
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_corner_specialist
  sql: clickhouse/gold/dml/signals/player/sig_player_possession_passing_corner_specialist.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_possession_passing_corner_specialist

## Purpose

Triggers when a player creates more than 1 chance from corner-kick deliveries in a single match, identifying dead-ball delivery specialists who repeatedly generate shots.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_corner_chances_created > 1`
- Trigger is computed from `silver.shot` rows where `situation = 'FromCorner'` and the player is recorded as `assist_player_id`, capturing shot-creating corner deliveries.
- Signal keeps bilateral team/opponent context via `silver.period_stat` (`period = 'All'`) and adds corner-shot team context from `silver.shot`.
- Output stores both player identity (`triggered_player_*`) and team identity (`triggered_team_*`) for contract-compliant player signal traceability.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_possession_passing_corner_specialist.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_possession_passing_corner_specialist`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_possession_passing_corner_specialist
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
| `triggered_player_corner_chances_created` | Shot chances created by triggered player from corner deliveries | Football developer: core trigger metric volume guard (`> 1`) |
| `triggered_player_corner_assisted_shots_on_target` | On-target shots created by triggered player from corner deliveries | Football developer: quality context for corner chance creation |
| `triggered_player_corner_assisted_shot_expected_goals` | Sum of expected goals from shots created by triggered player via corners | Football developer: quantifies quality of corner-created shots beyond raw volume |
| `triggered_player_corner_assisted_goals` | Goals scored from shots created by triggered player via corners | Football developer: outcome conversion context for delivery impact |
| `triggered_player_cross_attempts` | Cross attempts by triggered player | Football developer: wider delivery-volume context around corner specialization |
| `triggered_player_accurate_crosses` | Accurate crosses by triggered player | Football developer: delivery-quality baseline for crossing profile |
| `triggered_player_cross_success_rate_pct` | Triggered player cross accuracy percentage | Football developer: efficiency context for delivery profile |
| `triggered_player_total_passes` | Total pass attempts by triggered player | Football developer: passing-volume context around specialist role |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy percentage | Football developer: passing-quality baseline around corner creation event |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: reliability context to separate starters from short stints |
| `triggered_player_touches` | Total touches by triggered player | Football developer: involvement context to interpret role/load |
| `triggered_team_corner_shots` | Total shots taken by triggered team from corner situations | Football developer: team-level corner-shot environment around the player signal |
| `opponent_corner_shots` | Total shots taken by opponent team from corner situations | Football developer: bilateral dead-ball shot-creation comparator |
| `triggered_team_corners` | Corners won by triggered player's team | Football developer: set-piece opportunity baseline around corner deliveries |
| `opponent_corners` | Corners won by opponent team | Football developer: bilateral set-piece opportunity comparator |
| `triggered_team_cross_attempts` | Cross attempts by triggered player's team | Football developer: team wide-service baseline around corner specialist usage |
| `opponent_cross_attempts` | Cross attempts by opponent team | Football developer: bilateral wide-service comparator |
| `triggered_team_accurate_crosses` | Accurate crosses by triggered player's team | Football developer: team delivery-quality baseline for interpreting player contribution |
| `opponent_accurate_crosses` | Accurate crosses by opponent team | Football developer: bilateral delivery-quality comparator |
| `triggered_team_cross_accuracy_pct` | Cross accuracy of triggered player's team | Football developer: contextual team delivery efficiency benchmark |
| `opponent_cross_accuracy_pct` | Cross accuracy of opponent team | Football developer: bilateral cross-efficiency reference for matchup balance |
| `triggered_team_pass_attempts` | Total pass attempts by triggered player's team | Football developer: team possession-volume baseline around player event |
| `opponent_pass_attempts` | Total pass attempts by opponent team | Football developer: bilateral passing-volume context |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered player's team | Football developer: contextual team passing-quality benchmark |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent team | Football developer: bilateral passing-quality reference |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context for corner-creation interpretation |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral possession comparator |
| `player_share_of_triggered_team_corner_shots_pct` | Triggered player share of team corner-originated shots created | Football developer: quantifies how central the player is to the team's corner-shot creation |
| `player_share_of_team_crosses_pct` | Triggered player cross attempts as % of team cross attempts | Football developer: quantifies player ownership of team-wide delivery volume |
