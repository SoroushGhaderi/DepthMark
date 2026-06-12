---
signal_id: sig_player_discipline_cards_foul_magnet
status: active
entity: player
family: discipline
subfamily: cards
grain: match_player
headline: "Foul Magnet"
trigger: "player is fouled >= 6 times in a single match"
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_discipline_cards_foul_magnet
  sql: clickhouse/gold/signal/sig_player_discipline_cards_foul_magnet.sql
  runner: scripts/gold/signal/runners/sig_player_discipline_cards_foul_magnet.py
---
# sig_player_discipline_cards_foul_magnet

## Purpose

Flags players who are fouled six or more times in a match, surfacing high-contact focal points who repeatedly draw defensive infringements.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_was_fouled >= 6`
- Player foul-drawn volume is sourced from `silver.player_match_stat.was_fouled`.
- Player card counts are sourced from `silver.card` at `match_id + player_id` grain to contextualize whether repeated contact also led to retaliation or bookings.
- Team and opponent discipline context is sourced from `silver.period_stat` (`period = 'All'`) using symmetric `triggered_team_*` and `opponent_*` fields for fouls and cards.
- Possession context helps distinguish foul-drawing in proactive possession phases from transition or low-possession defensive match states.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_discipline_cards_foul_magnet.sql`
- Runner: `scripts/gold/signal/runners/sig_player_discipline_cards_foul_magnet.py`
- Target table: `gold_signals.sig_player_discipline_cards_foul_magnet`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_discipline_cards_foul_magnet.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for player, team, and match-level diagnostics |
| `match_date` | Match calendar date | Football developer: enables temporal trend analysis on foul-drawing behavior |
| `home_team_id` | Home team ID | Football developer: preserves bilateral match context |
| `home_team_name` | Home team name | Football developer: readable contextual labeling |
| `away_team_id` | Away team ID | Football developer: preserves bilateral match context |
| `away_team_name` | Away team name | Football developer: readable contextual labeling |
| `home_score` | Home full-time goals | Football developer: outcome context for interpreting foul pressure impact |
| `away_score` | Away full-time goals | Football developer: outcome context for interpreting foul pressure impact |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for side-aware aggregation |
| `triggered_player_id` | Triggered player ID | Football developer: player-level identity key for feature joins |
| `triggered_player_name` | Triggered player name | Football developer: readable player attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player contact profile to team tactical context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: matchup identity for bilateral comparisons |
| `opponent_team_name` | Opponent team name | Football developer: readable matchup attribution |
| `trigger_threshold_was_fouled` | Configured foul-drawn threshold for trigger | Football developer: makes trigger boundary explicit in row-level outputs |
| `triggered_player_was_fouled` | Number of fouls suffered by triggered player | Football developer: core trigger metric for repeated contact absorption |
| `triggered_player_fouls_committed` | Fouls committed by triggered player | Football developer: balances foul-drawn profile with own infringement behavior |
| `triggered_player_total_cards` | Total cards received by triggered player in match | Football developer: discipline context for escalation risk around repeated contact |
| `triggered_player_yellow_cards` | Yellow-card count for triggered player | Football developer: card-color decomposition for discipline profiling |
| `triggered_player_red_cards` | Red-card count for triggered player | Football developer: severe-discipline context around high-contact matches |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure context for interpreting foul-drawn totals |
| `was_fouled_count_above_threshold` | Fouls suffered above trigger threshold (`was_fouled - 6`) | Football developer: severity measure beyond binary trigger |
| `triggered_team_total_fouls` | Fouls committed by triggered player's team | Football developer: team-level infringement environment around the triggered player |
| `opponent_total_fouls` | Fouls committed by opponent team | Football developer: bilateral infringement comparator against player-level foul-drawn volume |
| `triggered_team_total_cards` | Total cards (yellow+red) for triggered player's team | Football developer: team discipline context for referee strictness and game tone |
| `opponent_total_cards` | Total cards (yellow+red) for opponent team | Football developer: bilateral discipline comparator |
| `triggered_team_yellow_cards` | Triggered-team yellow-card count | Football developer: card-color decomposition for team discipline profiling |
| `opponent_yellow_cards` | Opponent yellow-card count | Football developer: bilateral card-color decomposition |
| `triggered_team_red_cards` | Triggered-team red-card count | Football developer: high-impact discipline context around repeated-contact matches |
| `opponent_red_cards` | Opponent red-card count | Football developer: bilateral high-impact discipline comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: style/context signal for whether fouls were drawn in proactive or reactive phases |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral possession comparator for foul-drawing interpretation |
