---
signal_id: sig_team_goalkeeping_defense_defensive_discipline
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Defensive Discipline"
trigger: "Team commits <= 5 fouls and keeps a clean sheet in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_goalkeeping_defense_defensive_discipline
  sql: clickhouse/gold/signal/sig_team_goalkeeping_defense_defensive_discipline.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_goalkeeping_defense_defensive_discipline

## Purpose

Detect clean-sheet performances delivered with strong defensive discipline, where a side concedes zero goals while committing at most five fouls.

## Tactical And Statistical Logic

- Trigger condition:
  - finished match (`match_finished = 1`)
  - `triggered_team_fouls <= 5`
  - `triggered_team_clean_sheet_flag = 1` (opponent goals equals zero)
- Output grain is `match_team` with canonical `triggered_side`, so both teams may emit in the same match (for example a disciplined 0-0).
- Core trigger metrics are enriched with bilateral defensive workload and pressure context from `silver.period_stat` (`period = 'All'`), including shots faced, keeper saves, xG against, and defending actions.
- Similarity gate note:
  - `sig_team_goalkeeping_defense_parking_the_bus`: same entity/family/subfamily, but trigger is low-possession winning defense (`<30% possession` and `>=30 clearances`), not foul-discipline clean sheets.
  - `sig_team_goalkeeping_defense_clearance_barrage`: same entity/family/subfamily, but trigger is extreme clearance volume (`>=40`) regardless of fouls/clean sheet.
  - `sig_team_discipline_cards_clean_discipline`: discipline-oriented overlap, but that signal is cards-family and requires `0` cards with `<=7` fouls, without a clean-sheet requirement.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_goalkeeping_defense_defensive_discipline.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_goalkeeping_defense_defensive_discipline`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_goalkeeping_defense_defensive_discipline
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for downstream joins and deduplication |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills |
| `home_team_id` | Home team identifier | Fixture orientation baseline |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team identifier | Fixture orientation baseline |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Scoreline context |
| `away_score` | Away full-time goals | Scoreline context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered team identifier | Primary triggered-side identity key |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Readable opponent attribution |
| `trigger_threshold_max_fouls_committed` | Maximum fouls threshold (`5`) | Explicit trigger provenance for QA |
| `trigger_condition_clean_sheet_required` | Clean-sheet requirement flag (`1`) | Makes mandatory clean-sheet condition explicit |
| `triggered_team_goals` | Goals scored by triggered side | Outcome context |
| `opponent_goals` | Goals scored by opponent side | Bilateral outcome context |
| `goal_delta` | Triggered minus opponent goals | Compact result differential |
| `triggered_team_goals_conceded` | Goals conceded by triggered side | Defensive outcome severity context |
| `opponent_goals_conceded` | Goals conceded by opponent side | Bilateral defensive outcome comparator |
| `goals_conceded_delta` | Triggered minus opponent goals conceded | Net defensive outcome differential |
| `triggered_team_clean_sheet_flag` | 1 when triggered side keeps clean sheet | Trigger validation field |
| `opponent_clean_sheet_flag` | 1 when opponent keeps clean sheet | Distinguishes one-sided clean sheets from 0-0 outcomes |
| `triggered_team_fouls` | Fouls committed by triggered side | Core trigger metric |
| `opponent_fouls` | Fouls committed by opponent side | Bilateral discipline comparator |
| `fouls_delta` | Triggered minus opponent fouls | Net discipline differential |
| `triggered_team_keeper_saves` | Saves by triggered-side goalkeeper | Last-line defensive workload context |
| `opponent_keeper_saves` | Saves by opponent-side goalkeeper | Bilateral goalkeeper workload comparator |
| `keeper_saves_delta` | Triggered minus opponent goalkeeper saves | Net keeper workload differential |
| `triggered_team_shots_on_target_faced` | On-target shots faced by triggered side | Precision pressure denominator |
| `opponent_shots_on_target_faced` | On-target shots faced by opponent side | Bilateral pressure denominator comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent on-target shots faced | Net precision-pressure differential |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Overall defensive pressure context |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure-volume comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net pressure-volume differential |
| `triggered_team_expected_goals_on_target_faced` | xGOT faced by triggered side | On-target chance-severity context |
| `opponent_expected_goals_on_target_faced` | xGOT faced by opponent side | Bilateral on-target severity comparator |
| `expected_goals_on_target_faced_delta` | Triggered minus opponent xGOT faced | Net on-target chance-severity differential |
| `triggered_team_expected_goals_faced` | xG faced by triggered side | Chance-quality-against baseline |
| `opponent_expected_goals_faced` | xG faced by opponent side | Bilateral chance-quality comparator |
| `expected_goals_faced_delta` | Triggered minus opponent xG faced | Net chance-quality-against differential |
| `triggered_team_clearances` | Clearances by triggered side | Defensive resistance volume context |
| `opponent_clearances` | Clearances by opponent side | Bilateral resistance comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net clearance differential |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_tackles_won` | Tackles won by triggered side | Ground-duel defensive output context |
| `opponent_tackles_won` | Tackles won by opponent side | Bilateral ground-duel comparator |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net tackling differential |
| `triggered_team_duels_won` | Duels won by triggered side | Contest-control context |
| `opponent_duels_won` | Duels won by opponent side | Bilateral contest-control comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net contest-control differential |
| `triggered_team_possession_pct` | Triggered-side possession percentage | Control-state context |
| `opponent_possession_pct` | Opponent-side possession percentage | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession percentage | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy percentage | Team execution context under defensive game state |
| `opponent_pass_accuracy_pct` | Opponent-side pass accuracy percentage | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy percentage | Net execution differential |
