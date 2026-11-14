---
signal_id: sig_player_shooting_goals_one_shot_one_kill
status: active
entity: player
family: shooting
subfamily: goals
grain: match_player
headline: "One Shot One Kill"
trigger: "Player scores a goal from his only shot of a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_shooting_goals_one_shot_one_kill
  sql: clickhouse/gold/dml/signals/player/sig_player_shooting_goals_one_shot_one_kill.sql
---
# sig_player_shooting_goals_one_shot_one_kill

## Purpose

Flags a perfect one-from-one conversion, a clinical-and-efficient marker.

## Tactical And Statistical Logic

- Trigger: Player scores a goal from his only shot of a finished match.
- The player has exactly one shot row in `fotmob_silver.shot` and it is a goal. Shot facts come from `fotmob_silver.shot` (own goals excluded); the player's side comes from the team's match row.
- Similarity note: Closest: `sig_player_shooting_goals_shot_conversion_peak` (2 goals from 2 shots) and `sig_player_shooting_goals_one_man_army` (the only goal in a 1-0 win). Related shooting signals: `sig_player_shooting_goals_impossible_angle`, `sig_player_shooting_goals_shot_conversion_peak` and `sig_player_shooting_goals_shot_magnet`. Different logic: one goal from one shot. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_shooting_goals_one_shot_one_kill.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_shooting_goals_one_shot_one_kill`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_shooting_goals_one_shot_one_kill
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
| `trigger_threshold_exact_shots` | Configured trigger floor (exactly `1` shot and it is a goal) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_shots_taken` | Shots taken by the player | Core signal intensity variable. |
| `triggered_player_shots_taken_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_player_total_xg` | Expected goals of the single shot | Chance quality of the conversion. |
| `triggered_player_shots` | Shots by the player in this match (own goals excluded) | Shot-volume context. |
| `triggered_player_goals` | Goals by the player in this match | Outcome context for the trigger. |
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
