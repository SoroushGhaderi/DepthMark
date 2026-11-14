---
signal_id: sig_match_streak_consistency_home_dominance
status: active
entity: match
family: streak
subfamily: consistency
grain: match_team
headline: "Home Dominance Head To Head"
trigger: "The home team has won each of its last >= 7 meetings against this opponent (this match included)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_streak_consistency_home_dominance
  sql: clickhouse/gold/dml/signals/match/sig_match_streak_consistency_home_dominance.sql
---
# sig_match_streak_consistency_home_dominance

## Purpose

Flags fixtures where the home team has a long winning record against the visitor, a strong one-sided-fixture marker.

## Tactical And Statistical Logic

- Trigger: The home team has won each of its last >= 7 meetings against this opponent (this match included).
- From the home team's view a meeting is won when `goals_for > goals_against`. A draw or a defeat resets the run. Only the home-side row is emitted. Meetings are every finished match between the same two teams in `fotmob_silver.match`, in any competition and at either venue, ordered by `match_date` then `match_id`. A pair needs the full number of loaded meetings, so the signal can stay empty on a short history.
- Similarity note: Closest: `sig_match_streak_consistency_bogey_team` (the opposite run for the visitor, 8 winless meetings) and `sig_team_streak_consistency_winning_machine` (any opponent). Different logic: wins against one opponent. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_streak_consistency_home_dominance.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_streak_consistency_home_dominance`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_streak_consistency_home_dominance
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
| `trigger_threshold_min_consecutive_head_to_head_wins` | Configured minimum streak length (`7` meetings) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_head_to_head_win_streak_meetings` | Length of the current streak, including this match (meetings) | Core signal intensity variable: how long the home team's win run is. |
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
