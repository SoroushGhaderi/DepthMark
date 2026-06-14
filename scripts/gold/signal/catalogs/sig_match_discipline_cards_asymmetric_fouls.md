---
signal_id: sig_match_discipline_cards_asymmetric_fouls
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Match Discipline Cards Asymmetric Fouls"
trigger: "One team has >= 70% of total match fouls."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_discipline_cards_asymmetric_fouls
  sql: clickhouse/gold/dml/signals/match/sig_match_discipline_cards_asymmetric_fouls.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_discipline_cards_asymmetric_fouls

## Purpose

Flags matches where foul burden is highly concentrated on one side (at least 70% of all match fouls), surfacing directional discipline pressure and asymmetry.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_fouls_share_pct >= 70`
- Foul counts are sourced from `silver.period_stat` at `period = 'All'`.
- Trigger orientation (`triggered_side`) is assigned to the side with higher foul count, then filtered by the 70% threshold.
- Output keeps bilateral discipline, card-conversion, defensive workload, passing quality, and possession context for interpretation.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_discipline_cards_asymmetric_fouls.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_discipline_cards_asymmetric_fouls`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_discipline_cards_asymmetric_fouls
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for QA and downstream features. |
| `match_date` | Match date | Football developer: temporal slicing and partition alignment. |
| `home_team_id` | Home team identifier | Football developer: fixture orientation anchor. |
| `home_team_name` | Home team name | Football developer: readable fixture context. |
| `away_team_id` | Away team identifier | Football developer: fixture orientation anchor. |
| `away_team_name` | Away team name | Football developer: readable fixture context. |
| `home_score` | Home full-time goals | Football developer: scoreline context for discipline asymmetry interpretation. |
| `away_score` | Away full-time goals | Football developer: scoreline context for discipline asymmetry interpretation. |
| `triggered_side` | Side that satisfies foul-asymmetry trigger (`home` or `away`) | Football developer: canonical row identity orientation. |
| `triggered_team_id` | Triggered-side team identifier | Football developer: durable triggered entity key. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered attribution. |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context. |
| `trigger_threshold_min_triggered_team_fouls_share_pct` | Configured minimum triggered-side foul share threshold (`70`) | Football developer: explicit trigger governance and provenance. |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Football developer: core trigger numerator. |
| `opponent_fouls_committed` | Fouls committed by opponent side | Football developer: bilateral trigger denominator component. |
| `match_total_fouls_committed` | Combined fouls in match | Football developer: trigger denominator and match-level intensity anchor. |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net contact imbalance magnitude. |
| `triggered_team_fouls_share_pct` | Triggered-side share of total match fouls (%) | Football developer: core trigger metric. |
| `opponent_fouls_share_pct` | Opponent share of total match fouls (%) | Football developer: symmetric normalized comparator. |
| `fouls_share_delta_pct` | Triggered minus opponent foul share (percentage points) | Football developer: compact normalized asymmetry measure. |
| `triggered_team_fouls_share_above_threshold_pct` | Triggered foul-share excess above threshold (`triggered_team_fouls_share_pct - 70`) | Football developer: trigger intensity grading beyond binary qualification. |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: sanction load attached to foul-heavy side. |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: bilateral sanction comparator. |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: net disciplinary imbalance detail. |
| `match_total_cards` | Combined match cards (yellow + red) | Football developer: global sanction intensity context. |
| `match_total_yellow_cards` | Combined match yellow cards | Football developer: caution composition context. |
| `match_total_red_cards` | Combined match red cards | Football developer: dismissal composition context. |
| `triggered_team_yellow_cards` | Triggered-side yellow cards | Football developer: caution-level decomposition for the foul-heavy side. |
| `opponent_yellow_cards` | Opponent yellow cards | Football developer: bilateral caution comparator. |
| `yellow_cards_delta` | Triggered minus opponent yellow cards | Football developer: net caution imbalance detail. |
| `triggered_team_red_cards` | Triggered-side red cards | Football developer: dismissal contribution on triggered side. |
| `opponent_red_cards` | Opponent red cards | Football developer: bilateral dismissal comparator. |
| `red_cards_delta` | Triggered minus opponent red cards | Football developer: net dismissal imbalance detail. |
| `triggered_team_cards_per_foul_pct` | Triggered-side cards per foul (%) | Football developer: sanction-conversion intensity for triggered side. |
| `opponent_cards_per_foul_pct` | Opponent cards per foul (%) | Football developer: bilateral sanction-conversion comparator. |
| `cards_per_foul_delta_pct` | Triggered minus opponent cards-per-foul (percentage points) | Football developer: officiating/discipline asymmetry summary metric. |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: physical contest context for foul concentration. |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral physicality comparator. |
| `triggered_team_tackles_won` | Successful tackles by triggered side | Football developer: defensive engagement context. |
| `opponent_tackles_won` | Successful tackles by opponent side | Football developer: bilateral defensive engagement comparator. |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: defensive anticipation profile around trigger. |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator. |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-management context. |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-management comparator. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Football developer: technical execution context for foul-heavy side. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral technical comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: net technical differential paired with discipline imbalance. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control-share context for interpreting foul asymmetry. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential aligned with foul concentration. |
