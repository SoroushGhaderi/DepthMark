---
signal_id: sig_team_goalkeeping_defense_box_entry_denial
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Box Entry Denial"
trigger: "Team allows fewer than 10 opposition touches in its penalty area in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_goalkeeping_defense_box_entry_denial
  sql: clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_box_entry_denial.sql
---
# sig_team_goalkeeping_defense_box_entry_denial

## Purpose

Flags a defence that seals the penalty area, a low-pressure and box-control marker.

## Tactical And Statistical Logic

- Trigger: Team allows fewer than 10 opposition touches in its penalty area in a finished match.
- The opponent's `touches_opp_box` in `fotmob_silver.period_stat` is below 10 and is present (a missing value cannot qualify). Stats come from `fotmob_silver.period_stat` (`period = 'All'`).
- Similarity note: Closest: `sig_team_goalkeeping_defense_box_evacuation` (clearances) and `sig_match_goalkeeping_defense_box_siege_survival` (surviving 40+ touches). Different logic: the opposite, almost no box touches allowed. No overlap. Related defence signals: `sig_match_goalkeeping_defense_offside_frenzy`, `sig_team_goalkeeping_defense_offside_trap_mastery` and `sig_match_goalkeeping_defense_tackle_and_interception_fest`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_box_entry_denial.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_goalkeeping_defense_box_entry_denial`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_goalkeeping_defense_box_entry_denial
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
| `trigger_threshold_max_opponent_box_touches` | Configured trigger ceiling (fewer than `10` opposition box touches) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_opponent_box_touches_allowed` | Opposition touches in the team's penalty area | Core signal intensity variable. |
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
