---
signal_id: sig_team_possession_passing_final_third_efficiency
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Final Third Efficiency"
trigger: "team goals >= 2 with triggered_team_final_third_entries < 10 (entries proxied by touches_opp_box)"
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_final_third_efficiency
  sql: clickhouse/gold/dml/signals/team/sig_team_possession_passing_final_third_efficiency.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_possession_passing_final_third_efficiency

## Purpose

Detect teams that score at least 2 goals despite fewer than 10 final-third entries (proxied by `touches_opp_box`), highlighting extreme attacking efficiency.

## Tactical And Statistical Logic

- Signal name source: `-- Signal: sig_team_possession_passing_final_third_efficiency`
- Trigger condition source: `-- Trigger: team goals >= 2 with triggered_team_final_third_entries < 10 (entries proxied by touches_opp_box).`
- Signal isolates unusually clinical finishing profiles and enriches with bilateral shot quality, passing control, and territorial progression context.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_possession_passing_final_third_efficiency.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_possession_passing_final_third_efficiency`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_possession_passing_final_third_efficiency
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: anchors joins across match, team, and downstream feature tables |
| `match_date` | Match date | Football developer: anchors joins across match, team, and downstream feature tables |
| `home_team_id` | Home team identifier | Football developer: anchors joins across match, team, and downstream feature tables |
| `home_team_name` | Home team name | Football developer: anchors joins across match, team, and downstream feature tables |
| `away_team_id` | Away team identifier | Football developer: anchors joins across match, team, and downstream feature tables |
| `away_team_name` | Away team name | Football developer: anchors joins across match, team, and downstream feature tables |
| `home_score` | Home team goals | Football developer: anchors joins across match, team, and downstream feature tables |
| `away_score` | Away team goals | Football developer: anchors joins across match, team, and downstream feature tables |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `triggered_team_id` | Triggered team identifier | Football developer: anchors joins across match, team, and downstream feature tables |
| `triggered_team_name` | Triggered team name | Football developer: anchors joins across match, team, and downstream feature tables |
| `opponent_team_id` | Opponent team identifier | Football developer: anchors joins across match, team, and downstream feature tables |
| `opponent_team_name` | Opponent team name | Football developer: anchors joins across match, team, and downstream feature tables |
| `triggered_team_goals` | Goals scored by triggered team | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `opponent_goals` | Goals scored by opponent | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `goal_delta` | Triggered goals minus opponent goals | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_final_third_entries` | Triggered team final-third-entry proxy (`touches_opp_box`) | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `opponent_final_third_entries` | Opponent final-third-entry proxy (`touches_opp_box`) | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `final_third_entries_delta` | Triggered minus opponent final-third entries | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_goals_per_final_third_entry` | Triggered team goals per final-third entry | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_goals_per_final_third_entry` | Opponent goals per final-third entry | Football developer: adds diagnostic football context to explain why the trigger fired |
| `goals_per_entry_delta` | Triggered minus opponent goals-per-entry efficiency | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_total_shots` | Triggered team total shots | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_total_shots` | Opponent total shots | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_shots_on_target` | Triggered team shots on target | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_shots_on_target` | Opponent shots on target | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_on_target_ratio_pct` | Triggered team on-target shot ratio (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_on_target_ratio_pct` | Opponent on-target shot ratio (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_xg` | Triggered team expected goals | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_xg` | Opponent expected goals | Football developer: adds diagnostic football context to explain why the trigger fired |
| `xg_delta` | Triggered xG minus opponent xG | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_xg_per_shot` | Triggered team xG per shot | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_xg_per_shot` | Opponent xG per shot | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_pass_attempts` | Triggered team pass attempts | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_accurate_passes` | Triggered team accurate passes | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_accurate_passes` | Opponent accurate passes | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_pass_accuracy_pct` | Triggered team pass accuracy (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_opposition_half_passes` | Triggered team passes in opposition half | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_opposition_half_passes` | Opponent passes in opposition half | Football developer: adds diagnostic football context to explain why the trigger fired |
