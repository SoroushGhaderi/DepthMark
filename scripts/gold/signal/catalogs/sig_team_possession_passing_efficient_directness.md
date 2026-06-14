---
signal_id: sig_team_possession_passing_efficient_directness
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Efficient Directness"
trigger: "ball_possession <= 35` and `total_shots >= 15` at full match (`period = 'All'`) for home or away"
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_efficient_directness
  sql: clickhouse/gold/dml/signals/team/sig_team_possession_passing_efficient_directness.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_possession_passing_efficient_directness

## Purpose

Triggers when a team generates high shot volume with low possession, indicating efficient directness and transition-led threat creation.

## Tactical And Statistical Logic

- Trigger condition: `ball_possession <= 35` and `total_shots >= 15` at full match (`period = 'All'`) for home or away.
- Captures direct, transition-oriented football where threat generation is disproportionate to possession share.
- Enrichment layers differentiate clinical counter-attacking from noisy low-possession shot production.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_possession_passing_efficient_directness.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_possession_passing_efficient_directness`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_possession_passing_efficient_directness
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
| `triggered_team_id` | ID of the team with <=35% possession and >=15 shots | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `triggered_team_name` | Name of the triggered team | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `opponent_team_id` | ID of the opposition team | Football developer: provides side/opponent orientation so tactical readings are not misattributed — opponent or orientation field for bilateral interpretation |
| `opponent_team_name` | Name of the opposition team | Football developer: provides side/opponent orientation so tactical readings are not misattributed — opponent or orientation field for bilateral interpretation |
| `triggered_team_possession_pct` | Full-match possession % of triggered team — primary signal condition | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `opponent_possession_pct` | Full-match possession % of opponent — dominance baseline | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `triggered_team_total_shots` | Total shots by triggered team — primary signal condition | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `opponent_total_shots` | Total shots by opponent | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `triggered_team_shots_on_target` | Shots on target by triggered team — directness accuracy | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_shots_on_target` | Shots on target by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_shots_inside_box` | Shots from inside the box — proximity and danger of attempts | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_shots_inside_box` | Opponent shots from inside the box | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_big_chances` | Big chances created by triggered team — quality of transition openings | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_big_chances` | Big chances created by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_big_chances_missed` | Big chances missed by triggered team — clinical efficiency check | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_big_chances_missed` | Big chances missed by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_xg` | Total xG for triggered team — expected value of shots generated | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_xg` | Total xG for opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_xg_open_play` | Open-play xG for triggered team — transition-sourced threat only | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_xg_open_play` | Open-play xG for opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_xg_on_target` | xG on target for triggered team — quality of shots that tested keeper | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_xg_on_target` | xG on target for opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `xg_delta` | xG difference (triggered − opponent) — net expected threat balance | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_pass_attempts` | Pass attempts by triggered team — low volume confirms direct style | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_pass_attempts` | Pass attempts by opponent — confirms possession dominance | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_accurate_passes` | Accurate passes by triggered team | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_accurate_passes` | Accurate passes by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_pass_accuracy_pct` | Pass accuracy % of triggered team — quality of limited circulation | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_pass_accuracy_pct` | Pass accuracy % of opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_long_ball_attempts` | Long ball attempts by triggered team — key directness mechanism | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_long_ball_attempts` | Long ball attempts by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_accurate_long_balls` | Accurate long balls by triggered team — vertical progression success rate | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_accurate_long_balls` | Accurate long balls by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_touches_opposition_box` | Touches in opponent's box by triggered team — final-third penetration despite low possession | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_touches_opposition_box` | Opponent touches in triggered team's box | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_opposition_half_passes` | Triggered team passes in opponent's half — forward pitch occupation | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_opposition_half_passes` | Opponent passes in triggered team's half | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_interceptions` | Interceptions by triggered team — ball-winning to fuel transitions | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_interceptions` | Interceptions by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_tackles_won` | Tackles won by triggered team — ground-level ball recovery | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_tackles_won` | Tackles won by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_clearances` | Clearances by triggered team — defensive resilience under possession pressure | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_clearances` | Clearances by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_cross_attempts` | Cross attempts by triggered team — wide channel usage in attack | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_cross_attempts` | Cross attempts by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_accurate_crosses` | Accurate crosses by triggered team — delivery quality from wide | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_accurate_crosses` | Accurate crosses by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_corners` | Corners won by triggered team — set-piece volume as transition by-product | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_corners` | Corners won by opponent | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `triggered_team_fouls` | Fouls committed by triggered team — aggression in ball-winning | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `opponent_fouls` | Fouls committed by opponent — disruption of triggered team's transitions | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
