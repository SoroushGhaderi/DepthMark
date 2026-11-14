---
signal_id: sig_team_streak_consistency_first_goal_winner
status: active
entity: team
family: streak
subfamily: consistency
grain: match_team
headline: "First Goal Winner"
trigger: "Team has won its last >= 10 matches in which it scored first (this match included)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_streak_consistency_first_goal_winner
  sql: clickhouse/gold/dml/signals/team/sig_team_streak_consistency_first_goal_winner.sql
---
# sig_team_streak_consistency_first_goal_winner

## Purpose

Flags matches where a team scores first, wins, and extends a run of at least ten such matches. It measures how reliably a team protects a lead.

## Tactical And Statistical Logic

- Trigger: Team has won its last >= 10 matches in which it scored first (this match included).
- The first goal of each match is the goal whose running score (`home_score_after + away_score_after`) equals 1 in `fotmob_silver.shot`; this also covers own goals. For each team, only matches where it scored first are ordered by date. A win is `goals_for > goals_against`. The streak counts consecutive such wins and resets on the first match where the team scored first but did not win. Matches where the team did not score first are ignored, not counted as breaks. One row is emitted for each match where the run is >= 10.
- Similarity note: No existing first-goal-and-win history signal. Closest: `sig_match_shooting_goals_clean_sheet_broken_late` (the first goal arriving late at 0-0, single match) and `sig_team_streak_consistency_winning_machine` (any wins). Different grain and metric. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_streak_consistency_first_goal_winner.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_streak_consistency_first_goal_winner`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_streak_consistency_first_goal_winner
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
| `trigger_threshold_min_first_goal_wins` | Configured minimum streak length (`10` matches where the team scored first) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_first_goal_win_streak_matches` | Length of the current streak, including this match (matches where the team scored first) | Core signal intensity variable: how many opening-goal matches in a row were won. |
| `streak_matches_above_threshold` | Streak length minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match of the streak | Anchors the streak in time for recency and freshness filters. |
| `triggered_team_streak_goals_scored` | Goals scored across the streak matches | Attacking output in the converted-lead matches. |
| `triggered_team_streak_goals_conceded` | Goals conceded across the streak matches | Shows how much lead protection was needed. |
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
