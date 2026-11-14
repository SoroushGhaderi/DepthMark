---
signal_id: sig_team_streak_consistency_winning_machine
status: active
entity: team
family: streak
subfamily: consistency
grain: match_team
headline: "Winning Machine"
trigger: "Team has won >= 5 consecutive matches (this match included)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_streak_consistency_winning_machine
  sql: clickhouse/gold/dml/signals/team/sig_team_streak_consistency_winning_machine.sql
---
# sig_team_streak_consistency_winning_machine

## Purpose

Flags every match in which a team extends or reaches a winning run of at least five matches, so analysts can track momentum, form and market-narrative moments.

## Tactical And Statistical Logic

- Trigger: Team has won >= 5 consecutive matches (this match included).
- The streak is built from every finished match of the team in `fotmob_silver.match`, ordered by `match_date` then `match_id`, across all loaded competitions. A win is `goals_for > goals_against`. Any draw or defeat ends the streak. One row is emitted for each match where the running streak length is >= 5, so a seven-match run emits rows at matches 5, 6 and 7. Only matches loaded in the warehouse count: a short loaded history can shorten a real streak.
- Similarity note: No existing signal (active or deprecated) models multi-match streaks. Closest in intent: `sig_team_discipline_cards_man_down_resilience` (single-match result context). No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_streak_consistency_winning_machine.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_streak_consistency_winning_machine`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_streak_consistency_winning_machine
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
| `trigger_threshold_min_consecutive_wins` | Configured minimum streak length (`5` matches) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_win_streak_matches` | Length of the current streak, including this match (matches) | Core signal intensity variable: how long the winning run is. |
| `streak_matches_above_threshold` | Streak length minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match of the streak | Anchors the streak in time for recency and freshness filters. |
| `triggered_team_streak_goals_scored` | Goals scored across the streak | Attacking output behind the run. |
| `triggered_team_streak_goals_conceded` | Goals conceded across the streak | Defensive solidity behind the run. |
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
