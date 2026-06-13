---
signal_id: sig_team_discipline_cards_frustration_peak
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Frustration Peak"
trigger: "Team receives >= 3 yellow/red cards while trailing after the 75th minute."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_discipline_cards_frustration_peak
  sql: clickhouse/gold/signal/sig_team_discipline_cards_frustration_peak.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_discipline_cards_frustration_peak

## Purpose

Flags team-match performances where late-game scoreboard pressure (trailing state after minute 75) is paired with repeated cautions/dismissals, surfacing frustration-driven discipline breakdowns.

## Tactical And Statistical Logic

- Trigger condition:
  - Card event is yellow or red.
  - `card_minute > 75`.
  - Carded side is trailing at event-time score snapshot.
  - Team accumulates `>= 3` qualifying cards in the same match.
- Trigger is evaluated symmetrically for home and away via `silver.card` event states (`team_side`, `card_minute`, `score_home_at_time`, `score_away_at_time`).
- The signal preserves bilateral total-card context from `silver.period_stat` (`period = 'All'`) plus fouls, defensive actions, and possession for tactical interpretation.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_discipline_cards_frustration_peak.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_discipline_cards_frustration_peak`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_discipline_cards_frustration_peak
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key and release QA anchor |
| `match_date` | Match date | Football developer: temporal analysis and partition alignment |
| `home_team_id` | Home team identifier | Football developer: fixed fixture orientation anchor |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: fixed fixture orientation anchor |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: outcome context for late-discipline interpretation |
| `away_score` | Away full-time goals | Football developer: outcome context for late-discipline interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical orientation key for row identity |
| `triggered_team_id` | Triggered team identifier | Football developer: triggered-entity attribution key |
| `triggered_team_name` | Triggered team name | Football developer: human-readable triggered-entity context |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key |
| `opponent_team_name` | Opponent team name | Football developer: human-readable bilateral context |
| `trigger_threshold_min_cards_while_trailing_late` | Configured late-trailing card threshold (`3`) | Football developer: explicit trigger provenance and governance trace |
| `trigger_threshold_minute` | Configured minute gate (`75`) | Football developer: explicit timing rule provenance |
| `triggered_team_cards_while_trailing_late` | Triggered-side yellow/red cards after minute 75 while trailing | Football developer: core trigger metric |
| `opponent_cards_while_trailing_late` | Opponent yellow/red cards after minute 75 while trailing | Football developer: bilateral comparator for shared match stress |
| `cards_while_trailing_late_delta` | Triggered minus opponent late-trailing card count | Football developer: net late-frustration imbalance |
| `triggered_team_first_trailing_card_minute` | Minute of first qualifying late-trailing card | Football developer: onset timing for discipline collapse sequence |
| `triggered_team_last_trailing_card_minute` | Minute of last qualifying late-trailing card | Football developer: duration/span of late discipline stress |
| `triggered_team_score_at_first_trailing_card` | Triggered-side goals at first qualifying card | Football developer: exact game-state context at trigger onset |
| `opponent_score_at_first_trailing_card` | Opponent goals at first qualifying card | Football developer: bilateral game-state context at trigger onset |
| `score_margin_at_first_trailing_card` | Triggered-side score margin at first qualifying card | Football developer: deficit size at onset of discipline spike |
| `min_score_margin_during_trailing_cards` | Most negative triggered-side margin across qualifying cards | Football developer: worst-score-pressure severity during trigger window |
| `triggered_team_yellow_cards_while_trailing_late` | Triggered-side late-trailing yellow cards | Football developer: card-color decomposition for trigger diagnostics |
| `opponent_yellow_cards_while_trailing_late` | Opponent late-trailing yellow cards | Football developer: bilateral card-color comparator |
| `triggered_team_red_cards_while_trailing_late` | Triggered-side late-trailing red cards | Football developer: severe-discipline decomposition during trigger window |
| `opponent_red_cards_while_trailing_late` | Opponent late-trailing red cards | Football developer: bilateral severe-discipline comparator |
| `triggered_team_yellow_cards` | Triggered-side total yellow cards in match | Football developer: full-match caution context around trigger |
| `opponent_yellow_cards` | Opponent total yellow cards in match | Football developer: bilateral caution baseline |
| `triggered_team_red_cards` | Triggered-side total red cards in match | Football developer: full-match dismissal context around trigger |
| `opponent_red_cards` | Opponent total red cards in match | Football developer: bilateral dismissal baseline |
| `triggered_team_total_cards` | Triggered-side total cards (yellow+red) in match | Football developer: denominator and broader discipline burden context |
| `opponent_total_cards` | Opponent total cards (yellow+red) in match | Football developer: bilateral discipline burden comparator |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: net full-match card-pressure imbalance |
| `triggered_team_late_trailing_cards_share_pct` | Share of triggered-side total cards that are late-trailing cards (%) | Football developer: concentration of discipline events in pressure phase |
| `opponent_late_trailing_cards_share_pct` | Share of opponent total cards that are late-trailing cards (%) | Football developer: symmetric concentration comparator |
| `late_trailing_cards_share_delta_pct` | Triggered minus opponent late-trailing card share (percentage points) | Football developer: compact asymmetry metric for pressure-phase discipline clustering |
| `triggered_team_fouls_committed` | Triggered-side total fouls | Football developer: contact-volume context for card accumulation |
| `opponent_fouls_committed` | Opponent total fouls | Football developer: bilateral foul comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net aggression imbalance alongside late cards |
| `triggered_team_duels_won` | Triggered-side duels won | Football developer: physical contest context around frustration trigger |
| `opponent_duels_won` | Opponent duels won | Football developer: bilateral physical contest comparator |
| `triggered_team_tackles_won` | Triggered-side tackles won | Football developer: defensive-action context during chase state |
| `opponent_tackles_won` | Opponent tackles won | Football developer: bilateral defensive-action comparator |
| `triggered_team_interceptions` | Triggered-side interceptions | Football developer: anticipation/pressing context for pressure response |
| `opponent_interceptions` | Opponent interceptions | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Triggered-side clearances | Football developer: pressure-management context while chasing game |
| `opponent_clearances` | Opponent clearances | Football developer: bilateral pressure-management comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control-style context for late discipline behavior |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with frustration trigger |
