---
signal_id: sig_match_discipline_cards_clean_fair_play
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Match Discipline Cards Clean Fair Play"
trigger: "Combined match fouls are <= 12 and combined total cards (yellow + red) are 0."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_discipline_cards_clean_fair_play
  sql: clickhouse/gold/dml/signals/match/sig_match_discipline_cards_clean_fair_play.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_match_discipline_cards_clean_fair_play

## Purpose

Flags low-contact matches with no cards at all, isolating clean fair-play profiles where both teams keep foul volume controlled and avoid disciplinary sanctions.

## Tactical And Statistical Logic

- Trigger condition:
  - `fouls_home + fouls_away <= 12`
  - `(yellow_cards_home + red_cards_home + yellow_cards_away + red_cards_away) = 0`
- Trigger is match-level and emitted as two side-oriented rows (`home` and `away`) so team-centric downstream workflows can consume symmetric context.
- Output preserves bilateral foul split, card-per-foul rates, defensive action context, passing accuracy, and possession balance.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_discipline_cards_clean_fair_play.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_match_discipline_cards_clean_fair_play`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_match_discipline_cards_clean_fair_play
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for reproducible feature generation and QA. |
| `match_date` | Match date | Football developer: supports temporal slicing and backtesting. |
| `home_team_id` | Home team identifier | Football developer: fixture orientation anchor. |
| `home_team_name` | Home team name | Football developer: readable fixture context. |
| `away_team_id` | Away team identifier | Football developer: fixture orientation anchor. |
| `away_team_name` | Away team name | Football developer: readable fixture context. |
| `home_score` | Full-time home goals | Football developer: scoreline context for clean-discipline matches. |
| `away_score` | Full-time away goals | Football developer: scoreline context for clean-discipline matches. |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: canonical side key for match-team grain. |
| `triggered_team_id` | Triggered-side team identifier | Football developer: team-level ownership of each side-oriented row. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered-side attribution. |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context. |
| `trigger_threshold_max_combined_fouls` | Configured maximum combined fouls threshold (`12`) | Football developer: explicit trigger provenance and explainability. |
| `trigger_threshold_max_match_total_cards` | Configured maximum combined cards threshold (`0`) | Football developer: explicit no-card trigger provenance. |
| `match_total_fouls_committed` | Total fouls in the match (home + away) | Football developer: core fair-play trigger metric. |
| `match_total_fouls_below_threshold` | Margin below foul threshold (`12 - match_total_fouls_committed`) | Football developer: trigger severity and ranking context. |
| `match_total_cards` | Combined total cards in the match | Football developer: verifies strict no-card match condition. |
| `match_total_yellow_cards` | Combined yellow cards in the match | Football developer: sanction composition audit. |
| `match_total_red_cards` | Combined red cards in the match | Football developer: severe-sanction audit in clean matches. |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Football developer: side contribution to total foul load. |
| `opponent_fouls_committed` | Fouls committed by opponent side | Football developer: bilateral foul comparator. |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net foul-pressure imbalance. |
| `triggered_team_fouls_share_pct` | Triggered-side share of total match fouls (%) | Football developer: normalized side burden in low-foul matches. |
| `opponent_fouls_share_pct` | Opponent share of total match fouls (%) | Football developer: symmetric normalized comparator. |
| `fouls_share_delta_pct` | Triggered minus opponent foul share (percentage points) | Football developer: compact asymmetry measure for fair-play profiles. |
| `triggered_team_yellow_cards` | Triggered-side yellow cards | Football developer: side-level caution confirmation. |
| `opponent_yellow_cards` | Opponent yellow cards | Football developer: bilateral caution confirmation. |
| `triggered_team_red_cards` | Triggered-side red cards | Football developer: side-level dismissal confirmation. |
| `opponent_red_cards` | Opponent red cards | Football developer: bilateral dismissal confirmation. |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: aggregate side discipline check. |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: bilateral aggregate discipline check. |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: net sanction asymmetry metric for QA. |
| `triggered_team_cards_per_foul_pct` | Triggered-side cards per foul (%) | Football developer: sanction-conversion context; expected near zero in clean fair-play matches. |
| `opponent_cards_per_foul_pct` | Opponent cards per foul (%) | Football developer: bilateral sanction-conversion comparator. |
| `cards_per_foul_delta_pct` | Triggered minus opponent cards-per-foul (percentage points) | Football developer: compact officiating/discipline asymmetry context. |
| `triggered_team_tackles_won` | Successful tackles by triggered side | Football developer: defensive intensity context under low-foul conditions. |
| `opponent_tackles_won` | Successful tackles by opponent side | Football developer: bilateral defensive-intensity comparator. |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: physical contest context in clean matches. |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral contest comparator. |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: defensive anticipation profile with limited fouling. |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator. |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-release context despite low sanction load. |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-release comparator. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Football developer: technical control context in clean fair-play games. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral technical comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: net technical edge paired with discipline profile. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control-share context for low-contact match states. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential for tactical interpretation. |
