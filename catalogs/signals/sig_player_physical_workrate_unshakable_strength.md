---
signal_id: sig_player_physical_workrate_unshakable_strength
status: active
entity: player
family: physical
subfamily: workrate
grain: match_player
headline: "Unshakable Strength"
trigger: "Player wins >= 80% of his ground duels with at least 10 contested in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_physical_workrate_unshakable_strength
  sql: clickhouse/gold/dml/signals/player/sig_player_physical_workrate_unshakable_strength.sql
---
# sig_player_physical_workrate_unshakable_strength

## Purpose

Flags dominant ground-duel success at volume, a physical-strength marker.

## Tactical And Statistical Logic

- Trigger: Player wins >= 80% of his ground duels with at least 10 contested in a finished match.
- Success is `ground_duels_won / ground_duel_attempts` with at least 10 attempts. Duel counts come from `fotmob_silver.player_match_stat`; only players with `minutes_played > 0` are considered. This is the first signal family built only from duel, aerial and recovery counts, because the loaded data has no distance or sprint tracking.
- Similarity note: Closest: `sig_player_discipline_cards_physical_dominance` (>= 10 ground duels won with fewer than 2 fouls). Different logic: an 80% success rate on 10 or more attempts, regardless of fouls. Related physical signals in this family are built from the same duel statistics; the closest existing signals are `sig_player_discipline_cards_physical_dominance`, `sig_player_goalkeeping_defense_interception_king` and `sig_team_discipline_cards_physical_superiority`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_physical_workrate_unshakable_strength.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_physical_workrate_unshakable_strength`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_physical_workrate_unshakable_strength
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
| `trigger_threshold_min_ground_duel_win_pct` | Configured trigger floor (at least `80` % of 10+ ground duels won) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_ground_duel_win_pct` | Ground duels won (%) | Core signal intensity variable. |
| `triggered_player_ground_duel_win_pct_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_player_ground_duel_attempts` | Ground duels contested | Volume behind the rate. |
| `triggered_player_minutes_played` | Minutes played in this match | Playing-time context for the trigger. |
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
