---
signal_id: sig_match_discipline_cards_unpunished_aggression
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Unpunished Aggression"
trigger: "Combined match xG is >= 3.0 while combined match fouls are >= 28."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_discipline_cards_unpunished_aggression
  sql: clickhouse/gold/dml/signals/match/sig_match_discipline_cards_unpunished_aggression.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_discipline_cards_unpunished_aggression

## Purpose

Flags high-event matches where chance quality is strong and whistle volume is high at the same time, surfacing open but physical contests with potential under-penalized contact patterns.

## Tactical And Statistical Logic

- Trigger condition:
  - `(expected_goals_home + expected_goals_away) >= 3.0`
  - `(fouls_home + fouls_away) >= 28`
  - both measured from `silver.period_stat` at `period = 'All'`.
- Trigger is match-level and emitted as two side-oriented rows (`home` and `away`) for stable team-grain downstream use.
- Output preserves bilateral xG, foul-pressure, sanction-conversion, shooting, defensive-workload, and possession context for tactical interpretation.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_discipline_cards_unpunished_aggression.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_discipline_cards_unpunished_aggression`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_discipline_cards_unpunished_aggression
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
| `home_score` | Full-time home goals | Football developer: outcome context for physical/open matches. |
| `away_score` | Full-time away goals | Football developer: outcome context for physical/open matches. |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: canonical side identity for match-team grain. |
| `triggered_team_id` | Triggered-side team identifier | Football developer: team attribution key for downstream features. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context. |
| `trigger_threshold_min_match_total_xg` | Configured minimum combined xG threshold (`3.0`) | Football developer: explicit trigger provenance for explainability and QA. |
| `trigger_threshold_min_combined_fouls` | Configured minimum combined-fouls threshold (`28`) | Football developer: explicit trigger provenance for explainability and QA. |
| `match_total_xg` | Combined match expected goals | Football developer: core open-game intensity variable. |
| `match_total_xg_above_threshold` | Combined xG above threshold (`match_total_xg - 3.0`) | Football developer: trigger severity beyond binary activation. |
| `match_total_fouls_committed` | Combined match fouls | Football developer: core physical-contact intensity variable. |
| `match_total_fouls_above_threshold` | Combined fouls above threshold (`match_total_fouls_committed - 28`) | Football developer: trigger severity beyond binary activation. |
| `match_total_cards` | Combined match cards (yellow + red) | Football developer: sanction load context against foul volume. |
| `match_total_yellow_cards` | Combined yellow cards | Football developer: caution-level sanction composition. |
| `match_total_red_cards` | Combined red cards | Football developer: dismissal-level sanction composition. |
| `match_total_cards_per_foul_pct` | Match cards per foul (%) | Football developer: whistle-to-sanction conversion context. |
| `triggered_team_xg` | Triggered-side xG | Football developer: side-specific attacking threat. |
| `opponent_xg` | Opponent xG | Football developer: bilateral attacking comparator. |
| `xg_delta` | Triggered minus opponent xG | Football developer: net chance-quality imbalance. |
| `triggered_team_fouls_committed` | Triggered-side fouls committed | Football developer: side-level physicality contribution. |
| `opponent_fouls_committed` | Opponent fouls committed | Football developer: bilateral physicality comparator. |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net contact-pressure imbalance. |
| `triggered_team_fouls_share_pct` | Triggered-side share of match fouls (%) | Football developer: normalized side burden in physical matches. |
| `opponent_fouls_share_pct` | Opponent share of match fouls (%) | Football developer: symmetric normalized comparator. |
| `fouls_share_delta_pct` | Triggered minus opponent foul share (percentage points) | Football developer: compact normalized contact imbalance metric. |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: side sanction burden relative to fouls. |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: bilateral sanction comparator. |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: compact disciplinary asymmetry summary. |
| `triggered_team_cards_per_foul_pct` | Triggered-side cards per foul (%) | Football developer: side sanction-conversion rate. |
| `opponent_cards_per_foul_pct` | Opponent cards per foul (%) | Football developer: bilateral sanction-conversion comparator. |
| `cards_per_foul_delta_pct` | Triggered minus opponent cards-per-foul (percentage points) | Football developer: officiating/discipline asymmetry indicator. |
| `triggered_team_total_shots` | Triggered-side shot attempts | Football developer: shot-volume context for open-game interpretation. |
| `opponent_total_shots` | Opponent shot attempts | Football developer: bilateral shot-volume comparator. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Football developer: execution-quality context for chance creation. |
| `opponent_shots_on_target` | Opponent shots on target | Football developer: bilateral execution comparator. |
| `triggered_team_duels_won` | Triggered-side duels won | Football developer: physical contest context in aggressive matches. |
| `opponent_duels_won` | Opponent duels won | Football developer: bilateral physicality comparator. |
| `triggered_team_tackles_won` | Triggered-side successful tackles | Football developer: defending-intensity profile. |
| `opponent_tackles_won` | Opponent successful tackles | Football developer: bilateral defending-intensity comparator. |
| `triggered_team_interceptions` | Triggered-side interceptions | Football developer: anticipation/pressing context. |
| `opponent_interceptions` | Opponent interceptions | Football developer: bilateral anticipation comparator. |
| `triggered_team_clearances` | Triggered-side clearances | Football developer: pressure-release context during open phases. |
| `opponent_clearances` | Opponent clearances | Football developer: bilateral pressure-release comparator. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control-share context for tactical interpretation. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with xG and foul intensity. |
