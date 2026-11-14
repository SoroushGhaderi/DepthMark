---
signal_id: sig_player_streak_consistency_second_half_hero
status: active
entity: player
family: streak
subfamily: consistency
grain: match_player
headline: "Second Half Hero"
trigger: "Player's last >= 5 goals have all been scored after minute 70 (this match included)."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_streak_consistency_second_half_hero
  sql: clickhouse/gold/dml/signals/player/sig_player_streak_consistency_second_half_hero.sql
---
# sig_player_streak_consistency_second_half_hero

## Purpose

Flags a player whose goals keep arriving in the closing stage, a late-impact and substitute-scorer marker.

## Tactical And Statistical Logic

- Trigger: Player's last >= 5 goals have all been scored after minute 70 (this match included).
- Goals are non-own goal rows in `fotmob_silver.shot` (`is_goal = 1`), ordered per player by date, match, minute and `shot_id`. A late goal has `goal_time > 70`; an earlier goal resets the run. The run counts the player's own goals, so matches without a goal do not break it. One row is emitted for each match where the run reaches >= 5 at the player's last goal. Five late goals need a long history, so this can stay empty on a short history.
- Similarity note: Closest: `sig_player_streak_consistency_clutch_performer` (late goal in consecutive matches) and `sig_team_shooting_goals_late_surge_goals`. Different logic: every one of the last five goals is late. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_streak_consistency_second_half_hero.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_streak_consistency_second_half_hero`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_streak_consistency_second_half_hero
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
| `trigger_threshold_min_consecutive_late_goals` | Configured minimum run length (`5` goals) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_late_goal_streak` | Length of the current run at the player's last event in this match (goals) | Core signal intensity variable: how many goals in a row came after minute 70. |
| `streak_matches_above_threshold` | Run length minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first event of the run | Anchors the run in time for recency and freshness filters. |
| `triggered_player_events_in_match` | Goals the player scored in this match | Context for how many qualifying events the player had in this match. |
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
