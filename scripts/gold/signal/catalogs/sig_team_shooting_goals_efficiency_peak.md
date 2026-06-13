---
signal_id: sig_team_shooting_goals_efficiency_peak
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Efficiency Peak"
trigger: "Team scores >= 4 goals from < 8 total shots in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_efficiency_peak
  sql: clickhouse/gold/signal/sig_team_shooting_goals_efficiency_peak.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_shooting_goals_efficiency_peak

## Purpose

Detect extreme team-level shot economy matches where a side reaches 4+ goals from fewer than 8 total attempts.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_goals >= 4`
  - `triggered_team_total_shots < 8`
- Trigger is evaluated side-by-side for home and away teams in finished matches using `silver.period_stat` at `period = 'All'`.
- Bilateral context is preserved through symmetric `triggered_team_*` and `opponent_*` metrics so analysts can compare volume, conversion, chance quality, and control profile.
- Severity is surfaced with `goals_above_threshold` and `total_shots_below_exclusive_threshold`.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_ruthless_efficiency` and `sig_team_shooting_goals_xg_overperformance_team`; this signal coexists (Option 1) because it is total-shot-efficiency-first (`>= 4` goals from `< 8` total shots), not shots-on-target-threshold-first or xG-threshold-first.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_shooting_goals_efficiency_peak.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_shooting_goals_efficiency_peak`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_shooting_goals_efficiency_peak
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins and deduplication |
| `match_date` | Match date | Football developer: supports temporal analysis and backfill traceability |
| `home_team_id` | Home team identifier | Football developer: preserves bilateral fixture context |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: preserves bilateral fixture context |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home final goals | Football developer: scoreline context for trigger interpretation |
| `away_score` | Away final goals | Football developer: scoreline context for trigger interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered team identifier | Football developer: side-scoped key for downstream joins |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Football developer: preserves bilateral opponent orientation |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral opponent attribution |
| `trigger_threshold_min_goals` | Minimum goal threshold used by trigger (`4`) | Football developer: explicit trigger provenance for QA |
| `trigger_threshold_max_total_shots_exclusive` | Exclusive total-shot ceiling used by trigger (`8`) | Football developer: explicit trigger provenance for QA |
| `triggered_team_goals` | Goals scored by triggered team | Football developer: primary trigger output metric |
| `opponent_goals` | Goals scored by opponent | Football developer: bilateral score comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: compact outcome differential |
| `triggered_team_total_shots` | Total shots by triggered team | Football developer: primary trigger denominator |
| `opponent_total_shots` | Total shots by opponent | Football developer: bilateral shot-volume comparator |
| `total_shots_delta` | Triggered minus opponent total shots | Football developer: net shot-pressure context |
| `triggered_team_shots_on_target` | Shots on target by triggered team | Football developer: execution quality context |
| `opponent_shots_on_target` | Shots on target by opponent | Football developer: bilateral execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Football developer: compact execution differential |
| `triggered_team_shot_accuracy_pct` | Triggered-team shots-on-target share of total shots (%) | Football developer: precision context behind low-shot scoring |
| `opponent_shot_accuracy_pct` | Opponent shots-on-target share of total shots (%) | Football developer: bilateral precision benchmark |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Football developer: net execution-quality gap |
| `triggered_team_goals_per_total_shot` | Triggered-team goals divided by triggered-team total shots | Football developer: core shot-economy intensity metric |
| `opponent_goals_per_total_shot` | Opponent goals divided by opponent total shots | Football developer: bilateral shot-economy comparator |
| `goals_per_total_shot_delta` | Triggered minus opponent goals-per-total-shot ratio | Football developer: direct efficiency edge diagnostic |
| `triggered_team_goal_conversion_pct` | Triggered-team goals per shot on target (%) | Football developer: finishing conversion context |
| `opponent_goal_conversion_pct` | Opponent goals per shot on target (%) | Football developer: bilateral conversion comparator |
| `goal_conversion_delta_pct` | Triggered minus opponent goal conversion (percentage points) | Football developer: compact conversion differential |
| `triggered_team_goals_per_shot_on_target` | Triggered-team goals divided by triggered-team shots on target | Football developer: ratio-form conversion metric for modeling |
| `opponent_goals_per_shot_on_target` | Opponent goals divided by opponent shots on target | Football developer: bilateral ratio baseline |
| `goals_per_shot_on_target_delta` | Triggered minus opponent goals-per-shot-on-target ratio | Football developer: net conversion ratio differential |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: chance-quality baseline |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: net chance-generation context |
| `triggered_team_xg_per_shot` | Triggered-team xG per shot | Football developer: average chance quality per attempt |
| `opponent_xg_per_shot` | Opponent xG per shot | Football developer: bilateral per-shot quality comparator |
| `xg_per_shot_delta` | Triggered minus opponent xG per shot | Football developer: quality-profile differential independent of volume |
| `triggered_team_goals_minus_xg` | Triggered-team goals minus triggered-team xG | Football developer: finishing overperformance intensity |
| `opponent_goals_minus_xg` | Opponent goals minus opponent xG | Football developer: bilateral finishing benchmark |
| `goals_minus_xg_delta` | Triggered minus opponent goals-minus-xG | Football developer: identifies side driving finishing divergence |
| `goals_above_threshold` | Margin above goal trigger (`goals - 4`) | Football developer: trigger severity beyond binary activation |
| `total_shots_below_exclusive_threshold` | Margin below shot ceiling (`8 - total_shots`) | Football developer: trigger severity beyond binary activation |
| `triggered_team_big_chances` | Big chances by triggered team | Football developer: high-value chance volume context |
| `opponent_big_chances` | Big chances by opponent | Football developer: bilateral high-value chance comparator |
| `triggered_team_big_chances_missed` | Big chances missed by triggered team | Football developer: wastefulness context versus scoring output |
| `opponent_big_chances_missed` | Big chances missed by opponent | Football developer: bilateral wastefulness comparator |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in triggered-team box | Football developer: bilateral territorial comparator |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Football developer: control-profile context |
| `opponent_possession_pct` | Opponent possession (%) | Football developer: bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: compact control differential |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Football developer: circulation-volume context |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: build-up execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral build-up execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: compact circulation-quality differential |
| `triggered_team_corners` | Triggered-team corners won | Football developer: attacking pressure proxy |
| `opponent_corners` | Opponent corners won | Football developer: bilateral pressure comparator |
