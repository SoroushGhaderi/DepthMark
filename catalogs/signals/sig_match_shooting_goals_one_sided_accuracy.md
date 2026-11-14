---
signal_id: sig_match_shooting_goals_one_sided_accuracy
status: active
entity: match
family: shooting
subfamily: goals
grain: match_team
headline: "One Sided Accuracy"
trigger: "One team has >= 10 shots with >= 8 on target while the other has >= 10 shots and none on target."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_shooting_goals_one_sided_accuracy
  sql: clickhouse/gold/dml/signals/match/sig_match_shooting_goals_one_sided_accuracy.sql
---
# sig_match_shooting_goals_one_sided_accuracy

## Purpose

Flags a stark accuracy gap with equal volume, a finishing-quality marker.

## Tactical And Statistical Logic

- Trigger: One team has >= 10 shots with >= 8 on target while the other has >= 10 shots and none on target.
- Either side has `total_shots >= 10` and `shots_on_target >= 8` while the other side has `total_shots >= 10` and `shots_on_target = 0`, from `fotmob_silver.period_stat`. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_match_shooting_goals_one_sided_shooting` (one side has all the shots on target) and `sig_team_shooting_goals_shot_accuracy_peak`. Related signals: `sig_player_shooting_goals_freekick_master`, `sig_player_shooting_goals_penalty_composure` and `sig_match_shooting_goals_set_piece_duel`. Different logic: equal shot volume with 8 or more versus 0 on target. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_shooting_goals_one_sided_accuracy.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_shooting_goals_one_sided_accuracy`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_shooting_goals_one_sided_accuracy
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
| `trigger_threshold_min_winner_shots_on_target` | Configured trigger floor (one side has `8` shots on target, the other none, both with 10+ shots) | Explicit trigger provenance for explainability and QA. |
| `match_best_shots_on_target` | Shots on target of the accurate side | Core signal intensity variable. |
| `match_best_shots_on_target_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
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
