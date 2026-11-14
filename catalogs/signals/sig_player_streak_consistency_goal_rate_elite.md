---
signal_id: sig_player_streak_consistency_goal_rate_elite
status: active
entity: player
family: streak
subfamily: consistency
grain: match_player
headline: "Goal Rate Elite"
trigger: "Player averages more than 1.0 goals per 90 minutes over his last 5 consecutive team matches (this match included)."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_streak_consistency_goal_rate_elite
  sql: clickhouse/gold/dml/signals/player/sig_player_streak_consistency_goal_rate_elite.sql
---
# sig_player_streak_consistency_goal_rate_elite

## Purpose

Flags a five-match window where a player scores more than one goal per 90 minutes, an elite-form marker.

## Tactical And Statistical Logic

- Trigger: Player averages more than 1.0 goals per 90 minutes over his last 5 consecutive team matches (this match included).
- The window is the player's last 5 consecutive team matches (all five played, with minutes). Goals per 90 is `sum(goals) * 90 / sum(minutes_played)` from `fotmob_silver.player_match_stat` (goals include penalties). A row is emitted for each match where the 5-match window is complete and the rate is > 1.0, so a long hot run emits many rows. The player is tracked per team, so a transfer restarts the window. Only loaded matches count.
- Similarity note: Closest: `sig_player_streak_consistency_clinical_finisher` (scoring in 3 matches in a row, no rate) and `sig_player_shooting_goals_hat_trick_hero` (one match). Different logic: a per-90 scoring rate over a five-match window. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_streak_consistency_goal_rate_elite.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_streak_consistency_goal_rate_elite`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_streak_consistency_goal_rate_elite
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
| `trigger_threshold_min_window_goals_per_90` | Configured trigger floor (goals per 90 over 5 matches) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_window_goals_per_90` | Goals per 90 minutes over the last 5 matches, including this match | Core signal intensity variable. |
| `streak_matches_above_threshold` | Goals per 90 above the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match inside the window | Anchors the window in time for recency and freshness filters. |
| `triggered_player_window_goals` | Goals over the last 5 matches | Goal volume behind the rate. |
| `triggered_player_window_minutes` | Minutes played over the last 5 matches | Playing time behind the rate. |
| `triggered_player_goals` | Goals in this match | Current-match contribution to the window. |
| `triggered_player_minutes_played` | Minutes played in this match | Playing-time context for the current match. |
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
