---
signal_id: sig_team_possession_passing_siege_mode
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Siege Mode"
trigger: "ball_possession_home > 80` (home trigger) or `ball_possession_away > 80` (away trigger) for `period = 'All'`"
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_siege_mode
  sql: clickhouse/gold/signal/sig_team_possession_passing_siege_mode.sql
  runner: scripts/gold/signal/runners/sig_team_possession_passing_siege_mode.py
---
# sig_team_possession_passing_siege_mode

## Purpose

Triggers when a team sustains more than 80% full-match possession, indicating total territorial siege and opponent suppression.

## Tactical And Statistical Logic

- Trigger condition: `ball_possession_home > 80` (home trigger) or `ball_possession_away > 80` (away trigger) for `period = 'All'`.
- Signal is side-specific (`home` / `away`) and includes opponent identity for contextual analysis.
- Enrichment captures whether possession dominance is productive (xG, shots, box touches, corners, progression, and pass quality).

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_possession_passing_siege_mode.sql`
- Runner: `scripts/gold/signal/runners/sig_team_possession_passing_siege_mode.py`
- Target table: `gold_signals.sig_team_possession_passing_siege_mode`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_possession_passing_siege_mode.py
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
| `triggered_team_id` | ID of the team that exceeded 80% possession | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `triggered_team_name` | Name of the team that exceeded 80% possession | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `opponent_team_id` | ID of the opposition team | Football developer: provides side/opponent orientation so tactical readings are not misattributed — opponent or orientation field for bilateral interpretation |
| `opponent_team_name` | Name of the opposition team | Football developer: provides side/opponent orientation so tactical readings are not misattributed — opponent or orientation field for bilateral interpretation |
| `triggered_team_possession_pct` | Full-match possession % of the triggered team | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `opponent_possession_pct` | Full-match possession % of the opposition | Football developer: provides side/opponent orientation so tactical readings are not misattributed — opponent or orientation field for bilateral interpretation |
| `possession_delta` | Difference in possession % between triggered team and opponent | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `triggered_team_pass_attempts` | Total pass attempts by triggered team — volume of the siege | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_pass_attempts` | Total pass attempts by opponent — how suppressed were they | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_accurate_passes` | Accurate passes completed by triggered team | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_accurate_passes` | Accurate passes completed by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_pass_accuracy_pct` | Pass accuracy % of triggered team — quality of circulation | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_pass_accuracy_pct` | Pass accuracy % of opponent — disruption level under pressure | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_opposition_half_passes` | Passes completed in the opponent's half — forward intent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_opposition_half_passes` | Opponent passes in triggered team's half — counter-threat check | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_touches_opposition_box` | Touches inside the opponent's box — final-third penetration | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_touches_opposition_box` | Opponent touches in triggered team's box — defensive exposure | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_corners` | Corners won by triggered team — set-piece volume from dominance | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_corners` | Corners won by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_shots` | Total shots by triggered team — shot volume from possession | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_shots` | Total shots by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_shots_on_target` | Shots on target by triggered team — accuracy of attack | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_big_chances` | Big chances created by triggered team — quality of threat | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_big_chances` | Big chances created by opponent — danger despite low possession | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_xg` | Expected goals for triggered team — shot quality generated | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_xg` | Expected goals for opponent — threat via low-possession tactics | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `xg_delta` | xG difference (triggered − opponent) — whether dominance was productive | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
