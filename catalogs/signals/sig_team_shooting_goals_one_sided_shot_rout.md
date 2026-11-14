---
signal_id: sig_team_shooting_goals_one_sided_shot_rout
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "One Sided Shot Rout"
trigger: "Team out-shoots the opponent by at least 20 shots in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_shooting_goals_one_sided_shot_rout
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_one_sided_shot_rout.sql
---
# sig_team_shooting_goals_one_sided_shot_rout

## Purpose

Flags overwhelming shot volume, a territorial-dominance marker.

## Tactical And Statistical Logic

- Trigger: Team out-shoots the opponent by at least 20 shots in a finished match.
- The team's `total_shots` minus the opponent's is at least 20 in `fotmob_silver.period_stat` (`period = 'All'`).
- Similarity note: Closest: `sig_team_shooting_goals_total_shot_lockdown` (15 shots against 0) and `sig_team_streak_consistency_total_shot_dominance` (2x shots across matches). Different logic: a +20 shot difference in one match. Related team signals: `sig_team_shooting_goals_rout_win`, `sig_team_shooting_goals_late_surge_goals` and `sig_team_discipline_cards_early_warning`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_one_sided_shot_rout.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_shooting_goals_one_sided_shot_rout`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_one_sided_shot_rout
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
| `trigger_threshold_min_shot_difference` | Configured trigger floor (at least `20` more shots than the opponent) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_shot_difference` | Shots for minus shots against | Core signal intensity variable. |
| `triggered_team_shot_difference_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_team_shots` | Shots by the team | Volume behind the gap. |
| `opponent_shots` | Shots by the opponent | Bilateral comparator. |
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
