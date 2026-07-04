---
signal_id: sig_match_goalkeeping_defense_goalless_siege_match
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Goalless Siege Match"
trigger: "One team has > 2.5 xG but both goalkeepers keep a clean sheet (0-0)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_goalkeeping_defense_goalless_siege_match
  sql: clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_goalless_siege_match.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_match_goalkeeping_defense_goalless_siege_match

## Purpose

Detects goalkeeper-driven 0-0 stalemates where at least one side produces elite chance quality (`xG > 2.5`), then preserves bilateral defensive and control context for tactical diagnosis.

## Tactical And Statistical Logic

- Trigger condition:
  - `coalesce(home_score, 0) = 0`
  - `coalesce(away_score, 0) = 0`
  - `coalesce(expected_goals_home, 0) > 2.5 OR coalesce(expected_goals_away, 0) > 2.5`
  - all from finished matches at `period = 'All'`.
- Output is side-triggered at `match_team` grain: each side that satisfies `xG > 2.5` emits one row via `triggered_side`.
- If both teams exceed `2.5` xG, both sides emit rows; otherwise only the high-xG side emits.
- Enrichment retains bilateral shot-stopping, defensive-action, pressure, possession, passing, and scoreline diagnostics.
- Similarity gate note:
  - `sig_match_goalkeeping_defense_save_fest`: same match-goalkeeping-defense scope, but its trigger is combined save volume (`> 12`) rather than high-xG goalless contradiction.
  - `sig_match_shooting_goals_goalless_siege`: same 0-0 siege framing, but triggered by shot volume (`>= 25 shots`) not extreme xG (`> 2.5`) and goalkeeper-resistance context.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_goalless_siege_match.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_match_goalkeeping_defense_goalless_siege_match`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_match_goalkeeping_defense_goalless_siege_match
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for joins and deduplication |
| `match_date` | Match date | Supports partitioning and time slicing |
| `home_team_id` | Home team ID | Preserves fixture orientation |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team ID | Preserves fixture orientation |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Validates 0-0 trigger condition |
| `away_score` | Away full-time goals | Validates 0-0 trigger condition |
| `triggered_side` | Row orientation (`home` or `away`) | Canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered-side team ID | Stable triggered team key |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side context |
| `opponent_team_id` | Opponent team ID | Bilateral comparator key |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `trigger_threshold_min_team_xg` | Configured xG threshold (`2.5`) | Explicit trigger provenance |
| `trigger_condition_goalless_required` | Goalless-condition flag (`1`) | Documents mandatory 0-0 condition in-row |
| `match_total_goals` | Combined match goals | Confirms goalless match state |
| `match_total_xg` | Combined expected goals | Match-level chance-quality baseline |
| `home_team_clean_sheet_flag` | Home clean-sheet flag | Makes bilateral clean-sheet state explicit |
| `away_team_clean_sheet_flag` | Away clean-sheet flag | Makes bilateral clean-sheet state explicit |
| `both_teams_clean_sheet_flag` | Flag when both teams keep clean sheets | Captures core goalkeeper-outcome paradox context |
| `triggered_team_meets_xg_threshold` | Triggered-side `xG > 2.5` flag | Direct trigger integrity check |
| `opponent_team_meets_xg_threshold` | Opponent `xG > 2.5` flag | Shows bilateral threshold coverage |
| `both_teams_meet_xg_threshold` | Flag when both sides exceed threshold | Distinguishes one-sided vs bilateral siege intensity |
| `triggered_team_xg` | Triggered-side expected goals | Core side-level chance-quality trigger metric |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent xG | Net chance-generation differential |
| `triggered_team_xg_above_threshold` | Triggered-side xG above `2.5` | Trigger severity beyond activation boundary |
| `opponent_team_xg_above_threshold` | Opponent xG above `2.5` (floored at `0`) | Bilateral threshold-excess context |
| `triggered_team_keeper_saves` | Triggered-side keeper saves | Shot-stopping workload/output context |
| `opponent_keeper_saves` | Opponent keeper saves | Bilateral shot-stopping comparator |
| `keeper_saves_delta` | Triggered minus opponent saves | Net keeper-workload differential |
| `triggered_team_shots_on_target_faced` | Shots on target faced by triggered side | Direct save-workload denominator context |
| `opponent_shots_on_target_faced` | Shots on target faced by opponent | Bilateral pressure comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target pressure differential |
| `triggered_team_save_rate_pct` | Triggered-side save rate (%) | Normalized shot-stopping efficiency |
| `opponent_save_rate_pct` | Opponent save rate (%) | Bilateral efficiency comparator |
| `save_rate_delta_pct` | Triggered minus opponent save rate (pp) | Directional save-efficiency differential |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Broader defensive pressure context |
| `opponent_total_shots_faced` | Total shots faced by opponent | Bilateral pressure comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net shot-pressure differential |
| `triggered_team_expected_goals_conceded` | Expected goals conceded by triggered side | Chance-quality exposure against triggered defense |
| `opponent_expected_goals_conceded` | Expected goals conceded by opponent | Bilateral exposure comparator |
| `expected_goals_conceded_delta` | Triggered minus opponent expected goals conceded | Net expected-goals-against differential |
| `triggered_team_shot_blocks` | Triggered-side shot blocks | Box-protection context |
| `opponent_shot_blocks` | Opponent shot blocks | Bilateral block-volume comparator |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net shot-blocking differential |
| `triggered_team_clearances` | Triggered-side clearances | Danger-removal workload context |
| `opponent_clearances` | Opponent clearances | Bilateral clearance comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net clearance differential |
| `triggered_team_interceptions` | Triggered-side interceptions | Defensive anticipation context |
| `opponent_interceptions` | Opponent interceptions | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_tackles_won` | Triggered-side successful tackles | Ground-duel defensive output context |
| `opponent_tackles_won` | Opponent successful tackles | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered minus opponent successful tackles | Net tackling differential |
| `triggered_team_duels_won` | Triggered-side duels won | Physical contest context |
| `opponent_duels_won` | Opponent duels won | Bilateral contest comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net duel differential |
| `triggered_team_aerials_won` | Triggered-side aerial duels won | Vertical contest context |
| `opponent_aerials_won` | Opponent aerial duels won | Bilateral aerial comparator |
| `aerials_won_delta` | Triggered minus opponent aerials won | Net aerial differential |
| `triggered_team_fouls_committed` | Fouls committed by triggered side | Discipline/aggression context |
| `opponent_fouls_committed` | Fouls committed by opponent | Bilateral discipline comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls | Net discipline differential |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (pp) | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Technical execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Net circulation-quality differential |
| `triggered_team_goals` | Goals scored by triggered side | Scoreline context from triggered perspective |
| `opponent_goals` | Goals scored by opponent | Bilateral scoreline comparator |
| `goal_delta` | Triggered minus opponent goals | Outcome differential |
| `triggered_team_clean_sheet_flag` | Triggered-side clean-sheet flag | Side-level clean-sheet integrity check |
| `opponent_clean_sheet_flag` | Opponent clean-sheet flag | Bilateral clean-sheet comparator |
