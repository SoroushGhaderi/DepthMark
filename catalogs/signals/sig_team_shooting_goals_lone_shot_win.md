---
signal_id: sig_team_shooting_goals_lone_shot_win
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Lone Shot Win"
trigger: "Team wins 1-0 while recording only 1 shot on target."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_shooting_goals_lone_shot_win
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_lone_shot_win.sql
---
# sig_team_shooting_goals_lone_shot_win

## Purpose

Flags a one-shot 1-0 win, an efficiency-or-luck marker.

## Tactical And Statistical Logic

- Trigger: Team wins 1-0 while recording only 1 shot on target.
- The final score is 1-0 for the team and the team's `shots_on_target` is exactly 1 in `fotmob_silver.period_stat` (`period = 'All'`).
- Similarity note: Closest: `sig_match_shooting_goals_lone_shot_robbery` (the same win when the opponent has 10+ shots on target) and `sig_player_shooting_goals_one_man_army`. Different logic: any opponent, only the winner's single shot on target matters. Related team signals: `sig_team_shooting_goals_rout_win`, `sig_team_shooting_goals_late_surge_goals` and `sig_team_discipline_cards_early_warning`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_lone_shot_win.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_shooting_goals_lone_shot_win`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_lone_shot_win
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
| `trigger_threshold_exact_shots_on_target` | Configured trigger floor (a 1-0 win with exactly `1` shot on target) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_shots_on_target` | Shots on target by the team | Core signal intensity variable. |
| `triggered_team_shots_on_target_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `opponent_shots_on_target` | Shots on target by the opponent | Shows how one-sided the match was. |
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
