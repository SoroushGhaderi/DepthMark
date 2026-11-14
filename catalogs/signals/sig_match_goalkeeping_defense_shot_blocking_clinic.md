---
signal_id: sig_match_goalkeeping_defense_shot_blocking_clinic
status: active
entity: match
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Shot Blocking Clinic"
trigger: "More shots are blocked than reach the goalkeepers (combined) in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_goalkeeping_defense_shot_blocking_clinic
  sql: clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_shot_blocking_clinic.sql
---
# sig_match_goalkeeping_defense_shot_blocking_clinic

## Purpose

Flags a block-heavy match, a compact-defence marker.

## Tactical And Statistical Logic

- Trigger: More shots are blocked than reach the goalkeepers (combined) in a finished match.
- Combined blocked shots are greater than combined shots on target, with at least one blocked shot. Stats come from `fotmob_silver.period_stat` (`period = 'All'`). The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_match_goalkeeping_defense_box_scramble_chaos` (>= 10 blocked shots) and `sig_player_shooting_goals_blocked_shot_frustration`. Related defence signals: `sig_match_goalkeeping_defense_offside_frenzy`, `sig_team_goalkeeping_defense_offside_trap_mastery` and `sig_match_goalkeeping_defense_tackle_and_interception_fest`. Different logic: blocks outnumber shots on target. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_shot_blocking_clinic.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_goalkeeping_defense_shot_blocking_clinic`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_goalkeeping_defense_shot_blocking_clinic
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
| `trigger_threshold_min_blocked_shots` | Configured trigger floor (at least `1` blocked shot and more blocks than shots on target) | Explicit trigger provenance for explainability and QA. |
| `match_blocks_minus_shots_on_target` | Combined blocked shots minus combined shots on target | Core signal intensity variable. |
| `match_combined_blocked_shots` | Combined blocked shots | Block volume. |
| `match_combined_shots_on_target` | Combined shots on target | On-target volume. |
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
