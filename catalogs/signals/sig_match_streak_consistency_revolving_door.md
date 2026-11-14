---
signal_id: sig_match_streak_consistency_revolving_door
status: active
entity: match
family: streak
subfamily: consistency
grain: match_team
headline: "Revolving Door"
trigger: "Both teams scored in each of the last >= 8 meetings of the same two teams (this match included)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_streak_consistency_revolving_door
  sql: clickhouse/gold/dml/signals/match/sig_match_streak_consistency_revolving_door.sql
---
# sig_match_streak_consistency_revolving_door

## Purpose

Flags rivalries with a long both-teams-to-score record, a strong BTTS market marker.

## Tactical And Statistical Logic

- Trigger: Both teams scored in each of the last >= 8 meetings of the same two teams (this match included).
- A both-teams-scored meeting has `home_score >= 1` and `away_score >= 1`. A meeting where a team is shut out resets the run. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match. Meetings are every finished match between the same two teams in `fotmob_silver.match`, in any competition and at either venue, ordered by `match_date` then `match_id`. A pair needs the full number of loaded meetings, so the signal can stay empty on a short history.
- Similarity note: Closest: `sig_match_shooting_goals_goal_fest` and `sig_match_streak_consistency_goal_fest_history` (total goals, not both-teams-scored). Different measure. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_streak_consistency_revolving_door.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_streak_consistency_revolving_door`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_streak_consistency_revolving_door
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
| `trigger_threshold_min_consecutive_both_scored_meetings` | Configured minimum streak length (`8` meetings) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_both_scored_meetings_streak` | Length of the current streak, including this match (meetings) | Core signal intensity variable: how long the both-teams-scored history is. |
| `streak_matches_above_threshold` | Streak length minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match of the streak | Anchors the streak in time for recency and freshness filters. |
| `streak_total_goals` | Total goals (both teams) across the both-scored meetings | Shows the goal volume behind the head-to-head run. |
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
