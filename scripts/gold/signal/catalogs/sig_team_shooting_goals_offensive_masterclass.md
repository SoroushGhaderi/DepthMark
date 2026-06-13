---
signal_id: sig_team_shooting_goals_offensive_masterclass
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Offensive Masterclass"
trigger: "Team records xG per shot > 0.20 (high quality chances) in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_offensive_masterclass
  sql: clickhouse/gold/signal/sig_team_shooting_goals_offensive_masterclass.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_shooting_goals_offensive_masterclass

## Purpose

Detect team matches where average chance quality per shot is elite (`xG per shot > 0.20`), surfacing compact high-quality attacking profiles rather than volume-heavy shooting alone.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_xg_per_shot > 0.20`
- Trigger is evaluated on finished matches only using full-match aggregates from `silver.period_stat` (`period = 'All'`).
- Signal keeps bilateral context with symmetric `triggered_team_*` and `opponent_*` metrics for chance quality, shot volume, execution, possession, circulation, and territory.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_shooting_gallery` and `sig_team_shooting_goals_xg_overperformance_team`; this signal intentionally coexists because it is average-chance-quality-first (`xG per shot > 0.20`) and does not require extreme shot volume or extreme goal-vs-xG outperformance.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_shooting_goals_offensive_masterclass.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_shooting_goals_offensive_masterclass`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_shooting_goals_offensive_masterclass
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for downstream features and QA |
| `match_date` | Match date | Football developer: supports temporal slicing and reproducible backfills |
| `home_team_id` | Home team identifier | Football developer: preserves bilateral match context |
| `home_team_name` | Home team name | Football developer: readable home-side attribution |
| `away_team_id` | Away team identifier | Football developer: preserves bilateral match context |
| `away_team_name` | Away team name | Football developer: readable away-side attribution |
| `home_score` | Home final goals | Football developer: scoreline context for trigger interpretation |
| `away_score` | Away final goals | Football developer: scoreline context for trigger interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical side orientation at match-team grain |
| `triggered_team_id` | Triggered team identifier | Football developer: primary triggered entity key |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Football developer: preserves bilateral opponent orientation |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral opponent context |
| `trigger_threshold_min_xg_per_shot` | Minimum xG-per-shot threshold used by trigger (`0.20`) | Football developer: explicit trigger-rule provenance |
| `triggered_team_xg_per_shot` | Triggered-team xG per shot | Football developer: primary trigger metric for average chance quality |
| `opponent_xg_per_shot` | Opponent xG per shot | Football developer: bilateral average shot-quality comparator |
| `xg_per_shot_delta` | Triggered minus opponent xG per shot | Football developer: net chance-quality profile differential |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: chance-quality volume baseline behind per-shot average |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: net chance-generation balance context |
| `triggered_team_total_shots` | Triggered-team total shots | Football developer: denominator volume context for xG-per-shot interpretation |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral shot-volume baseline |
| `total_shots_delta` | Triggered minus opponent total shots | Football developer: net shot-pressure differential |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Football developer: execution-quality volume context |
| `opponent_shots_on_target` | Opponent shots on target | Football developer: bilateral execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Football developer: compact execution-pressure differential |
| `triggered_team_on_target_ratio_pct` | Triggered-team on-target ratio (%) | Football developer: precision context around high average chance quality |
| `opponent_on_target_ratio_pct` | Opponent on-target ratio (%) | Football developer: bilateral precision comparator |
| `on_target_ratio_delta_pct` | Triggered minus opponent on-target ratio (%) | Football developer: net shot-precision differential |
| `triggered_team_goals` | Goals scored by triggered team | Football developer: conversion outcome context |
| `opponent_goals` | Goals scored by opponent | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: match outcome context |
| `triggered_team_big_chances` | Big chances created by triggered team | Football developer: high-quality chance-volume context |
| `opponent_big_chances` | Big chances created by opponent | Football developer: bilateral high-quality chance baseline |
| `triggered_team_big_chances_missed` | Big chances missed by triggered team | Football developer: wastefulness context against quality profile |
| `opponent_big_chances_missed` | Big chances missed by opponent | Football developer: bilateral wastefulness comparator |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Football developer: bilateral territorial baseline |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Football developer: control-profile context around chance quality |
| `opponent_possession_pct` | Opponent possession (%) | Football developer: bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession (%) | Football developer: net control differential |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Football developer: circulation-volume baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: build-up execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral build-up execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Football developer: net circulation-execution differential |
| `triggered_team_corners` | Triggered-team corners won | Football developer: sustained pressure proxy complementing shot-quality profile |
| `opponent_corners` | Opponent corners won | Football developer: bilateral pressure baseline |
