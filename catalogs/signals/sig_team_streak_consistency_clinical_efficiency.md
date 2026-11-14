---
signal_id: sig_team_streak_consistency_clinical_efficiency
status: active
entity: team
family: streak
subfamily: consistency
grain: match_team
headline: "Clinical Efficiency Span"
trigger: "Team converts > 25% of its shots into goals over its last 3 matches (this match included)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_streak_consistency_clinical_efficiency
  sql: clickhouse/gold/dml/signals/team/sig_team_streak_consistency_clinical_efficiency.sql
---
# sig_team_streak_consistency_clinical_efficiency

## Purpose

Flags a rolling three-match window where goals divided by shots is above 25%, an efficiency (and regression-risk) marker.

## Tactical And Statistical Logic

- Trigger: Team converts > 25% of its shots into goals over its last 3 matches (this match included).
- Conversion is `sum(goals) / sum(total shots) * 100` over the team's last 3 finished matches, with shots from `fotmob_silver.period_stat` (`period = 'All'`). A match without full-match stats is left out of the sequence, so the window is complete only with three matches that have stats. A row is emitted for each match where the 3-match window is complete, holds at least one shot and the conversion is > 25. The sequence is every finished match of the team in `fotmob_silver.match` (all loaded competitions), ordered by `match_date` then `match_id`. Only loaded matches count, so a short history can shorten a real run.
- Similarity note: Closest: `sig_team_shooting_goals_high_quality_only` and `sig_team_shooting_goals_offensive_masterclass` (xG per shot in one match) and `sig_team_shooting_goals_shot_accuracy_collapse`. Different logic: goals per shot over a rolling three-match window. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_streak_consistency_clinical_efficiency.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_streak_consistency_clinical_efficiency`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_streak_consistency_clinical_efficiency
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
| `trigger_threshold_min_window_conversion_pct` | Configured trigger floor (conversion above `25` % over 3 matches) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_window_conversion_pct` | Goals per 100 shots over the last 3 matches, including this match | Core signal intensity variable: how clinical the finishing is. |
| `streak_matches_above_threshold` | Conversion percentage points above the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match inside the window | Anchors the window in time for recency and freshness filters. |
| `triggered_team_streak_wins` | Wins inside the streak | Shows whether the streak is made of wins or draws. |
| `triggered_team_streak_draws` | Draws inside the streak | Shows how much of the streak is stalemates. |
| `triggered_team_streak_goals_scored` | Goals scored across the streak | Attacking output behind the streak. |
| `triggered_team_streak_goals_conceded` | Goals conceded across the streak | Defensive record behind the streak. |
| `triggered_team_window_shots` | Shots over the last 3 matches | Shot volume behind the conversion rate. |
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
