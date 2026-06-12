---
signal_id: sig_team_possession_passing_aerial_reliance
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Aerial Reliance"
trigger: "triggered_team_aerial_success_pct > 70 with long_ball_attempts >= 20 and long_ball_share_pct >= 18"
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_aerial_reliance
  sql: clickhouse/gold/signal/sig_team_possession_passing_aerial_reliance.sql
  runner: scripts/gold/signal/runners/sig_team_possession_passing_aerial_reliance.py
---
# sig_team_possession_passing_aerial_reliance

## Purpose

Detect teams that rely heavily on long-ball routes and win a dominant share of aerial duels (`>70%`), indicating aerial-route control.

## Tactical And Statistical Logic

- Signal name source: `-- Signal: sig_team_possession_passing_aerial_reliance`
- Trigger condition source: `-- Trigger: triggered_team_aerial_success_pct > 70 with long_ball_attempts >= 20 and long_ball_share_pct >= 18.`
- Signal uses bilateral aerial, long-ball, passing, and output context to separate style dependence from isolated duel spikes.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_possession_passing_aerial_reliance.sql`
- Runner: `scripts/gold/signal/runners/sig_team_possession_passing_aerial_reliance.py`
- Target table: `gold_signals.sig_team_possession_passing_aerial_reliance`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_possession_passing_aerial_reliance.py
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
| `home_score` | Home team goals | Football developer: anchors joins across match, team, and downstream feature tables |
| `away_score` | Away team goals | Football developer: anchors joins across match, team, and downstream feature tables |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `triggered_team_id` | Triggered team ID | Football developer: anchors joins across match, team, and downstream feature tables |
| `triggered_team_name` | Triggered team name | Football developer: anchors joins across match, team, and downstream feature tables |
| `opponent_team_id` | Opponent team ID | Football developer: anchors joins across match, team, and downstream feature tables |
| `opponent_team_name` | Opponent team name | Football developer: anchors joins across match, team, and downstream feature tables |
| `triggered_team_aerials_won` | Triggered-team aerial duels won | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `opponent_aerials_won` | Opponent aerial duels won | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `triggered_team_aerial_attempts` | Triggered-team aerial duel attempts | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `opponent_aerial_attempts` | Opponent aerial duel attempts | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `triggered_team_aerial_success_pct` | Triggered-team aerial duel win rate (%) | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `opponent_aerial_success_pct` | Opponent aerial duel win rate (%) | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `aerial_success_delta` | Triggered minus opponent aerial success rate (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_long_ball_attempts` | Triggered-team long-ball attempts | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_long_ball_attempts` | Opponent long-ball attempts | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_accurate_long_balls` | Triggered-team accurate long balls | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_accurate_long_balls` | Opponent accurate long balls | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_long_ball_accuracy_pct` | Triggered-team long-ball accuracy (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_long_ball_accuracy_pct` | Opponent long-ball accuracy (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_long_ball_share_pct` | Triggered-team long-ball share of passing (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_long_ball_share_pct` | Opponent long-ball share of passing (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `long_ball_share_delta` | Triggered minus opponent long-ball share (%) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_total_shots` | Triggered-team total shots | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_total_shots` | Opponent total shots | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_xg` | Triggered-team xG | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_xg` | Opponent xG | Football developer: adds diagnostic football context to explain why the trigger fired |
| `xg_delta` | Triggered minus opponent xG | Football developer: adds diagnostic football context to explain why the trigger fired |
