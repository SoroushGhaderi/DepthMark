---
signal_id: sig_team_possession_passing_high_press_victim
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "High Press Victim"
trigger: "accurate_passes / pass_attempts < 0.70` for home or away in full-match totals (`period = 'All'`)"
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_high_press_victim
  sql: clickhouse/gold/signal/sig_team_possession_passing_high_press_victim.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_possession_passing_high_press_victim

## Purpose

Triggers when a team's pass accuracy drops below 70% as a proxy for defensive-third breakdown under high press.

## Tactical And Statistical Logic

- Trigger condition: `accurate_passes / pass_attempts < 0.70` for home or away in full-match totals (`period = 'All'`).
- If both teams are below threshold, `triggered_side = both` and team-specific trigger identifiers are set to `NULL`.
- Enrichment fields provide context through pass volume, pass accuracy delta, and own-half pass share.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_possession_passing_high_press_victim.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_possession_passing_high_press_victim`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_possession_passing_high_press_victim
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `match_date` | Date the match was played | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `home_team_id` | Home team ID | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `home_team_name` | Home team name | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `away_team_id` | Away team ID | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `away_team_name` | Away team name | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `home_score` | Full-time home goals | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `away_score` | Full-time away goals | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `triggered_side` | Which side triggered the signal (`home`, `away`, `both`) | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `triggered_team_id` | Team ID of the triggered side | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `triggered_team_name` | Team name of the triggered side | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `triggered_team_pass_accuracy_pct` | Pass accuracy (%) of the triggered team — the core signal value | Football developer: this is the direct trigger metric used to classify the tactical pattern — core trigger field or direct signal context |
| `home_pass_accuracy_pct` | Home team pass accuracy (%) across full match | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `away_pass_accuracy_pct` | Away team pass accuracy (%) across full match | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `pass_accuracy_delta_pct` | Absolute accuracy gap between home and away — large delta implies one team imposed the press | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `pass_attempts_home` | Total passes attempted by home team — low volume + low accuracy = severe press domination | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `pass_attempts_away` | Total passes attempted by away team — same rationale | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `own_half_pass_share_home_pct` | Share of home passes played in own half — high value indicates team was pinned back | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
| `own_half_pass_share_away_pct` | Share of away passes played in own half — same rationale | Football developer: adds diagnostic football context to explain why the trigger fired — diagnostic context for interpreting signal quality and cause |
