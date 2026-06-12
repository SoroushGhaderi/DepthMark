---
signal_id: sig_match_shooting_goals_distance_shooting_duel
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Distance Shooting Duel"
trigger: "Both teams score from outside the penalty area in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_shooting_goals_distance_shooting_duel
  sql: clickhouse/gold/signal/sig_match_shooting_goals_distance_shooting_duel.sql
  runner: scripts/gold/signal/runners/sig_match_shooting_goals_distance_shooting_duel.py
---
# sig_match_shooting_goals_distance_shooting_duel

## Purpose

Detect finished matches where both sides convert at least one outside-box goal, then emit side-oriented long-range finishing, chance-quality, and control context.

## Tactical And Statistical Logic

- Trigger condition:
  - `home_outside_box_goals >= 1`
  - `away_outside_box_goals >= 1`
- Outside-box goal counts are derived from `silver.shot` where `is_from_inside_box = 0`, `is_goal = 1`, and `is_own_goal = 0`.
- Match-level trigger emits two rows (`triggered_side = 'home'` and `'away'`) to preserve canonical `match_team` grain.
- Similarity gate note: closest active signals are `sig_match_shooting_goals_shot_efficiency_parity`, `sig_match_shooting_goals_rapid_fire_exchange`, and `sig_team_shooting_goals_long_range_barrage`; this signal intentionally coexists because it is match-level and specifically requires bilateral outside-box scoring conversion, not parity on generic shot outputs, time-window exchange behavior, or one-team outside-box shot-volume overload.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_shooting_goals_distance_shooting_duel.sql`
- Runner: `scripts/gold/signal/runners/sig_match_shooting_goals_distance_shooting_duel.py`
- Target table: `gold_signals.sig_match_shooting_goals_distance_shooting_duel`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_shooting_goals_distance_shooting_duel.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for joins and deduplication. |
| `match_date` | Match date | Temporal slicing and reproducible backfills. |
| `home_team_id` | Home team identifier | Preserves fixture orientation. |
| `home_team_name` | Home team name | Readable fixture context. |
| `away_team_id` | Away team identifier | Preserves fixture orientation. |
| `away_team_name` | Away team name | Readable fixture context. |
| `home_score` | Home full-time goals | Scoreline context for long-range duel interpretation. |
| `away_score` | Away full-time goals | Scoreline context for long-range duel interpretation. |
| `triggered_side` | Row orientation (`home` or `away`) | Canonical side identity at `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Side-level join key. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator context. |
| `trigger_threshold_min_outside_box_goals_per_team` | Trigger minimum outside-box goals per side (`1`) | Explicit trigger provenance for QA. |
| `both_teams_scored_outside_box_flag` | Bilateral trigger flag (`1` when both sides satisfy trigger) | Fast sanity check for downstream consumers. |
| `home_outside_box_goals` | Outside-box goals by home side | Direct trigger audit component. |
| `away_outside_box_goals` | Outside-box goals by away side | Direct trigger audit component. |
| `match_total_outside_box_goals` | Combined outside-box goals in match | Captures total duel intensity. |
| `match_total_outside_box_xg` | Combined outside-box xG in match | Chance-quality baseline for long-range scoring. |
| `triggered_team_outside_box_goals` | Outside-box goals by triggered side | Side-oriented core long-range output metric. |
| `opponent_outside_box_goals` | Outside-box goals by opponent side | Bilateral long-range scoring comparator. |
| `outside_box_goals_delta` | Triggered minus opponent outside-box goals | Net long-range scoring edge. |
| `triggered_team_outside_box_xg` | Outside-box xG by triggered side | Side-level long-range chance quality. |
| `opponent_outside_box_xg` | Outside-box xG by opponent side | Bilateral long-range chance-quality comparator. |
| `outside_box_xg_delta` | Triggered minus opponent outside-box xG | Net long-range chance-quality edge. |
| `triggered_team_outside_box_shots` | Outside-box shots by triggered side | Long-range attempt volume context. |
| `opponent_outside_box_shots` | Outside-box shots by opponent side | Bilateral long-range attempt comparator. |
| `outside_box_shot_volume_delta` | Triggered minus opponent outside-box shots | Net long-range volume differential. |
| `triggered_team_outside_box_shots_on_target` | Outside-box shots on target by triggered side | Long-range execution precision context. |
| `opponent_outside_box_shots_on_target` | Outside-box shots on target by opponent side | Bilateral long-range precision comparator. |
| `outside_box_shots_on_target_delta` | Triggered minus opponent outside-box shots on target | Net long-range on-target edge. |
| `triggered_team_outside_box_shot_accuracy_pct` | Triggered-side outside-box shot accuracy (%) | Normalized long-range precision metric. |
| `opponent_outside_box_shot_accuracy_pct` | Opponent outside-box shot accuracy (%) | Bilateral normalized precision comparator. |
| `outside_box_shot_accuracy_delta_pct` | Triggered minus opponent outside-box shot accuracy (percentage points) | Compact long-range precision imbalance metric. |
| `triggered_team_outside_box_goal_conversion_pct` | Triggered-side outside-box goal conversion (%) | Normalized long-range finishing efficiency. |
| `opponent_outside_box_goal_conversion_pct` | Opponent outside-box goal conversion (%) | Bilateral long-range finishing comparator. |
| `outside_box_goal_conversion_delta_pct` | Triggered minus opponent outside-box conversion (percentage points) | Net long-range finishing efficiency differential. |
| `triggered_team_goals` | Goals by triggered side | Match outcome context. |
| `opponent_goals` | Goals by opponent side | Bilateral outcome comparator. |
| `goal_gap` | Triggered minus opponent goals | Score differential context. |
| `triggered_team_total_shots` | Total shots by triggered side | Overall shot-volume context. |
| `opponent_total_shots` | Total shots by opponent side | Bilateral shot-volume comparator. |
| `shot_volume_delta` | Triggered minus opponent total shots | Net attacking-volume differential. |
| `triggered_team_shots_on_target` | Shots on target by triggered side | Overall execution-quality context. |
| `opponent_shots_on_target` | Shots on target by opponent side | Bilateral execution comparator. |
| `shot_on_target_delta` | Triggered minus opponent shots on target | Net on-target differential. |
| `triggered_team_shot_accuracy_pct` | Triggered-side total shot accuracy (%) | General precision baseline beyond long-range subset. |
| `opponent_shot_accuracy_pct` | Opponent total shot accuracy (%) | Bilateral general precision comparator. |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Net general precision differential. |
| `triggered_team_xg` | xG by triggered side | Overall chance-quality context. |
| `opponent_xg` | xG by opponent side | Bilateral chance-quality comparator. |
| `xg_gap` | Triggered minus opponent xG | Net chance-quality differential. |
| `triggered_team_big_chances` | Big chances by triggered side | High-value chance-volume context. |
| `opponent_big_chances` | Big chances by opponent side | Bilateral high-value chance comparator. |
| `big_chance_delta` | Triggered minus opponent big chances | Net big-chance differential. |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Territorial penetration context. |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial comparator. |
| `opposition_box_touch_delta` | Triggered minus opponent opposition-box touches | Net territory-pressure differential. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Compact control differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Circulation execution context. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation-quality comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Net circulation-quality differential. |
