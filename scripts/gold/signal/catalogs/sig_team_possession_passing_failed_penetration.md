---
signal_id: sig_team_possession_passing_failed_penetration
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Failed Penetration"
trigger: "touches_opp_box >= 30 with shots_inside_box < 10 for the triggered side"
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_failed_penetration
  sql: clickhouse/gold/signal/sig_team_possession_passing_failed_penetration.sql
  runner: scripts/gold/signal/runners/sig_team_possession_passing_failed_penetration.py
---
# sig_team_possession_passing_failed_penetration

## Purpose

Detects matches where a team records high opponent-box touch volume without converting that territory into inside-box shot generation.

## Tactical And Statistical Logic

- Trigger condition: `touches_opp_box >= 30` with `shots_inside_box < 10` (for home or away).
- Signal name source: `-- === sig_team_possession_passing_failed_penetration ===`
- Trigger condition source: `-- Detects matches where a team achieves >= 30 touches in the opponent penalty box`

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_possession_passing_failed_penetration.sql`
- Runner: `scripts/gold/signal/runners/sig_team_possession_passing_failed_penetration.py`
- Target table: `gold_signals.sig_team_possession_passing_failed_penetration`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_possession_passing_failed_penetration.py
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
| `triggered_side` | Whether the triggered team played home or away | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `triggered_team_id` | Numeric ID of the team that triggered the signal | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `triggered_team_name` | Display name of the triggered team | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `opponent_team_id` | Numeric ID of the opposition | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `opponent_team_name` | Display name of the opposition | Football developer: provides side/opponent orientation so tactical readings are not misattributed |
| `triggered_team_touches_opposition_box` | Triggered team's touches in opponent penalty box (≥30 — signal volume) | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `triggered_team_shots_inside_box` | Inside-box shots by triggered team (<5 — signal failure condition) | Football developer: this is the direct trigger metric used to classify the tactical pattern |
| `opponent_touches_opposition_box` | Opposition touches in triggered team's penalty box | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_shots_inside_box` | Inside-box shots by the opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_touches_per_box_shot` | Box touches required per inside-box shot for triggered team — measures conversion collapse | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_touches_per_box_shot` | Box touches required per inside-box shot for opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_total_shots` | All shot attempts (inside + outside box) by triggered team | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_total_shots` | All shot attempts by opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_xg` | Expected goals for triggered team — quantifies if box presence yielded actual threat quality | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_xg` | Expected goals for opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_big_chances` | Big chances created by triggered team — highest-quality opportunities generated | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_big_chances_missed` | Big chances squandered by triggered team — measures wastefulness under failed penetration | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_big_chances` | Big chances created by opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_big_chances_missed` | Big chances squandered by opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_accurate_crosses` | Successful crosses delivered by triggered team — primary route when shots are not taken | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_cross_attempts` | Total crossing attempts by triggered team | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_cross_accuracy_pct` | Cross completion rate (%) for triggered team | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_accurate_crosses` | Successful crosses delivered by opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_cross_attempts` | Total crossing attempts by opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_cross_accuracy_pct` | Cross completion rate (%) for opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_dribbles_succeeded` | Successful dribbles by triggered team — individual carry into box as alternative to combination play | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_dribble_attempts` | Total dribble attempts by triggered team | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_dribbles_succeeded` | Successful dribbles by opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_dribble_attempts` | Total dribble attempts by opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_opposition_half_passes` | Passes completed in opponent's half by triggered team — measures sustained pressure phase volume | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_opposition_half_passes` | Passes completed in opponent's half by the opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `triggered_team_corners` | Corners won by triggered team — often the byproduct of failed final-action delivery into the box | Football developer: adds diagnostic football context to explain why the trigger fired |
| `opponent_corners` | Corners won by opponent | Football developer: adds diagnostic football context to explain why the trigger fired |
| `box_touch_delta` | Triggered team box touches minus opponent box touches — positive = triggered team dominated final-third territory | Football developer: adds diagnostic football context to explain why the trigger fired (net) |
| `xg_delta` | Triggered team xG minus opponent xG — reveals whether territorial dominance translated to expected threat | Football developer: adds diagnostic football context to explain why the trigger fired (net) |
| `corners_delta` | Triggered team corners minus opponent corners — net corner superiority from box-entry attempts | Football developer: adds diagnostic football context to explain why the trigger fired (net) |
