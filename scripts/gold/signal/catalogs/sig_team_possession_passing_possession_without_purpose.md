---
signal_id: sig_team_possession_passing_possession_without_purpose
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Possession Without Purpose"
trigger: "possession above 65% with fewer than 2 shots on target for either home or away side in full-match totals (`period = 'All'`)"
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_possession_without_purpose
  sql: clickhouse/gold/signal/sig_team_possession_passing_possession_without_purpose.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_possession_passing_possession_without_purpose

## Purpose

A team dominates possession (>65%) yet generates fewer than 2 shots on target across the full match, indicating sterile, directionless ball circulation with minimal attacking threat.

## Tactical And Statistical Logic

- Trigger condition: possession above 65% with fewer than 2 shots on target for either home or away side in full-match totals (`period = 'All'`).
- This isolates matches where control of the ball failed to translate into penetration or shot quality.
- Enrichment adds progression, final-third access, xG, passing profile, and opponent defensive context to diagnose why dominance became sterile.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_possession_passing_possession_without_purpose.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_possession_passing_possession_without_purpose`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_possession_passing_possession_without_purpose
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `match_date` | Date the match was played | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `home_team_id` | ID of the home team | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `home_team_name` | Name of the home team | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `away_team_id` | ID of the away team | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `away_team_name` | Name of the away team | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `home_score` | Goals scored by the home team | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `away_score` | Goals scored by the away team | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `triggered_side` | Which side (`home` / `away`) fired the signal | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `triggered_team_id` | ID of the team holding >65% possession | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `triggered_team_name` | Name of the team holding >65% possession | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `opponent_team_id` | ID of the opposition team | Football developer: provides side/opponent orientation so tactical readings are not misattributed — opponent or orientation field for bilateral interpretation |
| `opponent_team_name` | Name of the opposition team | Football developer: provides side/opponent orientation so tactical readings are not misattributed — opponent or orientation field for bilateral interpretation |
| `triggered_team_possession_pct` | Full-match possession % of the triggered team | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `opponent_possession_pct` | Full-match possession % of the opponent | Football developer: provides side/opponent orientation so tactical readings are not misattributed — opponent or orientation field for bilateral interpretation |
| `triggered_team_shots_on_target` | Shots on target for triggered team — primary scarcity metric | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `opponent_shots_on_target` | Shots on target for opponent — threat generated from low possession | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `triggered_team_pass_attempts` | Total pass attempts by triggered team — circulation volume | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_pass_attempts` | Total pass attempts by opponent — suppression context | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_accurate_passes` | Accurate passes by triggered team — technical execution | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_accurate_passes` | Accurate passes by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_pass_accuracy_pct` | Pass accuracy % of triggered team — whether ball was kept cleanly | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_pass_accuracy_pct` | Pass accuracy % of opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_opposition_half_passes` | Passes completed in opponent's half — forward intent of possession | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_opposition_half_passes` | Opponent passes in triggered team's half | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_touches_opposition_box` | Touches in opponent's penalty box — true final-third penetration | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_touches_opposition_box` | Opponent touches in triggered team's box | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_total_shots` | Total shots taken — attempt volume regardless of quality | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_total_shots` | Total shots taken by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_big_chances` | Big chances created — whether high-quality openings existed | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_big_chances` | Big chances created by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_big_chances_missed` | Big chances squandered by triggered team | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_big_chances_missed` | Big chances squandered by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_xg` | Total xG for triggered team — expected threat from all shots | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_xg` | Total xG for opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_xg_open_play` | Open-play xG for triggered team — threat from structured build-up | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_xg_open_play` | Open-play xG for opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `xg_delta` | xG difference (triggered − opponent) — net expected threat advantage | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_cross_attempts` | Cross attempts by triggered team — use of wide channels | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_cross_attempts` | Cross attempts by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_accurate_crosses` | Accurate crosses by triggered team — quality of wide delivery | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_accurate_crosses` | Accurate crosses by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_long_ball_attempts` | Long ball attempts by triggered team — direct progression tried | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_long_ball_attempts` | Long ball attempts by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_accurate_long_balls` | Accurate long balls by triggered team — effectiveness of direct play | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_accurate_long_balls` | Accurate long balls by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_interceptions` | Interceptions by triggered team — defensive activity when out of possession | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_interceptions` | Interceptions by opponent — active disruption of triggered team's build-up | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_clearances` | Clearances by triggered team | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_clearances` | Clearances by opponent — volume of last-ditch defensive actions | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_tackles_won` | Tackles won by triggered team | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_tackles_won` | Tackles won by opponent — contested duels won defensively | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_shot_blocks` | Shot blocks by triggered team — defensive exposure on opponent breaks | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_shot_blocks` | Shot blocks by opponent — physical suppression of triggered team's rare attempts | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_corners` | Corners won by triggered team — indirect proxy for box pressure | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_corners` | Corners won by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
