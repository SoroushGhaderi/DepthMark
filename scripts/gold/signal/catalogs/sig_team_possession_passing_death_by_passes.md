---
signal_id: sig_team_possession_passing_death_by_passes
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Death By Passes"
trigger: "at least one side has `touches_opp_box > 50` on full-match aggregates (`period = 'All'`)"
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_death_by_passes
  sql: clickhouse/gold/dml/signals/team/sig_team_possession_passing_death_by_passes.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_possession_passing_death_by_passes

## Purpose

Triggers when a team records extreme opposition-box touch volume (`>50`) as a proxy for siege-style final-third dominance.

## Tactical And Statistical Logic

- Trigger condition: at least one side has `touches_opp_box > 50` on full-match aggregates (`period = 'All'`).
- Dynamic triggered/opponent resolution ensures `triggered_team_*` always points to the side that fired the signal.
- Enrichment validates whether box presence reflected controlled territorial domination or sterile pressure.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_possession_passing_death_by_passes.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_possession_passing_death_by_passes`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_possession_passing_death_by_passes
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `match_date` | Calendar date of the match | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `home_team_id` | Numeric ID of the home team | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `home_team_name` | Display name of the home team | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `away_team_id` | Numeric ID of the away team | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `away_team_name` | Display name of the away team | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `home_score` | Home team final goals scored | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `away_score` | Away team final goals scored | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical row identity at match-team grain; required for deterministic activation IDs |
| `triggered_team_id` | Numeric ID of the team that exceeded 50 box touches; home takes precedence when both trigger | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `triggered_team_name` | Display name of the triggered team | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `opponent_team_id` | Numeric ID of the opposing team | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `opponent_team_name` | Display name of the opposing team | Football developer: anchors joins across match, team, and downstream feature tables — stable match/team reference field |
| `both_sides_triggered` | 1 if both teams independently exceeded the 50-touch threshold in the same match | Football developer: provides side/opponent orientation so tactical readings are not misattributed — flags matches where the signal fires bilaterally |
| `triggered_team_opposition_box_touches` | Total opposition-box touches by the triggered team | Football developer: this is the direct trigger metric used to classify the tactical pattern — core measured signal value for the triggered side |
| `opponent_opposition_box_touches` | Total opposition-box touches by the opponent | Football developer: this is the direct trigger metric used to classify the tactical pattern — symmetric pair; contextualises whether dominance was one-sided |
| `opposition_box_touches_delta` | Triggered team minus opponent opposition-box touches | Football developer: this is the direct trigger metric used to classify the tactical pattern — bilateral net spatial dominance in the final third |
| `triggered_team_possession_pct` | Ball possession percentage of the triggered team | Football developer: adds diagnostic football context to explain why the trigger fired — sustained box presence should correlate with possession control |
| `opponent_possession_pct` | Ball possession percentage of the opponent | Football developer: adds diagnostic football context to explain why the trigger fired — symmetric pair; reveals whether opponent was passive or active |
| `triggered_team_opposition_half_passes` | Total passes by the triggered team completed in the opponent's half | Football developer: adds diagnostic football context to explain why the trigger fired — confirms broad advanced territorial operation enabling box penetration |
| `opponent_opposition_half_passes` | Total passes by the opponent completed in the triggered team's half | Football developer: adds diagnostic football context to explain why the trigger fired — symmetric pair; measures opponent's ability to escape their own half |
| `triggered_team_pass_attempts` | Total pass attempts by the triggered team | Football developer: adds diagnostic football context to explain why the trigger fired — denominates box touches within overall passing activity |
| `opponent_pass_attempts` | Total pass attempts by the opponent | Football developer: adds diagnostic football context to explain why the trigger fired — symmetric pair; overall passing volume for the defending side |
| `triggered_team_pass_accuracy_pct` | Pass completion rate of the triggered team as a percentage | Football developer: adds diagnostic football context to explain why the trigger fired — high touch counts with poor accuracy signals chaotic rather than controlled dominance |
| `opponent_pass_accuracy_pct` | Pass completion rate of the opponent as a percentage | Football developer: adds diagnostic football context to explain why the trigger fired — symmetric pair; low accuracy under pressure confirms defensive disruption |
| `triggered_team_box_touch_per_pass_pct` | Triggered team opposition-box touches as a percentage of total pass attempts | Football developer: adds diagnostic football context to explain why the trigger fired — measures how efficiently possession was funnelled into box-level activity |
| `opponent_box_touch_per_pass_pct` | Opponent opposition-box touches as a percentage of their total pass attempts | Football developer: adds diagnostic football context to explain why the trigger fired — symmetric pair; shows counter-threat penetration efficiency |
| `triggered_team_xg` | Total expected goals generated by the triggered team | Football developer: adds diagnostic football context to explain why the trigger fired — tests whether sustained box presence produced high-quality chances |
| `opponent_xg` | Total expected goals generated by the opponent | Football developer: adds diagnostic football context to explain why the trigger fired — symmetric pair; measures defensive xG conceded under box siege |
| `triggered_team_xg_per_box_touch` | Triggered team xG divided by total opposition-box touches | Football developer: adds diagnostic football context to explain why the trigger fired — quality efficiency of box entries; low value exposes sterile domination |
| `opponent_xg_per_box_touch` | Opponent xG divided by their total opposition-box touches | Football developer: adds diagnostic football context to explain why the trigger fired — symmetric pair; efficiency of opponent's limited box entries |
| `xg_delta` | Home xG minus away xG across the full match | Football developer: adds diagnostic football context to explain why the trigger fired — bilateral net attacking threat differential |
| `triggered_team_big_chances` | Total big chances created by the triggered team | Football developer: adds diagnostic football context to explain why the trigger fired — directly tests whether box dominance yielded clear-cut opportunities |
| `opponent_big_chances` | Total big chances created by the opponent | Football developer: adds diagnostic football context to explain why the trigger fired — symmetric pair; measures opponent's ability to create despite being pinned |
| `triggered_team_big_chances_missed` | Total big chances missed by the triggered team | Football developer: adds diagnostic football context to explain why the trigger fired — measures clinical failure despite territorial dominance |
| `opponent_big_chances_missed` | Total big chances missed by the opponent | Football developer: adds diagnostic football context to explain why the trigger fired — symmetric pair; missed chances for the side defending the siege |
| `triggered_team_shots_inside_box` | Shots taken from inside the box by the triggered team | Football developer: adds diagnostic football context to explain why the trigger fired — confirms box touches converted into close-range attempts, not peripheral activity |
| `opponent_shots_inside_box` | Shots taken from inside the box by the opponent | Football developer: adds diagnostic football context to explain why the trigger fired — symmetric pair; counter-threat via box-level shot attempts |
| `triggered_team_corners` | Total corners won by the triggered team | Football developer: adds diagnostic football context to explain why the trigger fired — high corner count correlates with sustained box-area pressure and failed clearances |
| `opponent_corners` | Total corners won by the opponent | Football developer: adds diagnostic football context to explain why the trigger fired — symmetric pair; opponent's set-piece exposure under pressure |
| `triggered_team_accurate_crosses` | Accurate deliveries into the box by the triggered team | Football developer: adds diagnostic football context to explain why the trigger fired — cross volume directly feeds touch accumulation inside the box |
| `opponent_accurate_crosses` | Accurate deliveries into the box by the opponent | Football developer: adds diagnostic football context to explain why the trigger fired — symmetric pair; opponent's delivery threat on the counter |
