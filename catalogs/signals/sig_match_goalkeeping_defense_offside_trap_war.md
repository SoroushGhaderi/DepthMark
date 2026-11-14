---
signal_id: sig_match_goalkeeping_defense_offside_trap_war
status: active
entity: match
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Offside Trap War"
trigger: "Both teams are caught offside >= 4 times in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_goalkeeping_defense_offside_trap_war
  sql: clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_offside_trap_war.sql
---
# sig_match_goalkeeping_defense_offside_trap_war

## Purpose

Flags a two-way offside battle, a high-line and tactical-trap marker.

## Tactical And Statistical Logic

- Trigger: Both teams are caught offside >= 4 times in a finished match.
- Both `offsides_home` and `offsides_away` are at least 4. The measure is the lower of the two. Stats come from `fotmob_silver.period_stat` (`period = 'All'`). The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_match_goalkeeping_defense_offside_frenzy` (combined offsides > 10) and `sig_match_goalkeeping_defense_coordinated_trap_match` (combined >= 12). Related defence signals: `sig_match_goalkeeping_defense_offside_frenzy`, `sig_team_goalkeeping_defense_offside_trap_mastery` and `sig_match_goalkeeping_defense_tackle_and_interception_fest`. Different logic: each team at least 4. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_offside_trap_war.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_goalkeeping_defense_offside_trap_war`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_goalkeeping_defense_offside_trap_war
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable match key for joins and QA. |
| `match_date` | Match date | Temporal slicing and partition compatibility. |
| `home_team_id` | Home team identifier | Fixture orientation anchor. |
| `home_team_name` | Home team name | Readable fixture context. |
| `away_team_id` | Away team identifier | Fixture orientation anchor. |
| `away_team_name` | Away team name | Readable fixture context. |
| `home_score` | Full-time home goals | Outcome context for the streak match. |
| `away_score` | Full-time away goals | Outcome context for the streak match. |
| `triggered_side` | Row orientation (`home` or `away`) | Canonical side identity for match-team grain. |
| `triggered_team_id` | Triggered-side team identifier | Team attribution key for downstream features. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral context. |
| `trigger_threshold_min_offsides_per_team` | Configured trigger floor (each team caught offside at least `4` times) | Explicit trigger provenance for explainability and QA. |
| `match_lower_team_offsides` | The lower of the two teams' offside counts | Core signal intensity variable. |
| `match_lower_team_offsides_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `home_offsides` | Offsides called against the home side | Per-side split. |
| `away_offsides` | Offsides called against the away side | Per-side split. |
| `triggered_team_goals` | Triggered-side goals in the match | Result context for the streak match. |
| `opponent_goals` | Opponent goals in the match | Bilateral result comparator. |
| `triggered_team_xg` | Triggered-side expected goals (xG) | Chance-quality and control context behind the streak result. |
| `opponent_xg` | Opponent expected goals (xG) | Bilateral comparator for the same match. |
| `triggered_team_total_shots` | Triggered-side total shots | Chance-quality and control context behind the streak result. |
| `opponent_total_shots` | Opponent total shots | Bilateral comparator for the same match. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Chance-quality and control context behind the streak result. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral comparator for the same match. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Chance-quality and control context behind the streak result. |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral comparator for the same match. |
