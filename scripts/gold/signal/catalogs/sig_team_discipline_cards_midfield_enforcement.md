---
signal_id: sig_team_discipline_cards_midfield_enforcement
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Midfield Enforcement"
trigger: "Team's central midfielders combine for >= 10 fouls."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_discipline_cards_midfield_enforcement
  sql: clickhouse/gold/signal/sig_team_discipline_cards_midfield_enforcement.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_discipline_cards_midfield_enforcement

## Purpose

Flags match-team cases where the central-midfield unit drives a high share of the team's foul volume, surfacing enforcement-heavy midfield behavior.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_central_midfielder_fouls_committed >= 10`
- Central midfielders are identified via `silver.match_personnel` where `usual_playing_position_id = 2`.
- Midfielder foul contribution is sourced from `silver.player_match_stat.fouls_committed` and aggregated by side.
- Trigger is evaluated symmetrically for `home` and `away`, then enriched with bilateral card, foul, defensive-action, and possession context.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_discipline_cards_midfield_enforcement.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_discipline_cards_midfield_enforcement`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_discipline_cards_midfield_enforcement
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key and release QA anchor |
| `match_date` | Match date | Football developer: temporal analysis and partition checks |
| `home_team_id` | Home team identifier | Football developer: fixed fixture orientation |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: fixed fixture orientation |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: scoreline context |
| `away_score` | Away full-time goals | Football developer: scoreline context |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical row identity orientation |
| `triggered_team_id` | Triggered team identifier | Football developer: triggered-entity attribution |
| `triggered_team_name` | Triggered team name | Football developer: human-readable triggered context |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key |
| `opponent_team_name` | Opponent team name | Football developer: human-readable bilateral context |
| `trigger_threshold_min_central_midfielder_fouls_committed` | Trigger foul threshold for central midfielders (`10`) | Football developer: explicit trigger provenance |
| `triggered_team_central_midfielders` | Count of triggered-side central midfielders | Football developer: denominator for unit-level aggregation |
| `opponent_central_midfielders` | Count of opponent central midfielders | Football developer: bilateral denominator comparator |
| `central_midfielders_delta` | Triggered minus opponent central-midfielder count | Football developer: lineup-shape imbalance context |
| `triggered_team_central_midfielders_with_fouls` | Triggered-side central midfielders with at least one foul | Football developer: distribution of foul burden inside midfield unit |
| `opponent_central_midfielders_with_fouls` | Opponent central midfielders with at least one foul | Football developer: bilateral distribution comparator |
| `central_midfielders_with_fouls_delta` | Triggered minus opponent central midfielders with fouls | Football developer: net midfield foul-spread imbalance |
| `triggered_team_central_midfielder_fouls_committed` | Total fouls committed by triggered-side central midfielders | Football developer: core trigger numerator |
| `opponent_central_midfielder_fouls_committed` | Total fouls committed by opponent central midfielders | Football developer: bilateral midfield foul comparator |
| `central_midfielder_fouls_committed_delta` | Triggered minus opponent central-midfielder fouls | Football developer: net midfield enforcement differential |
| `triggered_team_central_midfielder_fouls_above_threshold` | Triggered-side central-midfielder fouls above threshold (`fouls - 10`) | Football developer: trigger severity beyond binary hit |
| `triggered_team_central_midfielder_fouls_share_of_team_fouls_pct` | Share of triggered team fouls committed by central midfielders (%) | Football developer: role concentration of team aggression |
| `opponent_central_midfielder_fouls_share_of_team_fouls_pct` | Share of opponent team fouls committed by opponent central midfielders (%) | Football developer: bilateral role-concentration comparator |
| `central_midfielder_fouls_share_of_team_fouls_delta_pct` | Triggered minus opponent central-midfielder foul share (percentage points) | Football developer: compact midfield-role asymmetry metric |
| `triggered_team_yellow_cards` | Triggered-side yellow cards | Football developer: discipline outcome context |
| `opponent_yellow_cards` | Opponent yellow cards | Football developer: bilateral discipline comparator |
| `triggered_team_red_cards` | Triggered-side red cards | Football developer: escalation context |
| `opponent_red_cards` | Opponent red cards | Football developer: bilateral escalation comparator |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: aggregate card burden |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: bilateral aggregate card comparator |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: net card-pressure imbalance |
| `triggered_team_fouls_committed` | Triggered-side fouls committed | Football developer: team-level aggression context |
| `opponent_fouls_committed` | Opponent fouls committed | Football developer: bilateral foul-volume comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net foul-pressure differential |
| `triggered_team_duels_won` | Triggered-side duels won | Football developer: physical contest context |
| `opponent_duels_won` | Opponent duels won | Football developer: bilateral physicality comparator |
| `triggered_team_tackles_won` | Triggered-side tackles won | Football developer: defensive-action context |
| `opponent_tackles_won` | Opponent tackles won | Football developer: bilateral defensive-action comparator |
| `triggered_team_interceptions` | Triggered-side interceptions | Football developer: defensive anticipation context |
| `opponent_interceptions` | Opponent interceptions | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Triggered-side clearances | Football developer: pressure-management context |
| `opponent_clearances` | Opponent clearances | Football developer: bilateral pressure-management comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control/style context |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with discipline load |
