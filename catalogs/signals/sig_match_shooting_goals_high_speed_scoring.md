---
signal_id: sig_match_shooting_goals_high_speed_scoring
status: active
entity: match
family: shooting
subfamily: goals
grain: match_team
headline: "High Speed Scoring"
trigger: "A finished match has >= 2 goals in the first 5 minutes."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_shooting_goals_high_speed_scoring
  sql: clickhouse/gold/dml/signals/match/sig_match_shooting_goals_high_speed_scoring.sql
---
# sig_match_shooting_goals_high_speed_scoring

## Purpose

Flags a very fast start, an early-goals and live-market marker.

## Tactical And Statistical Logic

- Trigger: A finished match has >= 2 goals in the first 5 minutes.
- Early goals are goal rows in `fotmob_silver.shot` with `goal_time` from 1 to 5 (both teams). The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_team_shooting_goals_early_blitz` (one team, >= 2 goals in 15 minutes) and `sig_match_shooting_goals_early_goal_late_goal`. Related match signals: `sig_match_shooting_goals_clinical_showdown`, `sig_match_shooting_goals_goal_fest` and `sig_match_shooting_goals_high_xg_low_score`. Different logic: two or more goals in the first 5 minutes of the match. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_shooting_goals_high_speed_scoring.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_shooting_goals_high_speed_scoring`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_shooting_goals_high_speed_scoring
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
| `trigger_threshold_min_goals_in_first_5` | Configured trigger floor (`2` goals in the first 5 minutes) | Explicit trigger provenance for explainability and QA. |
| `match_goals_in_first_5` | Goals scored in the first 5 minutes | Core signal intensity variable. |
| `match_goals_in_first_5_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
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
