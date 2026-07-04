---
signal_id: sig_team_goalkeeping_defense_box_evacuation
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Box Evacuation"
trigger: "Team allows >= 50 opposition touches in the box and concedes 0 goals in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_goalkeeping_defense_box_evacuation
  sql: clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_box_evacuation.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_goalkeeping_defense_box_evacuation

## Purpose

Detects clean-sheet escapes where a team absorbs extreme opposition penalty-box pressure (`>= 50` opposition box touches) yet concedes zero goals.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_opposition_box_touches_faced >= 50`
  - `triggered_team_clean_sheet_flag = 1` (opponent goals equals zero)
  - `match_finished = 1` and `period = 'All'`
- Rows are emitted at `match_team` grain with canonical `triggered_side`, so both teams can trigger in the same match (for example an extreme-pressure 0-0).
- Trigger severity is captured by `triggered_team_opposition_box_touches_faced_above_threshold`.
- Bilateral defensive pressure and resistance context is preserved via shots/xG faced, keeper saves, shot blocks, clearances, interceptions, tackles, and duel outputs.
- Similarity gate note:
  - `sig_team_shooting_goals_no_shots_allowed`: overlap in defensive suppression framing, but this signal is box-pressure absorption under clean sheet, not on-target suppression.
  - `sig_team_shooting_goals_wasteful_box_presence`: opposite perspective; that signal tracks own attacking box touches with 0 goals, while this one tracks opposition box touches faced with 0 goals conceded.
  - `sig_team_goalkeeping_defense_defensive_discipline`: shares clean-sheet context, but trigger here is extreme opposition box-pressure volume rather than low foul count.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_box_evacuation.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_goalkeeping_defense_box_evacuation`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_goalkeeping_defense_box_evacuation
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for downstream joins and deduplication |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills |
| `home_team_id` | Home team ID | Preserves bilateral fixture context |
| `home_team_name` | Home team name | Analyst-readable fixture attribution |
| `away_team_id` | Away team ID | Preserves bilateral fixture context |
| `away_team_name` | Away team name | Analyst-readable fixture attribution |
| `home_score` | Home full-time goals | Scoreline context for pressure absorption |
| `away_score` | Away full-time goals | Scoreline context for pressure absorption |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side orientation at `match_team` grain |
| `triggered_team_id` | Triggered team ID | Stable identity key for triggered side |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Readable opponent attribution |
| `trigger_threshold_min_opposition_box_touches_faced` | Trigger threshold (`50`) | Explicit trigger provenance for reproducibility |
| `trigger_condition_clean_sheet_required` | Clean-sheet requirement flag (`1`) | Makes mandatory trigger rule explicit |
| `triggered_team_goals` | Goals scored by triggered side | Outcome context under pressure |
| `opponent_goals` | Goals scored by opponent side | Trigger validation and bilateral result context |
| `goal_delta` | Triggered minus opponent goals | Compact result differential |
| `triggered_team_goals_conceded` | Goals conceded by triggered side | Core clean-sheet trigger dimension |
| `opponent_goals_conceded` | Goals conceded by opponent side | Bilateral defensive outcome context |
| `goals_conceded_delta` | Triggered minus opponent goals conceded | Net defensive outcome differential |
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes 0 goals | Trigger validation field |
| `opponent_clean_sheet_flag` | 1 when opponent concedes 0 goals | Distinguishes one-sided clean sheets from 0-0 |
| `triggered_team_opposition_box_touches_faced` | Opposition touches in triggered side's box | Core pressure-absorption trigger metric |
| `opponent_opposition_box_touches_faced` | Opposition touches in opponent side's box | Bilateral pressure baseline |
| `opposition_box_touches_faced_delta` | Triggered minus opponent opposition-box touches faced | Net pressure-load differential |
| `triggered_team_opposition_box_touches_faced_above_threshold` | Touches faced above threshold (`value - 50`) | Trigger severity beyond activation boundary |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive pressure denominator |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure-volume comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net shot-volume exposure differential |
| `triggered_team_shots_on_target_faced` | On-target shots faced by triggered side | Precision pressure context |
| `opponent_shots_on_target_faced` | On-target shots faced by opponent side | Bilateral precision-pressure comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target exposure differential |
| `triggered_team_expected_goals_faced` | xG faced by triggered side | Chance-quality-against context |
| `opponent_expected_goals_faced` | xG faced by opponent side | Bilateral chance-quality comparator |
| `expected_goals_faced_delta` | Triggered minus opponent xG faced | Net chance-quality-against differential |
| `triggered_team_expected_goals_on_target_faced` | xGOT faced by triggered side | On-target chance-severity context |
| `opponent_expected_goals_on_target_faced` | xGOT faced by opponent side | Bilateral on-target severity comparator |
| `expected_goals_on_target_faced_delta` | Triggered minus opponent xGOT faced | Net on-target chance-severity differential |
| `triggered_team_keeper_saves` | Goalkeeper saves by triggered side | Last-line defensive workload context |
| `opponent_keeper_saves` | Goalkeeper saves by opponent side | Bilateral keeper workload comparator |
| `keeper_saves_delta` | Triggered minus opponent keeper saves | Net goalkeeper workload differential |
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
| `opponent_duels_won` | Duels won by opponent side | Bilateral contest-control comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net duel-control differential |
| `triggered_team_aerials_won` | Aerial duels won by triggered side | Aerial-control context |
| `opponent_aerials_won` | Aerial duels won by opponent side | Bilateral aerial-control comparator |
| `aerials_won_delta` | Triggered minus opponent aerial duels won | Net aerial-control differential |
| `triggered_team_fouls` | Fouls committed by triggered side | Discipline trade-off context |
| `opponent_fouls` | Fouls committed by opponent side | Bilateral discipline comparator |
| `fouls_delta` | Triggered minus opponent fouls | Net discipline differential |
| `triggered_team_possession_pct` | Triggered-side possession percentage | Control-state context |
| `opponent_possession_pct` | Opponent-side possession percentage | Bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession percentage | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy percentage | Ball-retention execution context |
| `opponent_pass_accuracy_pct` | Opponent-side pass accuracy percentage | Bilateral circulation-quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy percentage | Net circulation-quality differential |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Counter-territory context alongside pressure absorbed |
| `opponent_touches_opposition_box` | Opponent-side touches in opposition box | Bilateral territory comparator |
| `touches_opposition_box_delta` | Triggered minus opponent touches in opposition box | Net attacking-territory differential |
