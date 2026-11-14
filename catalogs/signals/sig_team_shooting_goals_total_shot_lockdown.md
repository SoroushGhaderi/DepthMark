---
signal_id: sig_team_shooting_goals_total_shot_lockdown
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Total Shot Lockdown"
trigger: "Team takes >= 15 shots while allowing none at all in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_shooting_goals_total_shot_lockdown
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_total_shot_lockdown.sql
---
# sig_team_shooting_goals_total_shot_lockdown

## Purpose

Flags total shot dominance, a one-way match marker.

## Tactical And Statistical Logic

- Trigger: Team takes >= 15 shots while allowing none at all in a finished match.
- The team's `total_shots` is at least 15 and the opponent's `total_shots` is 0 (the opponent stat must exist). Stats come from `fotmob_silver.period_stat` (`period = 'All'`).
- Similarity note: Closest: `sig_team_shooting_goals_no_shots_allowed` (0 opponent shots on target) and `sig_match_shooting_goals_one_sided_shooting`. Related shooting signals: `sig_player_shooting_goals_impossible_angle`, `sig_player_shooting_goals_shot_conversion_peak` and `sig_player_shooting_goals_shot_magnet`. Different logic: 15 or more shots for and none against. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_total_shot_lockdown.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_shooting_goals_total_shot_lockdown`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_total_shot_lockdown
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
| `trigger_threshold_min_shots_for` | Configured trigger floor (`15` shots for and 0 against) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_shots` | Shots by the team | Core signal intensity variable. |
| `triggered_team_shots_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
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
