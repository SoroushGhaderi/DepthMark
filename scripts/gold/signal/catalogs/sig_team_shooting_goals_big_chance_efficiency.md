---
signal_id: sig_team_shooting_goals_big_chance_efficiency
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Big Chance Efficiency"
trigger: "Team converts 100% of big chances (Opta definition) into goals in a finished match (`period = 'All'`), requiring at least one big chance."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_big_chance_efficiency
  sql: clickhouse/gold/signal/sig_team_shooting_goals_big_chance_efficiency.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_shooting_goals_big_chance_efficiency

## Purpose

Detect team matches where all created big chances are converted (no big-chance misses), isolating elite chance-level finishing rather than generic shot conversion.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_big_chances >= 1`
  - `triggered_team_big_chances_missed = 0`
  - `triggered_team_big_chance_conversion_pct = 100%`
- Big-chance conversion uses Opta big-chance aggregates from `silver.period_stat` at full-match scope (`period = 'All'`).
- Trigger is evaluated only for finished matches.
- Output keeps bilateral symmetric context across big-chance profile, shot execution, xG, territorial control, and circulation.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_clinical_finishing_streak`, `sig_team_shooting_goals_ruthless_efficiency`, and `sig_team_shooting_goals_conversion_collapse`; this signal intentionally coexists because it is chance-type-specific (big chances only) and requires zero big-chance misses, not all-on-target conversion or goals-vs-on-target thresholds.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_shooting_goals_big_chance_efficiency.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_shooting_goals_big_chance_efficiency`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_shooting_goals_big_chance_efficiency
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for downstream features and QA |
| `match_date` | Match date | Football developer: temporal slicing and reproducible backfills |
| `home_team_id` | Home team identifier | Football developer: preserves bilateral fixture context |
| `home_team_name` | Home team name | Football developer: readable home-side attribution |
| `away_team_id` | Away team identifier | Football developer: preserves bilateral fixture context |
| `away_team_name` | Away team name | Football developer: readable away-side attribution |
| `home_score` | Home full-time goals | Football developer: scoreline context for trigger interpretation |
| `away_score` | Away full-time goals | Football developer: scoreline context for trigger interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical row identity at match-team grain |
| `triggered_team_id` | Triggered team identifier | Football developer: identity key for triggered-team joins |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-side context |
| `opponent_team_id` | Opponent team identifier | Football developer: preserves bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral opponent context |
| `trigger_threshold_min_big_chances` | Minimum big-chance threshold (`1`) | Football developer: explicit trigger-rule provenance |
| `trigger_threshold_required_big_chances_missed` | Required big chances missed (`0`) | Football developer: explicit trigger-rule provenance |
| `trigger_threshold_big_chance_conversion_pct` | Required big-chance conversion threshold (`100%`) | Football developer: explicit trigger-rule provenance |
| `triggered_team_big_chances` | Triggered-team big chances | Football developer: primary opportunity-volume trigger metric |
| `opponent_big_chances` | Opponent big chances | Football developer: bilateral chance-volume comparator |
| `big_chances_delta` | Triggered minus opponent big chances | Football developer: compact chance-volume differential |
| `triggered_team_big_chances_missed` | Triggered-team big chances missed | Football developer: primary zero-miss trigger metric |
| `opponent_big_chances_missed` | Opponent big chances missed | Football developer: bilateral wastefulness comparator |
| `big_chances_missed_delta` | Triggered minus opponent big chances missed | Football developer: net wastefulness differential |
| `triggered_team_big_chances_converted` | Triggered-team big chances converted | Football developer: direct converted-opportunity count |
| `opponent_big_chances_converted` | Opponent big chances converted | Football developer: bilateral converted-opportunity comparator |
| `big_chances_converted_delta` | Triggered minus opponent converted big chances | Football developer: net chance-conversion volume differential |
| `triggered_team_big_chance_conversion_pct` | Triggered-team big-chance conversion (%) | Football developer: core trigger efficiency metric |
| `opponent_big_chance_conversion_pct` | Opponent big-chance conversion (%) | Football developer: bilateral chance-conversion benchmark |
| `big_chance_conversion_delta_pct` | Triggered minus opponent big-chance conversion (%) | Football developer: net chance-type conversion advantage |
| `triggered_team_goals` | Goals scored by triggered team | Football developer: scoreboard output context |
| `opponent_goals` | Goals scored by opponent | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: compact outcome differential |
| `triggered_team_total_shots` | Triggered-team total shots | Football developer: shot-volume context beyond big chances |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral shot-volume baseline |
| `total_shots_delta` | Triggered minus opponent total shots | Football developer: net shot-pressure differential |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Football developer: execution context around conversion profile |
| `opponent_shots_on_target` | Opponent shots on target | Football developer: bilateral execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Football developer: compact on-target threat differential |
| `triggered_team_shot_accuracy_pct` | Triggered-team shot accuracy (%) | Football developer: normalized shot execution context |
| `opponent_shot_accuracy_pct` | Opponent shot accuracy (%) | Football developer: bilateral execution baseline |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (%) | Football developer: net shot-precision differential |
| `triggered_team_goal_conversion_pct` | Triggered-team goals per shot on target (%) | Football developer: broader finishing efficiency context |
| `opponent_goal_conversion_pct` | Opponent goals per shot on target (%) | Football developer: bilateral finishing comparator |
| `goal_conversion_delta_pct` | Triggered minus opponent goal conversion (%) | Football developer: net finishing differential beyond big chances |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: chance-quality total context |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: net chance-generation differential |
| `triggered_team_goals_minus_xg` | Triggered-team goals minus triggered-team xG | Football developer: finishing over/under-performance context |
| `opponent_goals_minus_xg` | Opponent goals minus opponent xG | Football developer: bilateral finishing benchmark |
| `goals_minus_xg_delta` | Triggered minus opponent goals-minus-xG | Football developer: net finishing-performance differential |
| `triggered_team_xg_per_shot` | Triggered-team xG per shot | Football developer: average chance quality per attempt |
| `opponent_xg_per_shot` | Opponent xG per shot | Football developer: bilateral per-shot quality comparator |
| `xg_per_shot_delta` | Triggered minus opponent xG per shot | Football developer: per-shot quality gap independent of volume |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Football developer: control-profile context |
| `opponent_possession_pct` | Opponent possession (%) | Football developer: bilateral control-share baseline |
| `possession_delta_pct` | Triggered minus opponent possession (%) | Football developer: net control differential |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Football developer: bilateral territorial comparator |
| `touches_opposition_box_delta` | Triggered minus opponent opposition-box touches | Football developer: compact territorial dominance measure |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Football developer: circulation-volume context |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation baseline |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: build-up execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral build-up comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Football developer: net circulation-quality differential |
| `triggered_team_corners` | Triggered-team corners won | Football developer: sustained pressure proxy |
| `opponent_corners` | Opponent corners won | Football developer: bilateral pressure comparator |
