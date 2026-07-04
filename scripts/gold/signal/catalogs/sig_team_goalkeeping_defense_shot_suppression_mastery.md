---
signal_id: sig_team_goalkeeping_defense_shot_suppression_mastery
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Shot Suppression Mastery"
trigger: "Opposition average xG per shot faced is < 0.05 in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_goalkeeping_defense_shot_suppression_mastery
  sql: clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_shot_suppression_mastery.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_goalkeeping_defense_shot_suppression_mastery

## Purpose

Detect team-level defensive structures that force very low-quality opposition shooting
(opposition xG per shot faced below `0.05`) in finished matches, while preserving bilateral
pressure, duel, control, and scoreline context.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_opposition_average_expected_goals_per_shot < 0.05`
  - `triggered_team_total_shots_faced > 0` (avoid zero-shot denominator artifacts)
  - finished-match scope (`match_finished = 1`) with full-match context (`period = 'All'`)
- Core trigger metric is computed as:
  - `opposition_expected_goals / opposition_total_shots`
  - from `silver.period_stat` with home/away orientation mapped into `triggered_side`
- Rows are emitted at `match_team` grain with canonical `triggered_side`, so either side can
  trigger in different matches when it suppresses opposition shot quality below the threshold.
- Trigger severity is preserved with
  `triggered_team_opposition_average_expected_goals_per_shot_below_threshold`.
- Similarity gate note:
  - `sig_team_goalkeeping_defense_unbroken_structure`: same family and suppression framing, but
    trigger axis is low inside-box shot volume allowed (`<= 3`), not low xG per shot faced.
  - `sig_team_goalkeeping_defense_early_lockdown`: same defensive denial theme, but trigger is
    first-20-minute shot suppression rather than full-match shot-quality suppression.
  - `sig_team_goalkeeping_defense_clean_sheet_efficiency`: same goalkeeping-defense family with
    save/load context, but trigger is clean sheet under high on-target volume, not per-shot xG cap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_shot_suppression_mastery.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_goalkeeping_defense_shot_suppression_mastery`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_goalkeeping_defense_shot_suppression_mastery
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for deduplication and downstream joins |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills |
| `home_team_id` | Home team ID | Preserves bilateral fixture context |
| `home_team_name` | Home team name | Readable fixture attribution |
| `away_team_id` | Away team ID | Preserves bilateral fixture context |
| `away_team_name` | Away team name | Readable fixture attribution |
| `home_score` | Home full-time goals | Outcome context for suppression interpretation |
| `away_score` | Away full-time goals | Outcome context for suppression interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered team ID | Stable triggered-side identifier |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Readable opponent attribution |
| `trigger_threshold_max_opposition_average_expected_goals_per_shot` | Maximum allowed opposition xG per shot threshold (`0.05`) | Explicit trigger-rule provenance |
| `triggered_team_opposition_average_expected_goals_per_shot` | Average xG per opposition shot faced by triggered side | Core trigger metric |
| `opponent_opposition_average_expected_goals_per_shot` | Opponent-side average xG per opposition shot faced | Bilateral shot-quality-suppression comparator |
| `opposition_average_expected_goals_per_shot_delta` | Triggered minus opponent opposition xG-per-shot faced | Net shot-quality-suppression differential |
| `triggered_team_opposition_average_expected_goals_per_shot_below_threshold` | Headroom below threshold (`0.05 - value`) | Trigger severity beyond binary activation |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive pressure denominator |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure-volume comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net shot-volume pressure differential |
| `triggered_team_shots_on_target_faced` | Shots on target faced by triggered side | On-target pressure context |
| `opponent_shots_on_target_faced` | Shots on target faced by opponent side | Bilateral on-target pressure comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target exposure differential |
| `triggered_team_shot_accuracy_faced_pct` | On-target share of shots faced by triggered side (%) | Normalized shot precision allowed |
| `opponent_shot_accuracy_faced_pct` | On-target share of shots faced by opponent side (%) | Bilateral precision-allowed comparator |
| `shot_accuracy_faced_delta_pct` | Triggered minus opponent shot-accuracy faced (pp) | Net precision-allowed differential |
| `triggered_team_keeper_saves` | Triggered-side goalkeeper saves | Last-line defensive workload context |
| `opponent_keeper_saves` | Opponent-side goalkeeper saves | Bilateral keeper-workload comparator |
| `keeper_saves_delta` | Triggered minus opponent goalkeeper saves | Net goalkeeper-workload differential |
| `triggered_team_save_rate_pct` | Triggered-side save rate (%) | Normalized shot-stopping efficiency |
| `opponent_save_rate_pct` | Opponent-side save rate (%) | Bilateral save-efficiency comparator |
| `save_rate_delta_pct` | Triggered minus opponent save rate (pp) | Net save-efficiency differential |
| `triggered_team_expected_goals_faced` | xG faced by triggered side | Chance-quality-against context |
| `opponent_expected_goals_faced` | xG faced by opponent side | Bilateral chance-quality comparator |
| `expected_goals_faced_delta` | Triggered minus opponent xG faced | Net chance-quality-against differential |
| `triggered_team_shot_blocks` | Shot blocks by triggered side | Box-protection workload context |
| `opponent_shot_blocks` | Shot blocks by opponent side | Bilateral block-volume comparator |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net block-volume differential |
| `triggered_team_clearances` | Clearances by triggered side | Pressure-release context |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_tackles_won` | Tackles won by triggered side | Ground-defense action context |
| `opponent_tackles_won` | Tackles won by opponent side | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net tackling differential |
| `triggered_team_duels_won` | Duels won by triggered side | Physical-control context |
| `opponent_duels_won` | Duels won by opponent side | Bilateral physical-control comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net contest-control differential |
| `triggered_team_aerials_won` | Aerial duels won by triggered side | Vertical-control context |
| `opponent_aerials_won` | Aerial duels won by opponent side | Bilateral aerial-control comparator |
| `aerials_won_delta` | Triggered minus opponent aerial wins | Net aerial-control differential |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-state context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession (pp) | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-retention execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Net circulation-quality differential |
| `triggered_team_goals` | Goals scored by triggered side | Result context |
| `opponent_goals` | Goals scored by opponent side | Bilateral outcome context |
| `goal_delta` | Triggered minus opponent goals | Compact match-result differential |
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes 0, else 0 | Separates shot-quality suppression from clean-sheet outcome |
