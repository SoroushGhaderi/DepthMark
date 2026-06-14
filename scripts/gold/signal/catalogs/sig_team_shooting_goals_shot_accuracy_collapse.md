---
signal_id: sig_team_shooting_goals_shot_accuracy_collapse
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Shot Accuracy Collapse"
trigger: "Team has at least 15 shots and shot accuracy is at most 10% in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_shot_accuracy_collapse
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_shot_accuracy_collapse.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_shooting_goals_shot_accuracy_collapse

## Purpose

Detect high-volume team shooting performances where execution collapses, measured as very low on-target precision despite sustained attempt volume.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_total_shots >= 15`
  - `triggered_team_shot_accuracy_pct <= 10.0`
- Trigger evaluation is full-match only (`period = 'All'`) and restricted to finished matches.
- Signal emits side-oriented rows (`triggered_side`) with bilateral `triggered_team_*` and `opponent_*` context.
- Enrichment preserves shot volume, conversion, xG-per-shot, chance quality, territorial pressure, and control baselines.
- Similarity gate note:
  - Closest active signals are `sig_team_shooting_goals_shooting_gallery`, `sig_match_shooting_goals_high_volume_low_target`, and `sig_team_shooting_goals_conversion_collapse`.
  - This signal is distinct because it is team-level precision-collapse logic (`>= 15` shots with `<= 10%` on-target rate), not pure volume, match-combined inefficiency, or high-on-target conversion failure.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_shot_accuracy_collapse.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_shooting_goals_shot_accuracy_collapse`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_shooting_goals_shot_accuracy_collapse
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join and dedup key |
| `match_date` | Match date | Temporal slicing and backfill reproducibility |
| `home_team_id` | Home team identifier | Preserves fixture orientation |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team identifier | Preserves fixture orientation |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Outcome context around trigger |
| `away_score` | Away full-time goals | Outcome context around trigger |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical match-team row identity |
| `triggered_team_id` | Triggered team identifier | Side-level identity key |
| `triggered_team_name` | Triggered team name | Readable side attribution |
| `opponent_team_id` | Opponent team identifier | Bilateral comparator key |
| `opponent_team_name` | Opponent team name | Readable opponent context |
| `trigger_threshold_min_total_shots` | Minimum shot-volume trigger threshold (`15`) | Explicit trigger provenance |
| `trigger_threshold_max_shot_accuracy_pct` | Maximum shot-accuracy trigger threshold (`10.0`) | Explicit trigger provenance |
| `triggered_team_total_shots` | Total shots by triggered side | Core trigger volume component |
| `opponent_total_shots` | Total shots by opponent side | Bilateral volume comparator |
| `total_shots_delta` | Triggered minus opponent total shots | Net shot-volume edge |
| `triggered_team_shots_on_target` | Shots on target by triggered side | Core trigger precision numerator |
| `opponent_shots_on_target` | Shots on target by opponent side | Bilateral precision comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Net on-target differential |
| `triggered_team_shot_accuracy_pct` | Triggered-side on-target ratio (%) | Core trigger precision metric |
| `opponent_shot_accuracy_pct` | Opponent on-target ratio (%) | Bilateral precision baseline |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Side-level precision gap |
| `triggered_team_shots_off_target` | Triggered-side shots not on target | Missed-target burden context |
| `opponent_shots_off_target` | Opponent shots not on target | Bilateral missed-target comparator |
| `shots_off_target_delta` | Triggered minus opponent off-target shots | Net directional wastefulness |
| `triggered_team_goals` | Goals scored by triggered side | Outcome context for precision collapse |
| `opponent_goals` | Goals scored by opponent side | Bilateral outcome baseline |
| `goal_delta` | Triggered minus opponent goals | Match outcome differential |
| `triggered_team_shot_conversion_pct` | Goals per total shots for triggered side (%) | Finishing efficiency context |
| `opponent_shot_conversion_pct` | Goals per total shots for opponent side (%) | Bilateral finishing comparator |
| `shot_conversion_delta_pct` | Triggered minus opponent shot conversion (percentage points) | Net finishing-efficiency gap |
| `triggered_team_expected_goals` | Expected goals by triggered side | Chance-quality baseline |
| `opponent_expected_goals` | Expected goals by opponent side | Bilateral chance-quality comparator |
| `expected_goals_delta` | Triggered minus opponent expected goals | Net chance-generation context |
| `triggered_team_expected_goals_per_shot` | Expected goals per shot for triggered side | Average chance quality per attempt |
| `opponent_expected_goals_per_shot` | Expected goals per shot for opponent side | Bilateral shot-quality comparator |
| `expected_goals_per_shot_delta` | Triggered minus opponent xG-per-shot | Net shot-quality differential |
| `triggered_team_big_chances` | Big chances by triggered side | High-value chance context |
| `opponent_big_chances` | Big chances by opponent side | Bilateral high-value comparator |
| `triggered_team_big_chances_missed` | Big chances missed by triggered side | Wastefulness severity context |
| `opponent_big_chances_missed` | Big chances missed by opponent side | Bilateral wastefulness comparator |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial comparator |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-profile context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share baseline |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Circulation-volume context |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Technical execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral technical comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Compact possession-quality differential |
| `triggered_team_corners` | Triggered-side corners won | Sustained attacking-pressure proxy |
| `opponent_corners` | Opponent corners won | Bilateral pressure comparator |
