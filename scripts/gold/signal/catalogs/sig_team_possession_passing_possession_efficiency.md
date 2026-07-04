---
signal_id: sig_team_possession_passing_possession_efficiency
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Low-Possession Scoring Efficiency"
trigger: "team goals >= 3 with triggered_team_possession_pct <= 40 at full match (`period = 'All'`)"
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_possession_efficiency
  sql: clickhouse/gold/dml/signals/team/sig_team_possession_passing_possession_efficiency.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_possession_passing_possession_efficiency

## Purpose

Detect teams that score at least 3 goals while holding 40% possession or less, highlighting extreme scoreline efficiency without territorial control.

## Tactical And Statistical Logic

- Trigger condition: `team goals >= 3` with `triggered_team_possession_pct <= 40` in full-match period stats (`period = 'All'`).
- Captures matches where low-control teams are highly clinical, usually through transition attacks, direct progression, or set-piece leverage.
- Bilateral enrichment compares finishing, shot quality, passing quality, and territorial progression versus the opponent.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_possession_passing_possession_efficiency.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_possession_passing_possession_efficiency`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_possession_passing_possession_efficiency
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
| `triggered_team_goals` | Goals scored by triggered team (trigger metric) | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `opponent_goals` | Goals scored by opponent | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `goal_delta` | Triggered minus opponent goals | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_possession_pct` | Triggered-team possession percentage (trigger metric) | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `opponent_possession_pct` | Opponent possession percentage | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `possession_delta_pct` | Triggered minus opponent possession percentage | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_goals_per_possession_pct` | Triggered goals normalized by possession percentage | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_goals_per_possession_pct` | Opponent goals normalized by possession percentage | Football developer: adds diagnostic football context to explain why the trigger fired |
| `goals_per_possession_delta` | Triggered minus opponent goals-per-possession efficiency | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_total_shots` | Total shots by triggered team | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_total_shots` | Total shots by opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_shots_on_target` | Shots on target by triggered team | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_shots_on_target` | Shots on target by opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_on_target_ratio_pct` | Triggered-team shots on target ratio (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_on_target_ratio_pct` | Opponent shots on target ratio (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_xg` | Opponent expected goals | Football developer: adds diagnostic football context to explain why the trigger fired |
| `xg_delta` | Triggered minus opponent xG | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_xg_per_shot` | Triggered-team xG per shot | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_xg_per_shot` | Opponent xG per shot | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_accurate_passes` | Triggered-team accurate passes | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_accurate_passes` | Opponent accurate passes | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_opposition_half_passes` | Triggered-team passes in opposition half | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_opposition_half_passes` | Opponent passes in opposition half | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opponent box | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_big_chances` | Triggered-team big chances created | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_big_chances` | Opponent big chances created | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_big_chances_missed` | Triggered-team big chances missed | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_big_chances_missed` | Opponent big chances missed | Football developer: adds diagnostic football context to explain why the trigger fired |
