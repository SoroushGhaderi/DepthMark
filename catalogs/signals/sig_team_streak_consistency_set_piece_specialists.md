---
signal_id: sig_team_streak_consistency_set_piece_specialists
status: active
entity: team
family: streak
subfamily: consistency
grain: match_team
headline: "Set Piece Specialists"
trigger: "Team scores from a set piece (corner, free kick or other set play) in >= 3 consecutive matches (this match included)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_streak_consistency_set_piece_specialists
  sql: clickhouse/gold/dml/signals/team/sig_team_streak_consistency_set_piece_specialists.sql
---
# sig_team_streak_consistency_set_piece_specialists

## Purpose

Flags a run of set-piece goals, a marker of dead-ball strength and tall, well-drilled players.

## Tactical And Statistical Logic

- Trigger: Team scores from a set piece (corner, free kick or other set play) in >= 3 consecutive matches (this match included).
- A set-piece match has at least one team goal whose `situation` is `FromCorner`, `FreeKick`, `SetPiece` or `ThrowInSetPiece`. The sequence is every finished match of the team in `fotmob_silver.match` (all loaded competitions), ordered by `match_date` then `match_id`. One row is emitted for each match where the running streak length is >= 3. Only loaded matches count, so a short history can shorten a real streak. Goal timing, set-piece and trailing facts come from the goal rows of `fotmob_silver.shot` (`is_goal = 1`, side from `is_home_goal`, minute from `goal_time`, own goals credited to the side that benefits); penalties come from shot rows whose `situation` contains `penalty`. A match with no goal rows counts as zero goals, so missing shot data can only hide a streak, never invent one.
- Similarity note: Closest: `sig_team_shooting_goals_dead_ball_specialists` (>= 2 dead-ball goals in one match) and `sig_team_shooting_goals_set_piece_masterclass`. Different grain: a multi-match run with a lower per-match floor. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_streak_consistency_set_piece_specialists.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_streak_consistency_set_piece_specialists`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_streak_consistency_set_piece_specialists
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
| `triggered_side` | Row orientation (`home` or `away`) | Canonical side identity for match-team grain. |
| `triggered_team_id` | Triggered-side team identifier | Team attribution key for downstream features. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral context. |
| `trigger_threshold_min_consecutive_set_piece_goal_matches` | Configured minimum streak length (`3` matches) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_set_piece_goal_streak_matches` | Length of the current streak, including this match (matches) | Core signal intensity variable: how long the set-piece run is. |
| `streak_matches_above_threshold` | Streak length minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match of the streak | Anchors the streak in time for recency and freshness filters. |
| `triggered_team_streak_wins` | Wins inside the streak | Shows whether the streak is made of wins or draws. |
| `triggered_team_streak_draws` | Draws inside the streak | Shows how much of the streak is stalemates. |
| `triggered_team_streak_goals_scored` | Goals scored across the streak | Attacking output behind the streak. |
| `triggered_team_streak_goals_conceded` | Goals conceded across the streak | Defensive record behind the streak. |
| `triggered_team_streak_set_piece_goals` | Set-piece goals across the streak | Set-piece volume behind the run. |
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
