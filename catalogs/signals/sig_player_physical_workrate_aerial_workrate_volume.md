---
signal_id: sig_player_physical_workrate_aerial_workrate_volume
status: active
entity: player
family: physical
subfamily: workrate
grain: match_player
headline: "Aerial Workrate Volume"
trigger: "Player contests >= 15 aerial duels in a single finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_physical_workrate_aerial_workrate_volume
  sql: clickhouse/gold/dml/signals/player/sig_player_physical_workrate_aerial_workrate_volume.sql
---
# sig_player_physical_workrate_aerial_workrate_volume

## Purpose

Flags an extreme aerial workload, a target-man marker.

## Tactical And Statistical Logic

- Trigger: Player contests >= 15 aerial duels in a single finished match.
- Aerial duels contested are `aerial_duel_attempts`. Duel counts come from `fotmob_silver.player_match_stat`; only players with `minutes_played > 0` are considered. This is the first signal family built only from duel, aerial and recovery counts, because the loaded data has no distance or sprint tracking.
- Similarity note: Closest: `sig_player_physical_workrate_aerial_dominator` (wins, not volume). Different logic: contested aerial duels, won or lost. Related physical signals in this family are built from the same duel statistics; the closest existing signals are `sig_player_discipline_cards_physical_dominance`, `sig_player_goalkeeping_defense_interception_king` and `sig_team_discipline_cards_physical_superiority`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_physical_workrate_aerial_workrate_volume.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_physical_workrate_aerial_workrate_volume`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_physical_workrate_aerial_workrate_volume
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
| `trigger_threshold_min_aerial_duels_contested` | Configured trigger floor (`15` aerial duels contested) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_aerial_duels_contested` | Aerial duels contested | Core signal intensity variable. |
| `triggered_player_aerial_duels_contested_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_player_aerial_duels_won` | Aerial duels won | Success behind the volume. |
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
