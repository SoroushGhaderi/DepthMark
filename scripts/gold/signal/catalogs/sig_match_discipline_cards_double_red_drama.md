---
signal_id: sig_match_discipline_cards_double_red_drama
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Double Red Drama"
trigger: "Both teams receive at least one red card."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_discipline_cards_double_red_drama
  sql: clickhouse/gold/dml/signals/match/sig_match_discipline_cards_double_red_drama.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_match_discipline_cards_double_red_drama

## Purpose

Flags bilateral dismissal matches where both teams lose at least one player to a red card, surfacing extreme-control-breakdown environments.

## Tactical And Statistical Logic

- Trigger condition:
  - `red_cards_home >= 1 AND red_cards_away >= 1` from `silver.period_stat` at `period = 'All'`.
- Trigger is match-level and emitted as two side-oriented rows (`home` and `away`) for stable team-grain downstream usage.
- Output preserves red-card symmetry plus card-to-foul conversion, defensive workload, and possession context to separate balanced chaos from one-sided indiscipline.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_discipline_cards_double_red_drama.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_match_discipline_cards_double_red_drama`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_match_discipline_cards_double_red_drama
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins, QA, and feature lineage. |
| `match_date` | Match date | Football developer: supports temporal slicing and partition alignment. |
| `home_team_id` | Home team identifier | Football developer: fixed fixture orientation context. |
| `home_team_name` | Home team name | Football developer: readable fixture context. |
| `away_team_id` | Away team identifier | Football developer: fixed fixture orientation context. |
| `away_team_name` | Away team name | Football developer: readable fixture context. |
| `home_score` | Full-time home goals | Football developer: outcome context for bilateral dismissals. |
| `away_score` | Full-time away goals | Football developer: outcome context for bilateral dismissals. |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: canonical team-side identity for match-team grain. |
| `triggered_team_id` | Triggered-side team identifier | Football developer: downstream feature ownership key. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison anchor. |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context. |
| `trigger_threshold_min_red_cards_per_team` | Per-team minimum red-card threshold (`1`) | Football developer: explicit trigger provenance for reproducibility and QA. |
| `home_red_cards` | Home-team red cards | Football developer: explicit bilateral trigger evidence in fixture orientation. |
| `away_red_cards` | Away-team red cards | Football developer: explicit bilateral trigger evidence in fixture orientation. |
| `match_total_red_cards` | Total red cards in match (home + away) | Football developer: dismissal intensity for severity ranking. |
| `triggered_team_red_cards` | Triggered-side red cards | Football developer: side-level dismissal burden. |
| `opponent_red_cards` | Opponent red cards | Football developer: bilateral dismissal comparator. |
| `red_cards_delta` | Triggered minus opponent red cards | Football developer: net dismissal imbalance despite bilateral trigger. |
| `triggered_team_yellow_cards` | Triggered-side yellow cards | Football developer: caution burden around red-card escalation. |
| `opponent_yellow_cards` | Opponent yellow cards | Football developer: bilateral caution comparator. |
| `triggered_team_total_cards` | Triggered-side total cards (yellow + red) | Football developer: aggregate sanction load for triggered side. |
| `opponent_total_cards` | Opponent total cards (yellow + red) | Football developer: bilateral aggregate sanction comparator. |
| `match_total_cards` | Combined total cards in the match | Football developer: full disciplinary volume context beyond reds alone. |
| `triggered_team_fouls_committed` | Triggered-side fouls committed | Football developer: aggression baseline paired with sanction outcomes. |
| `opponent_fouls_committed` | Opponent fouls committed | Football developer: bilateral aggression comparator. |
| `fouls_committed_delta` | Triggered minus opponent fouls | Football developer: net foul-pressure differential. |
| `triggered_team_cards_per_foul_pct` | Triggered-side cards per foul (%) | Football developer: sanction-conversion efficiency for side profiling. |
| `opponent_cards_per_foul_pct` | Opponent cards per foul (%) | Football developer: bilateral sanction-conversion comparator. |
| `cards_per_foul_delta_pct` | Triggered minus opponent cards-per-foul (percentage points) | Football developer: compact officiating/discipline asymmetry signal. |
| `triggered_team_tackles_won` | Triggered-side successful tackles | Football developer: defending-intensity context in dismissal-heavy games. |
| `opponent_tackles_won` | Opponent successful tackles | Football developer: bilateral defending-intensity comparator. |
| `triggered_team_duels_won` | Triggered-side duels won | Football developer: physicality context around bilateral dismissals. |
| `opponent_duels_won` | Opponent duels won | Football developer: bilateral physicality comparator. |
| `triggered_team_interceptions` | Triggered-side interceptions | Football developer: defensive anticipation context in chaotic game states. |
| `opponent_interceptions` | Opponent interceptions | Football developer: bilateral anticipation comparator. |
| `triggered_team_clearances` | Triggered-side clearances | Football developer: pressure-release profile in disordered matches. |
| `opponent_clearances` | Opponent clearances | Football developer: bilateral pressure-release comparator. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control-share context when both sides are reduced. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with bilateral red-card drama. |
