---
signal_id: sig_player_streak_consistency_fortress_keeper
status: active
entity: player
family: streak
subfamily: consistency
grain: match_player
headline: "Fortress Keeper"
trigger: "Goalkeeper makes >= 5 saves in a win in >= 3 consecutive team matches (this match included)."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_streak_consistency_fortress_keeper
  sql: clickhouse/gold/dml/signals/player/sig_player_streak_consistency_fortress_keeper.sql
---
# sig_player_streak_consistency_fortress_keeper

## Purpose

Flags a run of match-winning goalkeeper performances under pressure, a keeper-form marker.

## Tactical And Statistical Logic

- Trigger: Goalkeeper makes >= 5 saves in a win in >= 3 consecutive team matches (this match included).
- A qualifying match has the goalkeeper (`is_goalkeeper = 1`) with >= 5 saves and a team win. Saves are on-target, non-goal, non-off-the-line shots faced by the keeper in `fotmob_silver.shot` (`keeper_id`). The sequence is the team's finished matches in `fotmob_silver.match`, ordered by `match_date` then `match_id`. Missing a match (no squad row or 0 minutes) breaks the run. The run is tracked per player and team, so a transfer restarts it. One row is emitted for each match where the run is >= 3.
- Similarity note: Closest: `sig_player_goalkeeping_defense_save_paralyzer` (a high-xG save late in one match) and `sig_player_streak_consistency_clean_sheet_century` (minutes without conceding). Different logic: busy keeper in a win across matches. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_streak_consistency_fortress_keeper.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_streak_consistency_fortress_keeper`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_streak_consistency_fortress_keeper
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
| `trigger_threshold_min_consecutive_busy_keeper_wins` | Configured minimum streak length (`3` matches) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_busy_keeper_win_streak_matches` | Length of the current streak, including this match (matches) | Core signal intensity variable: how long the busy-keeper winning run is. |
| `streak_matches_above_threshold` | Streak length minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match of the streak | Anchors the streak in time for recency and freshness filters. |
| `triggered_player_streak_busy_keeper_win_matches` | Matches with >= 5 saves in a win across the streak | Volume behind the run: separates sustained output from one big match. |
| `triggered_player_busy_keeper_win_matches` | Matches with >= 5 saves in a win in this match | Current-match contribution to the run. |
| `triggered_player_streak_saves` | Saves across the streak | Volume behind the run: separates sustained output from one big match. |
| `triggered_player_saves` | Saves in this match | Current-match contribution to the run. |
| `triggered_player_minutes_played_match` | Minutes played in this match | Playing-time context for the current match. |
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
