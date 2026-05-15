---
signal_id: sig_match_discipline_cards_chaos_90_plus
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "90+ Added-Time Red Card Chaos"
trigger: "At least two red cards are issued in 90+ added time."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_match_discipline_cards_chaos_90_plus
  sql: clickhouse/gold/signal/sig_match_discipline_cards_chaos_90_plus.sql
  runner: scripts/gold/signal/runners/sig_match_discipline_cards_chaos_90_plus.py
---
# sig_match_discipline_cards_chaos_90_plus

## Purpose

Flags match-team rows for fixtures where late-game control collapses into severe disciplinary chaos, defined by two or more red cards in 90+ added time.

## Tactical And Statistical Logic

- Trigger condition:
  - red-card events from `silver.card` where `card_minute >= 90` and `added_time > 0`, with combined match count `>= 2`.
- Trigger is match-level and emits two side-oriented rows (`home` and `away`) for stable `match_team` downstream consumption.
- Output preserves late-red timing, bilateral card pressure, and defensive/control context to separate balanced late chaos from one-sided meltdowns.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_discipline_cards_chaos_90_plus.sql`
- Runner: `scripts/gold/signal/runners/sig_match_discipline_cards_chaos_90_plus.py`
- Target table: `gold.sig_match_discipline_cards_chaos_90_plus`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_discipline_cards_chaos_90_plus.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins, QA, and feature lineage. |
| `match_date` | Match date | Football developer: supports temporal slicing and partition alignment. |
| `home_team_id` | Home team identifier | Football developer: fixed fixture orientation context. |
| `home_team_name` | Home team name | Football developer: readable fixture context. |
| `away_team_id` | Away team identifier | Football developer: fixed fixture orientation context. |
| `away_team_name` | Away team name | Football developer: readable fixture context. |
| `home_score` | Full-time home goals | Football developer: outcome context for late-discipline collapse interpretation. |
| `away_score` | Full-time away goals | Football developer: outcome context for late-discipline collapse interpretation. |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: canonical side identity for `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Football developer: downstream feature ownership key. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison anchor. |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context. |
| `trigger_threshold_min_added_time_red_cards` | Minimum combined 90+ added-time red-card threshold (`2`) | Football developer: explicit trigger provenance for reproducibility and QA. |
| `trigger_threshold_window_base_minute` | Base minute of the trigger window (`90`) | Football developer: documents temporal boundary used by trigger logic. |
| `match_added_time_red_cards` | Combined red cards issued in 90+ added time | Football developer: late-chaos intensity signal core metric. |
| `match_added_time_red_cards_above_threshold` | Combined 90+ added-time red cards minus threshold | Football developer: severity gradient beyond trigger floor. |
| `home_added_time_red_cards` | Home-side red cards in 90+ added time | Football developer: fixture-oriented attribution of late red-card events. |
| `away_added_time_red_cards` | Away-side red cards in 90+ added time | Football developer: fixture-oriented attribution of late red-card events. |
| `triggered_team_added_time_red_cards` | Triggered-side red cards in 90+ added time | Football developer: side-level late-dismissal burden. |
| `opponent_added_time_red_cards` | Opponent red cards in 90+ added time | Football developer: bilateral late-dismissal comparator. |
| `added_time_red_cards_delta` | Triggered minus opponent 90+ added-time red cards | Football developer: net late-dismissal imbalance. |
| `triggered_team_added_time_red_cards_share_pct` | Triggered-side share of combined 90+ added-time red cards (%) | Football developer: ownership split of late-chaos events. |
| `opponent_added_time_red_cards_share_pct` | Opponent share of combined 90+ added-time red cards (%) | Football developer: bilateral ownership comparator. |
| `added_time_red_cards_share_delta_pct` | Triggered minus opponent share of combined 90+ added-time red cards (percentage points) | Football developer: compact asymmetry metric for late red-card concentration. |
| `triggered_team_first_added_time_red_minute` | Triggered-side first 90+ added-time red card base minute | Football developer: onset timing for late discipline collapse. |
| `opponent_first_added_time_red_minute` | Opponent first 90+ added-time red card base minute | Football developer: bilateral onset timing comparator. |
| `triggered_team_first_added_time_red_added_time` | Triggered-side added-time component of first 90+ red card | Football developer: stoppage-depth context for first triggered-side dismissal. |
| `opponent_first_added_time_red_added_time` | Opponent added-time component of first 90+ red card | Football developer: bilateral stoppage-depth comparator. |
| `triggered_team_first_added_time_red_effective_minute` | Triggered-side first 90+ red card effective minute (`minute + added_time`) | Football developer: normalized timing for sequence analysis. |
| `opponent_first_added_time_red_effective_minute` | Opponent first 90+ red card effective minute (`minute + added_time`) | Football developer: bilateral normalized timing comparator. |
| `match_total_red_cards` | Total match red cards (all phases) | Football developer: full-match dismissal context around 90+ chaos. |
| `match_total_yellow_cards` | Total match yellow cards (all phases) | Football developer: caution-volume context paired with late red spikes. |
| `match_total_cards` | Total match cards (yellow + red) | Football developer: aggregate disciplinary load context. |
| `triggered_team_red_cards` | Triggered-side total red cards (match) | Football developer: side-level dismissal burden across full match. |
| `opponent_red_cards` | Opponent total red cards (match) | Football developer: bilateral dismissal comparator across full match. |
| `red_cards_delta` | Triggered minus opponent total red cards (match) | Football developer: net severe-discipline imbalance in overall match context. |
| `triggered_team_yellow_cards` | Triggered-side total yellow cards (match) | Football developer: side-level caution burden context. |
| `opponent_yellow_cards` | Opponent total yellow cards (match) | Football developer: bilateral caution comparator. |
| `yellow_cards_delta` | Triggered minus opponent total yellow cards (match) | Football developer: net caution imbalance around late red chaos. |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: aggregate sanction load for triggered side. |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: bilateral aggregate sanction comparator. |
| `card_count_delta` | Triggered minus opponent total cards (match) | Football developer: net disciplinary-pressure differential. |
| `triggered_team_fouls_committed` | Triggered-side fouls committed | Football developer: aggression baseline paired with sanction outcomes. |
| `opponent_fouls_committed` | Opponent fouls committed | Football developer: bilateral aggression comparator. |
| `fouls_committed_delta` | Triggered minus opponent fouls committed | Football developer: net foul-pressure differential. |
| `triggered_team_cards_per_foul_pct` | Triggered-side cards per foul (%) | Football developer: sanction-conversion efficiency profile. |
| `opponent_cards_per_foul_pct` | Opponent cards per foul (%) | Football developer: bilateral sanction-conversion comparator. |
| `cards_per_foul_delta_pct` | Triggered minus opponent cards-per-foul (percentage points) | Football developer: compact officiating/discipline asymmetry signal. |
| `triggered_team_duels_won` | Triggered-side duels won | Football developer: physicality context around late-dismissal events. |
| `opponent_duels_won` | Opponent duels won | Football developer: bilateral physicality comparator. |
| `triggered_team_tackles_won` | Triggered-side successful tackles | Football developer: defending-intensity context for triggered side. |
| `opponent_tackles_won` | Opponent successful tackles | Football developer: bilateral defending-intensity comparator. |
| `triggered_team_interceptions` | Triggered-side interceptions | Football developer: defensive anticipation context in late chaotic phases. |
| `opponent_interceptions` | Opponent interceptions | Football developer: bilateral anticipation comparator. |
| `triggered_team_clearances` | Triggered-side clearances | Football developer: pressure-release profile in chaotic closing states. |
| `opponent_clearances` | Opponent clearances | Football developer: bilateral pressure-release comparator. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control-style context around late disciplinary chaos. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with 90+ chaos signal. |
