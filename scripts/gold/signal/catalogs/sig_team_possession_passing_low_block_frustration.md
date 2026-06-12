---
signal_id: sig_team_possession_passing_low_block_frustration
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Low Block Frustration"
trigger: "cross_attempts > 40` on full-match stats (`period = 'All'`) for home or away"
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_low_block_frustration
  sql: clickhouse/gold/signal/sig_team_possession_passing_low_block_frustration.sql
  runner: scripts/gold/signal/runners/sig_team_possession_passing_low_block_frustration.py
---
# sig_team_possession_passing_low_block_frustration

## Purpose

Triggers when a team records extreme cross volume in one match, indicating wide-overload behaviour caused by blocked central access.

## Tactical And Statistical Logic

- Trigger condition: `cross_attempts > 40` on full-match stats (`period = 'All'`) for home or away.
- This flags low-block frustration patterns where central progression is denied and attacks are repeatedly rerouted wide.
- Enrichment fields validate whether crossing pressure converted into threat and whether opponent defensive block behaviours were present.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_possession_passing_low_block_frustration.sql`
- Runner: `scripts/gold/signal/runners/sig_team_possession_passing_low_block_frustration.py`
- Target table: `gold_signals.sig_team_possession_passing_low_block_frustration`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_possession_passing_low_block_frustration.py
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
| `triggered_team_id` | ID of the team that attempted >40 crosses | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `triggered_team_name` | Name of the triggered team | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `opponent_team_id` | ID of the opposition team | Football developer: provides side/opponent orientation so tactical readings are not misattributed — opponent or orientation field for bilateral interpretation |
| `opponent_team_name` | Name of the opposition team | Football developer: provides side/opponent orientation so tactical readings are not misattributed — opponent or orientation field for bilateral interpretation |
| `triggered_team_cross_attempts` | Cross attempts by triggered team — the primary signal condition | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `opponent_cross_attempts` | Cross attempts by opponent | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `triggered_team_accurate_crosses` | Accurate crosses by triggered team — delivery success within the overload | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_accurate_crosses` | Accurate crosses by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_cross_accuracy_pct` | Cross accuracy % of triggered team — quality of wide delivery under frustration | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_cross_accuracy_pct` | Cross accuracy % of opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_touches_opposition_box` | Touches in opponent's box by triggered team — central penetration despite wide overload | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_touches_opposition_box` | Opponent touches in triggered team's box | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_opposition_half_passes` | Passes in opponent's half by triggered team — confirms sustained territorial pressure | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_opposition_half_passes` | Opponent passes in triggered team's half | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_dribbles_succeeded` | Successful dribbles by triggered team — attempts to beat the block 1v1 through the middle | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_dribbles_succeeded` | Successful dribbles by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_dribble_attempts` | Dribble attempts by triggered team — frequency of individual central carry attempts | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_dribble_attempts` | Dribble attempts by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_possession_pct` | Full-match possession % of triggered team — confirms attacking dominance framing | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_possession_pct` | Full-match possession % of opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_pass_attempts` | Total pass attempts by triggered team — volume of circulation before switching wide | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_pass_attempts` | Total pass attempts by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_accurate_passes` | Accurate passes by triggered team | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_accurate_passes` | Accurate passes by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_pass_accuracy_pct` | Pass accuracy % of triggered team | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_pass_accuracy_pct` | Pass accuracy % of opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_total_shots` | Total shots by triggered team — did crossing yield attempts at all? | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_total_shots` | Total shots by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_shots_on_target` | Shots on target by triggered team — quality of chances from wide delivery | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_shots_on_target` | Shots on target by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_shots_inside_box` | Shots from inside the box by triggered team — crossing converts to close-range chances | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_shots_inside_box` | Shots from inside the box by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_shots_outside_box` | Shots from outside the box by triggered team — speculative attempts when block holds firm | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_shots_outside_box` | Shots from outside the box by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_big_chances` | Big chances created by triggered team — whether crossing ever broke the block decisively | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_big_chances` | Big chances created by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_big_chances_missed` | Big chances missed by triggered team — wastefulness under frustration | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_big_chances_missed` | Big chances missed by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_xg` | Total xG for triggered team — expected value of all attempts generated | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_xg` | Total xG for opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_xg_set_play` | Set-play xG for triggered team — crosses often lead to set-play-adjacent situations | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_xg_set_play` | Set-play xG for opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_xg_open_play` | Open-play xG for triggered team — transition-sourced threat only | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_xg_open_play` | Open-play xG for opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `xg_delta` | xG difference (triggered − opponent) — net expected threat balance despite wide overload | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_clearances` | Clearances by triggered team | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_clearances` | Clearances by opponent — volume of headed/last-ditch defending of crosses | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_interceptions` | Interceptions by triggered team | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_interceptions` | Interceptions by opponent — active disruption of build-up before it reaches wide areas | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_shot_blocks` | Shot blocks by triggered team | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_shot_blocks` | Shot blocks by opponent — physical suppression of attempts from cross-derived positions | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_aerials_won` | Aerial duels won by triggered team — success in contesting crossed balls | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_aerials_won` | Aerial duels won by opponent — defensive dominance in the air against crosses | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_aerial_attempts` | Aerial duel attempts by triggered team | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_aerial_attempts` | Aerial duel attempts by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_corners` | Corners won by triggered team — natural by-product of sustained wide pressure | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_corners` | Corners won by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_fouls` | Fouls committed by triggered team — aggression in trying to win the ball back quickly | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_fouls` | Fouls committed by opponent — how cynically the block was maintained | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
