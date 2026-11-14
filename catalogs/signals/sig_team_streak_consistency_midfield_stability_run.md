---
signal_id: sig_team_streak_consistency_midfield_stability_run
status: active
entity: team
family: streak
subfamily: consistency
grain: match_team
headline: "Midfield Stability Run"
trigger: "Team starts the same three midfielders in >= 8 consecutive matches (this match included)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_streak_consistency_midfield_stability_run
  sql: clickhouse/gold/dml/signals/team/sig_team_streak_consistency_midfield_stability_run.sql
---
# sig_team_streak_consistency_midfield_stability_run

## Purpose

Flags a long run with an unchanged midfield, a stability and chemistry marker.

## Tactical And Statistical Logic

- Trigger: Team starts the same three midfielders in >= 8 consecutive matches (this match included).
- A settled match has exactly 3 starters whose `usual_playing_position_id` is 2 (the repo's midfielder group) in both this and the previous match, and none of them is new. The run counts repeats of the trio: a run of 7 repeats means 8 matches with the same trio. Silver has no formation field, so a team that starts a different number of midfielders cannot qualify. The sequence is every finished match of the team in `fotmob_silver.match` (all loaded competitions), ordered by `match_date` then `match_id`. Only loaded matches count, so a short history can shorten a real streak.
- Similarity note: Closest: `sig_team_streak_consistency_consistency_king` (the whole starting XI, 4 repeats) and `sig_team_creativity_playmaking_midfield_engine_vision` (one match). Different logic: only the midfield trio, over a longer run. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_streak_consistency_midfield_stability_run.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_streak_consistency_midfield_stability_run`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_streak_consistency_midfield_stability_run
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
| `trigger_threshold_min_consecutive_settled_midfield_repeats` | Configured minimum streak length (`7` matches) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_settled_midfield_streak_repeats` | Length of the current streak, including this match (matches) | Core signal intensity variable: how long the unchanged-midfield run is. |
| `streak_matches_above_threshold` | Streak length minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match of the streak | Anchors the streak in time for recency and freshness filters. |
| `triggered_team_streak_wins` | Wins inside the streak | Shows whether the streak is made of wins or draws. |
| `triggered_team_streak_draws` | Draws inside the streak | Shows how much of the streak is stalemates. |
| `triggered_team_streak_goals_scored` | Goals scored across the streak | Attacking output behind the streak. |
| `triggered_team_streak_goals_conceded` | Goals conceded across the streak | Defensive record behind the streak. |
| `triggered_team_streak_midfielders_started` | Midfielders started, summed across the streak | Midfield size behind the run. |
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
