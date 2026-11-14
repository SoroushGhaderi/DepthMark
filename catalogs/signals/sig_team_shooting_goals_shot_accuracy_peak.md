---
signal_id: sig_team_shooting_goals_shot_accuracy_peak
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Shot Accuracy Peak"
trigger: "Team records more than 70% shot accuracy with at least 10 shots in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_shooting_goals_shot_accuracy_peak
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_shot_accuracy_peak.sql
---
# sig_team_shooting_goals_shot_accuracy_peak

## Purpose

Flags very accurate shooting, a quality-over-quantity marker.

## Tactical And Statistical Logic

- Trigger: Team records more than 70% shot accuracy with at least 10 shots in a finished match.
- Accuracy is `shots_on_target / total_shots` (at least 10 shots). Stats come from `fotmob_silver.period_stat` (`period = 'All'`).
- Similarity note: Closest: `sig_team_shooting_goals_shot_accuracy_collapse` (the opposite, <= 10% from 15 shots) and `sig_player_shooting_goals_sniper_accuracy` (one player). Related shooting signals: `sig_player_shooting_goals_impossible_angle`, `sig_player_shooting_goals_shot_conversion_peak` and `sig_player_shooting_goals_shot_magnet`. Different logic: team accuracy above 70%. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_shot_accuracy_peak.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_shooting_goals_shot_accuracy_peak`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_shot_accuracy_peak
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
| `trigger_threshold_min_shot_accuracy_pct` | Configured trigger floor (more than `70` % shots on target with 10+ shots) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_shot_accuracy_pct` | Shot accuracy (%) | Core signal intensity variable. |
| `triggered_team_shot_accuracy_pct_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_team_shots` | Shots by the team | Volume behind the accuracy. |
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
