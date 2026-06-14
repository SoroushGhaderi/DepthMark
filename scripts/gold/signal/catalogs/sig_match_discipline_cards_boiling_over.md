---
signal_id: sig_match_discipline_cards_boiling_over
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Discipline Cards Boiling Over"
trigger: "Combined yellow/red cards issued after minute 80 are >= 4."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_discipline_cards_boiling_over
  sql: clickhouse/gold/dml/signals/match/sig_match_discipline_cards_boiling_over.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_discipline_cards_boiling_over

## Purpose

Flags matches where discipline breaks down late, with at least four cards issued after minute 80.

## Tactical And Statistical Logic

- Trigger condition:
  - Combined yellow/red card events with `card_minute > 80` is `>= 4`.
  - Card events are sourced from `silver.card` using yellow/red keywords in `card_type`/`description`.
- Trigger is match-level and emitted as two side-oriented rows (`home` and `away`) for stable `match_team` consumption.
- Output keeps late-window bilateral split, late-window share, total-match discipline context, foul conversion context, and defensive/possession context for tactical interpretation.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_discipline_cards_boiling_over.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_discipline_cards_boiling_over`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_discipline_cards_boiling_over
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join and QA key. |
| `match_date` | Match date | Football developer: temporal slicing and partition alignment. |
| `home_team_id` | Home team identifier | Football developer: fixture orientation anchor. |
| `home_team_name` | Home team name | Football developer: readable fixture context. |
| `away_team_id` | Away team identifier | Football developer: fixture orientation anchor. |
| `away_team_name` | Away team name | Football developer: readable fixture context. |
| `home_score` | Full-time home goals | Football developer: result context for late-discipline spikes. |
| `away_score` | Full-time away goals | Football developer: result context for late-discipline spikes. |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: canonical side identity at `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Football developer: downstream team attribution key. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context. |
| `trigger_threshold_min_late_window_cards` | Configured late-window card threshold (`4`) | Football developer: explicit trigger provenance for explainability and QA. |
| `trigger_threshold_window_start_minute` | Late-window start minute (`80`) | Football developer: explicit temporal boundary for reproducibility. |
| `trigger_threshold_window_end_minute` | Late-window end minute boundary (`NULL` for open-ended) | Football developer: explicit statement that the trigger window is open-ended after minute 80. |
| `match_late_window_cards` | Total yellow/red cards issued after minute 80 | Football developer: core trigger intensity variable. |
| `match_late_window_cards_above_threshold` | Cards above threshold (`match_late_window_cards - 4`) | Football developer: severity beyond binary trigger activation. |
| `home_late_window_cards` | Home-side late-window card count | Football developer: bilateral late-phase contribution context. |
| `away_late_window_cards` | Away-side late-window card count | Football developer: bilateral late-phase contribution context. |
| `triggered_team_late_window_cards` | Triggered-side late-window card count | Football developer: side-specific late-discipline load. |
| `opponent_late_window_cards` | Opponent late-window card count | Football developer: bilateral late-discipline comparator. |
| `late_window_cards_delta` | Triggered minus opponent late-window cards | Football developer: net late-phase discipline imbalance. |
| `triggered_team_late_window_cards_share_pct` | Triggered-side share of late-window cards (%) | Football developer: normalized late-window contribution metric. |
| `opponent_late_window_cards_share_pct` | Opponent share of late-window cards (%) | Football developer: symmetric normalized comparator. |
| `late_window_cards_share_delta_pct` | Triggered minus opponent late-window share (percentage points) | Football developer: compact normalized asymmetry metric. |
| `match_total_cards` | Total match cards (yellow + red) | Football developer: full-match discipline baseline for late-window interpretation. |
| `match_total_yellow_cards` | Total match yellow cards | Football developer: sanction composition context. |
| `match_total_red_cards` | Total match red cards | Football developer: dismissal-severity context. |
| `triggered_team_yellow_cards` | Triggered-side yellow cards | Football developer: side-level caution baseline. |
| `opponent_yellow_cards` | Opponent yellow cards | Football developer: bilateral caution comparator. |
| `yellow_cards_delta` | Triggered minus opponent yellow cards | Football developer: net caution imbalance context. |
| `triggered_team_red_cards` | Triggered-side red cards | Football developer: side-level dismissal baseline. |
| `opponent_red_cards` | Opponent red cards | Football developer: bilateral dismissal comparator. |
| `red_cards_delta` | Triggered minus opponent red cards | Football developer: net dismissal imbalance context. |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: aggregate side discipline load. |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: bilateral aggregate discipline comparator. |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: compact overall discipline imbalance metric. |
| `triggered_team_fouls_committed` | Triggered-side fouls committed | Football developer: aggression baseline behind sanction load. |
| `opponent_fouls_committed` | Opponent fouls committed | Football developer: bilateral aggression comparator. |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net contact-pressure differential. |
| `triggered_team_cards_per_foul_pct` | Triggered-side cards per foul (%) | Football developer: sanction-conversion rate for triggered side. |
| `opponent_cards_per_foul_pct` | Opponent cards per foul (%) | Football developer: bilateral sanction-conversion comparator. |
| `cards_per_foul_delta_pct` | Triggered minus opponent cards-per-foul (percentage points) | Football developer: officiating/discipline asymmetry summary. |
| `triggered_team_duels_won` | Triggered-side duels won | Football developer: physical-contest context. |
| `opponent_duels_won` | Opponent duels won | Football developer: bilateral physicality comparator. |
| `triggered_team_tackles_won` | Triggered-side successful tackles | Football developer: defensive-intensity context. |
| `opponent_tackles_won` | Opponent successful tackles | Football developer: bilateral defensive-intensity comparator. |
| `triggered_team_interceptions` | Triggered-side interceptions | Football developer: anticipation/pressing context. |
| `opponent_interceptions` | Opponent interceptions | Football developer: bilateral anticipation comparator. |
| `triggered_team_clearances` | Triggered-side clearances | Football developer: pressure-release context. |
| `opponent_clearances` | Opponent clearances | Football developer: bilateral pressure-release comparator. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control context for late-discipline interpretation. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with late-card intensity. |
