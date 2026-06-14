---
signal_id: sig_team_shooting_goals_early_blitz
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Early Blitz"
trigger: "Team scores >= 2 non-own goals within the first 15 effective minutes."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_early_blitz
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_early_blitz.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_shooting_goals_early_blitz

## Purpose

Detect team-level explosive starts where a side produces an early two-goal burst inside the first 15 effective minutes.

## Tactical And Statistical Logic

- Trigger condition: team records at least two non-own-goal events with `goal_effective_minute <= 15`.
- Triggered rows are side-oriented (`triggered_side`) and remain bilateral (`triggered_team_*` vs `opponent_*`) for tactical interpretation.
- Early-phase context captures first and second goal timing plus the gap between them (`minutes_between_first_two_goals_first_15`).
- Match-level context adds shooting, chance quality, possession, and passing baselines to assess whether the blitz came from sustainable dominance or short-run finishing variance.
- Similarity gate note: closest active signals are `sig_player_shooting_goals_rapid_brace` and `sig_team_shooting_goals_shooting_gallery`; this signal is distinct because it is team-triggered and explicitly time-windowed to early-match scoring bursts.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_early_blitz.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_shooting_goals_early_blitz`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_shooting_goals_early_blitz
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join key for downstream features and QA checks |
| `match_date` | Match date | Supports backfills and temporal slicing |
| `home_team_id` | Home team identifier | Preserves bilateral team context |
| `home_team_name` | Home team name | Human-readable home-side context |
| `away_team_id` | Away team identifier | Preserves bilateral team context |
| `away_team_name` | Away team name | Human-readable away-side context |
| `home_score` | Home full-time goals | Final-score context for blitz interpretation |
| `away_score` | Away full-time goals | Final-score context for blitz interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical row identity at match-team grain |
| `triggered_team_id` | Triggered team identifier | Identity key for side-oriented joins |
| `triggered_team_name` | Triggered team name | Readable triggered-side context |
| `opponent_team_id` | Opponent team identifier | Preserves matchup orientation |
| `opponent_team_name` | Opponent team name | Readable matchup orientation |
| `trigger_threshold_min_goals_first_15` | Trigger minimum goals in window (`2`) | Explicit trigger traceability |
| `trigger_threshold_window_end_minute` | Trigger window end minute (`15`) | Explicit temporal trigger boundary |
| `triggered_team_goals_first_15` | Triggered-team goals inside first 15 effective minutes | Primary trigger metric |
| `opponent_goals_first_15` | Opponent goals inside first 15 effective minutes | Bilateral early-score comparator |
| `goals_first_15_delta` | Triggered minus opponent early goals | Net early-game dominance indicator |
| `triggered_team_first_goal_minute_first_15` | Triggered-team first early goal minute | Timing anchor for blitz start |
| `triggered_team_first_goal_added_time_first_15` | Added time on first early goal | Separates regulation and stoppage contribution |
| `triggered_team_first_goal_effective_minute_first_15` | Effective minute of first early goal | Stable chronological ordering metric |
| `triggered_team_second_goal_minute_first_15` | Triggered-team second early goal minute | Timing anchor for trigger completion |
| `triggered_team_second_goal_added_time_first_15` | Added time on second early goal | Temporal precision for the second strike |
| `triggered_team_second_goal_effective_minute_first_15` | Effective minute of second early goal | Deterministic trigger timestamp |
| `minutes_between_first_two_goals_first_15` | Effective-minute gap between first two early goals | Measures burst intensity |
| `triggered_team_goals_first_15_above_threshold` | Early goals above trigger minimum | Captures how far the side exceeded baseline |
| `triggered_team_goals_final` | Triggered-team full-time goals | Links early blitz to final output |
| `opponent_goals_final` | Opponent full-time goals | Bilateral final outcome baseline |
| `goal_delta_final` | Triggered minus opponent full-time goals | Outcome context after early surge |
| `triggered_team_total_shots` | Triggered-team total shots (`period = 'All'`) | Shot volume context behind result |
| `opponent_total_shots` | Opponent total shots (`period = 'All'`) | Bilateral shot-volume comparator |
| `total_shots_delta` | Triggered minus opponent total shots | Net volume pressure indicator |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Execution context for chance quality |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral execution baseline |
| `triggered_team_on_target_ratio_pct` | Triggered-team on-target ratio (%) | Precision proxy for shot selection/execution |
| `opponent_on_target_ratio_pct` | Opponent on-target ratio (%) | Bilateral precision comparator |
| `on_target_ratio_delta_pct` | Triggered minus opponent on-target ratio (%) | Compact finishing-precision differential |
| `triggered_team_xg` | Triggered-team expected goals | Chance-quality production context |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality baseline |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-quality advantage |
| `triggered_team_big_chances` | Triggered-team big chances | High-quality chance volume diagnostic |
| `opponent_big_chances` | Opponent big chances | Bilateral high-quality chance comparator |
| `triggered_team_big_chances_missed` | Triggered-team big chances missed | Wastefulness context alongside early conversion |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral finishing-variance baseline |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Match-control context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control baseline |
| `possession_delta_pct` | Triggered minus opponent possession (%) | Net control indicator |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Circulation volume baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Ball-retention quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral retention comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Differential execution/retention signal |
| `triggered_team_corners` | Triggered-team corners | Sustained pressure proxy |
| `opponent_corners` | Opponent corners | Bilateral pressure baseline |
