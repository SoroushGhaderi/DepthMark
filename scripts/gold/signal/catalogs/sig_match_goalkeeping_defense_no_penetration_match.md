---
signal_id: sig_match_goalkeeping_defense_no_penetration_match
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "No Penetration Match"
trigger: "Combined total touches in the opposition boxes < 15."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_goalkeeping_defense_no_penetration_match
  sql: clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_no_penetration_match.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_goalkeeping_defense_no_penetration_match

## Purpose

Detects finished matches with very low combined opposition-box touches and emits bilateral
side-oriented rows to profile defensive denial, box protection workload, and match control context.

## Tactical And Statistical Logic

- Trigger condition: `(coalesce(touches_opp_box_home, 0) + coalesce(touches_opp_box_away, 0)) < 15` from `silver.period_stat` at `period = 'All'`.
- Match-level trigger emits two rows (`triggered_side = 'home'` and `triggered_side = 'away'`) to preserve canonical `match_team` orientation.
- Trigger severity is exposed by `match_total_touches_opposition_box_below_threshold = 15 - match_total_touches_opposition_box`.
- Bilateral opposition-box context is preserved with raw counts, side share percentages, and deltas, then enriched with shot blocks, clearances, interceptions, tackles, duels, aerials, shot pressure faced, keeper output, possession, passing quality, and scoreline context.
- Similarity gate note:
  - `sig_match_goalkeeping_defense_shot_block_fest`: same entity/family/subfamily and defensive workload framing, but trigger axis is high combined shot blocks (`> 15`), not low combined opposition-box entries.
  - `sig_match_goalkeeping_defense_goalless_siege_match`: same family and bilateral defensive context, but trigger requires a 0-0 plus high-xG paradox instead of territorial penetration suppression.
  - `sig_match_possession_passing_dead_zone_game`: closest low-penetration overlap, but it belongs to possession/passing and requires both sides at exactly zero opposition-box touches.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_no_penetration_match.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_goalkeeping_defense_no_penetration_match`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_goalkeeping_defense_no_penetration_match
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for deduplication and downstream joins |
| `match_date` | Match date | Supports temporal analysis and reproducible backfills |
| `home_team_id` | Home team ID | Preserves fixture context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Preserves fixture context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Outcome context |
| `away_score` | Away full-time goals | Outcome context |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity at `match_team` grain |
| `triggered_team_id` | Triggered-side team ID | Side-level identity key |
| `triggered_team_name` | Triggered-side team name | Readable side attribution |
| `opponent_team_id` | Opponent team ID | Bilateral comparison key |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `trigger_threshold_max_combined_touches_opposition_box` | Maximum combined opposition-box touch threshold (`15`) | Explicit trigger provenance |
| `match_total_touches_opposition_box` | Combined opposition-box touches (`home + away`) | Core low-penetration trigger metric |
| `match_total_touches_opposition_box_below_threshold` | Threshold gap (`15 - combined touches`) | Trigger severity beyond binary activation |
| `match_touches_opposition_box_balance_abs` | Absolute side gap in opposition-box touches | Distinguishes balanced suppression from one-sided suppression |
| `triggered_team_touches_opposition_box` | Opposition-box touches by triggered side | Side-level penetration contribution |
| `opponent_touches_opposition_box` | Opposition-box touches by opponent side | Bilateral penetration comparator |
| `touches_opposition_box_delta` | Triggered minus opponent opposition-box touches | Net penetration differential |
| `triggered_team_touches_opposition_box_share_pct` | Triggered-side share of combined opposition-box touches (%) | Normalized penetration contribution |
| `opponent_touches_opposition_box_share_pct` | Opponent share of combined opposition-box touches (%) | Symmetric normalized comparator |
| `touches_opposition_box_share_delta_pct` | Triggered minus opponent touch share (pp) | Net normalized penetration asymmetry |
| `triggered_team_shot_blocks` | Shot blocks by triggered side | Box-protection context |
| `opponent_shot_blocks` | Shot blocks by opponent side | Bilateral block-volume comparator |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net shot-blocking differential |
| `triggered_team_clearances` | Clearances by triggered side | Danger-removal context |
| `opponent_clearances` | Clearances by opponent side | Bilateral clearance comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net release differential |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_tackles_won` | Successful tackles by triggered side | Ground-duel defensive context |
| `opponent_tackles_won` | Successful tackles by opponent side | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered minus opponent successful tackles | Net tackling differential |
| `triggered_team_duels_won` | Duels won by triggered side | Physical-control context |
| `opponent_duels_won` | Duels won by opponent side | Bilateral duel comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net duel-control differential |
| `triggered_team_aerials_won` | Aerial duels won by triggered side | Vertical-control context |
| `opponent_aerials_won` | Aerial duels won by opponent side | Bilateral aerial comparator |
| `aerials_won_delta` | Triggered minus opponent aerial wins | Net aerial differential |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive pressure denominator |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure comparator |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net shot-pressure differential |
| `triggered_team_shots_on_target_faced` | Shots on target faced by triggered side | Shot-stopping pressure context |
| `opponent_shots_on_target_faced` | Shots on target faced by opponent side | Bilateral on-target comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target pressure differential |
| `triggered_team_keeper_saves` | Goalkeeper saves by triggered side | Last-line workload context |
| `opponent_keeper_saves` | Goalkeeper saves by opponent side | Bilateral goalkeeper-workload comparator |
| `keeper_saves_delta` | Triggered minus opponent saves | Net shot-stopping workload differential |
| `triggered_team_save_rate_pct` | Triggered-side save rate (%) | Normalized shot-stopping efficiency |
| `opponent_save_rate_pct` | Opponent save rate (%) | Bilateral save-efficiency comparator |
| `save_rate_delta_pct` | Triggered minus opponent save rate (pp) | Net save-efficiency differential |
| `triggered_team_fouls_committed` | Fouls by triggered side | Discipline and aggression context |
| `opponent_fouls_committed` | Fouls by opponent side | Bilateral discipline comparator |
| `fouls_committed_delta` | Triggered minus opponent fouls | Net discipline differential |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Control-state context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (pp) | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-retention execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Net execution differential |
| `triggered_team_goals` | Goals scored by triggered side | Scoreline contribution context |
| `opponent_goals` | Goals scored by opponent side | Bilateral scoreline comparator |
| `goal_delta` | Triggered minus opponent goals | Match-outcome differential |
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes 0, else 0 | Separates low-penetration state from clean-sheet outcome |
