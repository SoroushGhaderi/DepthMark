---
signal_id: sig_team_goalkeeping_defense_wing_lockdown_collective
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Wing Lockdown Collective"
trigger: "Fullbacks and wingers combine for >= 15 tackles in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_goalkeeping_defense_wing_lockdown_collective
  sql: clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_wing_lockdown_collective.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_goalkeeping_defense_wing_lockdown_collective

## Purpose

Detect team-level wing-lane defensive intensity matches where fullback and winger role proxies combine for extreme tackle output, while preserving bilateral defensive workload, control, and result context.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_fullbacks_and_wingers_tackles_won >= 15`
  - finished-match scope (`match_finished = 1`) with full-match context (`period = 'All'`)
- Role-gating implementation:
  - fullback proxy: `usual_playing_position_id = 1` and `position_id IN (2, 5)`
  - winger proxy: `usual_playing_position_id = 3` and `position_id IN (2, 4)`
  - player stats from `silver.player_match_stat` and position metadata from `silver.match_personnel` with starter-priority resolution.
- Rows are emitted at `match_team` grain with canonical `triggered_side`, so either side can trigger.
- Trigger severity is preserved with `triggered_team_fullbacks_and_wingers_tackles_won_above_threshold`.
- Similarity gate note:
  - `sig_team_goalkeeping_defense_tackle_volume_surge`: same family and tackle intensity framing, but trigger uses all-team tackles (`>= 25`) rather than fullback+winger subset tackles.
  - `sig_team_goalkeeping_defense_wide_blockade`: same wing-defense theme, but trigger is crossing suppression under volume, not tackle concentration by wide-role players.
  - `sig_team_goalkeeping_defense_parking_the_bus`: same defensive resistance context style, but trigger is low-possession win with clearances, not wide-role tackle aggregation.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_wing_lockdown_collective.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_goalkeeping_defense_wing_lockdown_collective`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_goalkeeping_defense_wing_lockdown_collective
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
| `trigger_threshold_min_fullbacks_and_wingers_tackles_won` | Minimum tackle threshold (`15`) | Explicit trigger provenance |
| `trigger_fullback_position_ids` | Fullback position-id proxy set (`[2,5]`) | Documents deterministic role gate |
| `trigger_winger_position_ids` | Winger position-id proxy set (`[2,4]`) | Documents deterministic role gate |
| `triggered_team_fullbacks_and_wingers` | Count of triggered-side players matching fullback/winger proxy | Exposure context for aggregation denominator |
| `opponent_fullbacks_and_wingers` | Opponent-side count of fullback/winger proxy players | Bilateral exposure comparator |
| `fullbacks_and_wingers_count_delta` | Triggered minus opponent fullback/winger player count | Net role-count differential |
| `triggered_team_fullbacks_and_wingers_with_tackles` | Triggered-side proxy players with at least one tackle won | Active-contributor context |
| `opponent_fullbacks_and_wingers_with_tackles` | Opponent-side proxy players with at least one tackle won | Bilateral active-contributor comparator |
| `fullbacks_and_wingers_with_tackles_delta` | Triggered minus opponent active contributors | Net wide-role defensive participation differential |
| `triggered_team_fullbacks_tackles_won` | Tackles won by triggered-side fullback proxies | Left/right fullback contribution context |
| `opponent_fullbacks_tackles_won` | Tackles won by opponent-side fullback proxies | Bilateral fullback contribution comparator |
| `fullbacks_tackles_won_delta` | Triggered minus opponent fullback tackles won | Net fullback-defending differential |
| `triggered_team_wingers_tackles_won` | Tackles won by triggered-side winger proxies | Press-back contribution context from wingers |
| `opponent_wingers_tackles_won` | Tackles won by opponent-side winger proxies | Bilateral winger-workrate comparator |
| `wingers_tackles_won_delta` | Triggered minus opponent winger tackles won | Net winger-defending differential |
| `triggered_team_fullbacks_and_wingers_tackles_won` | Combined tackles won by triggered-side fullback/winger proxies | Core trigger metric |
| `opponent_fullbacks_and_wingers_tackles_won` | Combined tackles won by opponent-side fullback/winger proxies | Bilateral core-metric comparator |
| `fullbacks_and_wingers_tackles_won_delta` | Triggered minus opponent combined fullback/winger tackles won | Net wing-lane defensive intensity differential |
| `triggered_team_fullbacks_and_wingers_tackles_won_above_threshold` | Margin above trigger threshold (`value - 15`) | Trigger severity beyond activation boundary |
| `triggered_team_fullbacks_and_wingers_tackles_share_of_team_tackles_pct` | Triggered-side fullback/winger tackles as share of all team tackles (%) | Normalized role-concentration metric |
| `opponent_fullbacks_and_wingers_tackles_share_of_team_tackles_pct` | Opponent-side fullback/winger tackle share (%) | Bilateral concentration comparator |
| `fullbacks_and_wingers_tackles_share_of_team_tackles_delta_pct` | Triggered minus opponent role-share concentration (pp) | Net concentration differential |
| `triggered_team_tackles_won` | Total team tackles won by triggered side | Whole-team defensive baseline |
| `opponent_tackles_won` | Total team tackles won by opponent side | Bilateral whole-team baseline |
| `tackles_won_delta` | Triggered minus opponent team tackles won | Net total tackling differential |
| `triggered_team_interceptions` | Interceptions by triggered side | Defensive anticipation context |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_clearances` | Clearances by triggered side | Pressure-release context |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential |
| `triggered_team_shot_blocks` | Shot blocks by triggered side | Box-protection context |
| `opponent_shot_blocks` | Shot blocks by opponent side | Bilateral block-volume comparator |
| `shot_blocks_delta` | Triggered minus opponent shot blocks | Net block differential |
| `triggered_team_duels_won` | Duels won by triggered side | Physical-control context |
| `opponent_duels_won` | Duels won by opponent side | Bilateral physical-control comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net duel-control differential |
| `triggered_team_aerials_won` | Aerial duels won by triggered side | Aerial-control context |
| `opponent_aerials_won` | Aerial duels won by opponent side | Bilateral aerial-control comparator |
| `aerials_won_delta` | Triggered minus opponent aerial wins | Net aerial-control differential |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Defensive pressure denominator |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral pressure baseline |
| `total_shots_faced_delta` | Triggered minus opponent total shots faced | Net exposure differential |
| `triggered_team_shots_on_target_faced` | Shots on target faced by triggered side | On-target pressure context |
| `opponent_shots_on_target_faced` | Shots on target faced by opponent side | Bilateral on-target comparator |
| `shots_on_target_faced_delta` | Triggered minus opponent shots on target faced | Net on-target exposure differential |
| `triggered_team_keeper_saves` | Goalkeeper saves by triggered side | Last-line defensive workload context |
| `opponent_keeper_saves` | Goalkeeper saves by opponent side | Bilateral keeper-workload comparator |
| `keeper_saves_delta` | Triggered minus opponent keeper saves | Net goalkeeper-workload differential |
| `triggered_team_fouls` | Fouls committed by triggered side | Defensive aggression and discipline trade-off context |
| `opponent_fouls` | Fouls committed by opponent side | Bilateral discipline comparator |
| `fouls_delta` | Triggered minus opponent fouls | Net discipline differential |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-state context |
| `opponent_possession_pct` | Opponent-side possession (%) | Bilateral control-state comparator |
| `possession_delta_pct` | Triggered minus opponent possession (pp) | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-retention execution context |
| `opponent_pass_accuracy_pct` | Opponent-side pass accuracy (%) | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Net circulation-quality differential |
| `triggered_team_goals` | Goals scored by triggered side | Result context |
| `opponent_goals` | Goals scored by opponent side | Bilateral result context |
| `goal_delta` | Triggered minus opponent goals | Compact outcome differential |
| `triggered_team_clean_sheet_flag` | 1 when triggered side concedes 0 goals, else 0 | Separates wing-lane defensive workrate from clean-sheet outcome |
