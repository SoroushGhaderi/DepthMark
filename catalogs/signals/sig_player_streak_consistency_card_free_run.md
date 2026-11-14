---
signal_id: sig_player_streak_consistency_card_free_run
status: active
entity: player
family: streak
subfamily: consistency
grain: match_player
headline: "Card Free Run"
trigger: "Player has >= 15 consecutive appearances without receiving a card (this match included)."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_streak_consistency_card_free_run
  sql: clickhouse/gold/dml/signals/player/sig_player_streak_consistency_card_free_run.sql
---
# sig_player_streak_consistency_card_free_run

## Purpose

Flags long card-free runs, a marker of discipline and a counter-signal to `card_magnet`.

## Tactical And Statistical Logic

- Trigger: Player has >= 15 consecutive appearances without receiving a card (this match included).
- An appearance counts when `minutes_played > 0` and the player has no row in `fotmob_silver.card` for that match. Unlike the match-sequence signals, the run counts the player's own appearances, so a rest match does not break it. The run is tracked per player and team, so a transfer restarts it. One row is emitted for each appearance where the run is >= 15.
- Similarity note: Closest: `sig_player_discipline_cards_iron_man_discipline` (single-match 0 fouls). Opposite of `sig_player_streak_consistency_card_magnet`. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_streak_consistency_card_free_run.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_streak_consistency_card_free_run`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_streak_consistency_card_free_run
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
| `trigger_threshold_min_card_free_appearances` | Configured minimum streak length (`15` matches) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_card_free_streak_appearances` | Length of the current streak, including this match (matches) | Core signal intensity variable: how long the card-free run is. |
| `streak_matches_above_threshold` | Streak length minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match of the streak | Anchors the streak in time for recency and freshness filters. |
| `triggered_player_streak_minutes_played` | Minutes played across the streak | Volume behind the run: separates sustained output from one big match. |
| `triggered_player_minutes_played` | Minutes played in this match | Current-match contribution to the run. |
| `triggered_player_streak_fouls_committed` | Fouls committed across the streak | Volume behind the run: separates sustained output from one big match. |
| `triggered_player_fouls_committed` | Fouls committed in this match | Current-match contribution to the run. |
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
