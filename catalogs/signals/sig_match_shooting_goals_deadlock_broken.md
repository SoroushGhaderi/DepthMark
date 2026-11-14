---
signal_id: sig_match_shooting_goals_deadlock_broken
status: active
entity: match
family: shooting
subfamily: goals
grain: match_team
headline: "Deadlock Broken"
trigger: "A finished match is goalless until the 80th minute and then sees >= 2 goals."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_shooting_goals_deadlock_broken
  sql: clickhouse/gold/dml/signals/match/sig_match_shooting_goals_deadlock_broken.sql
---
# sig_match_shooting_goals_deadlock_broken

## Purpose

Flags a late burst after 80 goalless minutes, a late-drama and live-market marker.

## Tactical And Statistical Logic

- Trigger: A finished match is goalless until the 80th minute and then sees >= 2 goals.
- The first goal row has `goal_time > 80`, the match has at least two goal rows, and the goal rows add up to the final score, so a match with incomplete goal data cannot count. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_match_shooting_goals_clean_sheet_broken_late` (first goal at 89+ in a 0-0) and `sig_match_shooting_goals_game_of_two_halves`. Different logic: two or more goals after a goalless 80 minutes. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_shooting_goals_deadlock_broken.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_shooting_goals_deadlock_broken`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_shooting_goals_deadlock_broken
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
| `trigger_threshold_min_goals_after_goalless_80` | Configured trigger floor (`2` goals after a goalless first 80 minutes) | Explicit trigger provenance for explainability and QA. |
| `match_goals_after_80` | Goals scored after minute 80 | Core signal intensity variable. |
| `match_goals_after_80_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `match_first_goal_minute` | Minute of the first goal | Shows how late the deadlock broke. |
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
