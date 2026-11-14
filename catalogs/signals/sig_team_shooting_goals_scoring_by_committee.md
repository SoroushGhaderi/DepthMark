---
signal_id: sig_team_shooting_goals_scoring_by_committee
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Scoring By Committee"
trigger: "At least 5 different players of the team record a shot on target in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_shooting_goals_scoring_by_committee
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_scoring_by_committee.sql
---
# sig_team_shooting_goals_scoring_by_committee

## Purpose

Flags a spread-out attack on target, a shared-threat marker.

## Tactical And Statistical Logic

- Trigger: At least 5 different players of the team record a shot on target in a finished match.
- A shot on target is a shot row with `is_on_target = 1` or a goal in `fotmob_silver.shot` (own goals excluded); the count is distinct `player_id` values per team.
- Similarity note: Closest: `sig_team_creativity_playmaking_unpredictable_attack` (shots from 8 different players) and `sig_team_shooting_goals_shared_scoring` (4 different scorers). Different logic: five different players on target. Related team signals: `sig_team_shooting_goals_rout_win`, `sig_team_shooting_goals_late_surge_goals` and `sig_team_discipline_cards_early_warning`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_scoring_by_committee.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_shooting_goals_scoring_by_committee`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_scoring_by_committee
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
| `trigger_threshold_min_shooters_on_target` | Configured trigger floor (`5` different players with a shot on target) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_shooters_on_target` | Different players with a shot on target | Core signal intensity variable. |
| `triggered_team_shooters_on_target_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
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
