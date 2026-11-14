---
signal_id: sig_match_shooting_goals_penalty_drama
status: active
entity: match
family: shooting
subfamily: goals
grain: match_team
headline: "Penalty Drama"
trigger: "A finished match features >= 2 penalties, scored or missed."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_shooting_goals_penalty_drama
  sql: clickhouse/gold/dml/signals/match/sig_match_shooting_goals_penalty_drama.sql
---
# sig_match_shooting_goals_penalty_drama

## Purpose

Flags matches with two or more spot-kicks, a referee-pressure and penalty-market marker.

## Tactical And Statistical Logic

- Trigger: A finished match features >= 2 penalties, scored or missed.
- A penalty is any shot row in `fotmob_silver.shot` whose `situation` contains `penalty`, whether it is scored, saved or missed. Own goals are excluded. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_match_shooting_goals_penalty_decided_match` (a 1-0, 0-1 or 1-1 match where all goals are penalties) and `sig_team_discipline_cards_penalty_prone`. Different logic: two or more penalties in any match. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_shooting_goals_penalty_drama.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_shooting_goals_penalty_drama`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_shooting_goals_penalty_drama
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
| `trigger_threshold_min_penalties` | Configured trigger floor (`2` penalties in the match) | Explicit trigger provenance for explainability and QA. |
| `match_penalties` | Penalties taken in the match, scored or not | Core signal intensity variable. |
| `match_penalties_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `match_penalty_goals` | Penalties that were scored | Outcome split of the penalties. |
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
