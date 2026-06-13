---
signal_id: sig_team_goalkeeping_defense_unbroken_structure
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Unbroken Structure"
trigger: "Team allows <= 3 shots from inside the box in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_goalkeeping_defense_unbroken_structure
  sql: clickhouse/gold/signal/sig_team_goalkeeping_defense_unbroken_structure.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_goalkeeping_defense_unbroken_structure

## Purpose

Detect team-level structural defensive performances where a side limits the opponent to at most
three inside-box shots in a finished match, then preserve bilateral defensive, control, and
scoreline context.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_shots_inside_box_allowed <= 3`
  - finished-match scope (`match_finished = 1`) with full-match context (`period = 'All'`)
  - inside-box scope is computed from `silver.shot` using `is_from_inside_box = 1` and `is_own_goal = 0`
- Side interpretation note:
  - this is a defense-oriented signal; “shots allowed” for the triggered side are sourced from the
    opponent's inside-box shot output.
- Rows are emitted at `match_team` grain with canonical `triggered_side`, so both sides can trigger
  in low-penetration matches.
- Trigger severity is preserved with `triggered_team_shots_inside_box_allowed_below_threshold`.
- Similarity gate note:
  - `sig_team_goalkeeping_defense_early_lockdown`: same family and suppression framing, but trigger is
    opening-window (`<=20` minutes) all-shot denial, not full-match inside-box suppression.
  - `sig_team_goalkeeping_defense_box_evacuation`: same family with “allowed” semantics, but that
    signal is high box-pressure absorption (`>=50` opposition box touches) plus clean sheet; this one
    is low inside-box shot allowance with no clean-sheet requirement.
  - `sig_team_shooting_goals_no_shots_allowed`: closest metric overlap in suppression intent, but it
    belongs to shooting family and focuses on shots on target allowed = 0 rather than inside-box shot
    volume allowed <= 3.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_goalkeeping_defense_unbroken_structure.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_goalkeeping_defense_unbroken_structure`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_goalkeeping_defense_unbroken_structure
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
| `home_score` | Home full-time goals | Outcome context for structural defense interpretation |
| `away_score` | Away full-time goals | Outcome context for structural defense interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered team ID | Stable triggered-side identifier |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Readable opponent attribution |
| `trigger_threshold_max_shots_inside_box_allowed` | Maximum inside-box shots allowed threshold (`3`) | Explicit trigger-rule provenance |
| `triggered_team_shots_inside_box_allowed` | Opponent inside-box shots against triggered side | Core trigger metric |
| `opponent_shots_inside_box_allowed` | Inside-box shots allowed by opponent side | Bilateral suppression comparator |
| `shots_inside_box_allowed_delta` | Triggered minus opponent inside-box shots allowed | Net box-protection differential |
| `triggered_team_shots_inside_box_allowed_below_threshold` | Trigger headroom (`3 - triggered_team_shots_inside_box_allowed`) | Trigger severity beyond binary activation |
| `triggered_team_inside_box_shots_on_target_allowed` | Opponent inside-box shots on target against triggered side | Precision pressure allowed inside box |
| `opponent_inside_box_shots_on_target_allowed` | Opponent-side equivalent on-target inside-box shots allowed | Bilateral precision-pressure comparator |
| `inside_box_shots_on_target_allowed_delta` | Triggered minus opponent inside-box shots on target allowed | Net inside-box precision pressure differential |
| `triggered_team_inside_box_shot_on_target_allowed_pct` | On-target share of inside-box shots allowed by triggered side (%) | Normalized inside-box defensive quality metric |
| `opponent_inside_box_shot_on_target_allowed_pct` | Opponent-side on-target share of inside-box shots allowed (%) | Bilateral normalized comparator |
| `inside_box_shot_on_target_allowed_delta_pct` | Triggered minus opponent on-target-allowed share (pp) | Net inside-box shot-quality suppression gap |
| `triggered_team_inside_box_goals_allowed` | Opponent goals from inside-box shots against triggered side | Outcome severity of box entries allowed |
| `opponent_inside_box_goals_allowed` | Opponent-side inside-box goals allowed | Bilateral outcome comparator |
| `inside_box_goals_allowed_delta` | Triggered minus opponent inside-box goals allowed | Net inside-box concession differential |
| `triggered_team_inside_box_expected_goals_allowed` | Opponent inside-box xG against triggered side | Chance-quality-against context in box |
| `opponent_inside_box_expected_goals_allowed` | Opponent-side inside-box xG allowed | Bilateral chance-quality comparator |
| `inside_box_expected_goals_allowed_delta` | Triggered minus opponent inside-box xG allowed | Net inside-box chance-quality-against differential |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive pressure denominator |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure baseline |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net defensive exposure differential |
| `triggered_team_shots_on_target_faced` | Shots on target faced by triggered side | Shot-stopping pressure context |
| `opponent_shots_on_target_faced` | Shots on target faced by opponent side | Bilateral shot-stopping pressure comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target pressure differential |
| `triggered_team_keeper_saves` | Triggered-side goalkeeper saves | Last-line defensive workload context |
| `opponent_keeper_saves` | Opponent-side goalkeeper saves | Bilateral keeper-workload comparator |
| `keeper_saves_delta` | Triggered minus opponent goalkeeper saves | Net goalkeeper workload differential |
| `triggered_team_save_rate_pct` | Triggered-side goalkeeper save rate (%) | Normalized shot-stopping effectiveness |
| `opponent_save_rate_pct` | Opponent-side goalkeeper save rate (%) | Bilateral save-effectiveness comparator |
| `save_rate_delta_pct` | Triggered minus opponent save rate (pp) | Net save-efficiency differential |
| `triggered_team_expected_goals_faced` | xG faced by triggered side | Full-match chance-quality-against baseline |
| `opponent_expected_goals_faced` | xG faced by opponent side | Bilateral chance-quality comparator |
| `expected_goals_faced_delta` | Triggered minus opponent xG faced | Net chance-quality-against differential |
| `triggered_team_shot_blocks` | Shot blocks by triggered side | Box-protection workload context |
| `opponent_shot_blocks` | Shot blocks by opponent side | Bilateral block-volume comparator |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net block-volume differential |
| `triggered_team_clearances` | Clearances by triggered side | Pressure-release context |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net release differential |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_tackles_won` | Tackles won by triggered side | Ground-defense action context |
| `opponent_tackles_won` | Tackles won by opponent side | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net tackling differential |
| `triggered_team_duels_won` | Duels won by triggered side | Physical-control context |
| `opponent_duels_won` | Duels won by opponent side | Bilateral physical comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net physical-control differential |
| `triggered_team_aerials_won` | Aerial duels won by triggered side | Vertical-control context |
| `opponent_aerials_won` | Aerial duels won by opponent side | Bilateral aerial comparator |
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
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes 0, else 0 | Separates low box-allowance from clean-sheet outcome |
