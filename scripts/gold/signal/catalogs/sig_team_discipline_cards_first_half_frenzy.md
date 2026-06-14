---
signal_id: sig_team_discipline_cards_first_half_frenzy
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "First-Half Card Frenzy"
trigger: "Team receives >= 4 cards before the half-time whistle."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_discipline_cards_first_half_frenzy
  sql: clickhouse/gold/dml/signals/team/sig_team_discipline_cards_first_half_frenzy.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_discipline_cards_first_half_frenzy

## Purpose

Flags team-match performances where a side accumulates four or more yellow/red card events before half-time, surfacing severe first-half discipline pressure before tactical resets are available.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_cards_first_half >= 4`
- Window definition:
  - card events in match minutes `1` to `45` inclusive from `silver.card`; minute `45` events retain `added_time` so first-half stoppage cards are ranked correctly.
- Card classification counts yellow/booked events and red-card events once per source event. Second-yellow dismissal style records are treated as red-card events for composition while still counting once toward the first-half total.
- Trigger is evaluated symmetrically for home and away teams, then enriched with full-match bilateral discipline, fouling, defensive-action, and possession context from `silver.period_stat` at `period = 'All'`.
- The signal preserves timing and score state at the triggered side's fourth first-half card to separate tactical fouling, pressure response, and genuine loss-of-control patterns.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_discipline_cards_first_half_frenzy.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_discipline_cards_first_half_frenzy`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_discipline_cards_first_half_frenzy
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
| `home_score` | Home full-time goals | Football developer: outcome context for first-half discipline interpretation |
| `away_score` | Away full-time goals | Football developer: outcome context for first-half discipline interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical orientation key for row identity |
| `triggered_team_id` | Triggered team identifier | Football developer: durable triggered-entity identity |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-entity context |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_min_cards_first_half` | Configured minimum first-half card threshold (`4`) | Football developer: explicit trigger provenance for reproducibility |
| `trigger_window_start_minute` | Start minute of trigger window (`1`) | Football developer: transparent temporal boundary for QA |
| `trigger_window_end_minute` | End minute of trigger window (`45`) | Football developer: transparent half-time boundary for QA |
| `triggered_team_cards_first_half` | Triggered-side card events before half-time | Football developer: core trigger intensity metric |
| `opponent_cards_first_half` | Opponent card events before half-time | Football developer: bilateral first-half discipline comparator |
| `cards_first_half_delta` | Triggered minus opponent first-half card events | Football developer: net first-half discipline imbalance |
| `triggered_team_cards_first_half_above_threshold` | Triggered first-half cards above the threshold | Football developer: severity ranking beyond binary activation |
| `triggered_team_yellow_cards_first_half` | Triggered-side yellow/booked card events before half-time | Football developer: caution composition behind the trigger |
| `opponent_yellow_cards_first_half` | Opponent yellow/booked card events before half-time | Football developer: bilateral caution composition comparator |
| `yellow_cards_first_half_delta` | Triggered minus opponent first-half yellow/booked cards | Football developer: net caution imbalance before half-time |
| `triggered_team_red_cards_first_half` | Triggered-side red-card events before half-time | Football developer: dismissal-severity context inside the trigger |
| `opponent_red_cards_first_half` | Opponent red-card events before half-time | Football developer: bilateral severe-discipline comparator |
| `red_cards_first_half_delta` | Triggered minus opponent first-half red cards | Football developer: net severe-discipline imbalance before half-time |
| `triggered_team_first_card_first_half_minute` | Minute of triggered side's first first-half card | Football developer: escalation-start timing context |
| `opponent_first_card_first_half_minute` | Minute of opponent's first first-half card | Football developer: bilateral escalation-start comparator |
| `triggered_team_fourth_card_first_half_minute` | Minute of triggered side's threshold-reaching fourth first-half card | Football developer: exact trigger timestamp for replay/debug |
| `triggered_team_fourth_card_first_half_added_time` | Added-time component at triggered side's fourth first-half card | Football developer: distinguishes normal-time from stoppage-time trigger timing |
| `triggered_team_fourth_card_first_half_effective_minute` | Fourth-card minute plus added-time component | Football developer: sortable trigger timing that keeps stoppage-time order |
| `opponent_fourth_card_first_half_minute` | Opponent fourth-card minute before half-time, when present | Football developer: bilateral threshold-proximity comparator |
| `opponent_fourth_card_first_half_added_time` | Added-time component for opponent fourth first-half card, when present | Football developer: symmetric stoppage-time timing context |
| `opponent_fourth_card_first_half_effective_minute` | Opponent fourth-card minute plus added-time component, when present | Football developer: sortable bilateral trigger timing comparator |
| `triggered_team_score_at_fourth_card` | Triggered team score at the fourth first-half card | Football developer: game-state context at trigger event |
| `opponent_score_at_fourth_card` | Opponent score at triggered side's fourth first-half card | Football developer: bilateral game-state comparator at trigger event |
| `score_margin_at_fourth_card` | Triggered minus opponent score at fourth first-half card | Football developer: pressure-state interpretation at trigger time |
| `triggered_team_first_half_cards_share_pct` | Triggered side's share of its full-match cards that occurred before half-time (%) | Football developer: concentration metric for front-loaded discipline |
| `opponent_first_half_cards_share_pct` | Opponent share of full-match cards before half-time (%) | Football developer: bilateral discipline-concentration comparator |
| `first_half_cards_share_delta_pct` | Triggered minus opponent first-half card-share percentage points | Football developer: normalized first-half discipline asymmetry |
| `triggered_team_yellow_cards_match` | Triggered-side yellow cards in full match | Football developer: full-match caution burden context |
| `opponent_yellow_cards_match` | Opponent yellow cards in full match | Football developer: bilateral caution comparator |
| `yellow_cards_match_delta` | Triggered minus opponent full-match yellow cards | Football developer: net caution imbalance beyond the trigger window |
| `triggered_team_red_cards_match` | Triggered-side red cards in full match | Football developer: severe-discipline escalation context |
| `opponent_red_cards_match` | Opponent red cards in full match | Football developer: bilateral severe-discipline comparator |
| `red_cards_match_delta` | Triggered minus opponent full-match red cards | Football developer: net dismissal imbalance beyond the trigger window |
| `triggered_team_total_cards_match` | Triggered-side total cards (yellow+red) in full match | Football developer: aggregate discipline load for downstream modeling |
| `opponent_total_cards_match` | Opponent total cards (yellow+red) in full match | Football developer: bilateral aggregate discipline comparator |
| `card_count_match_delta` | Triggered minus opponent total cards in full match | Football developer: net discipline-pressure differential |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Football developer: aggression load linked to early bookings |
| `opponent_fouls_committed` | Fouls committed by opponent side | Football developer: bilateral foul-load comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls committed | Football developer: net physical-intensity imbalance |
| `triggered_team_cards_per_foul_pct` | Triggered-side first-half cards per full-match foul (%) | Football developer: sanction-conversion context for early discipline |
| `opponent_cards_per_foul_pct` | Opponent first-half cards per full-match foul (%) | Football developer: bilateral sanction-conversion comparator |
| `cards_per_foul_delta_pct` | Triggered minus opponent first-half cards-per-foul percentage points | Football developer: compact officiating/discipline asymmetry metric |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: physical contest context for card accumulation |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral physical contest comparator |
| `triggered_team_tackles_won` | Tackles won by triggered side | Football developer: defensive-action profile around trigger |
| `opponent_tackles_won` | Tackles won by opponent side | Football developer: bilateral defensive-action comparator |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-management context before reset |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-management comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control/style context around the discipline spike |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with trigger |
