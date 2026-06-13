---
signal_id: sig_team_shooting_goals_shot_shy
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Shot Shy"
trigger: "Team records 0 total shots in at least one half (`FirstHalf` or `SecondHalf`) in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_shot_shy
  sql: clickhouse/gold/signal/sig_team_shooting_goals_shot_shy.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_shooting_goals_shot_shy

## Purpose

Detect team-level half-game attacking droughts where a side fails to take a single shot in at least one half.

## Tactical And Statistical Logic

- Trigger condition: `triggered_team_shots_first_half = 0` OR `triggered_team_shots_second_half = 0`.
- Half splits are computed from `silver.period_stat` using `period IN ('FirstHalf', 'SecondHalf')`.
- Trigger evaluation is restricted to finished matches only.
- The signal emits one row per `match_id` + `triggered_side`; `triggered_half_without_shot` is `FirstHalf`, `SecondHalf`, or `BothHalves`.
- Full-match bilateral context (`period = 'All'`) is preserved for scoreline, shot quality, chance volume, and control interpretation.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_no_shots_allowed` and `sig_team_shooting_goals_blank_range`; this signal is distinct because it is half-level own-shot suppression (volume drought), not opponent-on-target suppression or high-xG finishing failure.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_shooting_goals_shot_shy.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_shooting_goals_shot_shy`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_shooting_goals_shot_shy
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for QA, features, and reporting |
| `match_date` | Match date | Football developer: supports temporal slicing and backfill traceability |
| `home_team_id` | Home team identifier | Football developer: preserves bilateral match context |
| `home_team_name` | Home team name | Football developer: readable home-side context |
| `away_team_id` | Away team identifier | Football developer: preserves bilateral match context |
| `away_team_name` | Away team name | Football developer: readable away-side context |
| `home_score` | Home full-time goals | Football developer: scoreline context for trigger interpretation |
| `away_score` | Away full-time goals | Football developer: scoreline context for trigger interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical row identity for `match_team` grain |
| `triggered_team_id` | Triggered team identifier | Football developer: triggered-side identity key for joins |
| `triggered_team_name` | Triggered team name | Football developer: analyst-readable triggered entity |
| `opponent_team_id` | Opponent team identifier | Football developer: preserves matchup orientation |
| `opponent_team_name` | Opponent team name | Football developer: analyst-readable matchup orientation |
| `trigger_threshold_max_shots_per_half` | Trigger threshold for half-level shots (`0`) | Football developer: explicit trigger boundary for reproducibility |
| `triggered_half_without_shot` | Half label where trigger fired (`FirstHalf`, `SecondHalf`, `BothHalves`) | Football developer: direct tactical interpretation of drought timing |
| `triggered_team_shots_first_half` | Triggered-team shots in first half | Football developer: first-half trigger component |
| `triggered_team_shots_second_half` | Triggered-team shots in second half | Football developer: second-half trigger component |
| `opponent_shots_first_half` | Opponent shots in first half | Football developer: bilateral first-half comparator |
| `opponent_shots_second_half` | Opponent shots in second half | Football developer: bilateral second-half comparator |
| `triggered_team_zero_shot_first_half_flag` | 1 if triggered team had zero first-half shots, else 0 | Football developer: explicit trigger decomposition |
| `triggered_team_zero_shot_second_half_flag` | 1 if triggered team had zero second-half shots, else 0 | Football developer: explicit trigger decomposition |
| `opponent_zero_shot_first_half_flag` | 1 if opponent had zero first-half shots, else 0 | Football developer: bilateral half-level suppression context |
| `opponent_zero_shot_second_half_flag` | 1 if opponent had zero second-half shots, else 0 | Football developer: bilateral half-level suppression context |
| `half_shot_gap_first_half` | Triggered minus opponent first-half shots | Football developer: first-half shot-pressure differential |
| `half_shot_gap_second_half` | Triggered minus opponent second-half shots | Football developer: second-half shot-pressure differential |
| `triggered_team_goals` | Goals scored by triggered team | Football developer: outcome context around shot drought |
| `opponent_goals` | Goals scored by opponent | Football developer: bilateral scoreline baseline |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: compact match-outcome differential |
| `triggered_team_total_shots` | Triggered-team total match shots (`period = 'All'`) | Football developer: full-match shot volume context |
| `opponent_total_shots` | Opponent total match shots (`period = 'All'`) | Football developer: bilateral full-match shot baseline |
| `total_shots_delta` | Triggered minus opponent total shots | Football developer: net shot-pressure context |
| `triggered_team_shots_on_target` | Triggered-team shots on target (`period = 'All'`) | Football developer: shot execution context |
| `opponent_shots_on_target` | Opponent shots on target (`period = 'All'`) | Football developer: bilateral shot execution baseline |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Football developer: net on-target pressure differential |
| `triggered_team_on_target_ratio_pct` | Triggered-team shots-on-target ratio (%) | Football developer: triggered-side precision indicator |
| `opponent_on_target_ratio_pct` | Opponent shots-on-target ratio (%) | Football developer: bilateral precision comparator |
| `on_target_ratio_delta_pct` | Triggered minus opponent on-target ratio (percentage points) | Football developer: compact execution-quality gap |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: full-match chance-quality context |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality baseline |
| `xg_delta` | Triggered-team xG minus opponent xG | Football developer: net chance-generation differential |
| `triggered_team_big_chances` | Triggered-team big chances | Football developer: high-quality chance context |
| `opponent_big_chances` | Opponent big chances | Football developer: bilateral high-quality chance baseline |
| `triggered_team_big_chances_missed` | Triggered-team big chances missed | Football developer: finishing wastefulness context |
| `opponent_big_chances_missed` | Opponent big chances missed | Football developer: bilateral wastefulness comparator |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Football developer: bilateral territorial comparator |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Football developer: control-profile context |
| `opponent_possession_pct` | Opponent possession (%) | Football developer: bilateral control-share baseline |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: compact control differential |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Football developer: circulation-volume context |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation baseline |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: triggered-side retention quality |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral retention baseline |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: net circulation-quality differential |
| `triggered_team_corners` | Triggered-team corners | Football developer: sustained attacking-pressure proxy |
| `opponent_corners` | Opponent corners | Football developer: bilateral pressure comparator |
