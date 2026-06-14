---
signal_id: sig_match_possession_passing_passing_clinic
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Match Passing Clinic"
trigger: "Both teams maintain >88% pass accuracy in full match (`All`) and each half (`FirstHalf`, `SecondHalf`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_possession_passing_passing_clinic
  sql: clickhouse/gold/dml/signals/match/sig_match_possession_passing_passing_clinic.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_possession_passing_passing_clinic

## Purpose

Triggers when both sides sustain elite pass completion for the entire game, flagging matches that function as bilateral passing clinics.

## Tactical And Statistical Logic

- Trigger condition: both teams have pass accuracy strictly greater than `88%` in `All`, `FirstHalf`, and `SecondHalf`.
- Emits one row per side (`triggered_side in {'home','away'}`) so downstream consumers can analyze the same match from each team orientation.
- Enriches the trigger with pass volume by half, territorial progression, shot output, and xG context to separate sterile safety from high-quality control.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_possession_passing_passing_clinic.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_possession_passing_passing_clinic`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_possession_passing_passing_clinic
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins across match-level tables |
| `match_date` | Match calendar date | Football developer: supports temporal slicing and QA |
| `home_team_id` | Home team numeric ID | Football developer: bilateral orientation context |
| `home_team_name` | Home team display name | Football developer: readable bilateral context |
| `away_team_id` | Away team numeric ID | Football developer: bilateral orientation context |
| `away_team_name` | Away team display name | Football developer: readable bilateral context |
| `home_score` | Full-time home goals | Football developer: outcome context around style trigger |
| `away_score` | Full-time away goals | Football developer: outcome context around style trigger |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: canonical side identity for match-team grain |
| `triggered_team_id` | Triggered-side team ID | Football developer: side-scoped team key for downstream joins |
| `triggered_team_name` | Triggered-side team name | Football developer: readable side-scoped context |
| `opponent_team_id` | Opponent team ID | Football developer: opponent-aware bilateral interpretation |
| `opponent_team_name` | Opponent team name | Football developer: readable opponent context |
| `trigger_threshold_pct` | Pass-accuracy threshold used by trigger (`88`) | Football developer: explicit threshold traceability for QA and model explainability |
| `triggered_team_pass_accuracy_pct` | Triggered-side full-match pass accuracy % | Football developer: core trigger metric for the oriented side |
| `opponent_pass_accuracy_pct` | Opponent full-match pass accuracy % | Football developer: core bilateral trigger comparator |
| `pass_accuracy_gap_pct` | Triggered minus opponent full-match pass accuracy (percentage points) | Football developer: indicates which side executed cleaner circulation |
| `match_min_half_pass_accuracy_pct` | Minimum half-level pass accuracy across both teams | Football developer: strictest “throughout match” guardrail |
| `triggered_team_pass_accuracy_first_half_pct` | Triggered-side first-half pass accuracy % | Football developer: phase-level quality context |
| `triggered_team_pass_accuracy_second_half_pct` | Triggered-side second-half pass accuracy % | Football developer: phase-level quality context |
| `opponent_pass_accuracy_first_half_pct` | Opponent first-half pass accuracy % | Football developer: bilateral phase comparator |
| `opponent_pass_accuracy_second_half_pct` | Opponent second-half pass accuracy % | Football developer: bilateral phase comparator |
| `triggered_team_pass_accuracy_floor_pct` | Minimum triggered-side pass accuracy across full match and halves | Football developer: verifies sustained, not spiky, execution quality |
| `opponent_pass_accuracy_floor_pct` | Minimum opponent pass accuracy across full match and halves | Football developer: bilateral sustained-quality comparator |
| `triggered_team_pass_attempts` | Triggered-side full-match pass attempts | Football developer: volume context behind completion quality |
| `opponent_pass_attempts` | Opponent full-match pass attempts | Football developer: bilateral volume comparator |
| `triggered_team_pass_attempts_first_half` | Triggered-side first-half pass attempts | Football developer: first-half rhythm and involvement context |
| `triggered_team_pass_attempts_second_half` | Triggered-side second-half pass attempts | Football developer: second-half rhythm and involvement context |
| `opponent_pass_attempts_first_half` | Opponent first-half pass attempts | Football developer: bilateral first-half volume comparator |
| `opponent_pass_attempts_second_half` | Opponent second-half pass attempts | Football developer: bilateral second-half volume comparator |
| `triggered_team_opposition_half_passes` | Triggered-side completed passes in opposition-half territory | Football developer: progression context beyond raw retention |
| `opponent_opposition_half_passes` | Opponent completed passes in opposition-half territory | Football developer: bilateral progression comparator |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opponent penalty box | Football developer: penetration context for possession quality |
| `opponent_touches_opposition_box` | Opponent touches in triggered-side penalty box | Football developer: bilateral penetration comparator |
| `triggered_team_total_shots` | Triggered-side total shots | Football developer: chance-volume context linked to passing control |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral chance-volume comparator |
| `triggered_team_xg` | Triggered-side total expected goals | Football developer: chance-quality context linked to passing control |
| `opponent_xg` | Opponent total expected goals | Football developer: bilateral chance-quality comparator |
| `xg_gap` | Triggered minus opponent xG | Football developer: net attacking quality edge despite shared passing excellence |
