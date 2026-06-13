---
signal_id: sig_match_discipline_cards_blood_and_thunder
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Blood And Thunder"
trigger: "Combined match duels won are >= 50 and combined match fouls are >= 25."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_discipline_cards_blood_and_thunder
  sql: clickhouse/gold/signal/sig_match_discipline_cards_blood_and_thunder.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_discipline_cards_blood_and_thunder

## Purpose

Flags matches with sustained physical contest volume and elevated whistle pressure, capturing blood-and-thunder game states where duel intensity and fouling load rise together.

## Tactical And Statistical Logic

- Trigger condition:
  - `(duels_won_home + duels_won_away) >= 50`
  - `(fouls_home + fouls_away) >= 25`
  - both from `silver.period_stat` at `period = 'All'`.
- Trigger is match-level and emitted as two side-oriented rows (`home` and `away`) so downstream team pipelines can consume bilateral context consistently.
- Signal output keeps duel/foul share structure, card burden, sanctions-per-foul conversion, defensive action profile, and possession context for interpretability.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_discipline_cards_blood_and_thunder.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_discipline_cards_blood_and_thunder`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_discipline_cards_blood_and_thunder
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable identity key for joins, QA, and lineage. |
| `match_date` | Match date | Football developer: temporal slicing and partition compatibility. |
| `home_team_id` | Home team identifier | Football developer: fixture orientation anchor. |
| `home_team_name` | Home team name | Football developer: readable fixture context. |
| `away_team_id` | Away team identifier | Football developer: fixture orientation anchor. |
| `away_team_name` | Away team name | Football developer: readable fixture context. |
| `home_score` | Full-time home goals | Football developer: outcome context for physical-match interpretation. |
| `away_score` | Full-time away goals | Football developer: outcome context for physical-match interpretation. |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: canonical side identity for match-team grain. |
| `triggered_team_id` | Triggered-side team identifier | Football developer: downstream team attribution key. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context. |
| `trigger_threshold_min_combined_duels_won` | Configured minimum combined-duels-won threshold (`50`) | Football developer: explicit trigger provenance for reproducibility and QA. |
| `trigger_threshold_min_combined_fouls` | Configured minimum combined-fouls threshold (`25`) | Football developer: explicit trigger provenance for reproducibility and QA. |
| `match_total_duels_won` | Total duels won in match (home + away) | Football developer: core physical-intensity trigger variable in this signal. |
| `match_total_duels_won_above_threshold` | Duels won above threshold (`match_total_duels_won - 50`) | Football developer: trigger severity beyond binary activation. |
| `match_total_fouls_committed` | Total fouls in match (home + away) | Football developer: contact-pressure trigger variable. |
| `match_total_fouls_above_threshold` | Fouls above threshold (`match_total_fouls_committed - 25`) | Football developer: trigger severity beyond binary activation. |
| `triggered_team_duels_won` | Triggered-side duels won | Football developer: side-level physical contribution to match intensity. |
| `opponent_duels_won` | Opponent duels won | Football developer: bilateral physicality comparator. |
| `duels_won_delta` | Triggered minus opponent duels won | Football developer: net duel-control imbalance. |
| `triggered_team_duels_won_share_pct` | Triggered-side share of match duels won (%) | Football developer: normalized duel burden/contribution. |
| `opponent_duels_won_share_pct` | Opponent share of match duels won (%) | Football developer: symmetric normalized comparator. |
| `duels_won_share_delta_pct` | Triggered minus opponent duel share (percentage points) | Football developer: compact normalized duel asymmetry metric. |
| `triggered_team_fouls_committed` | Triggered-side fouls committed | Football developer: side-level foul contribution to trigger. |
| `opponent_fouls_committed` | Opponent fouls committed | Football developer: bilateral foul comparator. |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net whistle-pressure imbalance. |
| `triggered_team_fouls_share_pct` | Triggered-side share of match fouls (%) | Football developer: normalized foul burden in high-intensity matches. |
| `opponent_fouls_share_pct` | Opponent share of match fouls (%) | Football developer: symmetric normalized comparator. |
| `fouls_share_delta_pct` | Triggered minus opponent foul share (percentage points) | Football developer: compact normalized contact imbalance metric. |
| `match_total_cards` | Total cards in match (yellow + red) | Football developer: sanction intensity context around physical load. |
| `match_total_yellow_cards` | Total yellow cards in match | Football developer: caution-level sanction composition context. |
| `match_total_red_cards` | Total red cards in match | Football developer: severe-discipline composition context. |
| `triggered_team_yellow_cards` | Triggered-side yellow cards | Football developer: side-level caution burden. |
| `opponent_yellow_cards` | Opponent yellow cards | Football developer: bilateral caution comparator. |
| `yellow_cards_delta` | Triggered minus opponent yellow cards | Football developer: net caution imbalance. |
| `triggered_team_red_cards` | Triggered-side red cards | Football developer: side-level severe-discipline burden. |
| `opponent_red_cards` | Opponent red cards | Football developer: bilateral severe-discipline comparator. |
| `red_cards_delta` | Triggered minus opponent red cards | Football developer: net dismissal imbalance. |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: aggregate discipline load for triggered side. |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: bilateral aggregate discipline comparator. |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: compact disciplinary imbalance summary. |
| `triggered_team_cards_per_foul_pct` | Triggered-side cards per foul (%) | Football developer: sanction-conversion profile under high-contact conditions. |
| `opponent_cards_per_foul_pct` | Opponent cards per foul (%) | Football developer: bilateral sanction-conversion comparator. |
| `cards_per_foul_delta_pct` | Triggered minus opponent cards-per-foul (percentage points) | Football developer: officiating/discipline asymmetry summary. |
| `triggered_team_tackles_won` | Triggered-side successful tackles | Football developer: defensive action intensity context. |
| `opponent_tackles_won` | Opponent successful tackles | Football developer: bilateral defensive-action comparator. |
| `triggered_team_interceptions` | Triggered-side interceptions | Football developer: anticipation/pressing context in physical fixtures. |
| `opponent_interceptions` | Opponent interceptions | Football developer: bilateral anticipation comparator. |
| `triggered_team_clearances` | Triggered-side clearances | Football developer: pressure-release context under sustained contest. |
| `opponent_clearances` | Opponent clearances | Football developer: bilateral pressure-release comparator. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control-share context for intensity interpretation. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with physical intensity. |
