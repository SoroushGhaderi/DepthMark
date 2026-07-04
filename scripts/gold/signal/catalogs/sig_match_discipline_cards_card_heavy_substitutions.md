---
signal_id: sig_match_discipline_cards_card_heavy_substitutions
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Card-Heavy Substitutions"
trigger: "At least four different substitute players receive yellow cards in the same match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_discipline_cards_card_heavy_substitutions
  sql: clickhouse/gold/dml/signals/match/sig_match_discipline_cards_card_heavy_substitutions.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_match_discipline_cards_card_heavy_substitutions

## Purpose

Flags matches where bench usage is strongly associated with discipline risk, defined by four or more distinct substitute players receiving yellow cards in the same fixture.

## Tactical And Statistical Logic

- Trigger condition:
  - `match_distinct_substitute_yellow_carded_players >= 4`
- Substitute identity is sourced from `silver.match_personnel` where `role = 'substitute'` and `substitution_time > 0`.
- Qualifying card events are yellow-card events from `silver.card`, linked by `match_id`, `player_id`, and `team_side`.
- Trigger is match-level and emits two side-oriented rows (`home` and `away`) for stable `match_team` downstream consumption.
- Output preserves substitute-booking concentration, timing of first substitute booking by side, and bilateral discipline/control context from `silver.period_stat` (`period = 'All'`).

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_discipline_cards_card_heavy_substitutions.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_match_discipline_cards_card_heavy_substitutions`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_match_discipline_cards_card_heavy_substitutions
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable match key for joins, QA, and lineage. |
| `match_date` | Match date | Football developer: temporal slicing and partition alignment. |
| `home_team_id` | Home team identifier | Football developer: fixture orientation anchor. |
| `home_team_name` | Home team name | Football developer: readable fixture context. |
| `away_team_id` | Away team identifier | Football developer: fixture orientation anchor. |
| `away_team_name` | Away team name | Football developer: readable fixture context. |
| `home_score` | Home full-time goals | Football developer: outcome context for substitution-discipline analysis. |
| `away_score` | Away full-time goals | Football developer: outcome context for substitution-discipline analysis. |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: canonical side identity for `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Football developer: team attribution key for downstream features. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context. |
| `trigger_threshold_min_distinct_substitute_yellow_carded_players` | Configured minimum distinct substitute yellow-carded players (`4`) | Football developer: explicit trigger provenance for reproducibility and QA. |
| `match_distinct_substitute_yellow_carded_players` | Distinct substitute players with at least one yellow card in the match | Football developer: core trigger metric for bench-discipline burden. |
| `match_distinct_substitute_yellow_carded_players_above_threshold` | Distinct substitute yellow-carded players minus threshold | Football developer: severity gradient beyond binary trigger activation. |
| `home_distinct_substitute_yellow_carded_players` | Home-side distinct substitutes with yellow cards | Football developer: fixture-oriented side attribution of substitute cautions. |
| `away_distinct_substitute_yellow_carded_players` | Away-side distinct substitutes with yellow cards | Football developer: fixture-oriented side attribution of substitute cautions. |
| `triggered_team_distinct_substitute_yellow_carded_players` | Triggered-side distinct substitutes with yellow cards | Football developer: side-level substitute-discipline burden. |
| `opponent_distinct_substitute_yellow_carded_players` | Opponent distinct substitutes with yellow cards | Football developer: bilateral substitute-discipline comparator. |
| `distinct_substitute_yellow_carded_players_delta` | Triggered minus opponent distinct substitute yellow-carded players | Football developer: net substitute-booking concentration imbalance. |
| `triggered_team_substitute_yellow_card_events` | Yellow-card events for triggered-side substitutes | Football developer: event-volume severity beyond distinct-player count. |
| `opponent_substitute_yellow_card_events` | Yellow-card events for opponent substitutes | Football developer: bilateral event-volume comparator. |
| `substitute_yellow_card_events_delta` | Triggered minus opponent substitute yellow-card events | Football developer: net substitute yellow-card pressure imbalance. |
| `triggered_team_first_substitute_yellow_card_minute` | First yellow-card minute for triggered-side substitutes | Football developer: onset timing for bench-discipline deterioration. |
| `opponent_first_substitute_yellow_card_minute` | First yellow-card minute for opponent substitutes | Football developer: bilateral onset-timing comparator. |
| `triggered_team_substitute_yellow_carded_share_pct` | Triggered-side share of distinct substitute yellow-carded players (%) | Football developer: normalized triggered-side contribution to match trigger. |
| `opponent_substitute_yellow_carded_share_pct` | Opponent share of distinct substitute yellow-carded players (%) | Football developer: symmetric normalized comparator. |
| `substitute_yellow_carded_share_delta_pct` | Triggered minus opponent distinct substitute-yellow-carded share (percentage points) | Football developer: compact normalized asymmetry metric. |
| `triggered_team_yellow_cards` | Triggered-side yellow cards (all players) | Football developer: team-wide caution context around substitute bookings. |
| `opponent_yellow_cards` | Opponent yellow cards (all players) | Football developer: bilateral team caution comparator. |
| `yellow_cards_delta` | Triggered minus opponent yellow cards | Football developer: net caution imbalance at match-team level. |
| `triggered_team_red_cards` | Triggered-side red cards (all players) | Football developer: escalation context paired with substitute cautions. |
| `opponent_red_cards` | Opponent red cards (all players) | Football developer: bilateral dismissal comparator. |
| `red_cards_delta` | Triggered minus opponent red cards | Football developer: net dismissal imbalance context. |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: aggregate discipline burden for triggered side. |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: bilateral aggregate discipline comparator. |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: compact disciplinary-pressure differential. |
| `triggered_team_fouls_committed` | Triggered-side fouls committed | Football developer: aggression context behind card burden. |
| `opponent_fouls_committed` | Opponent fouls committed | Football developer: bilateral aggression comparator. |
| `fouls_committed_delta` | Triggered minus opponent fouls committed | Football developer: net foul-pressure differential. |
| `triggered_team_cards_per_foul_pct` | Triggered-side cards per foul (%) | Football developer: sanction-conversion context for team discipline. |
| `opponent_cards_per_foul_pct` | Opponent cards per foul (%) | Football developer: bilateral sanction-conversion comparator. |
| `cards_per_foul_delta_pct` | Triggered minus opponent cards-per-foul (percentage points) | Football developer: officiating/discipline asymmetry summary. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control context for interpreting bench-discipline trends. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential alongside substitute-card intensity. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Football developer: technical-control context around disruption. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral technical-control comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: compact execution-quality differential. |
