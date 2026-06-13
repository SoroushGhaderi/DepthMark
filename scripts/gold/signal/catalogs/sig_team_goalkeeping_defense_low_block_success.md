---
signal_id: sig_team_goalkeeping_defense_low_block_success
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Low Block Success"
trigger: "Team records >= 20 interceptions in own defensive third proxy in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_goalkeeping_defense_low_block_success
  sql: clickhouse/gold/signal/sig_team_goalkeeping_defense_low_block_success.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_goalkeeping_defense_low_block_success

## Purpose

Detect team-level low-block success profiles via very high interception volume in deep defending context, then retain bilateral pressure, control, and result context for interpretation.

## Tactical And Statistical Logic

- Trigger condition:
  - `match_finished = 1`
  - `triggered_team_interceptions_in_own_defensive_third_proxy >= 20`
- Data-availability note:
  - current `silver.period_stat` does not expose zone-split interceptions by defensive third
  - this signal therefore uses full-match team interceptions as the explicit `own_defensive_third_proxy`
- Rows are emitted at `match_team` grain with canonical `triggered_side`, so both teams can trigger in one match when both satisfy the threshold.
- Trigger intensity is captured by `triggered_team_interceptions_proxy_above_threshold` and enriched with bilateral deltas for shots faced, saves, xG against, clearances, tackles, blocks, duels, possession, passing, and scoreline outcomes.
- Similarity gate note:
  - `sig_team_goalkeeping_defense_tackle_volume_surge`: same entity/family/subfamily and defensive-volume framing, but trigger axis is tackles won (`>= 25`) rather than interception-pressure proxy.
  - `sig_team_goalkeeping_defense_clearance_barrage`: same family and pressure-context style, but trigger axis is clearances (`>= 40`) not interceptions.
  - `sig_team_goalkeeping_defense_parking_the_bus`: adjacent low-block tactical framing, but trigger is low-possession winning plus clearances, not interception-threshold activation.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_goalkeeping_defense_low_block_success.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_goalkeeping_defense_low_block_success`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_goalkeeping_defense_low_block_success
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for downstream joins and deduplication |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills |
| `home_team_id` | Home team identifier | Preserves bilateral fixture orientation |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team identifier | Preserves bilateral fixture orientation |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Scoreline context for low-block interpretation |
| `away_score` | Away full-time goals | Scoreline context for low-block interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered team identifier | Stable triggered-side key |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Readable opponent attribution |
| `trigger_threshold_min_interceptions_in_own_defensive_third_proxy` | Trigger threshold (`20`) | Explicit trigger provenance and auditability |
| `triggered_team_interceptions_in_own_defensive_third_proxy` | Triggered-side interception count in own-defensive-third proxy | Core trigger metric with explicit data-availability semantics |
| `opponent_interceptions_in_own_defensive_third_proxy` | Opponent interception count in same proxy definition | Bilateral proxy comparator |
| `interceptions_in_own_defensive_third_proxy_delta` | Triggered minus opponent interception proxy | Net low-block interception-pressure differential |
| `triggered_team_interceptions_proxy_above_threshold` | Triggered interception proxy above threshold (`value - 20`) | Trigger severity beyond activation boundary |
| `triggered_team_interceptions` | Triggered-side full-match interceptions | Canonical interception baseline for downstream compatibility |
| `opponent_interceptions` | Opponent full-match interceptions | Bilateral interception baseline |
| `interceptions_delta` | Triggered minus opponent interceptions | Net interception differential |
| `triggered_team_clearances` | Triggered-side clearances | Pressure-release context |
| `opponent_clearances` | Opponent clearances | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential |
| `triggered_team_tackles_won` | Triggered-side successful tackles | Ground-duel defensive output context |
| `opponent_tackles_won` | Opponent successful tackles | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered minus opponent successful tackles | Net tackling differential |
| `triggered_team_shot_blocks` | Triggered-side shot blocks | Box-protection context |
| `opponent_shot_blocks` | Opponent shot blocks | Bilateral block-volume comparator |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net block-volume differential |
| `triggered_team_duels_won` | Triggered-side duels won | Physical-control context |
| `opponent_duels_won` | Opponent duels won | Bilateral physical-control comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net contest-control differential |
| `triggered_team_total_shots_faced` | Triggered-side total shots faced | Defensive pressure denominator |
| `opponent_total_shots_faced` | Opponent total shots faced | Bilateral pressure baseline |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net defensive-exposure differential |
| `triggered_team_shots_on_target_faced` | Triggered-side shots on target faced | Precision pressure context |
| `opponent_shots_on_target_faced` | Opponent shots on target faced | Bilateral precision-pressure comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target exposure differential |
| `triggered_team_keeper_saves` | Triggered-side goalkeeper saves | Last-line defensive workload context |
| `opponent_keeper_saves` | Opponent goalkeeper saves | Bilateral keeper-workload comparator |
| `keeper_saves_delta` | Triggered minus opponent goalkeeper saves | Net keeper-workload differential |
| `triggered_team_expected_goals_faced` | Triggered-side expected goals faced | Chance-quality-against baseline |
| `opponent_expected_goals_faced` | Opponent expected goals faced | Bilateral chance-quality comparator |
| `expected_goals_faced_delta` | Triggered minus opponent expected goals faced | Net chance-quality-against differential |
| `triggered_team_expected_goals_on_target_faced` | Triggered-side expected goals on target faced | On-target chance-severity context |
| `opponent_expected_goals_on_target_faced` | Opponent expected goals on target faced | Bilateral on-target severity comparator |
| `expected_goals_on_target_faced_delta` | Triggered minus opponent expected goals on target faced | Net on-target chance-severity differential |
| `triggered_team_fouls` | Triggered-side fouls committed | Discipline trade-off context |
| `opponent_fouls` | Opponent fouls committed | Bilateral discipline comparator |
| `fouls_delta` | Triggered minus opponent fouls | Net discipline differential |
| `triggered_team_possession_pct` | Triggered-side possession percentage | Control-state context for low-block interpretation |
| `opponent_possession_pct` | Opponent possession percentage | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession percentage | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy percentage | Circulation-quality context under pressure |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy percentage | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy percentage | Net execution differential |
| `triggered_team_goals` | Goals scored by triggered side | Result translation context |
| `opponent_goals` | Goals scored by opponent side | Bilateral result context |
| `goal_delta` | Triggered minus opponent goals | Outcome differential context |
| `triggered_team_clean_sheet_flag` | 1 when triggered side keeps clean sheet | Distinguishes interception-pressure output with/without clean-sheet outcome |
