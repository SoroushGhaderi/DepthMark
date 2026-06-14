---
signal_id: sig_team_possession_passing_vertical_imbalance
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Vertical Passing Imbalance"
trigger: "team is trailing and has `long_ball_attempts >= 60`"
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_vertical_imbalance
  sql: clickhouse/gold/dml/signals/team/sig_team_possession_passing_vertical_imbalance.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_possession_passing_vertical_imbalance

## Purpose

Capture matches where a trailing team goes heavily direct (`>=60` long-ball attempts) and measure vertical-usage imbalance versus the opponent.

## Tactical And Statistical Logic

- Trigger condition: team is trailing and has `long_ball_attempts >= 60`.
- Signal emits one row per triggered side and aligns all `triggered_team_*` and `opponent_*` fields to that side.
- Enrichment tracks long-ball volume/efficiency, pass-profile divergence, and output quality context (`xg`, shots, possession, aerial success).

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_possession_passing_vertical_imbalance.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_possession_passing_vertical_imbalance`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_possession_passing_vertical_imbalance
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: anchors joins across match, team, and downstream feature tables |
| `match_date` | Match date | Football developer: anchors joins across match, team, and downstream feature tables |
| `home_team_id` | Home team ID | Football developer: anchors joins across match, team, and downstream feature tables |
| `home_team_name` | Home team name | Football developer: anchors joins across match, team, and downstream feature tables |
| `away_team_id` | Away team ID | Football developer: anchors joins across match, team, and downstream feature tables |
| `away_team_name` | Away team name | Football developer: anchors joins across match, team, and downstream feature tables |
| `home_score` | Home team final goals | Football developer: anchors joins across match, team, and downstream feature tables |
| `away_score` | Away team final goals | Football developer: anchors joins across match, team, and downstream feature tables |
| `triggered_side` | Side that satisfied the trigger (`home`/`away`) | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `triggered_team_id` | Triggered team ID | Football developer: anchors joins across match, team, and downstream feature tables |
| `triggered_team_name` | Triggered team name | Football developer: anchors joins across match, team, and downstream feature tables |
| `opponent_team_id` | Opponent team ID | Football developer: anchors joins across match, team, and downstream feature tables |
| `opponent_team_name` | Opponent team name | Football developer: anchors joins across match, team, and downstream feature tables |
| `score_deficit` | Goals behind for the triggered team at full time | Football developer: this is the direct trigger context used to classify deficit-driven direct play |
| `triggered_team_long_ball_attempts` | Long-ball attempts by the triggered team | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `opponent_long_ball_attempts` | Long-ball attempts by the opponent | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `long_ball_attempts_delta` | Triggered minus opponent long-ball attempts | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `triggered_team_pass_attempts` | Total pass attempts by the triggered team | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_pass_attempts` | Total pass attempts by the opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_long_ball_share_pct` | Long-ball share of passing for the triggered team (%) | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `opponent_long_ball_share_pct` | Long-ball share of passing for the opponent (%) | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `long_ball_share_delta_pct` | Triggered minus opponent long-ball share (%) | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `triggered_team_accurate_long_balls` | Accurate long balls by the triggered team | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_accurate_long_balls` | Accurate long balls by the opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_long_ball_accuracy_pct` | Long-ball accuracy of the triggered team (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_long_ball_accuracy_pct` | Long-ball accuracy of the opponent (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `long_ball_accuracy_delta_pct` | Triggered minus opponent long-ball accuracy (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_pass_accuracy_pct` | Overall pass accuracy of the triggered team (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_pass_accuracy_pct` | Overall pass accuracy of the opponent (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_possession_pct` | Possession share of the triggered team (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_possession_pct` | Possession share of the opponent (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `possession_delta_pct` | Triggered minus opponent possession share (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_xg` | Triggered team expected goals | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_xg` | Opponent expected goals | Football developer: adds diagnostic football context to explain why the trigger fired |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_total_shots` | Triggered team total shots | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_total_shots` | Opponent total shots | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_aerial_success_pct` | Triggered team aerial duel success (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_aerial_success_pct` | Opponent aerial duel success (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `aerial_success_delta_pct` | Triggered minus opponent aerial success (%) | Football developer: adds diagnostic football context to explain why the trigger fired |

