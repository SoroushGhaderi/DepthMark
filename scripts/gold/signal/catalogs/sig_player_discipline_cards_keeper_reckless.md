---
signal_id: sig_player_discipline_cards_keeper_reckless
status: active
entity: player
family: discipline
subfamily: cards
grain: match_player
headline: "Keeper Reckless"
trigger: "Goalkeeper receives at least one yellow/red card in the match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_discipline_cards_keeper_reckless
  sql: clickhouse/gold/dml/signals/player/sig_player_discipline_cards_keeper_reckless.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_discipline_cards_keeper_reckless

## Purpose

Flags goalkeeper bookings (yellow/red) to surface discipline breakdowns in the last line of defense, with bilateral match-state context.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_total_cards_match >= 1`
  - `is_goalkeeper = 1`
- Card events are sourced from `silver.card` and classified into yellow/red markers using `card_type` and `description`.
- The signal emits one row per goalkeeper per match and stores first-card timing/type plus total yellow/red card counts for severity profiling.
- Bilateral match context from `silver.period_stat` (`period = 'All'`) includes fouls, cards, keeper saves, and possession for interpretation of game tone and pressure.
- Output keeps both player identity (`triggered_player_*`) and team identity (`triggered_team_*`) for contract-compliant player-grain traceability.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_discipline_cards_keeper_reckless.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_discipline_cards_keeper_reckless`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_discipline_cards_keeper_reckless
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key across player and match features |
| `match_date` | Match date | Football developer: supports trend analysis and time-window modeling |
| `home_team_id` | Home team ID | Football developer: fixture orientation context |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixture orientation context |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Full-time home goals | Football developer: outcome context around keeper discipline events |
| `away_score` | Full-time away goals | Football developer: outcome context around keeper discipline events |
| `triggered_side` | Side of triggered goalkeeper (`home` or `away`) | Football developer: canonical side orientation for downstream slicing |
| `triggered_player_id` | Triggered goalkeeper player ID | Football developer: primary player attribution key |
| `triggered_player_name` | Triggered goalkeeper name | Football developer: readable signal attribution |
| `triggered_team_id` | Team ID of triggered goalkeeper | Football developer: team linkage for tactical context joins |
| `triggered_team_name` | Team name of triggered goalkeeper | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup context |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_total_cards` | Trigger threshold for total cards (`1`) | Football developer: explicit trigger provenance for QA |
| `triggered_player_first_card_minute` | Minute of the goalkeeper's first card event | Football developer: timing severity and game-state phase context |
| `triggered_player_first_card_type` | Type of first card (`yellow`, `red`, or `yellow_red`) | Football developer: immediate discipline severity at trigger point |
| `triggered_player_yellow_cards_match` | Yellow-card count for triggered goalkeeper | Football developer: caution load around the trigger |
| `triggered_player_red_cards_match` | Red-card count for triggered goalkeeper | Football developer: dismissal severity around the trigger |
| `triggered_player_total_cards_match` | Total card events for triggered goalkeeper | Football developer: aggregate discipline burden at player grain |
| `triggered_player_fouls_committed` | Fouls committed by triggered goalkeeper | Football developer: behavior context behind bookings |
| `triggered_player_was_fouled` | Times triggered goalkeeper was fouled | Football developer: physical-duel context around conflict events |
| `triggered_player_minutes_played` | Minutes played by triggered goalkeeper | Football developer: exposure context for interpreting card counts |
| `triggered_team_score_at_first_card` | Triggered team score at first keeper card | Football developer: match-state context at first trigger event |
| `opponent_score_at_first_card` | Opponent score at first keeper card | Football developer: bilateral match-state context at trigger event |
| `score_margin_at_first_card` | Triggered-side score margin at first keeper card | Football developer: pressure-state interpretation (chasing, level, leading) |
| `triggered_team_total_fouls` | Fouls committed by triggered side | Football developer: team discipline environment around keeper booking |
| `opponent_total_fouls` | Fouls committed by opponent side | Football developer: bilateral discipline comparator |
| `triggered_team_yellow_cards_match` | Yellow-card count for triggered side | Football developer: team caution context for referee/game strictness |
| `opponent_yellow_cards_match` | Yellow-card count for opponent side | Football developer: bilateral caution comparator |
| `triggered_team_red_cards_match` | Red-card count for triggered side | Football developer: team dismissal pressure context |
| `opponent_red_cards_match` | Red-card count for opponent side | Football developer: bilateral dismissal comparator |
| `triggered_team_total_cards_match` | Total cards (yellow+red) for triggered side | Football developer: aggregate team discipline load |
| `opponent_total_cards_match` | Total cards (yellow+red) for opponent side | Football developer: bilateral aggregate discipline comparator |
| `triggered_team_keeper_saves` | Keeper saves by triggered side | Football developer: defensive pressure context surrounding keeper discipline |
| `opponent_keeper_saves` | Keeper saves by opponent side | Football developer: bilateral defensive-pressure comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control context at match level |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
