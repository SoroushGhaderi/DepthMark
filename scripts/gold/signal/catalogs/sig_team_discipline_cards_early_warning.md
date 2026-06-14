---
signal_id: sig_team_discipline_cards_early_warning
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Early Warning"
trigger: "Team has >= 3 distinct booked players before minute 30."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_discipline_cards_early_warning
  sql: clickhouse/gold/dml/signals/team/sig_team_discipline_cards_early_warning.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_discipline_cards_early_warning

## Purpose

Flags teams that spread early cautions across multiple players, a practical indicator of early discipline stress and tactical-risk buildup.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_distinct_booked_players_early >= 3`
  - booking window uses `card_minute < 30`
- Booking events are sourced from `silver.card` and include yellow-card style events (`card_type`/`description` contains yellow or booked terms).
- Trigger is evaluated for both sides (`home` and `away`) and emits one row per triggered match-team.
- Output preserves bilateral context: early booking concentration, full-match card/foul load, defensive actions, and possession balance.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_discipline_cards_early_warning.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_discipline_cards_early_warning`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_discipline_cards_early_warning
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key and QA anchor |
| `match_date` | Match date | Football developer: supports partitioned checks and trend analysis |
| `home_team_id` | Home team identifier | Football developer: fixed fixture orientation |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: fixed fixture orientation |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: scoreline context for discipline interpretation |
| `away_score` | Away full-time goals | Football developer: scoreline context for discipline interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical row identity orientation |
| `triggered_team_id` | Triggered team identifier | Football developer: triggered-entity attribution key |
| `triggered_team_name` | Triggered team name | Football developer: human-readable triggered context |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key |
| `opponent_team_name` | Opponent team name | Football developer: human-readable bilateral context |
| `trigger_threshold_min_distinct_booked_players_early` | Distinct booked-player threshold (`3`) | Football developer: explicit trigger provenance |
| `trigger_threshold_booking_minute_exclusive` | Exclusive minute cap for early window (`30`) | Football developer: precise trigger window definition |
| `triggered_team_distinct_booked_players_early` | Distinct triggered-team players booked before minute 30 | Football developer: core trigger metric |
| `opponent_distinct_booked_players_early` | Distinct opponent players booked before minute 30 | Football developer: bilateral early-discipline comparator |
| `distinct_booked_players_early_delta` | Triggered minus opponent distinct early-booked players | Football developer: early discipline imbalance metric |
| `triggered_team_early_bookings_total` | Total triggered-team booking events before minute 30 | Football developer: event-volume severity beyond distinct count |
| `opponent_early_bookings_total` | Total opponent booking events before minute 30 | Football developer: bilateral event-volume comparator |
| `early_bookings_total_delta` | Triggered minus opponent early booking events | Football developer: net early-card pressure imbalance |
| `triggered_team_first_booking_minute_early` | Minute of triggered team’s first booking in early window | Football developer: onset timing of discipline pressure |
| `opponent_first_booking_minute_early` | Minute of opponent’s first booking in early window | Football developer: bilateral onset timing comparator |
| `triggered_team_third_distinct_booking_minute_early` | Minute when triggered team reaches third distinct booked player | Football developer: exact trigger activation timing |
| `opponent_third_distinct_booking_minute_early` | Minute when opponent reaches third distinct booked player (if any) | Football developer: bilateral trigger-timing context |
| `triggered_team_early_booked_player_share_pct` | Triggered share of distinct early-booked players (%) | Football developer: normalized early-discipline concentration |
| `opponent_early_booked_player_share_pct` | Opponent share of distinct early-booked players (%) | Football developer: bilateral normalization baseline |
| `triggered_team_yellow_cards` | Triggered-side total yellow cards (match) | Football developer: full-match caution load around early warning |
| `opponent_yellow_cards` | Opponent total yellow cards (match) | Football developer: bilateral caution context |
| `triggered_team_red_cards` | Triggered-side total red cards (match) | Football developer: escalation severity context |
| `opponent_red_cards` | Opponent total red cards (match) | Football developer: bilateral dismissal context |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: aggregate discipline burden |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: bilateral aggregate comparator |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: net match discipline imbalance |
| `triggered_team_fouls_committed` | Triggered-side fouls committed | Football developer: aggression load paired with booking spread |
| `opponent_fouls_committed` | Opponent fouls committed | Football developer: bilateral aggression comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net foul-pressure differential |
| `triggered_team_duels_won` | Triggered-side duels won | Football developer: physicality context |
| `opponent_duels_won` | Opponent duels won | Football developer: bilateral physicality comparator |
| `triggered_team_tackles_won` | Triggered-side tackles won | Football developer: defensive-action context |
| `opponent_tackles_won` | Opponent tackles won | Football developer: bilateral defensive-action comparator |
| `triggered_team_interceptions` | Triggered-side interceptions | Football developer: defensive anticipation context |
| `opponent_interceptions` | Opponent interceptions | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Triggered-side clearances | Football developer: pressure-management context |
| `opponent_clearances` | Opponent clearances | Football developer: bilateral pressure-management comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control/style context for early booking stress |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential alongside discipline signal |
