---
signal_id: sig_team_creativity_playmaking_crossing_volume_efficiency
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Crossing Volume Efficiency"
trigger: "Team completes >= 8 crosses from more than 25 attempts in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_creativity_playmaking_crossing_volume_efficiency
  sql: clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_crossing_volume_efficiency.sql
---
# sig_team_creativity_playmaking_crossing_volume_efficiency

## Purpose

Flags high-volume, productive crossing, a wide-play marker.

## Tactical And Statistical Logic

- Trigger: Team completes >= 8 crosses from more than 25 attempts in a finished match.
- Completed crosses are `accurate_crosses` and attempts are `cross_attempts` in `fotmob_silver.period_stat`. Stats come from `fotmob_silver.period_stat` (`period = 'All'`).
- Similarity note: Closest: `sig_team_creativity_playmaking_crossing_clinic` (>= 10 completed crosses) and `sig_team_possession_passing_cross_spam`. Related creativity signals: `sig_team_creativity_playmaking_chance_barrage`, `sig_team_creativity_playmaking_midfield_engine_vision` and `sig_match_creativity_playmaking_the_creativity_clash`. Different logic: at least 8 completed crosses from a volume above 25. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_crossing_volume_efficiency.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_creativity_playmaking_crossing_volume_efficiency`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_creativity_playmaking_crossing_volume_efficiency
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
| `trigger_threshold_min_completed_crosses` | Configured trigger floor (`8` completed crosses from more than 25 attempts) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_completed_crosses` | Completed crosses | Core signal intensity variable. |
| `triggered_team_completed_crosses_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_team_cross_attempts` | Crosses attempted | Volume behind the completions. |
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
