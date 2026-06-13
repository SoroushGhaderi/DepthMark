---
signal_id: sig_team_possession_passing_high_tempo_passing
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "High Tempo Passing"
trigger: "peak half passing tempo >= 6.5 passes per minute for at least one side"
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_high_tempo_passing
  sql: clickhouse/gold/signal/sig_team_possession_passing_high_tempo_passing.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_possession_passing_high_tempo_passing

## Purpose

Triggers when either side reaches a peak half passing tempo of `>= 6.5` passes per minute (half passes ÷ 45), indicating unusually high-possession circulation speed.

## Tactical And Statistical Logic

- Signal name: `sig_team_possession_passing_high_tempo_passing`.
- Trigger condition: either side peaks at `>= 6.5` passes per minute in one half (`FirstHalf`/`SecondHalf`).
- Measurement is symmetric for home and away and preserves bilateral context fields for downstream style classification.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_possession_passing_high_tempo_passing.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_possession_passing_high_tempo_passing`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_possession_passing_high_tempo_passing
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: anchors joins across match, team, and downstream feature tables |
| `match_date` | Calendar date of the match | Football developer: anchors joins across match, team, and downstream feature tables |
| `home_team_id` | Numeric ID of the home team | Football developer: anchors joins across match, team, and downstream feature tables |
| `home_team_name` | Display name of the home team | Football developer: anchors joins across match, team, and downstream feature tables |
| `away_team_id` | Numeric ID of the away team | Football developer: anchors joins across match, team, and downstream feature tables |
| `away_team_name` | Display name of the away team | Football developer: anchors joins across match, team, and downstream feature tables |
| `home_score` | Full-time goals scored by home team | Football developer: anchors joins across match, team, and downstream feature tables / result context |
| `away_score` | Full-time goals scored by away team | Football developer: anchors joins across match, team, and downstream feature tables / result context |
| `home_possession_first_half_pct` | Home team ball possession % in first half | Football developer: provides side/opponent orientation so tactical readings are not misattributed — tempo only means something relative to how long a team holds the ball |
| `home_possession_second_half_pct` | Home team ball possession % in second half | Football developer: provides side/opponent orientation so tactical readings are not misattributed — half-by-half possession shift reveals game state influence |
| `away_possession_first_half_pct` | Away team ball possession % in first half | Football developer: provides side/opponent orientation so tactical readings are not misattributed — symmetric pair to `home_possession_first_half_pct` |
| `away_possession_second_half_pct` | Away team ball possession % in second half | Football developer: provides side/opponent orientation so tactical readings are not misattributed — symmetric pair to `home_possession_second_half_pct` |
| `home_passes_first_half` | Total passes by home team in first half | Football developer: this is the direct trigger metric used to classify the tactical pattern source — raw numerator for passes-per-min proxy |
| `home_passes_second_half` | Total passes by home team in second half | Football developer: this is the direct trigger metric used to classify the tactical pattern source — detects half-level tempo shift |
| `away_passes_first_half` | Total passes by away team in first half | Football developer: this is the direct trigger metric used to classify the tactical pattern — symmetric pair to `home_passes_first_half` |
| `away_passes_second_half` | Total passes by away team in second half | Football developer: this is the direct trigger metric used to classify the tactical pattern — symmetric pair to `home_passes_second_half` |
| `home_passes_per_minute_first_half` | Home passes ÷ 45 for first half | Football developer: this is the direct trigger metric used to classify the tactical pattern — passes-per-minute proxy, H1 |
| `home_passes_per_minute_second_half` | Home passes ÷ 45 for second half | Football developer: this is the direct trigger metric used to classify the tactical pattern — passes-per-minute proxy, H2 |
| `away_passes_per_minute_first_half` | Away passes ÷ 45 for first half | Football developer: this is the direct trigger metric used to classify the tactical pattern — symmetric pair to `home_passes_per_minute_first_half` |
| `away_passes_per_minute_second_half` | Away passes ÷ 45 for second half | Football developer: this is the direct trigger metric used to classify the tactical pattern — symmetric pair to `home_passes_per_minute_second_half` |
| `home_peak_passes_per_minute` | Higher of H1/H2 passes-per-min for home team | Football developer: this is the direct trigger metric used to classify the tactical pattern — single trigger value used in HAVING and ranking |
| `away_peak_passes_per_minute` | Higher of H1/H2 passes-per-min for away team | Football developer: this is the direct trigger metric used to classify the tactical pattern — symmetric pair to `home_peak_passes_per_minute` |
| `home_accurate_passes_total` | Successful passes by home team across both halves | Football developer: adds diagnostic football context to explain why the trigger fired — volume without quality is misleading; accurate passes confirm circulation intent |
| `away_accurate_passes_total` | Successful passes by away team across both halves | Football developer: adds diagnostic football context to explain why the trigger fired — symmetric pair |
| `home_pass_attempts_total` | Total pass attempts by home team across both halves | Football developer: adds diagnostic football context to explain why the trigger fired — denominator for accuracy; exposes high-volume low-accuracy spam |
| `away_pass_attempts_total` | Total pass attempts by away team across both halves | Football developer: adds diagnostic football context to explain why the trigger fired — symmetric pair |
| `home_pass_accuracy_pct` | Accurate ÷ attempted passes % for home team | Football developer: adds diagnostic football context to explain why the trigger fired — distinguishes high-quality tempo from high-risk direct play |
| `away_pass_accuracy_pct` | Accurate ÷ attempted passes % for away team | Football developer: adds diagnostic football context to explain why the trigger fired — symmetric pair |
| `home_minus_away_pass_accuracy_delta_pct` | Home pass accuracy % minus away pass accuracy % | Football developer: adds diagnostic football context to explain why the trigger fired — bilateral net; positive = home dominates circulation quality |
| `home_opposition_half_passes` | Home passes played in the opposition's half | Football developer: adds diagnostic football context to explain why the trigger fired — high tempo in the final third signals aggressive press-and-circulate; distinguishes deep build-up from advanced possession |
| `away_opposition_half_passes` | Away passes played in the opposition's half | Football developer: adds diagnostic football context to explain why the trigger fired — symmetric pair |
| `home_own_half_passes` | Home passes played in own half | Football developer: adds diagnostic football context to explain why the trigger fired — high own-half share with high tempo = safety-first build-up rather than progressive intent |
| `away_own_half_passes` | Away passes played in own half | Football developer: adds diagnostic football context to explain why the trigger fired — symmetric pair |
| `home_opposition_half_pass_pct` | % of home passes played in opposition half | Football developer: adds diagnostic football context to explain why the trigger fired — progressive territory ratio; cross-reference with tempo to classify style archetype |
| `away_opposition_half_pass_pct` | % of away passes played in opposition half | Football developer: adds diagnostic football context to explain why the trigger fired — symmetric pair |
| `triggered_side` | Which side(s) fired the signal: `'home'`, `'away'`, or `'both'` | Football developer: this is the direct trigger metric used to classify the tactical pattern — routes downstream analysis to the correct team for asymmetric comparisons |
