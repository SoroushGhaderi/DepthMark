---
signal_id: sig_team_discipline_cards_the_triple_booking
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "The Triple Booking"
trigger: "Three different players on the same team receive yellow cards inside one rolling 5-minute window."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_discipline_cards_the_triple_booking
  sql: clickhouse/gold/signal/sig_team_discipline_cards_the_triple_booking.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_discipline_cards_the_triple_booking

## Purpose

Flags teams hit by a compact wave of cautions across multiple players, isolating sudden discipline flashpoints rather than general full-match card volume.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_distinct_yellow_carded_players_in_window >= 3`
  - the rolling window uses `card_minute <= window_start_minute + 5`
- Yellow-card events are sourced from `silver.card` where `card_type` or `description` includes yellow-card or booked terminology.
- The trigger is evaluated independently for home and away teams, then emits one row per triggered match-team.
- If a team has multiple qualifying windows, the earliest window is selected using the earliest start minute, then earliest third distinct yellow-card minute.
- Output preserves bilateral context: opponent maximum 5-minute booking window, full-match card and foul load, physical defensive actions, and possession balance.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_discipline_cards_the_triple_booking.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_discipline_cards_the_triple_booking`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_discipline_cards_the_triple_booking
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key and QA anchor |
| `match_date` | Match date | Football developer: supports trend analysis and partition checks |
| `home_team_id` | Home team identifier | Football developer: fixed fixture orientation |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: fixed fixture orientation |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: scoreline context for discipline interpretation |
| `away_score` | Away full-time goals | Football developer: scoreline context for discipline interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical match-team row identity |
| `triggered_team_id` | Triggered team identifier | Football developer: triggered-entity attribution key |
| `triggered_team_name` | Triggered team name | Football developer: human-readable triggered context |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key |
| `opponent_team_name` | Opponent team name | Football developer: human-readable bilateral context |
| `trigger_threshold_min_distinct_yellow_carded_players` | Distinct-player threshold (`3`) | Football developer: explicit trigger guard for QA |
| `trigger_threshold_rolling_window_minutes` | Rolling booking-window threshold in minutes (`5`) | Football developer: precise temporal trigger definition |
| `triggered_team_booking_window_start_minute` | Start minute of the selected triggered-team booking window | Football developer: flashpoint onset timing |
| `triggered_team_booking_window_end_minute` | Last yellow-card minute inside the selected triggered-team window | Football developer: flashpoint duration endpoint |
| `triggered_team_third_distinct_yellow_card_minute` | Minute when the triggered team reaches the third distinct booked player | Football developer: exact trigger activation timing |
| `triggered_team_distinct_yellow_carded_players_in_window` | Distinct triggered-team players yellow-carded in the selected window | Football developer: core trigger metric |
| `opponent_max_distinct_yellow_carded_players_in_window` | Opponent maximum distinct yellow-carded players in any rolling 5-minute window | Football developer: bilateral flashpoint comparator |
| `distinct_yellow_carded_players_in_window_delta` | Triggered minus opponent max distinct yellow-carded players in-window | Football developer: net clustered-discipline imbalance |
| `triggered_team_yellow_card_events_in_window` | Triggered-team yellow-card events in the selected window | Football developer: event-volume severity beyond distinct-player count |
| `opponent_max_yellow_card_events_in_window` | Opponent maximum yellow-card events in any rolling 5-minute window | Football developer: bilateral event-volume comparator |
| `yellow_card_events_in_window_delta` | Triggered selected-window events minus opponent max-window events | Football developer: net window intensity metric |
| `triggered_team_match_yellow_card_events` | Triggered-team yellow-card events across the match from `silver.card` | Football developer: validates cluster against total event load |
| `opponent_match_yellow_card_events` | Opponent yellow-card events across the match from `silver.card` | Football developer: bilateral event-load context |
| `match_yellow_card_events_delta` | Triggered minus opponent match yellow-card events | Football developer: net card-event imbalance |
| `triggered_team_yellow_cards` | Triggered-side yellow cards from full-match period stats | Football developer: official aggregate caution load |
| `opponent_yellow_cards` | Opponent yellow cards from full-match period stats | Football developer: bilateral aggregate caution comparator |
| `yellow_cards_delta` | Triggered minus opponent yellow cards | Football developer: net caution imbalance |
| `triggered_team_red_cards` | Triggered-side red cards | Football developer: escalation severity context |
| `opponent_red_cards` | Opponent red cards | Football developer: bilateral dismissal context |
| `red_cards_delta` | Triggered minus opponent red cards | Football developer: net escalation imbalance |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: aggregate discipline burden |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: bilateral aggregate discipline comparator |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: net match discipline imbalance |
| `triggered_team_fouls_committed` | Triggered-side fouls committed | Football developer: aggression load around the booking cluster |
| `opponent_fouls_committed` | Opponent fouls committed | Football developer: bilateral aggression comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls committed | Football developer: net foul-pressure differential |
| `triggered_team_cards_per_foul_pct` | Triggered-side cards per foul (%) | Football developer: sanction efficiency context |
| `opponent_cards_per_foul_pct` | Opponent cards per foul (%) | Football developer: bilateral sanction-efficiency comparator |
| `cards_per_foul_delta_pct` | Triggered minus opponent cards per foul (percentage points) | Football developer: referee/team discipline differential |
| `triggered_team_duels_won` | Triggered-side duels won | Football developer: physicality context |
| `opponent_duels_won` | Opponent duels won | Football developer: bilateral physicality comparator |
| `triggered_team_tackles_won` | Triggered-side tackles won | Football developer: defensive-action context |
| `opponent_tackles_won` | Opponent tackles won | Football developer: bilateral defensive-action comparator |
| `triggered_team_interceptions` | Triggered-side interceptions | Football developer: defensive anticipation context |
| `opponent_interceptions` | Opponent interceptions | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Triggered-side clearances | Football developer: pressure-management context |
| `opponent_clearances` | Opponent clearances | Football developer: bilateral pressure-management comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control context for the booking cluster |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential |
