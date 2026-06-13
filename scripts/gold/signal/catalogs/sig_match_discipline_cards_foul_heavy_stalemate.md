---
signal_id: sig_match_discipline_cards_foul_heavy_stalemate
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Foul-Heavy Stalemate"
trigger: "Full-time score is 0-0 and combined match fouls are >= 30."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_discipline_cards_foul_heavy_stalemate
  sql: clickhouse/gold/signal/sig_match_discipline_cards_foul_heavy_stalemate.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_discipline_cards_foul_heavy_stalemate

## Purpose

Flags goalless draws that were still physically intense, surfacing 0-0 matches where foul volume reached a high-contact threshold.

## Tactical And Statistical Logic

- Trigger conditions:
  - `home_score = 0`
  - `away_score = 0`
  - `fouls_home + fouls_away >= 30` from `silver.period_stat` at `period = 'All'`.
- Emits one row per side (`triggered_side in {'home','away'}`) so downstream team-oriented models can consume bilateral context.
- Enrichment keeps foul allocation, cards-per-foul conversion, defensive action load, and possession balance to separate mutual trench warfare from one-sided aggression inside scoreless matches.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_discipline_cards_foul_heavy_stalemate.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_discipline_cards_foul_heavy_stalemate`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_discipline_cards_foul_heavy_stalemate
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for lineage, QA, and feature reuse. |
| `match_date` | Match date | Football developer: supports temporal slicing and partition-aware analysis. |
| `home_team_id` | Home team identifier | Football developer: fixture orientation anchor. |
| `home_team_name` | Home team name | Football developer: readable fixture context. |
| `away_team_id` | Away team identifier | Football developer: fixture orientation anchor. |
| `away_team_name` | Away team name | Football developer: readable fixture context. |
| `home_score` | Home full-time goals | Football developer: explicit confirmation of the 0-0 stalemate outcome. |
| `away_score` | Away full-time goals | Football developer: explicit confirmation of the 0-0 stalemate outcome. |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: canonical side key for `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Football developer: durable team identity for downstream joins. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered entity label. |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparator identity. |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context. |
| `trigger_threshold_target_home_score` | Configured home-score target for trigger (`0`) | Football developer: explicit trigger provenance for governance and audits. |
| `trigger_threshold_target_away_score` | Configured away-score target for trigger (`0`) | Football developer: explicit trigger provenance for governance and audits. |
| `trigger_threshold_min_combined_fouls` | Configured minimum combined fouls threshold (`30`) | Football developer: reproducible threshold context for release checks. |
| `match_total_fouls_committed` | Combined match fouls (home + away) | Football developer: core physical-intensity trigger variable. |
| `match_total_fouls_above_threshold` | Foul excess above trigger threshold (`match_total_fouls_committed - 30`) | Football developer: measures trigger severity beyond binary activation. |
| `triggered_team_fouls_committed` | Triggered-side fouls committed | Football developer: side-level contribution to match physicality. |
| `opponent_fouls_committed` | Opponent fouls committed | Football developer: bilateral physicality comparator. |
| `triggered_team_fouls_share_pct` | Triggered-side share of match fouls (%) | Football developer: normalized foul burden for the triggered side. |
| `opponent_fouls_share_pct` | Opponent share of match fouls (%) | Football developer: symmetric normalized comparator. |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net whistle-pressure imbalance context. |
| `match_total_cards` | Combined yellow and red cards | Football developer: sanction intensity context for the stalemate. |
| `match_total_yellow_cards` | Combined yellow cards | Football developer: caution composition context. |
| `match_total_red_cards` | Combined red cards | Football developer: dismissal composition context. |
| `triggered_team_yellow_cards` | Triggered-side yellow cards | Football developer: caution burden on triggered side. |
| `opponent_yellow_cards` | Opponent yellow cards | Football developer: bilateral caution comparator. |
| `triggered_team_red_cards` | Triggered-side red cards | Football developer: severe discipline burden on triggered side. |
| `opponent_red_cards` | Opponent red cards | Football developer: bilateral severe-discipline comparator. |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: aggregate side-level sanction load. |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: aggregate bilateral sanction comparator. |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: net discipline skew in foul-heavy stalemates. |
| `triggered_team_cards_per_foul_pct` | Triggered-side cards per foul (%) | Football developer: sanction conversion intensity for triggered side. |
| `opponent_cards_per_foul_pct` | Opponent cards per foul (%) | Football developer: sanction conversion comparator for officiating asymmetry reads. |
| `cards_per_foul_delta_pct` | Triggered minus opponent cards-per-foul (percentage points) | Football developer: compact discipline conversion imbalance metric. |
| `triggered_team_duels_won` | Triggered-side duels won | Football developer: physical contest load contextualizing foul volume. |
| `opponent_duels_won` | Opponent duels won | Football developer: bilateral physicality comparator. |
| `triggered_team_tackles_won` | Triggered-side successful tackles | Football developer: defensive engagement context in 0-0 trench matches. |
| `opponent_tackles_won` | Opponent successful tackles | Football developer: bilateral defensive engagement comparator. |
| `triggered_team_interceptions` | Triggered-side interceptions | Football developer: anticipation profile under heavy-contact stalemate conditions. |
| `opponent_interceptions` | Opponent interceptions | Football developer: bilateral anticipation comparator. |
| `triggered_team_clearances` | Triggered-side clearances | Football developer: pressure-management profile in scoreless attritional states. |
| `opponent_clearances` | Opponent clearances | Football developer: bilateral pressure-management comparator. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control-share context paired with physical stalemate behavior. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net territorial-control differential under the trigger. |
