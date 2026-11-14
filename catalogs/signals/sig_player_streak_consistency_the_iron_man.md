---
signal_id: sig_player_streak_consistency_the_iron_man
status: active
entity: player
family: streak
subfamily: consistency
grain: match_player
headline: "The Iron Man"
trigger: "Player plays >= 90 minutes in >= 10 consecutive team matches (this match included)."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_streak_consistency_the_iron_man
  sql: clickhouse/gold/dml/signals/player/sig_player_streak_consistency_the_iron_man.sql
---
# sig_player_streak_consistency_the_iron_man

## Purpose

Flags matches where a player extends or reaches ten consecutive full-length appearances, a marker of fitness, trust and rotation risk.

## Tactical And Statistical Logic

- Trigger: Player plays >= 90 minutes in >= 10 consecutive team matches (this match included).
- The sequence is the team's finished matches in date order. A full match is `minutes_played >= 90` in `fotmob_silver.player_match_stat`. A missed match, substitution or short appearance breaks the run. The run is tracked per player and team. One row is emitted for each match where the run is >= 10. Because minutes can include stoppage or extra time, `>= 90` is used, not `= 90`.
- Similarity note: Closest: `sig_player_discipline_cards_iron_man_discipline` (single-match defender with 0 fouls and 5 tackles). Different logic and grain. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_streak_consistency_the_iron_man.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_streak_consistency_the_iron_man`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_streak_consistency_the_iron_man
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
| `trigger_threshold_min_consecutive_full_matches` | Configured minimum streak length (`10` matches) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_full_match_streak_matches` | Length of the current streak, including this match (matches) | Core signal intensity variable: how long the full-match run is. |
| `streak_matches_above_threshold` | Streak length minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match of the streak | Anchors the streak in time for recency and freshness filters. |
| `triggered_player_streak_minutes` | Minutes played across the streak | Total workload behind the run. |
| `triggered_player_minutes_played` | Minutes played in this match | Current-match workload. |
| `triggered_player_goals` | Goals in this match | Current-match output. |
| `triggered_player_assists` | Assists in this match | Current-match output. |
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
