---
signal_id: sig_match_discipline_cards_stop_start_hell
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Stop-Start Hell"
trigger: "A whistle (foul/card/offside) every 90 seconds on average."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_discipline_cards_stop_start_hell
  sql: clickhouse/gold/signal/sig_match_discipline_cards_stop_start_hell.sql
  runner: scripts/gold/signal/runners/sig_match_discipline_cards_stop_start_hell.py
---
# sig_match_discipline_cards_stop_start_hell

## Purpose

Flags matches with relentless interruption tempo, where whistle proxy events (fouls + cards + offsides) average at least one every 90 seconds across regulation time.

## Tactical And Statistical Logic

- Trigger condition:
  - `fouls_home + fouls_away + yellow_cards_home + yellow_cards_away + red_cards_home + red_cards_away + offsides_home + offsides_away >= 60` from `silver.period_stat` at `period = 'All'`.
  - Threshold maps directly from the trigger phrase under a 90-minute baseline: `5400 / 90 = 60`.
- Trigger is match-level and emitted as two side-oriented rows (`home` and `away`) so downstream team pipelines consume symmetric `match_team` grain output.
- Output keeps whistle intensity, side contribution splits, foul/card/offside composition, and bilateral defensive/possession context for tactical interpretation.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_discipline_cards_stop_start_hell.sql`
- Runner: `scripts/gold/signal/runners/sig_match_discipline_cards_stop_start_hell.py`
- Target table: `gold_signals.sig_match_discipline_cards_stop_start_hell`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_discipline_cards_stop_start_hell.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for lineage, QA, and feature reuse. |
| `match_date` | Match date | Football developer: temporal slicing and partition alignment. |
| `home_team_id` | Home team identifier | Football developer: fixture orientation anchor. |
| `home_team_name` | Home team name | Football developer: readable fixture context. |
| `away_team_id` | Away team identifier | Football developer: fixture orientation anchor. |
| `away_team_name` | Away team name | Football developer: readable fixture context. |
| `home_score` | Home full-time goals | Football developer: result context around stop-start rhythm intensity. |
| `away_score` | Away full-time goals | Football developer: result context around stop-start rhythm intensity. |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: canonical side identity for `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Football developer: downstream team attribution key. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context. |
| `trigger_threshold_match_minutes` | Baseline minutes used for trigger normalization (`90`) | Football developer: explicit denominator contract for reproducibility. |
| `trigger_threshold_max_seconds_per_whistle` | Maximum allowed seconds per whistle (`90.0`) | Football developer: human-readable trigger boundary for explainability. |
| `trigger_threshold_min_combined_whistle_events` | Minimum combined whistle proxy events (`60`) | Football developer: explicit threshold provenance for QA and release checks. |
| `match_total_whistle_events` | Combined whistle proxy events (fouls + cards + offsides, both sides) | Football developer: core trigger intensity variable. |
| `match_total_whistle_events_above_threshold` | Event count above trigger threshold (`match_total_whistle_events - 60`) | Football developer: severity measure beyond binary activation. |
| `match_seconds_per_whistle` | Match-level average seconds per whistle proxy event | Football developer: direct pace interpretation of stop-start burden. |
| `match_total_fouls_committed` | Combined fouls in the match | Football developer: physical-contact component of whistle load. |
| `match_total_cards` | Combined yellow and red cards in the match | Football developer: sanction component of whistle load. |
| `match_total_yellow_cards` | Combined yellow cards in the match | Football developer: caution composition diagnostics. |
| `match_total_red_cards` | Combined red cards in the match | Football developer: dismissal-severity diagnostics. |
| `match_total_offsides` | Combined offsides in the match | Football developer: offside-line and timing component of interruptions. |
| `triggered_team_whistle_events` | Triggered-side whistle proxy events | Football developer: side-level contribution to stop-start tempo. |
| `opponent_whistle_events` | Opponent whistle proxy events | Football developer: bilateral contribution comparator. |
| `whistle_events_delta` | Triggered minus opponent whistle proxy events | Football developer: net interruption-load imbalance summary. |
| `triggered_team_whistle_share_pct` | Triggered-side share of match whistle proxy events (%) | Football developer: normalized side burden for cross-match comparisons. |
| `opponent_whistle_share_pct` | Opponent share of match whistle proxy events (%) | Football developer: symmetric normalized comparator. |
| `whistle_share_delta_pct` | Triggered minus opponent whistle share (percentage points) | Football developer: compact asymmetry metric in normalized units. |
| `triggered_team_seconds_per_whistle` | Triggered-side average seconds per whistle proxy event | Football developer: side-level interruption pace interpretation. |
| `opponent_seconds_per_whistle` | Opponent average seconds per whistle proxy event | Football developer: bilateral pace comparator. |
| `seconds_per_whistle_delta` | Triggered minus opponent seconds per whistle | Football developer: net pace differential in interruption rhythm. |
| `triggered_team_fouls_committed` | Triggered-side fouls committed | Football developer: contact-driven share of stop-start profile. |
| `opponent_fouls_committed` | Opponent fouls committed | Football developer: bilateral contact-pressure comparator. |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net physicality imbalance context. |
| `triggered_team_offsides` | Triggered-side offsides | Football developer: attacking timing/offside-trap burden on triggered side. |
| `opponent_offsides` | Opponent offsides | Football developer: bilateral offside-load comparator. |
| `offsides_delta` | Triggered minus opponent offsides | Football developer: net offside-driven interruption imbalance. |
| `triggered_team_yellow_cards` | Triggered-side yellow cards | Football developer: caution burden context. |
| `opponent_yellow_cards` | Opponent yellow cards | Football developer: bilateral caution comparator. |
| `yellow_cards_delta` | Triggered minus opponent yellow cards | Football developer: net caution asymmetry summary. |
| `triggered_team_red_cards` | Triggered-side red cards | Football developer: dismissal burden context. |
| `opponent_red_cards` | Opponent red cards | Football developer: bilateral dismissal comparator. |
| `red_cards_delta` | Triggered minus opponent red cards | Football developer: severe discipline asymmetry summary. |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: aggregate sanction load for triggered side. |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: bilateral aggregate sanction comparator. |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: compact discipline imbalance metric. |
| `triggered_team_cards_per_foul_pct` | Triggered-side cards per foul (%) | Football developer: sanction-conversion rate on triggered side. |
| `opponent_cards_per_foul_pct` | Opponent cards per foul (%) | Football developer: bilateral sanction-conversion comparator. |
| `cards_per_foul_delta_pct` | Triggered minus opponent cards-per-foul (percentage points) | Football developer: officiating/discipline asymmetry indicator. |
| `triggered_team_duels_won` | Triggered-side duels won | Football developer: physical contest context for interruption-heavy matches. |
| `opponent_duels_won` | Opponent duels won | Football developer: bilateral physicality comparator. |
| `triggered_team_tackles_won` | Triggered-side successful tackles | Football developer: defending-intensity context for stop-start states. |
| `opponent_tackles_won` | Opponent successful tackles | Football developer: bilateral defending-intensity comparator. |
| `triggered_team_interceptions` | Triggered-side interceptions | Football developer: anticipation/pressing context under high whistle tempo. |
| `opponent_interceptions` | Opponent interceptions | Football developer: bilateral anticipation comparator. |
| `triggered_team_clearances` | Triggered-side clearances | Football developer: pressure-release context in disrupted game flow. |
| `opponent_clearances` | Opponent clearances | Football developer: bilateral pressure-release comparator. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control-share context for interpreting whistle pressure. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with interruption tempo. |
