---
signal_id: sig_team_shooting_goals_conversion_collapse
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Team Conversion Collapse"
trigger: "Team has >= 10 shots on target but scores exactly 1 goal in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_conversion_collapse
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_conversion_collapse.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_shooting_goals_conversion_collapse

## Purpose

Flag team matches with extreme on-target volume but only one goal, surfacing severe finishing collapse despite sustained shot execution.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_shots_on_target >= 10`
  - `triggered_team_goals = 1`
- Trigger evaluation is full-match only (`period = 'All'`) and restricted to finished matches.
- Output preserves bilateral context (`triggered_team_*` and `opponent_*`) across conversion, xG, shot volume, and control metrics to separate pure finishing failure from overall tactical inferiority.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_blank_range` and `sig_team_shooting_goals_ruthless_efficiency`; this signal is distinct because it isolates high on-target volume with exactly one goal, rather than high-xG zero-goal blanks or low-volume high-goal conversion spikes.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_conversion_collapse.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_shooting_goals_conversion_collapse`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_conversion_collapse
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for downstream features and QA |
| `match_date` | Match date | Football developer: supports temporal slicing and backfills |
| `home_team_id` | Home team identifier | Football developer: preserves bilateral match context |
| `home_team_name` | Home team name | Football developer: analyst-readable home-side context |
| `away_team_id` | Away team identifier | Football developer: preserves bilateral match context |
| `away_team_name` | Away team name | Football developer: analyst-readable away-side context |
| `home_score` | Home full-time goals | Football developer: scoreline context for interpreting finishing collapse |
| `away_score` | Away full-time goals | Football developer: scoreline context for interpreting finishing collapse |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical row orientation at match-team grain |
| `triggered_team_id` | Triggered team identifier | Football developer: triggered-entity identity for joins and features |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-side context |
| `opponent_team_id` | Opponent team identifier | Football developer: preserves bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral matchup orientation |
| `trigger_threshold_min_shots_on_target` | Minimum shots-on-target threshold used by trigger (`10`) | Football developer: explicit trigger-rule traceability |
| `trigger_required_goals` | Exact goals required by trigger (`1`) | Football developer: explicit trigger-rule traceability |
| `triggered_team_goals` | Goals scored by triggered team | Football developer: primary trigger metric |
| `opponent_goals` | Goals scored by opponent | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: outcome context around conversion collapse |
| `triggered_team_shots_on_target` | Shots on target by triggered team | Football developer: primary trigger denominator |
| `opponent_shots_on_target` | Shots on target by opponent | Football developer: bilateral shot-execution baseline |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Football developer: net shot-execution pressure differential |
| `triggered_team_total_shots` | Total shots by triggered team | Football developer: total-volume context behind on-target output |
| `opponent_total_shots` | Total shots by opponent | Football developer: bilateral shot-volume baseline |
| `total_shots_delta` | Triggered minus opponent total shots | Football developer: net shot-pressure differential |
| `triggered_team_goal_conversion_pct` | Triggered-team goals per shot on target (%) | Football developer: core collapse intensity metric in percentage form |
| `opponent_goal_conversion_pct` | Opponent goals per shot on target (%) | Football developer: bilateral conversion comparator |
| `goal_conversion_delta_pct` | Triggered minus opponent goal conversion (percentage points) | Football developer: direct side-vs-side finishing efficiency gap |
| `triggered_team_goals_per_shot_on_target` | Triggered-team goals divided by triggered-team shots on target | Football developer: ratio-form conversion diagnostic for modeling |
| `opponent_goals_per_shot_on_target` | Opponent goals divided by opponent shots on target | Football developer: bilateral ratio baseline |
| `goals_per_shot_on_target_delta` | Triggered minus opponent goals-per-shot-on-target ratio | Football developer: net conversion ratio differential |
| `triggered_team_unconverted_shots_on_target` | Triggered-team on-target shots that did not become goals | Football developer: direct wasted-on-target volume marker |
| `opponent_unconverted_shots_on_target` | Opponent on-target shots that did not become goals | Football developer: bilateral wasted-on-target comparator |
| `unconverted_shots_on_target_delta` | Triggered minus opponent unconverted on-target shots | Football developer: net wastefulness differential |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: chance-quality baseline around conversion collapse |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality baseline |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: net chance-generation context |
| `triggered_team_goals_minus_xg` | Triggered-team goals minus triggered-team xG | Football developer: side-level finishing over/under-performance |
| `opponent_goals_minus_xg` | Opponent goals minus opponent xG | Football developer: bilateral finishing benchmark |
| `goals_minus_xg_delta` | Triggered minus opponent goals-minus-xG | Football developer: net finishing-performance gap across sides |
| `triggered_team_big_chances` | Big chances by triggered team | Football developer: high-quality opportunity context |
| `opponent_big_chances` | Big chances by opponent | Football developer: bilateral chance-quality comparator |
| `triggered_team_big_chances_missed` | Big chances missed by triggered team | Football developer: explicit wastefulness diagnostic |
| `opponent_big_chances_missed` | Big chances missed by opponent | Football developer: bilateral wastefulness baseline |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in triggered-team box | Football developer: bilateral territorial baseline |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Football developer: control-profile context for interpreting trigger severity |
| `opponent_possession_pct` | Opponent possession (%) | Football developer: bilateral control-share baseline |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: compact control differential |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Football developer: circulation-volume context |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: ball-retention execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral retention benchmark |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: net circulation quality differential |
| `triggered_team_corners` | Corners won by triggered team | Football developer: sustained attacking-pressure proxy |
| `opponent_corners` | Corners won by opponent | Football developer: bilateral pressure comparator |
