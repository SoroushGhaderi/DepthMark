---
signal_id: sig_match_goalkeeping_defense_defensive_resilience_draw
status: active
entity: match
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Defensive Resilience Draw"
trigger: "A finished match ends 0-0 although one team has at least 2.0 more xG than the other."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_goalkeeping_defense_defensive_resilience_draw
  sql: clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_defensive_resilience_draw.sql
---
# sig_match_goalkeeping_defense_defensive_resilience_draw

## Purpose

Flags a 0-0 with a clear chance gap, a resilient-defence and keeper-heroics marker.

## Tactical And Statistical Logic

- Trigger: A finished match ends 0-0 although one team has at least 2.0 more xG than the other.
- The final score is 0-0 and the absolute xG difference in `fotmob_silver.period_stat` is at least 2.0. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_match_shooting_goals_goalless_siege` (a 0-0 with 25 shots) and `sig_team_shooting_goals_blank_range`. Related match signals: `sig_match_shooting_goals_goal_fest`, `sig_match_shooting_goals_set_piece_duel` and `sig_match_goalkeeping_defense_zero_threat_match`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_defensive_resilience_draw.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_goalkeeping_defense_defensive_resilience_draw`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_goalkeeping_defense_defensive_resilience_draw
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
| `trigger_threshold_min_xg_gap` | Configured trigger floor (a 0-0 with an xG gap of at least `2.0`) | Explicit trigger provenance for explainability and QA. |
| `match_xg_gap` | Absolute xG gap between the teams | Core signal intensity variable. |
| `match_xg_gap_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
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
