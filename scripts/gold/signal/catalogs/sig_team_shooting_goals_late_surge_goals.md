---
signal_id: sig_team_shooting_goals_late_surge_goals
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Late Surge Goals"
trigger: "Team scores >= 2 non-own goals after the 80th minute (effective minute > 80)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_late_surge_goals
  sql: clickhouse/gold/signal/sig_team_shooting_goals_late_surge_goals.sql
  runner: scripts/gold/signal/runners/sig_team_shooting_goals_late_surge_goals.py
---
# sig_team_shooting_goals_late_surge_goals

## Purpose

Detect team-level late-match scoring bursts where a side scores at least two non-own goals after the 80th minute.

## Tactical And Statistical Logic

- Trigger condition: team records at least two non-own-goal events with `goal_effective_minute > 80`.
- Effective-minute timing uses `goal_time + goal_overload_time` (fallback `minute + minute_added`) so stoppage-time goals are ordered consistently.
- Triggered rows are side-oriented (`triggered_side`) and preserve bilateral context (`triggered_team_*` vs `opponent_*`) for match interpretation.
- Late-phase timing diagnostics include the first and second qualifying goal timestamps plus the gap between them (`minutes_between_first_two_goals_after_80`).
- Similarity gate note: closest active signals are `sig_team_shooting_goals_early_blitz` and `sig_player_shooting_goals_late_winner_clutch`; this signal intentionally coexists because it is team-triggered and focuses on multi-goal late surges regardless of whether a single goal is decisive.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_shooting_goals_late_surge_goals.sql`
- Runner: `scripts/gold/signal/runners/sig_team_shooting_goals_late_surge_goals.py`
- Target table: `gold_signals.sig_team_shooting_goals_late_surge_goals`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_shooting_goals_late_surge_goals.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join key for downstream models and QA |
| `match_date` | Match date | Supports temporal slicing and backfill traceability |
| `home_team_id` | Home team identifier | Preserves fixture orientation |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team identifier | Preserves fixture orientation |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Final-score context for late-surge interpretation |
| `away_score` | Away full-time goals | Final-score context for late-surge interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical row identity at match-team grain |
| `triggered_team_id` | Triggered team identifier | Side-oriented entity key |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Preserves bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Readable bilateral matchup context |
| `trigger_threshold_min_goals_after_80` | Minimum required goals after minute 80 (`2`) | Explicit trigger provenance |
| `trigger_threshold_min_effective_minute` | Minimum effective minute boundary (`80`) | Explicit temporal trigger boundary |
| `triggered_team_goals_after_80` | Triggered-team non-own goals after minute 80 | Core trigger metric |
| `opponent_goals_after_80` | Opponent non-own goals after minute 80 | Bilateral late-phase score comparator |
| `goals_after_80_delta` | Triggered minus opponent goals after minute 80 | Net late-phase scoring dominance signal |
| `triggered_team_first_goal_minute_after_80` | Base minute of first triggered late goal | Timing anchor for surge start |
| `triggered_team_first_goal_added_time_after_80` | Added-time component of first triggered late goal | Stoppage-time precision for sequencing |
| `triggered_team_first_goal_effective_minute_after_80` | Effective minute of first triggered late goal | Normalized chronology across regulation and stoppage time |
| `triggered_team_second_goal_minute_after_80` | Base minute of second triggered late goal | Timing anchor for trigger completion |
| `triggered_team_second_goal_added_time_after_80` | Added-time component of second triggered late goal | Stoppage-time precision for completion timing |
| `triggered_team_second_goal_effective_minute_after_80` | Effective minute of second triggered late goal | Deterministic trigger completion timestamp |
| `minutes_between_first_two_goals_after_80` | Effective-minute gap between first and second late goals | Burst-intensity diagnostic |
| `triggered_team_goals_after_80_above_threshold` | Triggered goals above minimum threshold (`goals - 2`) | Severity ranking beyond binary activation |
| `triggered_team_goals_final` | Triggered-team full-time goals | Connects late surge to final output |
| `opponent_goals_final` | Opponent full-time goals | Bilateral final outcome baseline |
| `goal_delta_final` | Triggered minus opponent full-time goals | Outcome context after late surge |
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
| `triggered_team_big_chances_missed` | Triggered-team big chances missed | Wastefulness context around late conversion |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness baseline |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Control-profile context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control baseline |
| `possession_delta_pct` | Triggered minus opponent possession (%) | Net control indicator |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Circulation volume baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Ball-retention quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral retention comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Differential execution/retention signal |
| `triggered_team_corners` | Triggered-team corners won | Sustained pressure proxy |
| `opponent_corners` | Opponent corners won | Bilateral pressure baseline |
