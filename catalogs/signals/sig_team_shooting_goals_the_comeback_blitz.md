---
signal_id: sig_team_shooting_goals_the_comeback_blitz
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "The Comeback Blitz"
trigger: "Team scores >= 3 goals in the second half after trailing at half-time in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_shooting_goals_the_comeback_blitz
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_the_comeback_blitz.sql
---
# sig_team_shooting_goals_the_comeback_blitz

## Purpose

Flags a second-half goal blitz from behind, a comeback and half-time-adjustment marker.

## Tactical And Statistical Logic

- Trigger: Team scores >= 3 goals in the second half after trailing at half-time in a finished match.
- Half-time goals are goal rows in `fotmob_silver.shot` with `goal_time <= 45` and second-half goals have `goal_time > 45`; the side comes from `is_home_goal` (own goals are credited to the side that benefits).
- Similarity note: Closest: `sig_team_discipline_cards_man_down_resilience` (a win after an early red), `sig_team_streak_consistency_comeback_kings` (comeback wins across matches) and `sig_team_shooting_goals_half_time_talk_impact`. Different logic: three second-half goals after trailing at the break. Related team signals: `sig_team_shooting_goals_rout_win`, `sig_team_shooting_goals_late_surge_goals` and `sig_team_discipline_cards_early_warning`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_the_comeback_blitz.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_shooting_goals_the_comeback_blitz`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_the_comeback_blitz
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
| `trigger_threshold_min_second_half_goals` | Configured trigger floor (`3` second-half goals after trailing at half-time) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_second_half_goals` | Goals scored in the second half | Core signal intensity variable. |
| `triggered_team_second_half_goals_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_team_half_time_goals` | Goals scored in the first half | Half-time score of the team. |
| `opponent_half_time_goals` | Goals scored by the opponent in the first half | Half-time deficit. |
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
