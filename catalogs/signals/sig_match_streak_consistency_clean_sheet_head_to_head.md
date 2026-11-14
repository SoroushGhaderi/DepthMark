---
signal_id: sig_match_streak_consistency_clean_sheet_head_to_head
status: active
entity: match
family: streak
subfamily: consistency
grain: match_team
headline: "Clean Sheet Head To Head"
trigger: "The triggered team has kept a clean sheet against this opponent in each of its last >= 4 meetings (this match included)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_streak_consistency_clean_sheet_head_to_head
  sql: clickhouse/gold/dml/signals/match/sig_match_streak_consistency_clean_sheet_head_to_head.sql
---
# sig_match_streak_consistency_clean_sheet_head_to_head

## Purpose

Flags fixtures where one team shuts the other out meeting after meeting, a defensive-dominance marker.

## Tactical And Statistical Logic

- Trigger: The triggered team has kept a clean sheet against this opponent in each of its last >= 4 meetings (this match included).
- A clean-sheet meeting has `goals_against = 0` from the triggered team's view. Conceding resets the run. One row per side is emitted for each match where that side's run is >= 4. Meetings are every finished match between the same two teams in `fotmob_silver.match`, in any competition and at either venue, ordered by `match_date` then `match_id`. A pair needs the full number of loaded meetings, so the signal can stay empty on a short history.
- Similarity note: Closest: `sig_team_streak_consistency_clean_sheet_wall` (any opponent) and `sig_match_streak_consistency_nil_nil_curse` (0-0 only). Different logic: shutouts against one opponent. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_streak_consistency_clean_sheet_head_to_head.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_streak_consistency_clean_sheet_head_to_head`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_streak_consistency_clean_sheet_head_to_head
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
| `trigger_threshold_min_consecutive_head_to_head_clean_sheets` | Configured minimum streak length (`4` meetings) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_head_to_head_clean_sheet_streak_meetings` | Length of the current streak, including this match (meetings) | Core signal intensity variable: how long the shutout run against this opponent is. |
| `streak_matches_above_threshold` | Streak length minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match of the streak | Anchors the streak in time for recency and freshness filters. |
| `triggered_team_streak_wins` | Wins inside the head-to-head run | Shows whether the run is made of wins or draws. |
| `triggered_team_streak_draws` | Draws inside the head-to-head run | Shows how much of the run is stalemates. |
| `triggered_team_streak_goals_scored` | Goals scored against this opponent in the run | Attacking output in the fixture. |
| `triggered_team_streak_goals_conceded` | Goals conceded to this opponent in the run | Defensive record in the fixture. |
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
