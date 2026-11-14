---
signal_id: sig_player_streak_consistency_clean_sheet_century
status: active
entity: player
family: streak
subfamily: consistency
grain: match_player
headline: "Clean Sheet Century"
trigger: "Goalkeeper has played >= 450 minutes across consecutive appearances without his team conceding (this match included)."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_streak_consistency_clean_sheet_century
  sql: clickhouse/gold/dml/signals/player/sig_player_streak_consistency_clean_sheet_century.sql
---
# sig_player_streak_consistency_clean_sheet_century

## Purpose

Flags matches where a goalkeeper's run of clean-sheet appearances reaches at least 450 minutes, the equivalent of five full matches without conceding.

## Tactical And Statistical Logic

- Trigger: Goalkeeper has played >= 450 minutes across consecutive appearances without his team conceding (this match included).
- The sequence is the goalkeeper's own appearances (`is_goalkeeper = 1`, `minutes_played > 0`) in date order, so a rest match does not break it. An appearance is clean when the team's `goals_against = 0` in that match. A conceded goal breaks the run. Minutes are summed across the run. The check uses the match result, so a goal conceded after the goalkeeper was substituted also counts as conceded. This is a conservative reading. One row is emitted for each match where the run total is >= 450 minutes.
- Similarity note: Closest: `sig_player_goalkeeping_defense_clean_sheet_locked` and `sig_player_goalkeeping_defense_clean_sheet_contributor` (single-match clean sheets). Different grain. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_streak_consistency_clean_sheet_century.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_streak_consistency_clean_sheet_century`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_streak_consistency_clean_sheet_century
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
| `triggered_side` | Side of the player's team (`home` or `away`) | Canonical side identity. |
| `triggered_player_id` | Triggered player identifier | Player attribution key (row identity). |
| `triggered_player_name` | Triggered player name | Readable player context. |
| `triggered_team_id` | Player's team identifier | Team context key (row identity). |
| `triggered_team_name` | Player's team name | Readable team context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral context. |
| `trigger_threshold_min_clean_sheet_minutes` | Configured minimum minutes in the run (`450`) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_clean_sheet_streak_minutes` | Minutes played across the clean-sheet run, including this match | Core signal intensity variable. |
| `streak_minutes_above_threshold` | Run minutes minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_player_clean_sheet_streak_appearances` | Clean-sheet appearances in the run | Shows how many matches the minutes cover. |
| `streak_start_date` | Date of the first match of the run | Anchors the run in time. |
| `triggered_player_minutes_played` | Minutes played in this match | Current-match workload. |
| `triggered_player_saves` | Saves in this match (shots on target faced minus goals) | Shot-stopping workload behind the clean sheet. |
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
