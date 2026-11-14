---
signal_id: sig_player_streak_consistency_creative_hub
status: active
entity: player
family: streak
subfamily: consistency
grain: match_player
headline: "Creative Hub Streak"
trigger: "Player records >= 1 assist in >= 3 consecutive team matches (this match included)."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_streak_consistency_creative_hub
  sql: clickhouse/gold/dml/signals/player/sig_player_streak_consistency_creative_hub.sql
---
# sig_player_streak_consistency_creative_hub

## Purpose

Flags matches where a player extends or reaches a run of at least three consecutive matches with an assist.

## Tactical And Statistical Logic

- Trigger: Player records >= 1 assist in >= 3 consecutive team matches (this match included).
- The sequence is the team's finished matches in date order. An assisting match has `assists >= 1` in `fotmob_silver.player_match_stat`. Any match without an assist, or without an appearance, breaks the run. The run is tracked per player and team. One row is emitted for each match where the run is >= 3. Expected assists (xA) are carried to show whether the run is chance-creation driven.
- Similarity note: Closest: `sig_player_creativity_playmaking_assist_brace`, `sig_player_creativity_playmaking_assist_hat_trick` (single-match assist counts). Different grain: multi-match run. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_streak_consistency_creative_hub.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_streak_consistency_creative_hub`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_streak_consistency_creative_hub
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
| `trigger_threshold_min_consecutive_assisting_matches` | Configured minimum streak length (`3` matches) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_assisting_streak_matches` | Length of the current streak, including this match (matches) | Core signal intensity variable: how long the assisting run is. |
| `streak_matches_above_threshold` | Streak length minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match of the streak | Anchors the streak in time for recency and freshness filters. |
| `triggered_player_streak_assists` | Assists across the streak | Output size of the run. |
| `triggered_player_streak_expected_assists` | Expected assists (xA) across the streak | Tells whether the run is backed by chance creation. |
| `triggered_player_streak_chances_created` | Chances created (key passes) across the streak | Creation volume behind the run. |
| `triggered_player_assists` | Assists in this match | Current-match contribution. |
| `triggered_player_expected_assists` | Expected assists (xA) in this match | Current-match creation quality. |
| `triggered_player_chances_created` | Chances created in this match | Current-match creation volume. |
| `triggered_player_minutes_played` | Minutes played in this match | Playing-time context. |
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
