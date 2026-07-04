---
signal_id: sig_team_discipline_cards_penalty_prone
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Penalty-Prone Team Discipline"
trigger: "Team concedes >= 2 penalties in a single match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_discipline_cards_penalty_prone
  sql: clickhouse/gold/dml/signals/team/sig_team_discipline_cards_penalty_prone.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_discipline_cards_penalty_prone

## Purpose

Flags team-match performances where a team concedes at least two penalties, surfacing high-risk defensive discipline patterns with bilateral match context.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_penalties_conceded >= 2`
- Penalty awards are sourced from `silver.shot` using penalty-tagged shots (`situation`/`shot_type` contains `"penalty"`).
- Trigger is evaluated symmetrically for home and away teams by mapping awarded penalties to the conceding side.
- The signal preserves bilateral penalty outcomes (scored/missed), foul-card burden, defensive actions, and possession balance for tactical interpretation.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_discipline_cards_penalty_prone.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_discipline_cards_penalty_prone`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_discipline_cards_penalty_prone
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key and release QA anchor |
| `match_date` | Match date | Football developer: temporal analysis and partition alignment |
| `home_team_id` | Home team identifier | Football developer: fixed fixture orientation anchor |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: fixed fixture orientation anchor |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: outcome context around conceded-penalty profile |
| `away_score` | Away full-time goals | Football developer: outcome context around conceded-penalty profile |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical row identity orientation |
| `triggered_team_id` | Triggered team identifier | Football developer: durable triggered-entity key |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-entity context |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral comparison key |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_min_penalties_conceded` | Configured penalty-conceded trigger threshold (`2`) | Football developer: explicit trigger provenance for reproducibility |
| `triggered_team_penalties_conceded` | Penalties conceded by triggered side | Football developer: core trigger metric |
| `opponent_penalties_conceded` | Penalties conceded by opponent side | Football developer: symmetric concession comparator |
| `penalties_conceded_delta` | Triggered minus opponent penalties conceded | Football developer: net concession imbalance |
| `triggered_team_penalties_awarded` | Penalties awarded to triggered team | Football developer: reverse-flow context for bilateral penalty dynamics |
| `opponent_penalties_awarded` | Penalties awarded to opponent team | Football developer: direct counterpart to conceded penalties |
| `total_match_penalties_awarded` | Total penalties awarded in match | Football developer: match-level penalty volatility context |
| `triggered_team_penalties_conceded_scored` | Conceded penalties converted by opponent | Football developer: severity context of concession outcomes |
| `triggered_team_penalties_conceded_missed` | Conceded penalties missed by opponent | Football developer: mitigation/variance context for concessions |
| `opponent_penalties_conceded_scored` | Opponent concessions converted by triggered team | Football developer: symmetric conversion baseline |
| `opponent_penalties_conceded_missed` | Opponent concessions missed by triggered team | Football developer: symmetric miss baseline |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Football developer: aggression load context tied to penalty concessions |
| `opponent_fouls_committed` | Fouls committed by opponent side | Football developer: bilateral foul-load comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls committed | Football developer: net foul imbalance around trigger |
| `triggered_team_yellow_cards` | Yellow cards on triggered side | Football developer: caution-level discipline context |
| `opponent_yellow_cards` | Yellow cards on opponent side | Football developer: bilateral caution comparator |
| `triggered_team_red_cards` | Red cards on triggered side | Football developer: severe-discipline escalation context |
| `opponent_red_cards` | Red cards on opponent side | Football developer: bilateral severe-discipline comparator |
| `triggered_team_total_cards` | Total cards (yellow+red) on triggered side | Football developer: aggregate discipline burden around trigger |
| `opponent_total_cards` | Total cards (yellow+red) on opponent side | Football developer: bilateral aggregate discipline comparator |
| `card_count_delta` | Triggered minus opponent total cards | Football developer: net card-pressure imbalance |
| `triggered_team_duels_won` | Duels won by triggered side | Football developer: physical contest context tied to concession risk |
| `opponent_duels_won` | Duels won by opponent side | Football developer: bilateral physical contest comparator |
| `triggered_team_tackles_won` | Tackles won by triggered side | Football developer: defending profile context around box incidents |
| `opponent_tackles_won` | Tackles won by opponent side | Football developer: bilateral defending comparator |
| `triggered_team_interceptions` | Interceptions by triggered side | Football developer: defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Football developer: bilateral anticipation comparator |
| `triggered_team_clearances` | Clearances by triggered side | Football developer: pressure-management context in defensive phases |
| `opponent_clearances` | Clearances by opponent side | Football developer: bilateral pressure-management comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control/style context for interpreting concession patterns |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential paired with discipline signal |
