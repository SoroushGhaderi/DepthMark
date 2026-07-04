---
signal_id: sig_team_shooting_goals_clinical_finishing_streak
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Clinical Finishing Streak"
trigger: "Team has shots_on_target >= 3 and scores from every shot on target (`goals = shots_on_target`) in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_clinical_finishing_streak
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_clinical_finishing_streak.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_shooting_goals_clinical_finishing_streak

## Purpose

Detect team matches with a perfect on-target finishing streak at meaningful volume (`>= 3` shots on target), where every on-target effort becomes a goal.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_shots_on_target >= 3`
  - `triggered_team_goals = triggered_team_shots_on_target`
- Trigger is evaluated side-by-side for home and away teams in finished matches using full-match stats (`period = 'All'`).
- Bilateral enrichment is preserved with symmetric `triggered_team_*` and `opponent_*` fields so the conversion streak can be compared against opponent execution, chance quality, and territorial control.
- Similarity gate note: closest active signal is `sig_team_shooting_goals_ruthless_efficiency`; this signal intentionally narrows to exact perfect conversion (`100%` goals per shot on target) with a minimum on-target floor, while the other allows non-perfect conversion (`>= 3` goals from `<= 5` shots on target).

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_clinical_finishing_streak.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_shooting_goals_clinical_finishing_streak`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_clinical_finishing_streak
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins and deterministic deduplication |
| `match_date` | Match date | Football developer: temporal slicing and reproducible backfills |
| `home_team_id` | Home team identifier | Football developer: preserves bilateral fixture context |
| `home_team_name` | Home team name | Football developer: readable home-side attribution |
| `away_team_id` | Away team identifier | Football developer: preserves bilateral fixture context |
| `away_team_name` | Away team name | Football developer: readable away-side attribution |
| `home_score` | Home final goals | Football developer: scoreline context for interpreting conversion streak |
| `away_score` | Away final goals | Football developer: scoreline context for interpreting conversion streak |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered team identifier | Football developer: side-scoped key for downstream joins |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral opponent orientation |
| `opponent_team_name` | Opponent team name | Football developer: readable opponent attribution |
| `trigger_threshold_min_shots_on_target` | Minimum shots-on-target trigger threshold (`3`) | Football developer: explicit trigger provenance for QA and governance |
| `trigger_threshold_goal_conversion_pct` | Required conversion threshold (`100`) | Football developer: explicit perfect-conversion rule traceability |
| `triggered_team_goals` | Goals scored by triggered team | Football developer: core trigger numerator |
| `opponent_goals` | Goals scored by opponent | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: outcome context around finishing streaks |
| `triggered_team_shots_on_target` | Shots on target by triggered team | Football developer: core trigger denominator with minimum-volume floor |
| `opponent_shots_on_target` | Shots on target by opponent | Football developer: bilateral shot-execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Football developer: compact side-to-side shooting pressure gap |
| `triggered_team_total_shots` | Total shots by triggered team | Football developer: shot-volume context behind conversion perfection |
| `opponent_total_shots` | Total shots by opponent | Football developer: bilateral shot-volume comparator |
| `triggered_team_shot_accuracy_pct` | Triggered-team shots-on-target share of total shots (%) | Football developer: chance-execution quality context before conversion |
| `opponent_shot_accuracy_pct` | Opponent shots-on-target share of total shots (%) | Football developer: bilateral execution-quality benchmark |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Football developer: concise execution differential |
| `triggered_team_goal_conversion_pct` | Triggered-team goals per shot on target (%) | Football developer: direct perfect-finishing intensity metric |
| `opponent_goal_conversion_pct` | Opponent goals per shot on target (%) | Football developer: bilateral conversion benchmark |
| `goal_conversion_delta_pct` | Triggered minus opponent goal conversion (percentage points) | Football developer: net conversion advantage diagnostic |
| `triggered_team_goals_per_shot_on_target` | Triggered-team goals divided by triggered-team shots on target | Football developer: ratio-form conversion metric for modeling features |
| `opponent_goals_per_shot_on_target` | Opponent goals divided by opponent shots on target | Football developer: bilateral ratio baseline |
| `goals_per_shot_on_target_delta` | Triggered minus opponent goals-per-shot-on-target ratio | Football developer: compact finishing-efficiency differential |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: chance-quality baseline behind finishing output |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: net chance-generation context |
| `triggered_team_goals_minus_xg` | Triggered-team goals minus triggered-team xG | Football developer: overperformance intensity relative to chance quality |
| `opponent_goals_minus_xg` | Opponent goals minus opponent xG | Football developer: bilateral overperformance benchmark |
| `goals_minus_xg_delta` | Triggered minus opponent goals-minus-xG | Football developer: identifies which side drove finishing overperformance |
| `triggered_team_big_chances` | Triggered-team big chances | Football developer: high-value chance context for conversion streak interpretation |
| `opponent_big_chances` | Opponent big chances | Football developer: bilateral high-value chance comparator |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Football developer: control-profile context around finishing style |
| `opponent_possession_pct` | Opponent possession (%) | Football developer: bilateral control-share comparator |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in triggered-team box | Football developer: bilateral territorial baseline |
