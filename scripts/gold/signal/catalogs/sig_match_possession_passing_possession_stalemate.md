---
signal_id: sig_match_possession_passing_possession_stalemate
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Possession Passing Possession Stalemate"
trigger: "Both teams record exactly 50% possession at full time (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_possession_passing_possession_stalemate
  sql: clickhouse/gold/signal/sig_match_possession_passing_possession_stalemate.sql
  runner: scripts/gold/signal/runners/sig_match_possession_passing_possession_stalemate.py
---
# sig_match_possession_passing_possession_stalemate

## Purpose

Triggers when both teams finish the match with exactly 50% possession, flagging possession stalemate matches where ball control is perfectly balanced.

## Tactical And Statistical Logic

- Trigger condition: both home and away sides have `ball_possession = 50` at full match (`period = 'All'`).
- Emits one row per side (`triggered_side in {'home','away'}`) so downstream team-centric consumers can analyze the stalemate from each orientation.
- Enriches the equality trigger with bilateral passing volume, pass quality, territorial progression, and chance-creation context to separate low-event standoffs from high-intensity balanced contests.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_possession_passing_possession_stalemate.sql`
- Runner: `scripts/gold/signal/runners/sig_match_possession_passing_possession_stalemate.py`
- Target table: `gold_signals.sig_match_possession_passing_possession_stalemate`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_possession_passing_possession_stalemate.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `match_date` | Calendar date of the match | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `home_team_id` | Home team numeric ID | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `home_team_name` | Home team display name | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `away_team_id` | Away team numeric ID | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `away_team_name` | Away team display name | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `home_score` | Full-time goals scored by home team | Football developer: anchors joins across match, team, and downstream feature tables / outcome context |
| `away_score` | Full-time goals scored by away team | Football developer: anchors joins across match, team, and downstream feature tables / outcome context |
| `triggered_side` | Whether the triggered row is oriented to `'home'` or `'away'` | Football developer: this is the direct trigger metric used to classify the tactical pattern — row orientation label |
| `triggered_team_id` | Numeric ID of the side represented in this row | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `triggered_team_name` | Display name of the triggered side | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `opponent_team_id` | Numeric ID of the opposing side | Football developer: opponent or orientation field for bilateral interpretation |
| `opponent_team_name` | Display name of the opposing side | Football developer: opponent or orientation field for bilateral interpretation |
| `triggered_team_possession_pct` | Full-match possession % of triggered side (always 50) | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field |
| `opponent_possession_pct` | Full-match possession % of opponent side (always 50) | Football developer: this is the direct trigger metric used to classify the tactical pattern — symmetric trigger pair |
| `possession_gap_pct` | Absolute possession gap between teams (always 0) | Football developer: this is the direct trigger metric used to classify the tactical pattern — equality sanity field |
| `triggered_team_pass_attempts` | Total pass attempts by triggered side | Football developer: adds diagnostic football context to explain why the trigger fired — possession implementation volume |
| `opponent_pass_attempts` | Total pass attempts by opponent side | Football developer: adds diagnostic football context to explain why the trigger fired — bilateral comparator |
| `triggered_team_pass_accuracy_pct` | Pass completion rate of triggered side | Football developer: adds diagnostic football context to explain why the trigger fired — quality of controlled circulation |
| `opponent_pass_accuracy_pct` | Pass completion rate of opponent side | Football developer: adds diagnostic football context to explain why the trigger fired — bilateral quality comparator |
| `triggered_team_final_third_passes` | Triggered side completed passes in opposition half/final-third territory | Football developer: adds diagnostic football context to explain why the trigger fired — territorial usage of possession |
| `opponent_final_third_passes` | Opponent completed passes in opposition half/final-third territory | Football developer: adds diagnostic football context to explain why the trigger fired — territorial bilateral comparator |
| `triggered_team_touches_opposition_box` | Triggered side touches inside opponent penalty area | Football developer: adds diagnostic football context to explain why the trigger fired — penetration context |
| `opponent_touches_opposition_box` | Opponent touches inside triggered side penalty area | Football developer: adds diagnostic football context to explain why the trigger fired — bilateral penetration comparator |
| `triggered_team_total_shots` | Total shots by triggered side | Football developer: adds diagnostic football context to explain why the trigger fired — chance-volume context |
| `opponent_total_shots` | Total shots by opponent side | Football developer: adds diagnostic football context to explain why the trigger fired — bilateral chance-volume comparator |
| `triggered_team_xg` | Total expected goals generated by triggered side | Football developer: adds diagnostic football context to explain why the trigger fired — chance-quality context |
| `opponent_xg` | Total expected goals generated by opponent side | Football developer: adds diagnostic football context to explain why the trigger fired — bilateral chance-quality comparator |
| `xg_gap` | Triggered minus opponent xG | Football developer: adds diagnostic football context to explain why the trigger fired — balanced possession but possible chance asymmetry |
