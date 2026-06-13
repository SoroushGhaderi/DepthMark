---
signal_id: sig_team_shooting_goals_half_time_talk_impact
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Half-Time Talk Impact"
trigger: "Team scores >= 2 non-own goals between minutes 46 and 55 (first 10 minutes of second half)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_half_time_talk_impact
  sql: clickhouse/gold/signal/sig_team_shooting_goals_half_time_talk_impact.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_shooting_goals_half_time_talk_impact

## Purpose

Detect team-level post-halftime attacking bursts where a side scores at least two non-own goals in minutes 46-55.

## Tactical And Statistical Logic

- Trigger condition: team records at least two non-own-goal events in the second-half opening window (`goal_minute BETWEEN 46 AND 55`).
- Goal sequencing still uses effective-minute ordering (`goal_time + goal_overload_time`) so stoppage-time ordering remains deterministic for gap and first/second-goal diagnostics.
- Triggered rows are side-oriented (`triggered_side`) and preserve bilateral context (`triggered_team_*` vs `opponent_*`).
- Window context captures first and second qualifying goal timestamps and burst speed (`minutes_between_first_two_goals_first_10_second_half`).
- Similarity gate note: closest active signals are `sig_team_shooting_goals_early_blitz`, `sig_team_shooting_goals_late_surge_goals`, and `sig_match_shooting_goals_game_of_two_halves`; this signal intentionally coexists because it isolates only the immediate second-half opening burst window, not first-half starts, broader late surges, or match-level half-split conjunctions.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_shooting_goals_half_time_talk_impact.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_shooting_goals_half_time_talk_impact`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_shooting_goals_half_time_talk_impact
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join key for downstream features and QA checks |
| `match_date` | Match date | Supports backfills and temporal slicing |
| `home_team_id` | Home team identifier | Preserves bilateral fixture context |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team identifier | Preserves bilateral fixture context |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Final-score context for second-half burst interpretation |
| `away_score` | Away full-time goals | Final-score context for second-half burst interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical row identity at match-team grain |
| `triggered_team_id` | Triggered team identifier | Identity key for side-oriented joins |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Preserves bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator context |
| `trigger_threshold_min_goals_first_10_second_half` | Trigger minimum goals in second-half opening window (`2`) | Explicit trigger provenance |
| `trigger_threshold_second_half_window_start_minute` | Opening-window start minute (`46`) | Explicit temporal trigger boundary |
| `trigger_threshold_second_half_window_end_minute` | Opening-window end minute (`55`) | Explicit temporal trigger boundary |
| `triggered_team_goals_first_10_second_half` | Triggered-team goals in minutes 46-55 | Core trigger metric |
| `opponent_goals_first_10_second_half` | Opponent goals in minutes 46-55 | Bilateral comparator for opening-phase output |
| `goals_first_10_second_half_delta` | Triggered minus opponent goals in minutes 46-55 | Net post-halftime burst dominance signal |
| `triggered_team_first_goal_minute_first_10_second_half` | Minute of first qualifying goal in window | Timing anchor for burst start |
| `triggered_team_first_goal_added_time_first_10_second_half` | Added-time component of first qualifying goal | Stoppage-time precision for sequencing |
| `triggered_team_first_goal_effective_minute_first_10_second_half` | Effective minute of first qualifying goal | Normalized chronology for replayable sequencing |
| `triggered_team_second_goal_minute_first_10_second_half` | Minute of second qualifying goal in window | Timing anchor for trigger completion |
| `triggered_team_second_goal_added_time_first_10_second_half` | Added-time component of second qualifying goal | Stoppage-time precision for completion timing |
| `triggered_team_second_goal_effective_minute_first_10_second_half` | Effective minute of second qualifying goal | Deterministic trigger completion timestamp |
| `minutes_between_first_two_goals_first_10_second_half` | Effective-minute gap between first and second qualifying goals | Burst-intensity diagnostic |
| `triggered_team_goals_first_10_second_half_above_threshold` | Goals above minimum threshold (`goals - 2`) | Severity ranking beyond binary activation |
| `triggered_team_goals_final` | Triggered-team full-time goals | Links opening burst to final output |
| `opponent_goals_final` | Opponent full-time goals | Bilateral final outcome baseline |
| `goal_delta_final` | Triggered minus opponent full-time goals | Outcome context after opening burst |
| `triggered_team_total_shots` | Triggered-team total shots (`period = 'All'`) | Full-match shooting-volume context |
| `opponent_total_shots` | Opponent total shots (`period = 'All'`) | Bilateral shooting-volume baseline |
| `total_shots_delta` | Triggered minus opponent total shots | Net volume pressure indicator |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Shot-execution context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral execution baseline |
| `triggered_team_on_target_ratio_pct` | Triggered-team on-target ratio (%) | Precision proxy for shot execution |
| `opponent_on_target_ratio_pct` | Opponent on-target ratio (%) | Bilateral precision comparator |
| `on_target_ratio_delta_pct` | Triggered minus opponent on-target ratio (%) | Net finishing-precision differential |
| `triggered_team_xg` | Triggered-team expected goals | Chance-quality production context |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality baseline |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-quality edge |
| `triggered_team_big_chances` | Triggered-team big chances | High-quality chance volume diagnostic |
| `opponent_big_chances` | Opponent big chances | Bilateral high-quality chance comparator |
| `triggered_team_big_chances_missed` | Triggered-team big chances missed | Wastefulness context around conversion |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral finishing-variance baseline |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Control-profile context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control baseline |
| `possession_delta_pct` | Triggered minus opponent possession (%) | Net control indicator |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Circulation volume baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Ball-retention quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral retention comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Differential execution/retention signal |
| `triggered_team_corners` | Triggered-team corners | Sustained pressure proxy |
| `opponent_corners` | Opponent corners | Bilateral pressure baseline |
