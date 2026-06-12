---
signal_id: sig_team_shooting_goals_ruthless_efficiency
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Ruthless Efficiency"
trigger: "Team scores >= 3 goals from <= 5 shots on target in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_ruthless_efficiency
  sql: clickhouse/gold/signal/sig_team_shooting_goals_ruthless_efficiency.sql
  runner: scripts/gold/signal/runners/sig_team_shooting_goals_ruthless_efficiency.py
---
# sig_team_shooting_goals_ruthless_efficiency

## Purpose

Flags teams that produce high goal output from a very low on-target shot volume, capturing extreme finishing efficiency events that often outperform chance volume.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_goals >= 3`
  - `triggered_team_shots_on_target <= 5`
- Trigger evaluation is based on full-match team stats (`period = 'All'`) for finished matches only.
- Tactical enrichment stays bilateral via `triggered_team_*` and `opponent_*` metrics so analysts can compare chance volume, chance quality, and execution between both sides.
- Similarity gate note: closest active signals are `sig_match_possession_passing_clinical_match` and `sig_player_shooting_goals_shot_conversion_peak`; this signal is intentionally distinct because it is team-triggered and keyed to strict goals-vs-on-target efficiency (`>= 3` goals, `<= 5` shots on target) rather than match-total xG divergence or player-level exact shot counts.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_shooting_goals_ruthless_efficiency.sql`
- Runner: `scripts/gold/signal/runners/sig_team_shooting_goals_ruthless_efficiency.py`
- Target table: `gold_signals.sig_team_shooting_goals_ruthless_efficiency`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_shooting_goals_ruthless_efficiency.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins and deduplication |
| `match_date` | Match date | Football developer: temporal slicing and trend analysis |
| `home_team_id` | Home team identifier | Football developer: bilateral match-context anchor |
| `home_team_name` | Home team name | Football developer: readable home-side context |
| `away_team_id` | Away team identifier | Football developer: bilateral match-context anchor |
| `away_team_name` | Away team name | Football developer: readable away-side context |
| `home_score` | Home full-time goals | Football developer: scoreline context for trigger interpretation |
| `away_score` | Away full-time goals | Football developer: scoreline context for trigger interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical side identity for match-team grain |
| `triggered_team_id` | Triggered team identifier | Football developer: side-scoped identity key for downstream joins |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-side context |
| `opponent_team_id` | Opponent team identifier | Football developer: preserves bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral matchup orientation |
| `trigger_threshold_min_goals` | Minimum goals threshold used by trigger (`3`) | Football developer: explicit threshold traceability for QA |
| `trigger_threshold_max_shots_on_target` | Maximum shots-on-target threshold used by trigger (`5`) | Football developer: explicit threshold traceability for QA |
| `triggered_team_goals` | Goals scored by triggered team | Football developer: primary trigger metric |
| `opponent_goals` | Goals scored by opponent | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: outcome context around finishing efficiency |
| `triggered_team_shots_on_target` | Shots on target by triggered team | Football developer: primary trigger denominator |
| `opponent_shots_on_target` | Shots on target by opponent | Football developer: bilateral shot-execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Football developer: compact bilateral shot-execution gap |
| `triggered_team_total_shots` | Total shots by triggered team | Football developer: shot-volume context behind goal output |
| `opponent_total_shots` | Total shots by opponent | Football developer: bilateral shot-volume comparator |
| `triggered_team_shot_accuracy_pct` | Triggered-team shots-on-target share of total shots (%) | Football developer: finishing platform quality context |
| `opponent_shot_accuracy_pct` | Opponent shots-on-target share of total shots (%) | Football developer: bilateral execution-quality comparator |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Football developer: concise execution imbalance diagnostic |
| `triggered_team_goals_per_shot_on_target` | Triggered-team goals divided by triggered-team shots on target | Football developer: core ruthless-efficiency intensity metric |
| `opponent_goals_per_shot_on_target` | Opponent goals divided by opponent shots on target | Football developer: bilateral conversion-efficiency comparator |
| `goals_per_shot_on_target_delta` | Triggered minus opponent goals-per-shot-on-target ratio | Football developer: side-level finishing efficiency edge |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: chance-quality baseline behind scoring output |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: chance-generation balance context |
| `triggered_team_goals_minus_xg` | Triggered-team goals minus triggered-team xG | Football developer: side-level finishing overperformance measure |
| `opponent_goals_minus_xg` | Opponent goals minus opponent xG | Football developer: bilateral finishing overperformance comparator |
| `goals_minus_xg_delta` | Triggered minus opponent goals-minus-xG | Football developer: identifies which side drove conversion outperformance |
| `triggered_team_big_chances` | Big chances by triggered team | Football developer: high-quality chance context for efficiency classification |
| `opponent_big_chances` | Big chances by opponent | Football developer: bilateral high-quality chance comparator |
| `triggered_team_possession_pct` | Triggered-team possession percentage | Football developer: control-profile context around direct scoring efficiency |
| `opponent_possession_pct` | Opponent possession percentage | Football developer: bilateral control-share comparator |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opponent box | Football developer: territorial-penetration context |
| `opponent_touches_opposition_box` | Opponent touches in triggered-team box | Football developer: bilateral territorial comparator |
