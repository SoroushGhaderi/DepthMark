---
signal_id: sig_match_streak_consistency_xg_goal_gap_rivalry
status: active
entity: match
family: streak
subfamily: consistency
grain: match_team
headline: "xG Goal Gap Rivalry"
trigger: "The last 3 meetings of the same two teams had a combined xG above 4.0 but at most 1 goal in total (this match included)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_streak_consistency_xg_goal_gap_rivalry
  sql: clickhouse/gold/dml/signals/match/sig_match_streak_consistency_xg_goal_gap_rivalry.sql
---
# sig_match_streak_consistency_xg_goal_gap_rivalry

## Purpose

Flags rivalries that badly under-deliver on chance quality over three meetings, a regression and over-goals-value marker.

## Tactical And Statistical Logic

- Trigger: The last 3 meetings of the same two teams had a combined xG above 4.0 but at most 1 goal in total (this match included).
- The window is the pair's last 3 consecutive meetings, each with stats. Combined xG is `expected_goals_home + expected_goals_away` summed over the window (in hundredths, so 400 means 4.00) from `fotmob_silver.period_stat`, and goals are the final scores. A row is emitted for each match where the 3-meeting window is complete, every meeting has stats, combined xG is above 4.00 and total goals are 0 or 1. The workbook says 'only 1 goal', and 0 goals is included because it is the same story. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted. Meetings are every finished match between the same two teams in `fotmob_silver.match`, in any competition and at either venue, ordered by `match_date` then `match_id`. A pair needs the full number of loaded meetings, so the signal can stay empty on a short history.
- Similarity note: Closest: `sig_team_shooting_goals_blank_range` (no goals despite total xG > 2.5 in one match) and `sig_team_streak_consistency_high_xg_no_win`. Related head-to-head signals: `sig_match_streak_consistency_penalty_fest_rivalry`, `sig_match_streak_consistency_foul_fest_rivalry` and `sig_match_streak_consistency_goal_fest_history`. Different grain: xG against goals over three meetings of one pair. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_streak_consistency_xg_goal_gap_rivalry.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_streak_consistency_xg_goal_gap_rivalry`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_streak_consistency_xg_goal_gap_rivalry
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
| `trigger_threshold_min_window_xg_hundredths` | Configured trigger floor (combined xG in hundredths over 3 meetings, so `400` is 4.00) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_window_combined_xg` | Combined xG of both teams over the last 3 meetings, including this match | Core signal intensity variable: how many chances the pair created. |
| `streak_matches_above_threshold` | Combined xG above the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first meeting inside the window | Anchors the window in time for recency and freshness filters. |
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
