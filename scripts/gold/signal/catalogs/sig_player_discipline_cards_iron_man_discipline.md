---
signal_id: sig_player_discipline_cards_iron_man_discipline
status: active
entity: player
family: discipline
subfamily: cards
grain: match_player
headline: "Iron Man Discipline"
trigger: "defender/defensive-midfielder proxy plays 90 minutes, commits 0 fouls, and records >= 5 tackles won"
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_discipline_cards_iron_man_discipline
  sql: clickhouse/gold/dml/signals/player/sig_player_discipline_cards_iron_man_discipline.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_discipline_cards_iron_man_discipline

## Purpose

Flags defensive players who complete the full 90 with high tackle output but zero fouls, surfacing clean, high-volume duel control profiles.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_minutes_played = 90`
  - `triggered_player_fouls_committed = 0`
  - `triggered_player_tackles_won >= 5`
  - `triggered_player_usual_playing_position_id IN (1, 2)` (defender + defensive-midfielder proxy scope)
- Player tackle/foul/minutes metrics are sourced from `silver.player_match_stat`.
- Player card counts are sourced from `silver.card` at `match_id + player_id` grain for discipline context.
- Player role scope comes from `silver.match_personnel` via `triggered_player_position_id` and `triggered_player_usual_playing_position_id`.
- Team/opponent bilateral foul, card, tackle, and possession context is sourced from `silver.period_stat` (`period = 'All'`).

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_discipline_cards_iron_man_discipline.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_discipline_cards_iron_man_discipline`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_discipline_cards_iron_man_discipline
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for player, team, and match-level diagnostics |
| `match_date` | Match calendar date | Football developer: enables temporal trend analysis on clean defensive performances |
| `home_team_id` | Home team ID | Football developer: preserves bilateral match context |
| `home_team_name` | Home team name | Football developer: readable contextual labeling |
| `away_team_id` | Away team ID | Football developer: preserves bilateral match context |
| `away_team_name` | Away team name | Football developer: readable contextual labeling |
| `home_score` | Home full-time goals | Football developer: outcome context for interpreting defensive control impact |
| `away_score` | Away full-time goals | Football developer: outcome context for interpreting defensive control impact |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for side-aware aggregation |
| `triggered_player_id` | Triggered player ID | Football developer: player-level identity key for feature joins |
| `triggered_player_name` | Triggered player name | Football developer: readable player attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player behavior to team tactical context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: matchup identity for bilateral comparisons |
| `opponent_team_name` | Opponent team name | Football developer: readable matchup attribution |
| `triggered_player_role_group` | Derived role label (`defender` or `defensive_midfielder_proxy`) | Football developer: explicit role segmentation for clean-defending profiles |
| `triggered_player_position_id` | Match-specific position ID from personnel data | Football developer: positional QA and role diagnostics |
| `triggered_player_usual_playing_position_id` | Broad role bucket from personnel data | Football developer: reproducible role-scope gate for defender/DM proxy coverage |
| `trigger_threshold_minutes_played` | Configured minutes threshold for trigger | Football developer: keeps full-match requirement explicit in row output |
| `trigger_threshold_fouls_committed` | Configured foul threshold for trigger | Football developer: keeps zero-foul requirement explicit in row output |
| `trigger_threshold_tackles_won` | Configured tackles-won threshold for trigger | Football developer: keeps defensive-volume requirement explicit in row output |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: validates full-match exposure |
| `triggered_player_fouls_committed` | Fouls committed by triggered player | Football developer: core discipline gate for clean tackling profile |
| `triggered_player_tackles_won` | Tackles won by triggered player | Football developer: core defensive-volume trigger metric |
| `triggered_player_tackle_attempts` | Tackle attempts by triggered player | Football developer: context for tackle efficiency and duel load |
| `triggered_player_total_cards` | Total cards received by triggered player in match | Football developer: discipline context around clean-tackle performances |
| `triggered_player_yellow_cards` | Yellow-card count for triggered player | Football developer: card-color decomposition for discipline profiling |
| `triggered_player_red_cards` | Red-card count for triggered player | Football developer: severe-discipline context for edge-case audits |
| `triggered_player_was_fouled` | Times triggered player was fouled | Football developer: duel-context signal around defensive engagement intensity |
| `tackles_won_above_threshold` | Tackles won above trigger threshold (`tackles_won - 5`) | Football developer: severity measure beyond binary trigger |
| `triggered_team_fouls` | Fouls committed by triggered player's team | Football developer: team-level discipline environment around player event |
| `opponent_fouls` | Fouls committed by opponent team | Football developer: bilateral discipline comparator |
| `triggered_team_total_cards` | Total cards (yellow+red) for triggered player's team | Football developer: team discipline context for officiating/game tone |
| `opponent_total_cards` | Total cards (yellow+red) for opponent team | Football developer: bilateral discipline comparator |
| `triggered_team_yellow_cards` | Triggered-team yellow-card count | Football developer: card-color decomposition for team discipline profiling |
| `opponent_yellow_cards` | Opponent yellow-card count | Football developer: bilateral card-color decomposition |
| `triggered_team_red_cards` | Triggered-team red-card count | Football developer: high-impact discipline context around defensive load |
| `opponent_red_cards` | Opponent red-card count | Football developer: bilateral high-impact discipline comparator |
| `triggered_team_tackles_won` | Team tackles won by triggered side | Football developer: team defensive-intensity baseline around the player trigger |
| `opponent_tackles_won` | Team tackles won by opponent side | Football developer: bilateral defensive-intensity comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: style/context signal for defending workload |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral possession comparator for discipline interpretation |
