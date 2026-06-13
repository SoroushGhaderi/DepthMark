---
signal_id: sig_match_discipline_cards_physical_showdown
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Match Discipline Cards Physical Showdown"
trigger: "Every starter defender on a side receives at least one card (minimum 3 starter defenders)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_discipline_cards_physical_showdown
  sql: clickhouse/gold/signal/sig_match_discipline_cards_physical_showdown.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_discipline_cards_physical_showdown

## Purpose

Flags match-team cases where card pressure is fully distributed across a side's starting defensive line, surfacing physically intense defensive performances.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_starting_defenders_carded = triggered_team_starting_defenders`
  - `triggered_team_starting_defenders >= 3`
- Starter defenders are sourced from `silver.match_personnel` with `role = 'starter'` and `usual_playing_position_id = 1`.
- Card events are sourced from `silver.card` with yellow/red card metadata and mapped to starter defenders by `match_id`, `team_side`, and `player_id`.
- Trigger is evaluated symmetrically for `home` and `away`, then enriched with bilateral discipline, foul load, defensive actions, and possession context.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_discipline_cards_physical_showdown.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_discipline_cards_physical_showdown`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_discipline_cards_physical_showdown
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key and QA anchor. |
| `match_date` | Match date | Football developer: supports temporal slicing and partition checks. |
| `home_team_id` | Home team identifier | Football developer: fixed fixture orientation key. |
| `home_team_name` | Home team name | Football developer: readable fixture context. |
| `away_team_id` | Away team identifier | Football developer: fixed fixture orientation key. |
| `away_team_name` | Away team name | Football developer: readable fixture context. |
| `home_score` | Home full-time goals | Football developer: scoreline context for discipline interpretation. |
| `away_score` | Away full-time goals | Football developer: scoreline context for discipline interpretation. |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical row orientation for match-team grain. |
| `triggered_team_id` | Triggered-side team identifier | Football developer: durable triggered-entity key. |
| `triggered_team_name` | Triggered-side team name | Football developer: human-readable triggered context. |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Football developer: human-readable bilateral context. |
| `trigger_threshold_min_starting_defenders` | Minimum starter defenders required for trigger evaluation (`3`) | Football developer: explicit eligibility constraint for reliability. |
| `trigger_threshold_min_cards_per_starting_defender` | Required minimum cards per starter defender (`1`) | Football developer: explicit per-player trigger rule. |
| `triggered_team_starting_defenders` | Count of triggered-side starter defenders | Football developer: trigger denominator and formation context. |
| `opponent_starting_defenders` | Count of opponent starter defenders | Football developer: bilateral denominator comparator. |
| `starting_defenders_delta` | Triggered minus opponent starter-defender count | Football developer: lineup-structure imbalance context. |
| `triggered_team_starting_defenders_carded` | Triggered-side starter defenders with at least one card | Football developer: core trigger numerator. |
| `opponent_starting_defenders_carded` | Opponent starter defenders with at least one card | Football developer: bilateral defensive-line card spread comparator. |
| `starting_defenders_carded_delta` | Triggered minus opponent carded starter defenders | Football developer: net defensive-line discipline spread differential. |
| `triggered_team_starting_defenders_carded_share_pct` | Share of triggered-side starter defenders who were carded (%) | Football developer: normalized trigger-severity measure. |
| `opponent_starting_defenders_carded_share_pct` | Share of opponent starter defenders who were carded (%) | Football developer: bilateral normalized comparator. |
| `triggered_team_cards_on_starting_defenders` | Total cards shown to triggered-side starter defenders | Football developer: card-load concentration on the back line. |
| `opponent_cards_on_starting_defenders` | Total cards shown to opponent starter defenders | Football developer: bilateral card-load comparator on defensive units. |
| `cards_on_starting_defenders_delta` | Triggered minus opponent cards on starter defenders | Football developer: net defensive-line card burden differential. |
| `triggered_team_first_starting_defender_card_minute` | Earliest card minute among triggered-side starter defenders | Football developer: onset timing of defensive-line discipline stress. |
| `opponent_first_starting_defender_card_minute` | Earliest card minute among opponent starter defenders | Football developer: bilateral onset timing comparator. |
| `triggered_team_last_starting_defender_card_minute` | Latest card minute among triggered-side starter defenders | Football developer: persistence/spread timing of defensive-line cards. |
| `opponent_last_starting_defender_card_minute` | Latest card minute among opponent starter defenders | Football developer: bilateral persistence timing comparator. |
| `triggered_team_yellow_cards` | Triggered-side total yellow cards (match) | Football developer: full-match caution context around the trigger. |
| `opponent_yellow_cards` | Opponent total yellow cards (match) | Football developer: bilateral caution context. |
| `triggered_team_red_cards` | Triggered-side total red cards (match) | Football developer: dismissal escalation context. |
| `opponent_red_cards` | Opponent total red cards (match) | Football developer: bilateral dismissal comparator. |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: aggregate discipline burden around trigger activation. |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: bilateral aggregate discipline comparator. |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: net disciplinary imbalance measure. |
| `triggered_team_fouls_committed` | Triggered-side fouls committed | Football developer: aggression context behind defensive-line cards. |
| `opponent_fouls_committed` | Opponent fouls committed | Football developer: bilateral aggression comparator. |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net foul-pressure differential. |
| `triggered_team_duels_won` | Triggered-side duels won | Football developer: physical contest context. |
| `opponent_duels_won` | Opponent duels won | Football developer: bilateral physicality comparator. |
| `triggered_team_tackles_won` | Triggered-side tackles won | Football developer: defensive-action context tied to card load. |
| `opponent_tackles_won` | Opponent tackles won | Football developer: bilateral defensive-action comparator. |
| `triggered_team_interceptions` | Triggered-side interceptions | Football developer: defensive anticipation context. |
| `opponent_interceptions` | Opponent interceptions | Football developer: bilateral anticipation comparator. |
| `triggered_team_clearances` | Triggered-side clearances | Football developer: pressure-management context. |
| `opponent_clearances` | Opponent clearances | Football developer: bilateral pressure-management comparator. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control-style context for interpreting discipline load. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: compact control differential paired with card-distribution signal. |
