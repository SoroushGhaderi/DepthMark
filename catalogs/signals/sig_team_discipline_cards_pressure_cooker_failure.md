---
signal_id: sig_team_discipline_cards_pressure_cooker_failure
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Pressure Cooker Failure"
trigger: "Team concedes a penalty in the first 5 minutes of a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_discipline_cards_pressure_cooker_failure
  sql: clickhouse/gold/dml/signals/team/sig_team_discipline_cards_pressure_cooker_failure.sql
---
# sig_team_discipline_cards_pressure_cooker_failure

## Purpose

Flags an early penalty conceded, a nerves and early-error marker.

## Tactical And Statistical Logic

- Trigger: Team concedes a penalty in the first 5 minutes of a finished match.
- A penalty conceded is a shot row in `fotmob_silver.shot` whose `situation` contains `penalty` for the opponent (`team_id` = the opponent) with `minute <= 5`.
- Similarity note: Closest: `sig_team_discipline_cards_penalty_prone` (>= 2 penalties conceded in one match) and `sig_player_discipline_cards_penalty_conceder`. Different logic: a penalty conceded within the first 5 minutes. Related team signals: `sig_team_shooting_goals_rout_win`, `sig_team_shooting_goals_late_surge_goals` and `sig_team_discipline_cards_early_warning`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_discipline_cards_pressure_cooker_failure.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_discipline_cards_pressure_cooker_failure`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_discipline_cards_pressure_cooker_failure
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
| `trigger_threshold_max_penalty_minute` | Configured trigger floor (penalty conceded at minute `5` or earlier) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_early_penalties_conceded` | Penalties conceded in the first 5 minutes | Core signal intensity variable. |
| `triggered_team_early_penalties_conceded_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
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
