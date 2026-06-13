---
signal_id: sig_match_discipline_cards_heated_derby_stats
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Heated Derby Stats"
trigger: "Combined match cards are >= 5 and combined match fouls are >= 30."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_discipline_cards_heated_derby_stats
  sql: clickhouse/gold/signal/sig_match_discipline_cards_heated_derby_stats.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_discipline_cards_heated_derby_stats

## Purpose

Flags matches with jointly high sanction volume and contact pressure, capturing derby-like game states where discipline and whistle intensity rise together.

## Tactical And Statistical Logic

- Trigger condition:
  - `(yellow_cards_home + yellow_cards_away + red_cards_home + red_cards_away) >= 5`
  - `(fouls_home + fouls_away) >= 30`
  - both from `silver.period_stat` at `period = 'All'`.
- Trigger is match-level and emitted as two side-oriented rows (`home` and `away`) for stable team-grain downstream consumption.
- Output combines card composition, foul share, sanctions-per-foul conversion, defensive workload, and possession context for bilateral interpretation.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_discipline_cards_heated_derby_stats.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_discipline_cards_heated_derby_stats`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_discipline_cards_heated_derby_stats
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable identity key for joins and QA. |
| `match_date` | Match date | Football developer: temporal slicing and partition compatibility. |
| `home_team_id` | Home team identifier | Football developer: fixture orientation anchor. |
| `home_team_name` | Home team name | Football developer: readable fixture context. |
| `away_team_id` | Away team identifier | Football developer: fixture orientation anchor. |
| `away_team_name` | Away team name | Football developer: readable fixture context. |
| `home_score` | Full-time home goals | Football developer: outcome context for heated matches. |
| `away_score` | Full-time away goals | Football developer: outcome context for heated matches. |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: canonical side identity for match-team grain. |
| `triggered_team_id` | Triggered-side team identifier | Football developer: team attribution key for downstream features. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context. |
| `trigger_threshold_min_combined_cards` | Configured minimum combined-card threshold (`5`) | Football developer: explicit trigger provenance for explainability and QA. |
| `trigger_threshold_min_combined_fouls` | Configured minimum combined-foul threshold (`30`) | Football developer: explicit trigger provenance for explainability and QA. |
| `match_total_cards` | Total cards in match (yellow + red) | Football developer: core sanction-intensity variable. |
| `match_total_cards_above_threshold` | Cards above threshold (`match_total_cards - 5`) | Football developer: trigger severity beyond binary activation. |
| `match_total_fouls_committed` | Total fouls in match (home + away) | Football developer: core contact-intensity variable. |
| `match_total_fouls_above_threshold` | Fouls above threshold (`match_total_fouls_committed - 30`) | Football developer: trigger severity beyond binary activation. |
| `match_total_yellow_cards` | Combined yellow cards in match | Football developer: sanction composition context. |
| `match_total_red_cards` | Combined red cards in match | Football developer: dismissal-severity context. |
| `triggered_team_yellow_cards` | Triggered-side yellow cards | Football developer: side-level caution burden. |
| `opponent_yellow_cards` | Opponent yellow cards | Football developer: bilateral caution comparator. |
| `yellow_cards_delta` | Triggered minus opponent yellow cards | Football developer: net caution imbalance. |
| `triggered_team_red_cards` | Triggered-side red cards | Football developer: side-level dismissal burden. |
| `opponent_red_cards` | Opponent red cards | Football developer: bilateral dismissal comparator. |
| `red_cards_delta` | Triggered minus opponent red cards | Football developer: net dismissal imbalance. |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: aggregate discipline load for triggered side. |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: bilateral aggregate card-load comparator. |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: compact disciplinary imbalance summary. |
| `triggered_team_cards_share_pct` | Triggered-side share of match cards (%) | Football developer: normalized sanction contribution in heated matches. |
| `opponent_cards_share_pct` | Opponent share of match cards (%) | Football developer: symmetric normalized comparator. |
| `cards_share_delta_pct` | Triggered minus opponent card share (percentage points) | Football developer: compact normalized asymmetry metric. |
| `triggered_team_fouls_committed` | Triggered-side fouls committed | Football developer: side-level contact contribution to match heat. |
| `opponent_fouls_committed` | Opponent fouls committed | Football developer: bilateral contact comparator. |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net whistle-pressure imbalance. |
| `triggered_team_fouls_share_pct` | Triggered-side share of match fouls (%) | Football developer: normalized side burden in high-contact matches. |
| `opponent_fouls_share_pct` | Opponent share of match fouls (%) | Football developer: symmetric normalized comparator. |
| `fouls_share_delta_pct` | Triggered minus opponent foul share (percentage points) | Football developer: compact normalized contact imbalance metric. |
| `triggered_team_cards_per_foul_pct` | Triggered-side cards per foul (%) | Football developer: sanction-conversion rate for triggered side. |
| `opponent_cards_per_foul_pct` | Opponent cards per foul (%) | Football developer: bilateral sanction-conversion comparator. |
| `cards_per_foul_delta_pct` | Triggered minus opponent cards-per-foul (percentage points) | Football developer: officiating/discipline asymmetry summary. |
| `triggered_team_duels_won` | Triggered-side duels won | Football developer: physical contest context. |
| `opponent_duels_won` | Opponent duels won | Football developer: bilateral physicality comparator. |
| `triggered_team_tackles_won` | Triggered-side successful tackles | Football developer: defending intensity profile in heated fixtures. |
| `opponent_tackles_won` | Opponent successful tackles | Football developer: bilateral defending-intensity comparator. |
| `triggered_team_interceptions` | Triggered-side interceptions | Football developer: anticipation/pressing context. |
| `opponent_interceptions` | Opponent interceptions | Football developer: bilateral anticipation comparator. |
| `triggered_team_clearances` | Triggered-side clearances | Football developer: pressure-release profile in high-friction phases. |
| `opponent_clearances` | Opponent clearances | Football developer: bilateral pressure-release comparator. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control-share context for interpretation. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with discipline intensity. |
