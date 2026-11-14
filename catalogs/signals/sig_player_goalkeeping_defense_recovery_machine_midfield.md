---
signal_id: sig_player_goalkeeping_defense_recovery_machine_midfield
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Recovery Machine Midfield"
trigger: "Midfielder records >= 15 ball recoveries in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_goalkeeping_defense_recovery_machine_midfield
  sql: clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_recovery_machine_midfield.sql
---
# sig_player_goalkeeping_defense_recovery_machine_midfield

## Purpose

Flags an extreme ball-winning workload for a midfielder, a screening and pressing marker.

## Tactical And Statistical Logic

- Trigger: Midfielder records >= 15 ball recoveries in a finished match.
- A midfielder has `usual_playing_position_id = 2` in `fotmob_silver.match_personnel`; recoveries are `recoveries` in `fotmob_silver.player_match_stat`.
- Similarity note: Closest: `sig_player_creativity_playmaking_box_to_box_playmaker` (>= 5 recoveries with progression) and `sig_player_streak_consistency_recovery_king` (>= 10 recoveries, 5 matches in a row). Related defence signals: `sig_team_goalkeeping_defense_aerial_fortress`, `sig_match_goalkeeping_defense_tackle_and_interception_fest` and `sig_player_goalkeeping_defense_save_paralyzer`. Different logic: 15 recoveries by a midfielder in one match. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_recovery_machine_midfield.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_goalkeeping_defense_recovery_machine_midfield`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_goalkeeping_defense_recovery_machine_midfield
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable match key for joins and QA. |
| `match_date` | Match date | Temporal slicing and partition compatibility. |
| `home_team_id` | Home team identifier | Fixture orientation anchor. |
| `home_team_name` | Home team name | Readable fixture context. |
| `away_team_id` | Away team identifier | Fixture orientation anchor. |
| `away_team_name` | Away team name | Readable fixture context. |
| `home_score` | Full-time home goals | Outcome context for the streak match. |
| `away_score` | Full-time away goals | Outcome context for the streak match. |
| `triggered_side` | Side of the player's team (`home` or `away`) | Canonical side identity. |
| `triggered_player_id` | Triggered player identifier | Player attribution key (row identity). |
| `triggered_player_name` | Triggered player name | Readable player context. |
| `triggered_team_id` | Player's team identifier | Team context key (row identity). |
| `triggered_team_name` | Player's team name | Readable team context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral context. |
| `trigger_threshold_min_recoveries` | Configured trigger floor (`15` ball recoveries by a midfielder) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_recoveries` | Ball recoveries by the player | Core signal intensity variable. |
| `triggered_player_recoveries_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_player_minutes_played` | Minutes played in this match | Playing-time context. |
| `triggered_team_goals` | Triggered-side goals in the match | Result context for the streak match. |
| `opponent_goals` | Opponent goals in the match | Bilateral result comparator. |
| `triggered_team_xg` | Triggered-side expected goals (xG) | Chance-quality and control context behind the streak result. |
| `opponent_xg` | Opponent expected goals (xG) | Bilateral comparator for the same match. |
| `triggered_team_total_shots` | Triggered-side total shots | Chance-quality and control context behind the streak result. |
| `opponent_total_shots` | Opponent total shots | Bilateral comparator for the same match. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Chance-quality and control context behind the streak result. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral comparator for the same match. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Chance-quality and control context behind the streak result. |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral comparator for the same match. |
