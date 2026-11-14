---
signal_id: sig_team_shooting_goals_deadlock_breaking_unit
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Deadlock Breaking Unit"
trigger: "Team scores the first goal of a finished match after minute 70."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_shooting_goals_deadlock_breaking_unit
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_deadlock_breaking_unit.sql
---
# sig_team_shooting_goals_deadlock_breaking_unit

## Purpose

Flags a late opener, a patience and late-breakthrough marker.

## Tactical And Statistical Logic

- Trigger: Team scores the first goal of a finished match after minute 70.
- The first goal is the goal row with the lowest `goal_time` in `fotmob_silver.shot` (side from `is_home_goal`), and it must come after minute 70. The goal rows must add up to the final score, so incomplete goal data cannot make a later goal look first.
- Similarity note: Closest: `sig_match_shooting_goals_deadlock_broken` (a match goalless until 80 with at least 2 goals after) and `sig_match_shooting_goals_clean_sheet_broken_late` (first goal at 89+ in a 0-0). Different logic: the team scores the opener after minute 70. No overlap. Related signals: `sig_player_shooting_goals_freekick_master`, `sig_player_shooting_goals_penalty_composure` and `sig_match_shooting_goals_set_piece_duel`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_deadlock_breaking_unit.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_shooting_goals_deadlock_breaking_unit`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_deadlock_breaking_unit
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
| `trigger_threshold_min_first_goal_minute` | Configured trigger floor (the team's goal is the first of the match and comes after minute `70`) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_first_goal_minute` | Minute of the first goal of the match | Core signal intensity variable. |
| `triggered_team_first_goal_minute_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
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
