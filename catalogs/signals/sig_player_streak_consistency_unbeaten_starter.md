---
signal_id: sig_player_streak_consistency_unbeaten_starter
status: active
entity: player
family: streak
subfamily: consistency
grain: match_player
headline: "Unbeaten When Starting"
trigger: "The team has not lost any of the last >= 10 matches the player started (this match included)."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_streak_consistency_unbeaten_starter
  sql: clickhouse/gold/dml/signals/player/sig_player_streak_consistency_unbeaten_starter.sql
---
# sig_player_streak_consistency_unbeaten_starter

## Purpose

Flags a long unbeaten run across a player's starts, a lucky-charm and form marker.

## Tactical And Statistical Logic

- Trigger: The team has not lost any of the last >= 10 matches the player started (this match included).
- A qualifying start has the player in the `starter` list of `fotmob_silver.match_personnel`, `minutes_played > 0` and the team's `goals_for >= goals_against`. A start with a defeat resets the run. The run counts only the player's own starts, so matches he missed or came on as a substitute do not break it. One row is emitted for each start where the run is >= 10. Ten starts need a long history, so this can stay empty on a short history.
- Similarity note: Closest: `sig_team_streak_consistency_invincible_run` (the team's unbeaten run, any lineup). Different logic: the run is counted only over the player's starts. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_streak_consistency_unbeaten_starter.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_streak_consistency_unbeaten_starter`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_streak_consistency_unbeaten_starter
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
| `trigger_threshold_min_unbeaten_starts` | Configured minimum streak length (`10` matches) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_unbeaten_starts_streak` | Length of the current streak, including this match (matches) | Core signal intensity variable: how many starts in a row ended without a defeat. |
| `streak_matches_above_threshold` | Streak length minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match of the streak | Anchors the streak in time for recency and freshness filters. |
| `triggered_player_streak_role_flag` | Starts without a defeat across the streak | Volume behind the run: separates sustained output from one big match. |
| `triggered_player_role_flag` | Starts without a defeat in this match | Current-match contribution to the run. |
| `triggered_player_streak_minutes_played` | Minutes played across the streak | Volume behind the run: separates sustained output from one big match. |
| `triggered_player_minutes_played` | Minutes played in this match | Current-match contribution to the run. |
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
