---
signal_id: sig_match_goalkeeping_defense_unproductive_attack
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Unproductive Attack Punished"
trigger: "Opponent records >= 25 shots, triggered side records >= 15 shot blocks, and triggered side wins in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_goalkeeping_defense_unproductive_attack
  sql: clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_unproductive_attack.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_goalkeeping_defense_unproductive_attack

## Purpose

Detect defensive wins where one side absorbs very high shot volume, blocks an extreme number of attempts, and still wins, then preserve bilateral context to explain how attacking pressure became unproductive.

## Tactical And Statistical Logic

- Trigger condition for each side at `period = 'All'`:
  - opponent total shots `>= 25`
  - triggered-side shot blocks `>= 15`
  - triggered side wins (`triggered_team_goals > opponent_goals`)
- Rows are emitted at canonical `match_team` grain with `triggered_side` (`home` or `away`), but only the winning defensive side can trigger in a match.
- Trigger severity is explicit through `triggered_team_shot_blocks_above_threshold = triggered_team_shot_blocks - 15`.
- Enrichment preserves bilateral diagnostics for pressure faced, shot-block and save efficiency, defensive actions, control state, passing execution, and outcome.
- Similarity gate note:
  - `sig_match_goalkeeping_defense_shot_block_fest`: closest defensive block overlap, but that signal is match-triggered on combined blocks (`home + away > 15`) and does not require win or high opponent shot volume.
  - `sig_match_shooting_goals_unproductive_dominance`: closest unproductive-attack framing, but that signal triggers the attacking side on high shots with zero big chances, not the winning defensive side on shot blocks.
  - `sig_team_goalkeeping_defense_low_block_success`: same family/subfamily and defensive workload context, but trigger axis is interception volume rather than high-opponent-shots plus high blocks plus win.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_unproductive_attack.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_goalkeeping_defense_unproductive_attack`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_goalkeeping_defense_unproductive_attack
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable deduplication key and downstream join anchor |
| `match_date` | Match date | Enables reproducible backfills and temporal analysis |
| `home_team_id` | Home team ID | Preserves fixture context for bilateral interpretation |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Preserves fixture context for bilateral interpretation |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Outcome context for trigger interpretation |
| `away_score` | Away full-time goals | Outcome context for trigger interpretation |
| `triggered_side` | Triggered row orientation (`home` or `away`) | Canonical row identity at `match_team` grain |
| `triggered_team_id` | Triggered-side team ID | Stable triggered-side identifier |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team ID | Bilateral comparison identifier |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator |
| `trigger_threshold_min_opponent_total_shots` | Configured opponent shot threshold (`25`) | Makes high-pressure trigger boundary explicit |
| `trigger_threshold_min_triggered_team_shot_blocks` | Configured triggered-side block threshold (`15`) | Makes defensive-output trigger boundary explicit |
| `trigger_condition_triggered_team_win_required` | Win requirement flag (`1`) | Documents mandatory result condition |
| `triggered_team_shot_blocks` | Shot blocks by triggered side | Core defensive trigger metric |
| `opponent_shot_blocks` | Shot blocks by opponent side | Bilateral block-volume comparator |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net block-volume differential |
| `triggered_team_shot_blocks_above_threshold` | Triggered-side shot blocks above threshold (`value - 15`) | Quantifies trigger severity |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive pressure denominator and core trigger component |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net pressure-exposure differential |
| `triggered_team_shots_on_target_faced` | Shots on target faced by triggered side | Direct keeper-pressure context |
| `opponent_shots_on_target_faced` | Shots on target faced by opponent side | Bilateral on-target pressure comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target exposure differential |
| `triggered_team_shot_block_rate_pct` | Triggered-side blocks per shot faced (%) | Normalized resistance efficiency under pressure |
| `opponent_shot_block_rate_pct` | Opponent blocks per shot faced (%) | Symmetric efficiency comparator |
| `shot_block_rate_delta_pct` | Triggered minus opponent shot-block rate (pp) | Net normalized block-efficiency gap |
| `triggered_team_keeper_saves` | Saves by triggered-side goalkeeper | Last-line defensive workload context |
| `opponent_keeper_saves` | Saves by opponent goalkeeper | Bilateral goalkeeper workload comparator |
| `keeper_saves_delta` | Triggered minus opponent saves | Net goalkeeper workload differential |
| `triggered_team_save_rate_pct` | Triggered-side save rate (%) | Normalized shot-stopping effectiveness |
| `opponent_save_rate_pct` | Opponent save rate (%) | Bilateral save-effectiveness comparator |
| `save_rate_delta_pct` | Triggered minus opponent save rate (pp) | Net shot-stopping efficiency differential |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_clearances` | Clearances by triggered side | Pressure-release and danger-removal context |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net danger-removal differential |
| `triggered_team_tackles_won` | Successful tackles by triggered side | Ground-defense output context |
| `opponent_tackles_won` | Successful tackles by opponent side | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered minus opponent successful tackles | Net tackling differential |
| `triggered_team_duels_won` | Duels won by triggered side | Physical contest context |
| `opponent_duels_won` | Duels won by opponent side | Bilateral physical comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net contest-control differential |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-state context around defensive strategy |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (pp) | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-retention execution context under pressure |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation-quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Net execution-quality differential |
| `triggered_team_goals` | Goals scored by triggered side | Result contribution from defensive winner |
| `opponent_goals` | Goals scored by opponent side | Bilateral result context |
| `goal_delta` | Triggered minus opponent goals | Outcome differential from triggered perspective |
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes zero goals, else 0 | Separates blocked-pressure wins with/without clean sheets |
| `opponent_shot_accuracy_pct` | Opponent on-target rate (%) | Quantifies attacking precision of the high-volume shooter |
| `opponent_shot_conversion_pct` | Opponent goals per shot (%) | Quantifies finishing failure in the unproductive attack |
| `opponent_expected_goals` | Opponent expected goals total | Chance-quality baseline behind shot volume |
| `opponent_expected_goals_on_target` | Opponent expected goals on target total | On-target chance-severity baseline for keeper/blocks context |
