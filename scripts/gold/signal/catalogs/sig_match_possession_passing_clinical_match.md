---
signal_id: sig_match_possession_passing_clinical_match
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Clinical Match"
trigger: "Combined match goals >= 5 from combined match xG <= 2.5 in period `All`."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_possession_passing_clinical_match
  sql: clickhouse/gold/signal/sig_match_possession_passing_clinical_match.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_possession_passing_clinical_match

## Purpose

Flags extreme finishing matches where total scoring is high despite low underlying xG, then emits side-oriented rows for symmetric tactical diagnosis.

## Tactical And Statistical Logic

- Trigger condition: `(home_score + away_score) >= 5` and `(expected_goals_home + expected_goals_away) <= 2.5` at `period='All'`.
- Emits one row per side (`triggered_side in {'home','away'}`) so model features and diagnostics stay team-oriented while preserving identical match context.
- Quantifies clinical overperformance at match and side levels using goals-minus-xG deltas, while retaining passing and territorial context.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_possession_passing_clinical_match.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_possession_passing_clinical_match`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_possession_passing_clinical_match
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins across match-level assets |
| `match_date` | Match date | Football developer: supports temporal validation and downstream slicing |
| `home_team_id` | Home team ID | Football developer: preserves full bilateral match context |
| `home_team_name` | Home team name | Football developer: readable bilateral context |
| `away_team_id` | Away team ID | Football developer: preserves full bilateral match context |
| `away_team_name` | Away team name | Football developer: readable bilateral context |
| `home_score` | Full-time home goals | Football developer: direct scoreline context for trigger interpretation |
| `away_score` | Full-time away goals | Football developer: direct scoreline context for trigger interpretation |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: canonical identity for match-team grain |
| `triggered_team_id` | Triggered-side team ID | Football developer: side-scoped team key for joins |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered-side context |
| `opponent_team_id` | Opponent team ID | Football developer: preserves opponent identity for side orientation |
| `opponent_team_name` | Opponent team name | Football developer: readable opponent context |
| `trigger_threshold_match_total_goals` | Goals threshold used by trigger (`5`) | Football developer: explicit threshold traceability for QA |
| `trigger_threshold_match_total_xg` | xG ceiling used by trigger (`2.5`) | Football developer: explicit threshold traceability for QA |
| `match_total_goals` | Combined full-time goals | Football developer: core trigger intensity signal |
| `match_total_xg` | Combined expected goals | Football developer: core chance-quality denominator for clinicality |
| `match_goal_minus_xg` | Combined goals minus combined xG | Football developer: quantifies match-level finishing overperformance |
| `triggered_team_goals` | Goals scored by triggered side | Football developer: side-specific output contribution |
| `opponent_goals` | Goals scored by opponent | Football developer: bilateral scoreline comparator |
| `goal_gap` | Triggered goals minus opponent goals | Football developer: outcome edge context |
| `triggered_team_xg` | Triggered-side expected goals | Football developer: side-specific chance-quality context |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_gap` | Triggered xG minus opponent xG | Football developer: chance-generation balance context |
| `triggered_team_goals_minus_xg` | Triggered-side goals minus xG | Football developer: side-level finishing overperformance metric |
| `opponent_goals_minus_xg` | Opponent goals minus xG | Football developer: bilateral finishing overperformance comparator |
| `goals_minus_xg_gap` | Triggered-side minus opponent-side goals-minus-xG | Football developer: isolates which side drove the clinical divergence |
| `triggered_team_total_shots` | Triggered-side total shots | Football developer: chance-volume context behind goals |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral shot-volume comparator |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Football developer: shot quality proxy supporting clinicality checks |
| `opponent_shots_on_target` | Opponent shots on target | Football developer: bilateral shot quality proxy comparator |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Football developer: possession-structure context |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral possession-structure comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy % | Football developer: circulation quality context around finishing outcomes |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy % | Football developer: bilateral circulation quality comparator |
| `triggered_team_possession_pct` | Triggered-side possession % | Football developer: control share context |
| `opponent_possession_pct` | Opponent possession % | Football developer: bilateral control-share comparator |
| `triggered_team_opposition_half_passes` | Triggered-side opposition-half passes | Football developer: progression footprint context |
| `opponent_opposition_half_passes` | Opponent opposition-half passes | Football developer: bilateral progression comparator |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opponent box | Football developer: penetration context vs scored output |
| `opponent_touches_opposition_box` | Opponent touches in triggered-side box | Football developer: bilateral penetration comparator |
