---
signal_id: sig_team_possession_passing_sterile_dominance
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Sterile Dominance"
trigger: "possession > 70 and big_chances = 0 for the triggered team in full-match period stats"
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_sterile_dominance
  sql: clickhouse/gold/dml/signals/team/sig_team_possession_passing_sterile_dominance.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_possession_passing_sterile_dominance

## Purpose

Detect teams that dominate possession (`>70%`) but create zero big chances, signaling sterile circulation without high-quality attacking outcomes.

## Tactical And Statistical Logic

- Signal name source: `-- Signal: sig_team_possession_passing_sterile_dominance`
- Trigger condition source: `-- Trigger: possession > 70 and big_chances = 0 for the triggered team in full-match period stats.`
- Triggered rows are side-specific (`home`/`away`) and preserve symmetric tactical context for passing control, shot output, chance quality, and territorial progression.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_possession_passing_sterile_dominance.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_possession_passing_sterile_dominance`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_possession_passing_sterile_dominance
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: anchors joins across match, team, and downstream feature tables |
| `match_date` | Match calendar date | Football developer: anchors joins across match, team, and downstream feature tables |
| `home_team_id` | Home team identifier | Football developer: anchors joins across match, team, and downstream feature tables |
| `home_team_name` | Home team name | Football developer: anchors joins across match, team, and downstream feature tables |
| `away_team_id` | Away team identifier | Football developer: anchors joins across match, team, and downstream feature tables |
| `away_team_name` | Away team name | Football developer: anchors joins across match, team, and downstream feature tables |
| `home_score` | Home team goals | Football developer: anchors joins across match, team, and downstream feature tables |
| `away_score` | Away team goals | Football developer: anchors joins across match, team, and downstream feature tables |
| `triggered_side` | Which side triggered (`home`/`away`) | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `triggered_team_id` | Team id that triggered the signal | Football developer: anchors joins across match, team, and downstream feature tables |
| `triggered_team_name` | Team name that triggered the signal | Football developer: anchors joins across match, team, and downstream feature tables |
| `opponent_team_id` | Opponent team id relative to triggered team | Football developer: anchors joins across match, team, and downstream feature tables |
| `opponent_team_name` | Opponent team name relative to triggered team | Football developer: anchors joins across match, team, and downstream feature tables |
| `triggered_team_possession_pct` | Triggered-team possession % | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `opponent_possession_pct` | Opponent possession % | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `possession_delta` | Triggered minus opponent possession % | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_big_chances` | Triggered-team big chances created | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `opponent_big_chances` | Opponent big chances created | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `big_chance_delta` | Triggered minus opponent big chances | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_total_shots` | Triggered-team total shots | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_total_shots` | Opponent total shots | Football developer: adds diagnostic football context to explain why the trigger fired |
| `shot_volume_delta` | Triggered minus opponent shot volume | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_shots_on_target` | Opponent shots on target | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_on_target_ratio_pct` | Triggered-team shots-on-target ratio % | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_on_target_ratio_pct` | Opponent shots-on-target ratio % | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_xg` | Opponent expected goals | Football developer: adds diagnostic football context to explain why the trigger fired |
| `xg_delta` | Triggered minus opponent xG | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_xg_per_shot` | Triggered-team xG per shot | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_xg_per_shot` | Opponent xG per shot | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_accurate_passes` | Triggered-team accurate passes | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_accurate_passes` | Opponent accurate passes | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy % | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy % | Football developer: adds diagnostic football context to explain why the trigger fired |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy % | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opponent box | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_touches_opposition_box` | Opponent touches in triggered-team box | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_opposition_half_passes` | Triggered-team passes in opposition half | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_opposition_half_passes` | Opponent passes in opposition half | Football developer: adds diagnostic football context to explain why the trigger fired |
