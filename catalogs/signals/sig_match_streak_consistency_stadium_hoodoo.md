---
signal_id: sig_match_streak_consistency_stadium_hoodoo
status: active
entity: match
family: streak
subfamily: consistency
grain: match_team
headline: "Stadium Hoodoo"
trigger: "The visiting team has failed to score in each of its last >= 5 visits to this opponent's ground (this match included)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_streak_consistency_stadium_hoodoo
  sql: clickhouse/gold/dml/signals/match/sig_match_streak_consistency_stadium_hoodoo.sql
---
# sig_match_streak_consistency_stadium_hoodoo

## Purpose

Flags fixtures where a team cannot score away at one opponent visit after visit, a venue-hoodoo and under-goals marker.

## Tactical And Statistical Logic

- Trigger: The visiting team has failed to score in each of its last >= 5 visits to this opponent's ground (this match included).
- The sequence is only the triggered team's away matches against this opponent, so the home meetings in between do not break the run. A blank visit has `goals_for = 0`. Only the away-side row is emitted. Meetings are every finished match between the same two teams in `fotmob_silver.match`, in any competition and at either venue, ordered by `match_date` then `match_id`. A pair needs the full number of loaded meetings, so the signal can stay empty on a short history.
- Similarity note: Closest: `sig_team_streak_consistency_away_goal_drought` (away blanks against any opponent) and `sig_match_streak_consistency_bogey_team` (winless against one opponent, either venue). Related head-to-head signals: `sig_match_streak_consistency_bogey_team`, `sig_match_streak_consistency_stalemate_cycle` and `sig_match_streak_consistency_goal_fest_history`. Different logic: blank away visits to one ground. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_streak_consistency_stadium_hoodoo.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_streak_consistency_stadium_hoodoo`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_streak_consistency_stadium_hoodoo
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
| `trigger_threshold_min_consecutive_blank_visits` | Configured minimum streak length (`5` away visits) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_blank_visits_streak` | Length of the current streak, including this match (away visits) | Core signal intensity variable: how long the scoring drought at this ground is. |
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
