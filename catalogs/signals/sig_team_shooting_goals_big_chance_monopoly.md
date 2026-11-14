---
signal_id: sig_team_shooting_goals_big_chance_monopoly
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Big Chance Monopoly"
trigger: "Team creates >= 5 big chances while the opponent creates none in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_shooting_goals_big_chance_monopoly
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_big_chance_monopoly.sql
---
# sig_team_shooting_goals_big_chance_monopoly

## Purpose

Flags total big-chance control, a dominance and missed-opportunity marker.

## Tactical And Statistical Logic

- Trigger: Team creates >= 5 big chances while the opponent creates none in a finished match.
- Big chances come from `fotmob_silver.period_stat` (`period = 'All'`): the team has `big_chances >= 5` and the opponent has 0.
- Similarity note: Closest: `sig_team_shooting_goals_big_chance_efficiency` (all big chances converted) and `sig_match_shooting_goals_unproductive_dominance` (>= 20 shots, 0 big chances). Different logic: five big chances to none. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_big_chance_monopoly.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_shooting_goals_big_chance_monopoly`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_big_chance_monopoly
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
| `trigger_threshold_min_big_chances` | Configured trigger floor (`5` big chances for, 0 against) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_big_chances` | Big chances created | Core signal intensity variable. |
| `triggered_team_big_chances_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `opponent_big_chances` | Big chances created by the opponent | Bilateral comparator for the monopoly. |
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
