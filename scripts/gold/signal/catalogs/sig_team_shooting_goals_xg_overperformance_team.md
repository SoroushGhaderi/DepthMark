---
signal_id: sig_team_shooting_goals_xg_overperformance_team
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Team xG Overperformance"
trigger: "Team scores >= 4 goals from expected_goals < 1.5 in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_xg_overperformance_team
  sql: clickhouse/gold/signal/sig_team_shooting_goals_xg_overperformance_team.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_shooting_goals_xg_overperformance_team

## Purpose

Detect rare team matches where very high scoring output (4+ goals) is produced from low expected-goal totals (`xG < 1.5`), highlighting extreme finishing overperformance.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_goals >= 4`
  - `triggered_team_xg < 1.5`
- Trigger is evaluated on finished matches only using full-match aggregates from `silver.period_stat` (`period = 'All'`).
- Output remains bilateral with symmetric `triggered_team_*` and `opponent_*` features for shot volume, conversion, chance quality, possession, circulation, and territory.
- Signal severity is ranked with `goals_above_threshold`, `expected_goals_below_threshold`, and `triggered_team_goals_minus_xg`.
- Similarity gate note: closest active signal is `sig_team_shooting_goals_ruthless_efficiency`; this signal coexists because it is xG-overperformance-first (`>= 4` goals from `< 1.5` xG) rather than shots-on-target-efficiency-first (`>= 3` goals from `<= 5` shots on target).

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_shooting_goals_xg_overperformance_team.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_shooting_goals_xg_overperformance_team`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_shooting_goals_xg_overperformance_team
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for downstream features and QA |
| `match_date` | Match date | Football developer: temporal slicing and reproducible backfills |
| `home_team_id` | Home team identifier | Football developer: preserves bilateral match context |
| `home_team_name` | Home team name | Football developer: readable home-side attribution |
| `away_team_id` | Away team identifier | Football developer: preserves bilateral match context |
| `away_team_name` | Away team name | Football developer: readable away-side attribution |
| `home_score` | Home final goals | Football developer: scoreline context for interpreting trigger severity |
| `away_score` | Away final goals | Football developer: scoreline context for interpreting trigger severity |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical side orientation at match-team grain |
| `triggered_team_id` | Triggered team identifier | Football developer: primary triggered entity key |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Football developer: preserves bilateral opponent orientation |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral opponent context |
| `trigger_threshold_min_goals` | Minimum goal threshold used by trigger (`4`) | Football developer: explicit trigger-rule provenance |
| `trigger_threshold_max_expected_goals` | Maximum xG threshold used by trigger (`1.5`) | Football developer: explicit trigger-rule provenance |
| `triggered_team_goals` | Goals scored by triggered team | Football developer: primary trigger outcome metric |
| `opponent_goals` | Goals scored by opponent | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: outcome context around overperformance |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: primary trigger quality denominator |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: net chance-generation balance context |
| `triggered_team_goals_minus_xg` | Triggered-team goals minus triggered-team xG | Football developer: direct finishing overperformance intensity metric |
| `opponent_goals_minus_xg` | Opponent goals minus opponent xG | Football developer: bilateral finishing benchmark |
| `goals_minus_xg_delta` | Triggered minus opponent goals-minus-xG | Football developer: isolates which side drove finishing divergence |
| `goals_above_threshold` | Margin above goal trigger (`goals - 4`) | Football developer: trigger severity beyond binary activation |
| `expected_goals_below_threshold` | Margin below xG ceiling (`1.5 - triggered_team_xg`) | Football developer: trigger severity beyond binary activation |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Football developer: finishing-platform volume context |
| `opponent_shots_on_target` | Opponent shots on target | Football developer: bilateral shot-execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Football developer: compact shot-execution pressure differential |
| `triggered_team_total_shots` | Triggered-team total shots | Football developer: volume context behind low-xG high-goal output |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral shot-volume baseline |
| `total_shots_delta` | Triggered minus opponent total shots | Football developer: net shot-pressure differential |
| `triggered_team_goal_conversion_pct` | Triggered-team goals per shot on target (%) | Football developer: conversion-rate context for finishing outlier detection |
| `opponent_goal_conversion_pct` | Opponent goals per shot on target (%) | Football developer: bilateral conversion benchmark |
| `goal_conversion_delta_pct` | Triggered minus opponent goal conversion (percentage points) | Football developer: direct side-to-side conversion gap |
| `triggered_team_goals_per_shot_on_target` | Triggered-team goals divided by triggered-team shots on target | Football developer: ratio-form conversion intensity metric |
| `opponent_goals_per_shot_on_target` | Opponent goals divided by opponent shots on target | Football developer: bilateral ratio baseline |
| `goals_per_shot_on_target_delta` | Triggered minus opponent goals-per-shot-on-target ratio | Football developer: net conversion ratio differential |
| `triggered_team_xg_per_shot` | Triggered-team xG per shot | Football developer: average chance quality per attempt for triggered side |
| `opponent_xg_per_shot` | Opponent xG per shot | Football developer: bilateral average chance-quality comparator |
| `xg_per_shot_delta` | Triggered minus opponent xG per shot | Football developer: quality profile contrast independent of raw volume |
| `triggered_team_big_chances` | Big chances created by triggered team | Football developer: high-quality chance-volume context |
| `opponent_big_chances` | Big chances created by opponent | Football developer: bilateral high-quality chance baseline |
| `triggered_team_big_chances_missed` | Big chances missed by triggered team | Football developer: wastefulness context against high goal output |
| `opponent_big_chances_missed` | Big chances missed by opponent | Football developer: bilateral wastefulness comparator |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Football developer: bilateral territorial baseline |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Football developer: control-profile context around finishing outlier |
| `opponent_possession_pct` | Opponent possession (%) | Football developer: bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Football developer: circulation-volume baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: build-up execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral build-up execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: net circulation quality differential |
| `triggered_team_corners` | Triggered-team corners won | Football developer: set-piece pressure context |
| `opponent_corners` | Opponent corners won | Football developer: bilateral pressure baseline |
