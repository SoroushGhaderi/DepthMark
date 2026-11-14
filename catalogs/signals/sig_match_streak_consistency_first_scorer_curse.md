---
signal_id: sig_match_streak_consistency_first_scorer_curse
status: active
entity: match
family: streak
subfamily: consistency
grain: match_team
headline: "First Scorer Curse"
trigger: "In each of the last >= 5 meetings of the same two teams, the team that scored first did not win (this match included)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_streak_consistency_first_scorer_curse
  sql: clickhouse/gold/dml/signals/match/sig_match_streak_consistency_first_scorer_curse.sql
---
# sig_match_streak_consistency_first_scorer_curse

## Purpose

Flags rivalries where the opening goal keeps failing to win the match, a comeback-prone and in-play-market marker.

## Tactical And Statistical Logic

- Trigger: In each of the last >= 5 meetings of the same two teams, the team that scored first did not win (this match included).
- The first scorer is read from the goal row whose score after the goal totals 1 (`home_score_after`, `away_score_after` in `fotmob_silver.shot`). A cursed meeting has a first scorer who then drew or lost. A goalless meeting has no first scorer and resets the run, and so does a win by the first scorer. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match. Meetings are every finished match between the same two teams in `fotmob_silver.match`, in any competition and at either venue, ordered by `match_date` then `match_id`. A pair needs the full number of loaded meetings, so the signal can stay empty on a short history.
- Similarity note: Closest: `sig_team_streak_consistency_first_goal_winner` (the opposite, one team's own first-goal wins) and `sig_match_streak_consistency_comeback_head_to_head`. Related head-to-head signals: `sig_match_streak_consistency_bogey_team`, `sig_match_streak_consistency_stalemate_cycle` and `sig_match_streak_consistency_goal_fest_history`. Different logic: the first scorer fails to win across a pair's meetings. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_streak_consistency_first_scorer_curse.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_streak_consistency_first_scorer_curse`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_streak_consistency_first_scorer_curse
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
| `trigger_threshold_min_consecutive_first_scorer_failed_meetings` | Configured minimum streak length (`5` meetings) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_first_scorer_failed_meetings_streak` | Length of the current streak, including this match (meetings) | Core signal intensity variable: how long the first-scorer curse is. |
| `streak_matches_above_threshold` | Streak length minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match of the streak | Anchors the streak in time for recency and freshness filters. |
| `streak_total_goals` | Total goals (both teams) across the meetings in the run | Shows the goal volume behind the head-to-head run. |
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
