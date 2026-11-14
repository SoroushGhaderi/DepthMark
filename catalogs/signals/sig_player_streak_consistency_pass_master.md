---
signal_id: sig_player_streak_consistency_pass_master
status: active
entity: player
family: streak
subfamily: consistency
grain: match_player
headline: "Pass Master Streak"
trigger: "Player completes > 90% of at least 20 passes in >= 5 consecutive team matches (this match included)."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_streak_consistency_pass_master
  sql: clickhouse/gold/dml/signals/player/sig_player_streak_consistency_pass_master.sql
---
# sig_player_streak_consistency_pass_master

## Purpose

Flags a sustained high pass-accuracy run, a ball-security and style marker.

## Tactical And Statistical Logic

- Trigger: Player completes > 90% of at least 20 passes in >= 5 consecutive team matches (this match included).
- A passing match has `total_passes >= 20` and `accurate_passes / total_passes > 0.90` in `fotmob_silver.player_match_stat`. The 20-pass floor stops a player with a handful of passes from qualifying. The sequence is the team's finished matches in `fotmob_silver.match`, ordered by `match_date` then `match_id`. Missing a match (no squad row or 0 minutes) breaks the run. The run is tracked per player and team, so a transfer restarts it. One row is emitted for each match where the run is >= 5.
- Similarity note: Closest: `sig_team_possession_passing_accurate_unit` (team pass accuracy > 92% in one match). Different entity and grain: one player across matches. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_streak_consistency_pass_master.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_streak_consistency_pass_master`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_streak_consistency_pass_master
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
| `trigger_threshold_min_consecutive_accurate_passing_matches` | Configured minimum streak length (`5` matches) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_accurate_passing_streak_matches` | Length of the current streak, including this match (matches) | Core signal intensity variable: how long the passing run is. |
| `streak_matches_above_threshold` | Streak length minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match of the streak | Anchors the streak in time for recency and freshness filters. |
| `triggered_player_streak_accurate_passing_matches` | Matches with > 90% pass accuracy across the streak | Volume behind the run: separates sustained output from one big match. |
| `triggered_player_accurate_passing_matches` | Matches with > 90% pass accuracy in this match | Current-match contribution to the run. |
| `triggered_player_streak_total_passes` | Passes attempted across the streak | Volume behind the run: separates sustained output from one big match. |
| `triggered_player_total_passes` | Passes attempted in this match | Current-match contribution to the run. |
| `triggered_player_streak_chances_created` | Chances created (key passes) across the streak | Volume behind the run: separates sustained output from one big match. |
| `triggered_player_chances_created` | Chances created (key passes) in this match | Current-match contribution to the run. |
| `triggered_player_minutes_played_match` | Minutes played in this match | Playing-time context for the current match. |
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
