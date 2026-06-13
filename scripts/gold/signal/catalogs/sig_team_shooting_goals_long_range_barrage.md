---
signal_id: sig_team_shooting_goals_long_range_barrage
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Long-Range Barrage"
trigger: "Team records >= 10 shots from outside the box in one finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_long_range_barrage
  sql: clickhouse/gold/signal/sig_team_shooting_goals_long_range_barrage.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_shooting_goals_long_range_barrage

## Purpose

Detect team-level long-range shooting overloads where a side relies heavily on outside-box attempts (`>= 10`) in a single finished match.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_shots_outside_box >= 10`
- Outside-box scope is defined from shot-location events where the attempt origin is outside the 18-yard box.
- Trigger evaluation is full-match only (`period = 'All'`) and finished matches only.
- Signal output is bilateral (`triggered_team_*` vs `opponent_*`) so analysts can evaluate whether the long-range barrage reflected tactical necessity, shot selection bias, or territorial constraints.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_shooting_gallery` and `sig_player_shooting_goals_long_range_specialist`; this signal is intentionally distinct because it is team-triggered and location-volume-first (outside-box attempts) rather than total shot volume or player-level long-range conversion.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_shooting_goals_long_range_barrage.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_shooting_goals_long_range_barrage`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_shooting_goals_long_range_barrage
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for downstream features and QA checks |
| `match_date` | Match date | Football developer: temporal slicing and reproducible backfills |
| `home_team_id` | Home team identifier | Football developer: bilateral fixture anchor |
| `home_team_name` | Home team name | Football developer: readable home-side context |
| `away_team_id` | Away team identifier | Football developer: bilateral fixture anchor |
| `away_team_name` | Away team name | Football developer: readable away-side context |
| `home_score` | Home full-time goals | Football developer: scoreline context for tactical interpretation |
| `away_score` | Away full-time goals | Football developer: scoreline context for tactical interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical side identity for match-team grain |
| `triggered_team_id` | Triggered team identifier | Football developer: triggered entity identity for joins |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Football developer: readable opponent orientation |
| `trigger_threshold_min_shots_outside_box` | Outside-box shot trigger threshold (`10`) | Football developer: explicit trigger-rule provenance and QA traceability |
| `triggered_team_shots_outside_box` | Outside-box shots by triggered team | Football developer: primary trigger metric |
| `opponent_shots_outside_box` | Outside-box shots by opponent | Football developer: bilateral long-range baseline |
| `shots_outside_box_delta` | Triggered minus opponent outside-box shots | Football developer: net long-range volume dominance diagnostic |
| `triggered_team_total_shots` | Total shots by triggered team | Football developer: denominator for long-range reliance context |
| `opponent_total_shots` | Total shots by opponent | Football developer: bilateral shot-volume comparator |
| `triggered_team_outside_box_shot_share_pct` | Triggered-team outside-box shots as share of total shots (%) | Football developer: direct long-range reliance indicator |
| `opponent_outside_box_shot_share_pct` | Opponent outside-box shots as share of total shots (%) | Football developer: bilateral shot-selection comparator |
| `outside_box_shot_share_delta_pct` | Triggered minus opponent outside-box shot share (percentage points) | Football developer: compact long-range profile imbalance metric |
| `triggered_team_outside_box_shots_on_target` | Outside-box shots on target by triggered team | Football developer: long-range execution quality context |
| `opponent_outside_box_shots_on_target` | Outside-box shots on target by opponent | Football developer: bilateral long-range execution comparator |
| `triggered_team_outside_box_shot_accuracy_pct` | Triggered-team outside-box shots-on-target share (%) | Football developer: precision context for long-range attempts |
| `opponent_outside_box_shot_accuracy_pct` | Opponent outside-box shots-on-target share (%) | Football developer: bilateral precision comparator |
| `outside_box_shot_accuracy_delta_pct` | Triggered minus opponent outside-box shot accuracy (percentage points) | Football developer: net long-range execution differential |
| `triggered_team_outside_box_goals` | Goals scored by triggered team from outside the box | Football developer: long-range end-product intensity context |
| `opponent_outside_box_goals` | Goals scored by opponent from outside the box | Football developer: bilateral long-range scoring comparator |
| `triggered_team_outside_box_xg` | Expected goals generated by triggered team from outside-box shots | Football developer: long-range chance-quality baseline |
| `opponent_outside_box_xg` | Expected goals generated by opponent from outside-box shots | Football developer: bilateral long-range chance-quality comparator |
| `triggered_team_xg` | Total expected goals by triggered team | Football developer: overall chance-quality context |
| `opponent_xg` | Total expected goals by opponent | Football developer: bilateral overall chance-quality baseline |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: net chance-generation context |
| `triggered_team_big_chances` | Big chances by triggered team | Football developer: high-quality chance context versus long-range reliance |
| `opponent_big_chances` | Big chances by opponent | Football developer: bilateral high-value chance comparator |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Football developer: bilateral territorial comparator |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Football developer: control-profile context for shot-location behavior |
| `opponent_possession_pct` | Opponent possession (%) | Football developer: bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control indicator |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Football developer: circulation volume context |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation baseline |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: ball-retention quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral retention comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: control and execution differential |
| `triggered_team_corners` | Corners won by triggered team | Football developer: sustained pressure and repeat-entry proxy |
| `opponent_corners` | Corners won by opponent | Football developer: bilateral pressure comparator |
