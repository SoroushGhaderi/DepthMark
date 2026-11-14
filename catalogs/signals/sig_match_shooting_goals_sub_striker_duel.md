---
signal_id: sig_match_shooting_goals_sub_striker_duel
status: active
entity: match
family: shooting
subfamily: goals
grain: match_team
headline: "Sub Striker Duel"
trigger: "Substitutes of both teams score a goal in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_shooting_goals_sub_striker_duel
  sql: clickhouse/gold/dml/signals/match/sig_match_shooting_goals_sub_striker_duel.sql
---
# sig_match_shooting_goals_sub_striker_duel

## Purpose

Flags a two-sided bench impact, a substitution-battle marker.

## Tactical And Statistical Logic

- Trigger: Substitutes of both teams score a goal in a finished match.
- A substitute goal is a non-own goal in `fotmob_silver.shot` by a player listed as a `substitute` in `fotmob_silver.match_personnel`; each team needs at least one. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_match_shooting_goals_substituted_scoring_fest` (3 different substitutes score) and `sig_match_shooting_goals_clinical_sub_impact` (>= 3 substitute goals combined). Related match signals: `sig_match_shooting_goals_clinical_showdown`, `sig_match_shooting_goals_goal_fest` and `sig_match_shooting_goals_high_xg_low_score`. Different logic: a substitute goal for each team. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_shooting_goals_sub_striker_duel.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_shooting_goals_sub_striker_duel`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_shooting_goals_sub_striker_duel
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
| `trigger_threshold_min_substitute_goals_per_side` | Configured trigger floor (each side gets at least `1` substitute goal) | Explicit trigger provenance for explainability and QA. |
| `match_substitute_goals` | Substitute goals by both teams | Core signal intensity variable. |
| `match_substitute_goals_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `home_substitute_goals` | Substitute goals by the home side | Per-side split. |
| `away_substitute_goals` | Substitute goals by the away side | Per-side split. |
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
