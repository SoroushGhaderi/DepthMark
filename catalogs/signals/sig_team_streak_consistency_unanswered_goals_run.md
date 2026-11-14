---
signal_id: sig_team_streak_consistency_unanswered_goals_run
status: active
entity: team
family: streak
subfamily: consistency
grain: match_team
headline: "Unanswered Goals Run"
trigger: "Team has scored >= 10 goals across consecutive matches without conceding (this match included)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_streak_consistency_unanswered_goals_run
  sql: clickhouse/gold/dml/signals/team/sig_team_streak_consistency_unanswered_goals_run.sql
---
# sig_team_streak_consistency_unanswered_goals_run

## Purpose

Flags runs of consecutive clean sheets whose goals scored add up to at least ten, a dominance marker.

## Tactical And Statistical Logic

- Trigger: Team has scored >= 10 goals across consecutive matches without conceding (this match included).
- A run is a sequence of consecutive finished matches with `goals_against = 0`; a goal conceded ends it. The running sum of the team's goals inside the run must reach 10. A row is emitted for each match where the run has reached 10 goals. The sequence is every finished match of the team in `fotmob_silver.match` (all loaded competitions), ordered by `match_date` then `match_id`. Only loaded matches count, so a short history can shorten a real run.
- Similarity note: Closest: `sig_team_streak_consistency_clean_sheet_wall` (>= 4 clean sheets, no goals floor) and `sig_team_streak_consistency_goal_machine`. Different logic: cumulative goals scored during a clean-sheet run. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_streak_consistency_unanswered_goals_run.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_streak_consistency_unanswered_goals_run`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_streak_consistency_unanswered_goals_run
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
| `trigger_threshold_min_unanswered_goals` | Configured minimum unanswered goals (`10`) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_unanswered_goals` | Goals scored since the team last conceded, including this match | Core signal intensity variable. |
| `streak_matches_above_threshold` | Unanswered goals minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match of the clean-sheet run | Anchors the run in time for recency and freshness filters. |
| `triggered_team_clean_sheet_run_matches` | Matches in the clean-sheet run, including this match | Shows how many matches it took to reach the goal total. |
| `triggered_team_streak_wins` | Wins inside the streak | Shows whether the streak is made of wins or draws. |
| `triggered_team_streak_draws` | Draws inside the streak | Shows how much of the streak is stalemates. |
| `triggered_team_streak_goals_scored` | Goals scored across the streak | Attacking output behind the streak. |
| `triggered_team_streak_goals_conceded` | Goals conceded across the streak | Defensive record behind the streak. |
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
