---
signal_id: sig_player_streak_consistency_shot_volume_drought
status: active
entity: player
family: streak
subfamily: consistency
grain: match_player
headline: "Shot Volume Drought"
trigger: "Forward records <= 1 shot in >= 4 consecutive team matches (this match included)."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_streak_consistency_shot_volume_drought
  sql: clickhouse/gold/dml/signals/player/sig_player_streak_consistency_shot_volume_drought.sql
---
# sig_player_streak_consistency_shot_volume_drought

## Purpose

Flags a quiet run for an attacker, a negative-form and role-change marker.

## Tactical And Statistical Logic

- Trigger: Forward records <= 1 shot in >= 4 consecutive team matches (this match included).
- A quiet match has `total_shots <= 1` for a player whose usual position is a forward (`usual_playing_position_id = 3` in `fotmob_silver.match_personnel`, the repo's forward group). The sequence is the team's finished matches in `fotmob_silver.match`, ordered by `match_date` then `match_id`. Missing a match (no squad row or 0 minutes) breaks the run. The run is tracked per player and team, so a transfer restarts it. One row is emitted for each match where the run is >= 4.
- Similarity note: Closest: `sig_player_streak_consistency_shot_machine` (the opposite, high-volume run) and `sig_player_creativity_playmaking_unselfish_forward`. Different logic: a forward's low shot volume across matches. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_streak_consistency_shot_volume_drought.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_streak_consistency_shot_volume_drought`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_streak_consistency_shot_volume_drought
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
| `trigger_threshold_min_consecutive_quiet_forward_matches` | Configured minimum streak length (`4` matches) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_quiet_forward_streak_matches` | Length of the current streak, including this match (matches) | Core signal intensity variable: how long the quiet run is. |
| `streak_matches_above_threshold` | Streak length minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match of the streak | Anchors the streak in time for recency and freshness filters. |
| `triggered_player_streak_role_flag` | Matches with <= 1 shot for a forward across the streak | Volume behind the run: separates sustained output from one big match. |
| `triggered_player_role_flag` | Matches with <= 1 shot for a forward in this match | Current-match contribution to the run. |
| `triggered_player_streak_shots` | Shots across the streak | Volume behind the run: separates sustained output from one big match. |
| `triggered_player_shots` | Shots in this match | Current-match contribution to the run. |
| `triggered_player_streak_goals` | Goals across the streak | Volume behind the run: separates sustained output from one big match. |
| `triggered_player_goals` | Goals in this match | Current-match contribution to the run. |
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
