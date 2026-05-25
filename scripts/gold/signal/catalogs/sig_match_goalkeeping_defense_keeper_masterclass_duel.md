---
signal_id: sig_match_goalkeeping_defense_keeper_masterclass_duel
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Keeper Masterclass Duel"
trigger: "Both goalkeepers prevent > 1.0 goals (`expected_goals_on_target_faced - goals_conceded`) in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_match_goalkeeping_defense_keeper_masterclass_duel
  sql: clickhouse/gold/signal/sig_match_goalkeeping_defense_keeper_masterclass_duel.sql
  runner: scripts/gold/signal/runners/sig_match_goalkeeping_defense_keeper_masterclass_duel.py
---
# sig_match_goalkeeping_defense_keeper_masterclass_duel

## Purpose

Detect finished matches where both goalkeepers overperform simultaneously by preventing more than one expected on-target goal, then preserve bilateral defensive workload and control-state context for side-level interpretation.

## Tactical And Statistical Logic

- Trigger condition:
  - `home_goalkeeper_goals_prevented = expected_goals_on_target_away - away_goals > 1.0`
  - `away_goalkeeper_goals_prevented = expected_goals_on_target_home - home_goals > 1.0`
  - `match_finished = 1` with `period = 'All'`
- Match-level trigger emits two side-oriented rows (`triggered_side = 'home'` and `'away'`) at canonical `match_team` grain.
- Trigger intensity and balance are retained via:
  - `home_goalkeeper_goals_prevented_above_threshold`
  - `away_goalkeeper_goals_prevented_above_threshold`
  - `match_combined_goalkeeper_goals_prevented`
  - `match_goalkeeper_goals_prevented_balance_abs`
- Similarity gate note:
  - `sig_match_goalkeeping_defense_save_to_goal_ratio`: closest overlap on goalkeeper overperformance framing, but that trigger is save-volume normalized by total goals, not expected-goals-prevented by both keepers.
  - `sig_match_goalkeeping_defense_save_fest`: overlap on bilateral keeper workload, but trigger is combined saves `> 12`, not dual PSxG-minus-goals overperformance.
  - `sig_match_goalkeeping_defense_goalkeeper_man_of_the_match`: overlaps on standout goalkeeper narratives, but that trigger uses player ratings in low-score games rather than dual expected-goal prevention.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_goalkeeping_defense_keeper_masterclass_duel.sql`
- Runner: `scripts/gold/signal/runners/sig_match_goalkeeping_defense_keeper_masterclass_duel.py`
- Target table: `gold.sig_match_goalkeeping_defense_keeper_masterclass_duel`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_goalkeeping_defense_keeper_masterclass_duel.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for deduplication and downstream joins |
| `match_date` | Match date | Temporal slicing and reproducible backfills |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Scoreline context for goalkeeper outcome interpretation |
| `away_score` | Away full-time goals | Scoreline context for goalkeeper outcome interpretation |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity for `match_team` grain |
| `triggered_team_id` | Triggered-side team ID | Side-level identity key |
| `triggered_team_name` | Triggered-side team name | Readable triggered attribution |
| `opponent_team_id` | Opponent team ID | Bilateral comparison key |
| `opponent_team_name` | Opponent team name | Readable opponent attribution |
| `trigger_threshold_min_goalkeeper_goals_prevented` | Minimum prevented-goals threshold (`1.0`) | Explicit trigger boundary for auditability |
| `trigger_condition_both_goalkeepers_required` | Bilateral trigger-required flag (`1`) | Makes dual-keeper condition explicit |
| `home_goalkeeper_goals_prevented` | Home keeper prevented goals (`xGOT faced - goals conceded`) | Core trigger metric for home side |
| `away_goalkeeper_goals_prevented` | Away keeper prevented goals (`xGOT faced - goals conceded`) | Core trigger metric for away side |
| `match_combined_goalkeeper_goals_prevented` | Combined prevented goals by both keepers | Captures aggregate match-level shot-stopping overperformance |
| `match_goalkeeper_goals_prevented_balance_abs` | Absolute gap between keepers' prevented goals | Distinguishes balanced duels from one-sided overperformance |
| `home_goalkeeper_goals_prevented_above_threshold` | Home prevented goals above threshold | Trigger severity for home keeper |
| `away_goalkeeper_goals_prevented_above_threshold` | Away prevented goals above threshold | Trigger severity for away keeper |
| `triggered_team_goalkeeper_goals_prevented` | Triggered-side keeper prevented goals | Side-oriented core metric for analytics and modeling |
| `opponent_goalkeeper_goals_prevented` | Opponent keeper prevented goals | Bilateral comparator for keeper impact |
| `goalkeeper_goals_prevented_delta` | Triggered minus opponent prevented goals | Net keeper-overperformance differential |
| `triggered_team_expected_goals_on_target_faced` | Triggered-side expected goals on target faced | Shot-quality pressure context faced by triggered keeper |
| `opponent_expected_goals_on_target_faced` | Opponent-side expected goals on target faced | Bilateral shot-quality pressure comparator |
| `expected_goals_on_target_faced_delta` | Triggered minus opponent expected goals on target faced | Net shot-quality pressure differential |
| `triggered_team_goals_conceded` | Goals conceded by triggered side | Outcome side of prevented-goals calculation |
| `opponent_goals_conceded` | Goals conceded by opponent side | Bilateral concession comparator |
| `goals_conceded_delta` | Triggered minus opponent goals conceded | Net concession differential |
| `triggered_team_keeper_saves` | Triggered-side keeper saves | Shot-stopping workload context |
| `opponent_keeper_saves` | Opponent keeper saves | Bilateral workload comparator |
| `keeper_saves_delta` | Triggered minus opponent saves | Net keeper workload differential |
| `triggered_team_shots_on_target_faced` | Triggered-side shots on target faced | On-target pressure volume context |
| `opponent_shots_on_target_faced` | Opponent shots on target faced | Bilateral pressure-volume comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target pressure differential |
| `triggered_team_save_rate_pct` | Triggered-side save rate (%) | Normalized shot-stopping efficiency |
| `opponent_save_rate_pct` | Opponent save rate (%) | Bilateral save-efficiency comparator |
| `save_rate_delta_pct` | Triggered minus opponent save rate (pp) | Net save-efficiency gap |
| `triggered_team_total_shots_faced` | Triggered-side total shots faced | Overall defensive pressure context |
| `opponent_total_shots_faced` | Opponent total shots faced | Bilateral pressure comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net shot-pressure differential |
| `triggered_team_shot_blocks` | Triggered-side shot blocks | Defensive resistance context beyond keeper saves |
| `opponent_shot_blocks` | Opponent shot blocks | Bilateral resistance comparator |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net shot-blocking differential |
| `triggered_team_clearances` | Triggered-side clearances | Pressure-release and box-protection context |
| `opponent_clearances` | Opponent clearances | Bilateral clearance comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential |
| `triggered_team_interceptions` | Triggered-side interceptions | Anticipation and lane-denial context |
| `opponent_interceptions` | Opponent interceptions | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-state context around goalkeeper duel |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (pp) | Net control differential |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Circulation workload context |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `pass_attempt_delta` | Triggered minus opponent pass attempts | Net circulation-load differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Execution quality under defensive pressure |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Net circulation-quality differential |
| `triggered_team_goals` | Goals scored by triggered side | Scoreline contribution from triggered perspective |
| `opponent_goals` | Goals scored by opponent side | Bilateral scoreline comparator |
| `goal_delta` | Triggered minus opponent goals | Match outcome differential |
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes zero, else 0 | Separates prevented-goals overperformance from clean-sheet outcome |
