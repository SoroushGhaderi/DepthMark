---
signal_id: sig_player_creativity_playmaking_isolated_chance_creator
status: active
entity: player
family: creativity
subfamily: playmaking
grain: match_player
headline: "Isolated Chance Creator"
trigger: "Player creates >= 3 chances (key passes) while his team has less than 35% possession in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_creativity_playmaking_isolated_chance_creator
  sql: clickhouse/gold/dml/signals/player/sig_player_creativity_playmaking_isolated_chance_creator.sql
---
# sig_player_creativity_playmaking_isolated_chance_creator

## Purpose

Flags chance creation from a team that rarely has the ball, a counter-attack and one-man-playmaker marker.

## Tactical And Statistical Logic

- Trigger: Player creates >= 3 chances (key passes) while his team has less than 35% possession in a finished match.
- Key passes are `chances_created` in `fotmob_silver.player_match_stat`; possession is the team's `ball_possession` in `fotmob_silver.period_stat` (`period = 'All'`).
- Similarity note: Closest: `sig_player_creativity_playmaking_isolated_creativity` (a player with >= 50% of the team's key passes) and `sig_player_creativity_playmaking_maestro_output` (>= 5 key passes). Related creativity signals: `sig_player_creativity_playmaking_maestro_output`, `sig_player_creativity_playmaking_isolated_creativity` and `sig_player_creativity_playmaking_clutch_vision`. Different logic: three key passes for a team with under 35% possession. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_creativity_playmaking_isolated_chance_creator.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_creativity_playmaking_isolated_chance_creator`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_creativity_playmaking_isolated_chance_creator
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
| `trigger_threshold_min_key_passes` | Configured trigger floor (`3` key passes with team possession below 35 %) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_key_passes` | Key passes by the player | Core signal intensity variable. |
| `triggered_player_key_passes_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_team_possession_pct` | Possession of the player's team (%) | Confirms the low-possession context. |
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
