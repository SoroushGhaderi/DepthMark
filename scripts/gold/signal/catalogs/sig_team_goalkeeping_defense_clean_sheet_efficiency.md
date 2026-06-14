---
signal_id: sig_team_goalkeeping_defense_clean_sheet_efficiency
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Clean-Sheet Efficiency"
trigger: "Team keeps a clean sheet despite facing >= 8 shots on target."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_goalkeeping_defense_clean_sheet_efficiency
  sql: clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_clean_sheet_efficiency.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_goalkeeping_defense_clean_sheet_efficiency

## Purpose

Detect teams that keep a clean sheet under sustained on-target pressure (`>= 8` shots on target
faced), then retain bilateral defensive workload and control context for interpretation.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_shots_on_target_faced >= 8`
  - `triggered_team_clean_sheet_flag = 1` (opponent goals equals zero)
  - `match_finished = 1` and `period = 'All'`
- Rows are emitted at `match_team` grain with canonical `triggered_side`, so both sides can trigger
  in rare high-pressure 0-0 matches.
- Trigger severity is captured by `triggered_team_shots_on_target_faced_above_threshold`.
- Bilateral context is preserved through saves/save rate, xG/xGOT faced, defensive event volume,
  possession, and passing differentials.
- Similarity gate note:
  - `sig_team_goalkeeping_defense_box_evacuation`: same clean-sheet-under-pressure framing, but
    trigger axis is opposition box touches faced (`>= 50`), not shots on target faced.
  - `sig_team_goalkeeping_defense_defensive_discipline`: same clean-sheet requirement, but trigger
    axis is low fouls committed (`<= 5`), not high on-target pressure.
  - `sig_team_goalkeeping_defense_unbroken_structure`: same defensive suppression family, but trigger
    axis is low inside-box shots allowed (`<= 3`) rather than high on-target workload survived.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_clean_sheet_efficiency.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_goalkeeping_defense_clean_sheet_efficiency`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_goalkeeping_defense_clean_sheet_efficiency
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for downstream joins and deduplication |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills |
| `home_team_id` | Home team ID | Preserves bilateral fixture context |
| `home_team_name` | Home team name | Readable fixture attribution |
| `away_team_id` | Away team ID | Preserves bilateral fixture context |
| `away_team_name` | Away team name | Readable fixture attribution |
| `home_score` | Home full-time goals | Match-outcome context |
| `away_score` | Away full-time goals | Match-outcome context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered team ID | Stable triggered-side identity key |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Readable opponent attribution |
| `trigger_threshold_min_shots_on_target_faced` | Trigger threshold (`8`) | Explicit trigger provenance |
| `trigger_condition_clean_sheet_required` | Clean-sheet requirement flag (`1`) | Makes mandatory trigger rule explicit |
| `triggered_team_goals` | Goals scored by triggered side | Result context under pressure |
| `opponent_goals` | Goals scored by opponent side | Trigger validation and bilateral result context |
| `goal_delta` | Triggered minus opponent goals | Compact result differential |
| `triggered_team_goals_conceded` | Goals conceded by triggered side | Core clean-sheet trigger dimension |
| `opponent_goals_conceded` | Goals conceded by opponent side | Bilateral defensive outcome context |
| `goals_conceded_delta` | Triggered minus opponent goals conceded | Net defensive outcome differential |
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes 0 goals | Trigger validation field |
| `opponent_clean_sheet_flag` | 1 when opponent concedes 0 goals | Distinguishes one-sided clean sheets from 0-0 |
| `triggered_team_shots_on_target_faced` | On-target shots faced by triggered side | Core pressure-survival trigger metric |
| `opponent_shots_on_target_faced` | On-target shots faced by opponent side | Bilateral pressure comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target exposure differential |
| `triggered_team_shots_on_target_faced_above_threshold` | On-target shots faced above threshold (`value - 8`) | Trigger severity beyond activation boundary |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive pressure denominator |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure-volume comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net shot-volume exposure differential |
| `triggered_team_keeper_saves` | Goalkeeper saves by triggered side | Last-line defensive workload context |
| `opponent_keeper_saves` | Goalkeeper saves by opponent side | Bilateral keeper-workload comparator |
| `keeper_saves_delta` | Triggered minus opponent goalkeeper saves | Net keeper-workload differential |
| `triggered_team_save_rate_pct` | Triggered-side save rate (%) | Normalized shot-stopping efficiency |
| `opponent_save_rate_pct` | Opponent-side save rate (%) | Bilateral shot-stopping comparator |
| `save_rate_delta_pct` | Triggered minus opponent save rate (pp) | Net save-efficiency differential |
| `triggered_team_expected_goals_faced` | xG faced by triggered side | Chance-quality-against context |
| `opponent_expected_goals_faced` | xG faced by opponent side | Bilateral chance-quality comparator |
| `expected_goals_faced_delta` | Triggered minus opponent xG faced | Net chance-quality-against differential |
| `triggered_team_expected_goals_on_target_faced` | xGOT faced by triggered side | On-target chance-severity context |
| `opponent_expected_goals_on_target_faced` | xGOT faced by opponent side | Bilateral on-target severity comparator |
| `expected_goals_on_target_faced_delta` | Triggered minus opponent xGOT faced | Net on-target chance-severity differential |
| `triggered_team_shot_blocks` | Shot blocks by triggered side | Box-protection context |
| `opponent_shot_blocks` | Shot blocks by opponent side | Bilateral box-protection comparator |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net block-volume differential |
| `triggered_team_clearances` | Clearances by triggered side | Pressure-release context |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_tackles_won` | Tackles won by triggered side | Ground-duel defensive output context |
| `opponent_tackles_won` | Tackles won by opponent side | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net tackling differential |
| `triggered_team_duels_won` | Duels won by triggered side | Physical-control context |
| `opponent_duels_won` | Duels won by opponent side | Bilateral physical-control comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net contest-control differential |
| `triggered_team_aerials_won` | Aerial duels won by triggered side | Vertical-control context |
| `opponent_aerials_won` | Aerial duels won by opponent side | Bilateral aerial-control comparator |
| `aerials_won_delta` | Triggered minus opponent aerial duels won | Net aerial-control differential |
| `triggered_team_fouls` | Fouls committed by triggered side | Discipline trade-off context |
| `opponent_fouls` | Fouls committed by opponent side | Bilateral discipline comparator |
| `fouls_delta` | Triggered minus opponent fouls | Net discipline differential |
| `triggered_team_possession_pct` | Triggered-side possession percentage | Control-state context |
| `opponent_possession_pct` | Opponent-side possession percentage | Bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession percentage | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy percentage | Ball-retention execution context |
| `opponent_pass_accuracy_pct` | Opponent-side pass accuracy percentage | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy percentage | Net circulation-quality differential |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Counter-territory context while under pressure |
| `opponent_touches_opposition_box` | Opponent-side touches in opposition box | Bilateral territory comparator |
| `touches_opposition_box_delta` | Triggered minus opponent touches in opposition box | Net attacking-territory differential |
