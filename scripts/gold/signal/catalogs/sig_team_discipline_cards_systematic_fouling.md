---
signal_id: sig_team_discipline_cards_systematic_fouling
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Systematic Fouling"
trigger: "Every starter midfielder on a side receives at least one yellow card in the match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_discipline_cards_systematic_fouling
  sql: clickhouse/gold/dml/signals/team/sig_team_discipline_cards_systematic_fouling.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_discipline_cards_systematic_fouling

## Purpose

Flags match-team cases where caution pressure is spread across the entire starting midfield unit, signaling coordinated or repeated midfield fouling risk.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_starting_midfielders_booked = triggered_team_starting_midfielders`
  - `triggered_team_starting_midfielders >= 1`
- Starter midfielders are sourced from `silver.match_personnel` with `role = 'starter'` and `usual_playing_position_id = 2`.
- Yellow bookings are sourced from `silver.card` where card metadata indicates yellow/booked events.
- Trigger is evaluated symmetrically for `home` and `away`, then enriched with bilateral discipline, foul volume, defensive actions, and possession context.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_discipline_cards_systematic_fouling.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_discipline_cards_systematic_fouling`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_discipline_cards_systematic_fouling
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key and QA anchor |
| `match_date` | Match date | Football developer: supports temporal analysis and partition checks |
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
| `trigger_threshold_min_starting_midfielders` | Minimum starter midfielders required to evaluate trigger (`1`) | Football developer: explicit trigger eligibility provenance |
| `trigger_threshold_min_yellow_cards_per_starting_midfielder` | Required yellow-card count per starter midfielder (`1`) | Football developer: explicit per-player trigger rule |
| `triggered_team_starting_midfielders` | Count of triggered-side starter midfielders | Football developer: trigger denominator and data completeness context |
| `opponent_starting_midfielders` | Count of opponent starter midfielders | Football developer: bilateral denominator comparator |
| `starting_midfielders_delta` | Triggered minus opponent starter-midfielder count | Football developer: formation/selection imbalance context |
| `triggered_team_starting_midfielders_booked` | Triggered-side starter midfielders with at least one yellow | Football developer: core trigger numerator |
| `opponent_starting_midfielders_booked` | Opponent starter midfielders with at least one yellow | Football developer: bilateral booking-coverage comparator |
| `starting_midfielders_booked_delta` | Triggered minus opponent booked starter midfielders | Football developer: net midfield caution spread imbalance |
| `triggered_team_starting_midfielders_booked_share_pct` | Triggered-side share of booked starter midfielders (%) | Football developer: normalized trigger-severity view |
| `opponent_starting_midfielders_booked_share_pct` | Opponent share of booked starter midfielders (%) | Football developer: bilateral normalized comparator |
| `triggered_team_yellow_cards_on_starting_midfielders` | Yellow cards shown to triggered-side starter midfielders | Football developer: caution load concentrated in midfield unit |
| `opponent_yellow_cards_on_starting_midfielders` | Yellow cards shown to opponent starter midfielders | Football developer: bilateral midfield caution comparator |
| `yellow_cards_on_starting_midfielders_delta` | Triggered minus opponent yellow cards on starter midfielders | Football developer: net midfield caution pressure differential |
| `triggered_team_first_starting_midfielder_yellow_card_minute` | Minute of earliest triggered-side starter-midfielder yellow card | Football developer: onset timing of midfield discipline stress |
| `opponent_first_starting_midfielder_yellow_card_minute` | Minute of earliest opponent starter-midfielder yellow card | Football developer: bilateral onset timing comparator |
| `triggered_team_last_starting_midfielder_yellow_card_minute` | Minute of latest triggered-side starter-midfielder yellow card | Football developer: spread and persistence of midfield cautions |
| `opponent_last_starting_midfielder_yellow_card_minute` | Minute of latest opponent starter-midfielder yellow card | Football developer: bilateral persistence comparator |
| `triggered_team_yellow_cards` | Triggered-side total yellow cards (match) | Football developer: full-match caution context around trigger |
| `opponent_yellow_cards` | Opponent total yellow cards (match) | Football developer: bilateral caution context |
| `triggered_team_red_cards` | Triggered-side total red cards (match) | Football developer: dismissal escalation context |
| `opponent_red_cards` | Opponent total red cards (match) | Football developer: bilateral dismissal context |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: aggregate discipline burden |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: bilateral aggregate comparator |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: net disciplinary imbalance |
| `triggered_team_fouls_committed` | Triggered-side fouls committed | Football developer: aggression context behind midfield cautions |
| `opponent_fouls_committed` | Opponent fouls committed | Football developer: bilateral aggression comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net foul-pressure differential |
| `triggered_team_duels_won` | Triggered-side duels won | Football developer: physical contest context |
| `opponent_duels_won` | Opponent duels won | Football developer: bilateral physicality comparator |
| `triggered_team_tackles_won` | Triggered-side tackles won | Football developer: defensive-action context |
| `opponent_tackles_won` | Opponent tackles won | Football developer: bilateral defensive-action comparator |
| `triggered_team_interceptions` | Triggered-side interceptions | Football developer: defensive anticipation context |
| `opponent_interceptions` | Opponent interceptions | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Triggered-side clearances | Football developer: pressure-management context |
| `opponent_clearances` | Opponent clearances | Football developer: bilateral pressure-management comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control/style context for foul interpretation |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential aligned with discipline load |
