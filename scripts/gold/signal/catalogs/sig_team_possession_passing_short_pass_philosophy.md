---
signal_id: sig_team_possession_passing_short_pass_philosophy
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Short Pass Philosophy"
trigger: "team long_ball_attempts are <= 5% of total pass_attempts in full-match period stats"
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_short_pass_philosophy
  sql: clickhouse/gold/signal/sig_team_possession_passing_short_pass_philosophy.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_possession_passing_short_pass_philosophy

## Purpose

Triggers when a team keeps long-ball usage at `<= 5%` of pass attempts, indicating a short-passing philosophy.

## Tactical And Statistical Logic

- Trigger condition: `long_ball_attempts / pass_attempts * 100 <= 5` in full-match period stats (`period = 'All'`), evaluated independently for home and away.
- Rows are side-resolved (`triggered_side` is `home` or `away`) and preserve symmetric opponent context.
- Enrichment captures pass quality, territorial pass distribution, possession control, and attacking output generated from this short-passing profile.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_possession_passing_short_pass_philosophy.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_possession_passing_short_pass_philosophy`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_possession_passing_short_pass_philosophy
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
| `home_score` | Home team goals scored | Football developer: anchors joins across match, team, and downstream feature tables |
| `away_score` | Away team goals scored | Football developer: anchors joins across match, team, and downstream feature tables |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `triggered_team_id` | Triggered team identifier | Football developer: anchors joins across match, team, and downstream feature tables |
| `triggered_team_name` | Triggered team name | Football developer: anchors joins across match, team, and downstream feature tables |
| `opponent_team_id` | Opponent team identifier relative to triggered team | Football developer: anchors joins across match, team, and downstream feature tables |
| `opponent_team_name` | Opponent team name relative to triggered team | Football developer: anchors joins across match, team, and downstream feature tables |
| `trigger_threshold_long_ball_share_pct` | Fixed trigger threshold (`5.0`) used by this signal | Football developer: makes trigger configuration explicit for QA and feature traceability |
| `triggered_team_long_ball_attempts` | Long-ball attempts by triggered team | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `opponent_long_ball_attempts` | Long-ball attempts by opponent | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `triggered_team_pass_attempts` | Pass attempts by triggered team | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `opponent_pass_attempts` | Pass attempts by opponent | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `triggered_team_long_ball_share_pct` | Triggered team long-ball share of pass attempts (%) | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `opponent_long_ball_share_pct` | Opponent long-ball share of pass attempts (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `long_ball_share_delta_pct` | Triggered minus opponent long-ball share (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_accurate_passes` | Accurate passes by triggered team | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_accurate_passes` | Accurate passes by opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_pass_accuracy_pct` | Triggered team pass accuracy (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_possession_pct` | Triggered team possession share (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `possession_delta_pct` | Triggered minus opponent possession share (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_own_half_passes` | Triggered team passes in own half | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_own_half_passes` | Opponent passes in own half | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_opposition_half_passes` | Triggered team passes in opposition half | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_opposition_half_passes` | Opponent passes in opposition half | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_own_half_pass_share_pct` | Share of triggered team passes played in own half (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_own_half_pass_share_pct` | Share of opponent passes played in own half (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_opposition_half_pass_share_pct` | Share of triggered team passes played in opposition half (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_opposition_half_pass_share_pct` | Share of opponent passes played in opposition half (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_touches_opposition_box` | Triggered team touches in opposition box | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_total_shots` | Total shots by triggered team | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_total_shots` | Total shots by opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_xg` | Triggered team expected goals | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_xg` | Opponent expected goals | Football developer: adds diagnostic football context to explain why the trigger fired |
| `xg_delta` | Triggered minus opponent xG | Football developer: adds diagnostic football context to explain why the trigger fired |
