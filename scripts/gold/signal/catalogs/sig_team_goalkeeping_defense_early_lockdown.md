---
signal_id: sig_team_goalkeeping_defense_early_lockdown
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Early Lockdown"
trigger: "Team allows 0 opposition shots in the first 20 minutes of a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_goalkeeping_defense_early_lockdown
  sql: clickhouse/gold/signal/sig_team_goalkeeping_defense_early_lockdown.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_goalkeeping_defense_early_lockdown

## Purpose

Detect team-level opening-phase defensive suppression where a side allows zero opposition shots
through minute 20, then preserve bilateral early-window, defending, control, and outcome context.

## Tactical And Statistical Logic

- Trigger condition:
  - `opponent_first_20_total_shots = 0`
  - first-window scope uses `silver.shot.minute <= 20`
  - match eligibility requires `match_finished = 1` and `period = 'All'` for full-match context
- Rows are emitted at `match_team` grain with canonical `triggered_side`, so both sides can emit
  rows when both teams keep the opponent shotless through the opening window.
- First-window context preserves attempt volume, on-target volume, and first-shot timing, while
  full-match context captures defensive exposure (shots/xG faced, saves, blocks, clearances,
  interceptions), control (possession and pass accuracy), and final scoreline translation.
- Similarity gate note:
  - `sig_team_goalkeeping_defense_shot_blocking_unit`: same entity/family/subfamily, but trigger
    is full-match shot-block volume (`>= 10`) rather than early-window shot suppression.
  - `sig_team_goalkeeping_defense_box_evacuation`: shared defensive-resilience framing, but that
    trigger is high opposition box pressure with clean sheet, not first-20 shot denial.
  - `sig_team_goalkeeping_defense_offside_trap_mastery`: same family but distinct trigger axis
    (offsides caught vs zero shots allowed in opening minutes).

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_goalkeeping_defense_early_lockdown.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_goalkeeping_defense_early_lockdown`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_goalkeeping_defense_early_lockdown
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for joins, deduplication, and QA |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills |
| `home_team_id` | Home team identifier | Preserves fixture context |
| `home_team_name` | Home team name | Analyst-readable fixture attribution |
| `away_team_id` | Away team identifier | Preserves fixture context |
| `away_team_name` | Away team name | Analyst-readable fixture attribution |
| `home_score` | Full-time home goals | Outcome context for interpreting early suppression |
| `away_score` | Full-time away goals | Outcome context for interpreting early suppression |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side orientation for `match_team` grain |
| `triggered_team_id` | Triggered team identifier | Stable identity for the triggered side |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Readable opponent attribution |
| `trigger_window_minutes` | Opening trigger window in minutes (`20`) | Explicit temporal trigger boundary for reproducibility |
| `trigger_threshold_max_opponent_shots_first_20` | Maximum allowed opponent shots in window (`0`) | Explicit trigger threshold provenance |
| `match_first_20_total_shots` | Combined shots by both teams in minutes 1-20 | Match-level opening shot environment context |
| `triggered_team_first_20_total_shots` | Triggered-side shots in minutes 1-20 | Offensive output while maintaining defensive lockdown |
| `opponent_first_20_total_shots` | Opponent shots in minutes 1-20 | Core trigger metric |
| `first_20_shots_delta` | Triggered minus opponent shots in minutes 1-20 | Net opening-shot dominance indicator |
| `match_first_20_total_shots_on_target` | Combined on-target shots by both teams in minutes 1-20 | Opening precision-pressure context |
| `triggered_team_first_20_shots_on_target` | Triggered-side on-target shots in minutes 1-20 | Early attacking precision context |
| `opponent_first_20_shots_on_target` | Opponent on-target shots in minutes 1-20 | Opening shot-stopping pressure baseline |
| `first_20_shots_on_target_delta` | Triggered minus opponent on-target shots in minutes 1-20 | Net early precision-pressure differential |
| `match_first_20_first_shot_minute` | Earliest shot minute by either side in minutes 1-20 | Tempo diagnostic for first chance creation |
| `triggered_team_first_20_first_shot_minute` | Triggered-side earliest shot minute in minutes 1-20 | Triggered-side opening-tempo context |
| `opponent_first_20_first_shot_minute` | Opponent earliest shot minute in minutes 1-20 | Confirms and explains shotless-opponent trigger state |
| `triggered_team_total_shots_faced` | Full-match total shots faced by triggered side | Defensive workload denominator beyond opening phase |
| `opponent_total_shots_faced` | Full-match total shots faced by opponent side | Bilateral defensive workload comparator |
| `total_shots_faced_delta` | Triggered minus opponent full-match shots faced | Net defensive-exposure differential |
| `triggered_team_shots_on_target_faced` | Full-match shots on target faced by triggered side | Shot-stopping pressure context |
| `opponent_shots_on_target_faced` | Full-match shots on target faced by opponent side | Bilateral pressure comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent full-match shots on target faced | Net on-target exposure differential |
| `triggered_team_expected_goals_faced` | Full-match xG faced by triggered side | Chance-quality-against context |
| `opponent_expected_goals_faced` | Full-match xG faced by opponent side | Bilateral chance-quality comparator |
| `expected_goals_faced_delta` | Triggered minus opponent full-match xG faced | Net chance-quality-against differential |
| `triggered_team_keeper_saves` | Goalkeeper saves by triggered side | Last-line workload context |
| `opponent_keeper_saves` | Goalkeeper saves by opponent side | Bilateral goalkeeper-workload comparator |
| `keeper_saves_delta` | Triggered minus opponent goalkeeper saves | Net last-line workload differential |
| `triggered_team_shot_blocks` | Shot blocks by triggered side | Box-protection context |
| `opponent_shot_blocks` | Shot blocks by opponent side | Bilateral box-protection comparator |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net block-volume differential |
| `triggered_team_clearances` | Clearances by triggered side | Pressure-release context |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_possession_pct` | Triggered-side possession percentage | Control-state context |
| `opponent_possession_pct` | Opponent-side possession percentage | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession percentage | Net control-share differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy percentage | Ball-retention execution context |
| `opponent_pass_accuracy_pct` | Opponent-side pass accuracy percentage | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy percentage | Net circulation-quality differential |
| `triggered_team_goals` | Goals scored by triggered side | Result-translation context |
| `opponent_goals` | Goals scored by opponent side | Bilateral outcome context |
| `goal_delta` | Triggered minus opponent goals | Compact result differential |
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes 0, else 0 | Separates opening suppression from full-match clean-sheet outcome |
