---
signal_id: sig_team_possession_passing_shot_per_possession
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Shot Every 20 Completed Passes"
trigger: "triggered_team_accurate_passes >= 20 and triggered_team_accurate_passes / triggered_team_total_shots <= 20 at full match (`period = 'All'`)"
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_shot_per_possession
  sql: clickhouse/gold/dml/signals/team/sig_team_possession_passing_shot_per_possession.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_possession_passing_shot_per_possession

## Purpose

Detect teams that convert completed passing volume into shooting quickly, defined as at least one shot for every 20 accurate passes.

## Tactical And Statistical Logic

- Trigger condition: `triggered_team_accurate_passes >= 20` and `triggered_team_accurate_passes / triggered_team_total_shots <= 20` in full-match stats (`period = 'All'`).
- Captures direct or fast-progressing attacking possessions where circulation turns into attempts without long sterile buildup phases.
- Bilateral enrichment keeps opponent baselines for passing quality, territorial control, shot quality, and vertical/direct tendencies.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_possession_passing_shot_per_possession.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_possession_passing_shot_per_possession`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_possession_passing_shot_per_possession
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
| `opponent_team_id` | Opponent team identifier | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `opponent_team_name` | Opponent team name | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `trigger_threshold_accurate_passes_per_shot` | Fixed trigger threshold value (20 accurate passes per shot) | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `triggered_team_accurate_passes` | Accurate passes by triggered team | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `opponent_accurate_passes` | Accurate passes by opponent | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `triggered_team_total_shots` | Total shots by triggered team | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `opponent_total_shots` | Total shots by opponent | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `triggered_team_accurate_passes_per_shot` | Triggered-team ratio of accurate passes per shot | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `opponent_accurate_passes_per_shot` | Opponent ratio of accurate passes per shot | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `accurate_passes_per_shot_delta` | Triggered minus opponent accurate-passes-per-shot ratio | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_shots_per_20_accurate_passes` | Triggered-team shots normalized to 20 accurate passes | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_shots_per_20_accurate_passes` | Opponent shots normalized to 20 accurate passes | Football developer: adds diagnostic football context to explain why the trigger fired |
| `shots_per_20_accurate_passes_delta` | Triggered minus opponent shots-per-20-accurate-passes | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_pass_attempts` | Pass attempts by triggered team | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_pass_attempts` | Pass attempts by opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_possession_pct` | Triggered-team possession percentage | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_possession_pct` | Opponent possession percentage | Football developer: adds diagnostic football context to explain why the trigger fired |
| `possession_delta_pct` | Triggered minus opponent possession percentage | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_shots_on_target` | Shots on target by triggered team | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_shots_on_target` | Shots on target by opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_on_target_ratio_pct` | Triggered-team on-target shot ratio (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_on_target_ratio_pct` | Opponent on-target shot ratio (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_xg` | Opponent expected goals | Football developer: adds diagnostic football context to explain why the trigger fired |
| `xg_delta` | Triggered minus opponent xG | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_opposition_half_passes` | Triggered-team passes in opposition half | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_opposition_half_passes` | Opponent passes in opposition half | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opponent box | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_long_ball_attempts` | Triggered-team long-ball attempts | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_long_ball_attempts` | Opponent long-ball attempts | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_accurate_long_balls` | Triggered-team accurate long balls | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_accurate_long_balls` | Opponent accurate long balls | Football developer: adds diagnostic football context to explain why the trigger fired |
