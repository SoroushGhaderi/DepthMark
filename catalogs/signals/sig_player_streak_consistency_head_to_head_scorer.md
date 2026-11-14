---
signal_id: sig_player_streak_consistency_head_to_head_scorer
status: active
entity: player
family: streak
subfamily: consistency
grain: match_player
headline: "Head To Head Scorer"
trigger: "Player has scored against this opponent in each of his last >= 4 meetings with it (this match included)."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_streak_consistency_head_to_head_scorer
  sql: clickhouse/gold/dml/signals/player/sig_player_streak_consistency_head_to_head_scorer.sql
---
# sig_player_streak_consistency_head_to_head_scorer

## Purpose

Flags a bogey-opponent run where a player scores in every meeting, an opponent-specific scoring marker.

## Tactical And Statistical Logic

- Trigger: Player has scored against this opponent in each of his last >= 4 meetings with it (this match included).
- The sequence is the player's team's finished meetings with the same opponent (any competition, either venue), ordered by `match_date` then `match_id`. A scoring meeting has `goals >= 1` and `minutes_played > 0` in `fotmob_silver.player_match_stat`. A meeting where he did not play or did not score resets the run. The run is tracked per player, team and opponent, so a transfer restarts it. One row is emitted for each meeting where the run is >= 4. Four meetings with one opponent need a long history, so this can stay empty on a short history.
- Similarity note: Closest: `sig_player_streak_consistency_clinical_finisher` (scoring in 3 matches in a row, any opponent) and `sig_match_streak_consistency_one_sided_scoring` (a team's goals against one opponent). Different logic: one player's scoring against one opponent. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_streak_consistency_head_to_head_scorer.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_streak_consistency_head_to_head_scorer`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_streak_consistency_head_to_head_scorer
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
| `trigger_threshold_min_consecutive_scoring_meetings_vs_opponent` | Configured minimum streak length (`4` meetings) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_scoring_meetings_streak_vs_opponent` | Length of the current streak, including this match (meetings) | Core signal intensity variable: how long the scoring run against this opponent is. |
| `streak_matches_above_threshold` | Streak length minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match of the streak | Anchors the streak in time for recency and freshness filters. |
| `triggered_player_goals` | Goals in this match | Current-match contribution to the run. |
| `triggered_player_streak_goals` | Goals against this opponent across the run | Volume behind the run. |
| `triggered_player_streak_shots` | Shots against this opponent across the run | Shot volume behind the run. |
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
