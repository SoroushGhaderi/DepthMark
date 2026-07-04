---
signal_id: sig_team_discipline_cards_half_time_talk_fail
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Half-Time Talk Fail"
trigger: "Team receives >= 3 yellow cards between minutes 46 and 60."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_discipline_cards_half_time_talk_fail
  sql: clickhouse/gold/dml/signals/team/sig_team_discipline_cards_half_time_talk_fail.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_discipline_cards_half_time_talk_fail

## Purpose

Flags team-match performances where a team collects three or more yellow cards in the first 15 minutes after half-time, surfacing second-half discipline collapse patterns.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_yellow_cards_window >= 3`
- Window definition:
  - yellow-card events in match minutes `46` to `60` inclusive (`15` minutes from second-half restart).
- Trigger is evaluated symmetrically for home and away teams from `silver.card` events, then enriched with full-match bilateral context from `silver.period_stat`.
- The signal preserves in-window booking pace and score state at the third yellow card to differentiate panic, tactical fouling, and loss-of-control patterns.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_discipline_cards_half_time_talk_fail.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_discipline_cards_half_time_talk_fail`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_discipline_cards_half_time_talk_fail
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key and release QA anchor |
| `match_date` | Match date | Football developer: temporal slicing and partition alignment |
| `home_team_id` | Home team identifier | Football developer: fixed fixture orientation anchor |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: fixed fixture orientation anchor |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: outcome context for discipline interpretation |
| `away_score` | Away full-time goals | Football developer: outcome context for discipline interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical orientation key for row identity |
| `triggered_team_id` | Triggered team identifier | Football developer: durable triggered-entity identity |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-entity context |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_min_yellow_cards` | Configured minimum yellow-card threshold (`3`) | Football developer: explicit trigger provenance for reproducibility |
| `trigger_window_start_minute` | Start minute of trigger window (`46`) | Football developer: transparent temporal boundary for QA |
| `trigger_window_end_minute` | End minute of trigger window (`60`) | Football developer: transparent temporal boundary for QA |
| `triggered_team_yellow_cards_window` | Yellow cards on triggered side inside minutes 46-60 | Football developer: core trigger intensity metric |
| `opponent_yellow_cards_window` | Opponent yellow cards inside minutes 46-60 | Football developer: bilateral in-window comparator |
| `yellow_cards_window_delta` | Triggered minus opponent yellow cards in the window | Football developer: net second-half restart discipline imbalance |
| `triggered_team_first_yellow_card_window_minute` | Minute of first triggered-side yellow in the window | Football developer: escalation timing context |
| `triggered_team_third_yellow_card_window_minute` | Minute of threshold-reaching third yellow | Football developer: exact trigger timestamp for replay/debug |
| `minutes_from_second_half_start_to_third_yellow` | Minutes from restart to the third yellow (`minute - 45`) | Football developer: speed-of-collapse diagnostic |
| `triggered_team_score_at_third_yellow` | Triggered team score at threshold event | Football developer: game-state context around loss of discipline |
| `opponent_score_at_third_yellow` | Opponent score at threshold event | Football developer: bilateral game-state comparator |
| `score_margin_at_third_yellow` | Triggered minus opponent score at threshold event | Football developer: pressure-state interpretation at trigger time |
| `triggered_team_yellow_cards_match` | Triggered-side yellow cards in full match | Football developer: full-match caution burden context |
| `opponent_yellow_cards_match` | Opponent yellow cards in full match | Football developer: bilateral caution comparator |
| `yellow_cards_match_delta` | Triggered minus opponent full-match yellow cards | Football developer: net caution imbalance beyond trigger window |
| `triggered_team_red_cards_match` | Triggered-side red cards in full match | Football developer: severe-discipline escalation context |
| `opponent_red_cards_match` | Opponent red cards in full match | Football developer: bilateral severe-discipline comparator |
| `triggered_team_total_cards_match` | Triggered-side total cards (yellow+red) in full match | Football developer: aggregate discipline load for downstream modeling |
| `opponent_total_cards_match` | Opponent total cards (yellow+red) in full match | Football developer: bilateral aggregate discipline comparator |
| `card_count_match_delta` | Triggered minus opponent total cards in full match | Football developer: net discipline-pressure differential |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Football developer: aggression load linked to bookings |
| `opponent_fouls_committed` | Fouls committed by opponent side | Football developer: bilateral foul-load comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls committed | Football developer: net physical-intensity imbalance |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: physical contest context for booking sequences |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral physical contest comparator |
| `triggered_team_tackles_won` | Tackles won by triggered side | Football developer: defensive-action profile around trigger |
| `opponent_tackles_won` | Tackles won by opponent side | Football developer: bilateral defensive-action comparator |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-management context after restart |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-management comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control/style context around the discipline spike |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with trigger |
