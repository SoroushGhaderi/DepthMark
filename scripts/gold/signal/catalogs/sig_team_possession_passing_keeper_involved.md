---
signal_id: sig_team_possession_passing_keeper_involved
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Keeper Involved"
trigger: "max goalkeeper touches by team in a finished match > 50"
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_keeper_involved
  sql: clickhouse/gold/dml/signals/team/sig_team_possession_passing_keeper_involved.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_possession_passing_keeper_involved

## Purpose

Detect matches where a team goalkeeper records very high involvement in circulation (`> 50` touches), indicating build-up routed heavily through the keeper.

## Tactical And Statistical Logic

- Signal name source: `-- Signal: sig_team_possession_passing_keeper_involved`
- Trigger condition source: `-- Trigger: max goalkeeper touches by team in a finished match > 50.`
- Triggered rows are team-specific and include bilateral passing/possession context to distinguish controlled deep build-up from press-induced emergency recycling.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_possession_passing_keeper_involved.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_possession_passing_keeper_involved`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_possession_passing_keeper_involved
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: anchors joins across match, team, and downstream feature tables |
| `match_date` | Calendar date the match was played | Football developer: anchors joins across match, team, and downstream feature tables |
| `home_team_id` | Numeric ID of the home team | Football developer: anchors joins across match, team, and downstream feature tables |
| `home_team_name` | Display name of the home team | Football developer: anchors joins across match, team, and downstream feature tables |
| `away_team_id` | Numeric ID of the away team | Football developer: anchors joins across match, team, and downstream feature tables |
| `away_team_name` | Display name of the away team | Football developer: anchors joins across match, team, and downstream feature tables |
| `home_score` | Full-time goals scored by home team | Football developer: anchors joins across match, team, and downstream feature tables |
| `away_score` | Full-time goals scored by away team | Football developer: anchors joins across match, team, and downstream feature tables |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical row identity at match-team grain; required for deterministic activation IDs |
| `triggered_team_id` | Team ID of the side whose goalkeeper triggered the signal | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `triggered_team_name` | Display name of the triggered team | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `triggered_goalkeeper_player_id` | Player ID of the goalkeeper who recorded >50 touches | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `triggered_goalkeeper_player_name` | Name of the triggering goalkeeper | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `triggered_team_goalkeeper_touches` | Goalkeeper touch count (signal value) — >50 indicates heavy back-pass usage | Football developer: this is the direct trigger metric for detecting keeper-led build-up patterns under pressure. |
| `opponent_team_id` | Team ID of the opposition in the same match | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `opponent_team_name` | Display name of the opposition | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `triggered_team_possession_pct` | Ball possession percentage for the triggered team (full match) | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_possession_pct` | Ball possession percentage for the opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_pass_attempts` | Total pass attempts by the triggered team | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_pass_attempts` | Total pass attempts by the opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_pass_accuracy_pct` | Pass completion rate (%) for the triggered team | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_pass_accuracy_pct` | Pass completion rate (%) for the opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_own_half_passes` | Passes completed in own half by the triggered team — proxy for deep build-up under pressure | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_own_half_passes` | Passes completed in own half by the opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_long_ball_attempts` | Number of long ball attempts by the triggered team — indicates direct keeper distribution | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_long_ball_attempts` | Number of long ball attempts by the opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_long_ball_accuracy_pct` | Successful long ball rate (%) for the triggered team | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_long_ball_accuracy_pct` | Successful long ball rate (%) for the opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `possession_delta` | Triggered team possession % minus opponent possession % — negative value signals a team under sustained pressure | Football developer: adds diagnostic football context to explain why the trigger fired (net) |
| `pass_attempt_delta` | Triggered team pass attempts minus opponent pass attempts — large negative delta reveals press suppression of build-up volume | Football developer: adds diagnostic football context to explain why the trigger fired (net) |
