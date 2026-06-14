---
signal_id: sig_team_shooting_goals_wasteful_box_presence
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Wasteful Box Presence"
trigger: "Team has >= 30 touches in opposition box but scores 0 goals in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_wasteful_box_presence
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_wasteful_box_presence.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_shooting_goals_wasteful_box_presence

## Purpose

Detect team-level matches where penalty-area territorial penetration is extreme (`>= 30` opposition-box touches) but end-product collapses to zero goals.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_touches_opposition_box >= 30`
  - `triggered_team_goals = 0`
- Trigger is evaluated on full-match aggregates (`period = 'All'`) for finished matches only.
- Output remains bilateral with symmetric `triggered_team_*` and `opponent_*` diagnostics across finishing, chance quality, shot execution, possession, circulation, and pressure context.
- Signal intensity beyond binary activation is tracked with `triggered_team_touches_opposition_box_above_threshold` and `touches_opposition_box_delta`.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_blank_range`, `sig_team_shooting_goals_box_siege`, and `sig_match_shooting_goals_goalless_siege`; this signal intentionally coexists because it is box-territory-plus-zero-goals-first, not xG-threshold-first, inside-box shot-count-first, or strict match-level 0-0 logic.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_wasteful_box_presence.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_shooting_goals_wasteful_box_presence`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_shooting_goals_wasteful_box_presence
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
| `home_score` | Home full-time goals | Football developer: scoreline context around wasteful territorial control |
| `away_score` | Away full-time goals | Football developer: scoreline context around wasteful territorial control |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical row identity at match-team grain |
| `triggered_team_id` | Triggered team identifier | Football developer: identity key for triggered-team joins |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-side context |
| `opponent_team_id` | Opponent team identifier | Football developer: preserves bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral opponent context |
| `trigger_threshold_min_touches_opposition_box` | Minimum opposition-box-touch threshold (`30`) | Football developer: explicit trigger-rule provenance |
| `trigger_required_goals` | Trigger-required goals (`0`) | Football developer: explicit trigger-rule provenance |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Football developer: primary territorial trigger metric |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Football developer: bilateral territorial comparator |
| `touches_opposition_box_delta` | Triggered minus opponent opposition-box touches | Football developer: compact box-territory dominance measure |
| `triggered_team_touches_opposition_box_above_threshold` | Margin above touch threshold (`touches - 30`) | Football developer: trigger intensity beyond binary activation |
| `triggered_team_goals` | Goals scored by triggered team | Football developer: core finishing-failure trigger metric |
| `opponent_goals` | Goals scored by opponent | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: outcome context around territorial inefficiency |
| `triggered_team_total_shots` | Total shots by triggered team | Football developer: shot-volume context behind box presence |
| `opponent_total_shots` | Total shots by opponent | Football developer: bilateral shot-volume baseline |
| `total_shots_delta` | Triggered minus opponent total shots | Football developer: net shot-pressure differential |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Football developer: execution context for finishing inefficiency |
| `opponent_shots_on_target` | Opponent shots on target | Football developer: bilateral execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Football developer: compact on-target threat differential |
| `triggered_team_on_target_ratio_pct` | Triggered-team on-target ratio (%) | Football developer: normalized shot-precision context |
| `opponent_on_target_ratio_pct` | Opponent on-target ratio (%) | Football developer: bilateral precision baseline |
| `on_target_ratio_delta_pct` | Triggered minus opponent on-target ratio (%) | Football developer: net execution-quality differential |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: chance-quality context behind zero-goal output |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: net chance-creation differential |
| `triggered_team_goals_minus_xg` | Triggered-team goals minus triggered-team xG | Football developer: direct finishing underperformance magnitude |
| `opponent_goals_minus_xg` | Opponent goals minus opponent xG | Football developer: bilateral finishing benchmark |
| `goals_minus_xg_delta` | Triggered minus opponent goals-minus-xG | Football developer: net finishing efficiency gap |
| `triggered_team_xg_per_shot` | Triggered-team xG per shot | Football developer: average chance quality per attempt |
| `opponent_xg_per_shot` | Opponent xG per shot | Football developer: bilateral chance-quality-per-shot comparator |
| `xg_per_shot_delta` | Triggered minus opponent xG per shot | Football developer: quality differential independent of shot count |
| `triggered_team_big_chances` | Triggered-team big chances created | Football developer: high-value chance context |
| `opponent_big_chances` | Opponent big chances created | Football developer: bilateral high-value chance comparator |
| `triggered_team_big_chances_missed` | Triggered-team big chances missed | Football developer: explicit wastefulness diagnostic |
| `opponent_big_chances_missed` | Opponent big chances missed | Football developer: bilateral wastefulness baseline |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Football developer: control-profile context |
| `opponent_possession_pct` | Opponent possession (%) | Football developer: bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession (%) | Football developer: net control differential |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Football developer: circulation-volume context |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation baseline |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: retention/execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral retention comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Football developer: compact circulation-quality differential |
| `triggered_team_corners` | Triggered-team corners won | Football developer: sustained pressure proxy |
| `opponent_corners` | Opponent corners won | Football developer: bilateral pressure comparator |
