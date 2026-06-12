---
signal_id: sig_team_shooting_goals_box_siege
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Box Siege"
trigger: "Team records >= 20 shots from inside the penalty area in one finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_box_siege
  sql: clickhouse/gold/signal/sig_team_shooting_goals_box_siege.sql
  runner: scripts/gold/signal/runners/sig_team_shooting_goals_box_siege.py
---
# sig_team_shooting_goals_box_siege

## Purpose

Detect team-level penalty-area shot sieges where one side generates extreme inside-box volume (`>= 20`) in a single finished match.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_shots_inside_box >= 20`
- Inside-box scope uses shot-location events where the attempt origin is inside the penalty area.
- Trigger evaluation is full-match only (`period = 'All'`) and finished matches only.
- Signal output remains bilateral (`triggered_team_*` vs `opponent_*`) to separate true box pressure dominance from game-state inflation.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_shooting_gallery` and `sig_team_shooting_goals_long_range_barrage`; this signal coexists because it is zone-specific (inside-box volume) rather than total-shot volume or outside-box reliance.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_shooting_goals_box_siege.sql`
- Runner: `scripts/gold/signal/runners/sig_team_shooting_goals_box_siege.py`
- Target table: `gold_signals.sig_team_shooting_goals_box_siege`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_shooting_goals_box_siege.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for downstream feature pipelines and QA |
| `match_date` | Match date | Football developer: temporal slicing and reproducible backfills |
| `home_team_id` | Home team identifier | Football developer: bilateral fixture anchor |
| `home_team_name` | Home team name | Football developer: readable home-side attribution |
| `away_team_id` | Away team identifier | Football developer: bilateral fixture anchor |
| `away_team_name` | Away team name | Football developer: readable away-side attribution |
| `home_score` | Home full-time goals | Football developer: scoreline context for pressure interpretation |
| `away_score` | Away full-time goals | Football developer: scoreline context for pressure interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical side identity at match-team grain |
| `triggered_team_id` | Triggered team identifier | Football developer: triggered entity identity for joins |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Football developer: readable opponent orientation |
| `trigger_threshold_min_shots_inside_box` | Inside-box shot trigger threshold (`20`) | Football developer: explicit trigger-rule provenance and QA traceability |
| `triggered_team_shots_inside_box` | Inside-box shots by triggered team | Football developer: primary trigger metric |
| `opponent_shots_inside_box` | Inside-box shots by opponent | Football developer: bilateral box-entry shot baseline |
| `shots_inside_box_delta` | Triggered minus opponent inside-box shots | Football developer: net penalty-area shot dominance diagnostic |
| `triggered_team_total_shots` | Total shots by triggered team | Football developer: denominator for inside-box shot profile context |
| `opponent_total_shots` | Total shots by opponent | Football developer: bilateral shot-volume comparator |
| `triggered_team_inside_box_shot_share_pct` | Triggered-team inside-box shots as share of total shots (%) | Football developer: direct penalty-area shot-profile indicator |
| `opponent_inside_box_shot_share_pct` | Opponent inside-box shots as share of total shots (%) | Football developer: bilateral shot-profile comparator |
| `inside_box_shot_share_delta_pct` | Triggered minus opponent inside-box shot share (percentage points) | Football developer: compact profile imbalance measure |
| `triggered_team_inside_box_shots_on_target` | Inside-box shots on target by triggered team | Football developer: box-finishing execution context |
| `opponent_inside_box_shots_on_target` | Inside-box shots on target by opponent | Football developer: bilateral execution comparator |
| `triggered_team_inside_box_shot_accuracy_pct` | Triggered-team inside-box shots-on-target share (%) | Football developer: precision context for penalty-area shot selection |
| `opponent_inside_box_shot_accuracy_pct` | Opponent inside-box shots-on-target share (%) | Football developer: bilateral precision comparator |
| `inside_box_shot_accuracy_delta_pct` | Triggered minus opponent inside-box shot accuracy (percentage points) | Football developer: net penalty-area execution differential |
| `triggered_team_inside_box_goals` | Goals scored by triggered team from inside-box shots | Football developer: inside-box end-product intensity context |
| `opponent_inside_box_goals` | Goals scored by opponent from inside-box shots | Football developer: bilateral inside-box scoring comparator |
| `triggered_team_inside_box_xg` | Expected goals generated by triggered team from inside-box shots | Football developer: penalty-area chance-quality baseline |
| `opponent_inside_box_xg` | Expected goals generated by opponent from inside-box shots | Football developer: bilateral penalty-area chance-quality comparator |
| `triggered_team_xg` | Total expected goals by triggered team | Football developer: overall chance-quality context |
| `opponent_xg` | Total expected goals by opponent | Football developer: bilateral overall chance-quality baseline |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: net chance-generation context |
| `triggered_team_big_chances` | Big chances by triggered team | Football developer: high-value chance context behind box pressure |
| `opponent_big_chances` | Big chances by opponent | Football developer: bilateral high-value chance comparator |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Football developer: bilateral territorial comparator |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Football developer: control-profile context for siege behavior |
| `opponent_possession_pct` | Opponent possession (%) | Football developer: bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control indicator |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Football developer: circulation-volume context |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation baseline |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: ball-retention quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral retention comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: control and execution differential |
| `triggered_team_corners` | Corners won by triggered team | Football developer: sustained pressure and repeat-entry proxy |
| `opponent_corners` | Corners won by opponent | Football developer: bilateral pressure comparator |
