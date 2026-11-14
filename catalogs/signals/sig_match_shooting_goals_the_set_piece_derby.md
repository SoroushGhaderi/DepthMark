---
signal_id: sig_match_shooting_goals_the_set_piece_derby
status: active
entity: match
family: shooting
subfamily: goals
grain: match_team
headline: "The Set Piece Derby"
trigger: "A finished match has >= 3 goals and every one of them comes from a set piece."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_shooting_goals_the_set_piece_derby
  sql: clickhouse/gold/dml/signals/match/sig_match_shooting_goals_the_set_piece_derby.sql
---
# sig_match_shooting_goals_the_set_piece_derby

## Purpose

Flags a match where open play produced nothing but set pieces did, a dead-ball-dominance marker.

## Tactical And Statistical Logic

- Trigger: A finished match has >= 3 goals and every one of them comes from a set piece.
- Set-piece goals are goal rows in `fotmob_silver.shot` whose `situation` is `FromCorner`, `FreeKick`, `SetPiece` or `ThrowInSetPiece`. Their count must equal all goal rows, which must equal the final score (so incomplete goal data cannot count). The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_match_shooting_goals_set_piece_duel` (both teams score from a set piece) and `sig_match_shooting_goals_penalty_decided_match` (all goals are penalties). Related match signals: `sig_match_shooting_goals_goal_fest`, `sig_match_shooting_goals_set_piece_duel` and `sig_match_goalkeeping_defense_zero_threat_match`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_shooting_goals_the_set_piece_derby.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_shooting_goals_the_set_piece_derby`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_shooting_goals_the_set_piece_derby
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
| `trigger_threshold_min_goals` | Configured trigger floor (`3` goals, all from set pieces) | Explicit trigger provenance for explainability and QA. |
| `match_set_piece_goals` | Goals from set pieces | Core signal intensity variable. |
| `match_set_piece_goals_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
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
