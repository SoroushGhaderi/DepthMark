---
signal_id: sig_player_possession_passing_deadball_creator
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Dead-Ball Creator"
trigger: "player creates > 0 big chances from indirect free kicks in a single match"
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_deadball_creator
  sql: clickhouse/gold/signal/sig_player_possession_passing_deadball_creator.sql
  runner: scripts/gold/signal/runners/sig_player_possession_passing_deadball_creator.py
---
# sig_player_possession_passing_deadball_creator

## Purpose

Triggers when a player creates at least 1 big chance from indirect free kicks in a single match, identifying dead-ball creators who consistently produce high-quality opportunities.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_indirect_free_kick_big_chances_created > 0`
- Indirect free-kick creation is modeled from `silver.shot` rows where `situation IN ('FreeKick', 'SetPiece')` and the player is recorded as `assist_player_id`.
- Big chances are proxied at shot level by `expected_goals >= 0.30` because a direct per-shot big-chance flag is not available in `silver.shot`.
- Signal keeps bilateral team/opponent context via `silver.period_stat` (`period = 'All'`) and adds set-piece shot context from `silver.shot`.
- Output stores both player identity (`triggered_player_*`) and team identity (`triggered_team_*`) for contract-compliant player signal traceability.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_possession_passing_deadball_creator.sql`
- Runner: `scripts/gold/signal/runners/sig_player_possession_passing_deadball_creator.py`
- Target table: `gold_signals.sig_player_possession_passing_deadball_creator`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_possession_passing_deadball_creator.py
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
| `triggered_player_indirect_free_kick_big_chances_created` | Big chances created by triggered player from indirect free kicks (xG proxy >= 0.30) | Football developer: core trigger metric volume guard (`> 0`) |
| `triggered_player_indirect_free_kick_chances_created` | Total chances created by triggered player from indirect free kicks | Football developer: volume context around high-quality dead-ball creation |
| `triggered_player_indirect_free_kick_assisted_shots_on_target` | On-target shots created by triggered player from indirect free kicks | Football developer: delivery quality and conversion pressure context |
| `triggered_player_indirect_free_kick_assisted_shot_expected_goals` | Sum of expected goals from shots created by triggered player via indirect free kicks | Football developer: quantifies total quality produced from dead-ball deliveries |
| `triggered_player_indirect_free_kick_assisted_goals` | Goals scored from shots created by triggered player via indirect free kicks | Football developer: outcome conversion context for dead-ball creation |
| `triggered_player_expected_assists` | Triggered player expected assists from all actions | Football developer: all-phase creativity baseline to compare against dead-ball specialization |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Football developer: passing-quality baseline for creator profile |
| `triggered_player_total_passes` | Total pass attempts by triggered player | Football developer: passing-volume context around specialist role |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy percentage | Football developer: efficiency context balancing risk and control |
| `triggered_player_cross_attempts` | Cross attempts by triggered player | Football developer: delivery-volume context around set-piece profile |
| `triggered_player_accurate_crosses` | Accurate crosses by triggered player | Football developer: direct delivery-quality context |
| `triggered_player_cross_success_rate_pct` | Triggered player cross accuracy percentage | Football developer: efficiency context for wide/dead-ball service |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: reliability context to separate starters from short stints |
| `triggered_player_touches` | Total touches by triggered player | Football developer: involvement context to interpret role/load |
| `triggered_team_indirect_free_kick_big_chances` | Big chances created by triggered team from indirect free kicks (xG proxy >= 0.30) | Football developer: team dead-ball quality baseline around player signal |
| `opponent_indirect_free_kick_big_chances` | Big chances created by opponent from indirect free kicks (xG proxy >= 0.30) | Football developer: bilateral dead-ball quality comparator |
| `triggered_team_indirect_free_kick_chances` | Total chances created by triggered team from indirect free kicks | Football developer: team dead-ball volume baseline around player signal |
| `opponent_indirect_free_kick_chances` | Total chances created by opponent from indirect free kicks | Football developer: bilateral dead-ball volume comparator |
| `triggered_team_set_piece_shots` | Set-piece shots by triggered team (corner, free kick, set piece, throw-in set piece) | Football developer: broader dead-ball shot environment around trigger |
| `opponent_set_piece_shots` | Set-piece shots by opponent team | Football developer: bilateral set-piece shot-pressure comparator |
| `triggered_team_corners` | Corners won by triggered player's team | Football developer: set-piece opportunity baseline |
| `opponent_corners` | Corners won by opponent team | Football developer: bilateral set-piece opportunity comparator |
| `triggered_team_cross_attempts` | Cross attempts by triggered player's team | Football developer: team delivery-volume baseline |
| `opponent_cross_attempts` | Cross attempts by opponent team | Football developer: bilateral delivery-volume comparator |
| `triggered_team_cross_accuracy_pct` | Cross accuracy of triggered player's team | Football developer: contextual team delivery-efficiency benchmark |
| `opponent_cross_accuracy_pct` | Cross accuracy of opponent team | Football developer: bilateral delivery-efficiency reference |
| `triggered_team_pass_attempts` | Total pass attempts by triggered player's team | Football developer: team possession-volume baseline around player event |
| `opponent_pass_attempts` | Total pass attempts by opponent team | Football developer: bilateral passing-volume context |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered player's team | Football developer: contextual team passing-quality benchmark |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent team | Football developer: bilateral passing-quality reference |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context for dead-ball creation interpretation |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral possession comparator |
| `player_share_of_triggered_team_indirect_free_kick_big_chances_pct` | Triggered player share of team indirect-free-kick big chances created | Football developer: quantifies concentration of high-quality dead-ball creation |
| `player_share_of_triggered_team_indirect_free_kick_chances_pct` | Triggered player share of team indirect-free-kick chances created | Football developer: quantifies player ownership of dead-ball creation volume |
| `player_share_of_team_crosses_pct` | Triggered player cross attempts as % of team cross attempts | Football developer: quantifies delivery ownership beyond set-piece phases |
