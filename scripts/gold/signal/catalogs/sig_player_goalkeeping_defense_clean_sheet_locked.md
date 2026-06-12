---
signal_id: sig_player_goalkeeping_defense_clean_sheet_locked
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Clean Sheet Locked"
trigger: "Goalkeeper records a clean sheet while facing expected-goals-on-target >= 1.5 in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_clean_sheet_locked
  sql: clickhouse/gold/signal/sig_player_goalkeeping_defense_clean_sheet_locked.sql
  runner: scripts/gold/signal/runners/sig_player_goalkeeping_defense_clean_sheet_locked.py
---
# sig_player_goalkeeping_defense_clean_sheet_locked

## Purpose

Flags goalkeepers who keep a clean sheet despite facing high expected-goals-on-target pressure
(`>= 1.5`), then preserves bilateral pressure and control context for resilience profiling.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_expected_goals_on_target_faced >= 1.5`
  - `triggered_team_clean_sheet_flag = 1`
  - `is_goalkeeper = 1`
  - `match_finished = 1`
- Goalkeeper pressure events are derived from `silver.shot` at `(match_id, keeper_id)` grain:
  - shots-on-target faced: `is_on_target = 1` and not `is_saved_off_line`
  - saves: on-target, not goal, not `is_saved_off_line`
  - goals conceded: on-target goals, not `is_saved_off_line`
  - expected-goals-on-target faced: sum of `expected_goals_on_target` (fallback `expected_goals`) on eligible on-target events
- Clean-sheet enforcement uses final match score orientation by triggered side.
- Bilateral context from `silver.period_stat` (`period = 'All'`) keeps symmetric team/opponent xGOT faced,
  shots faced, saves, possession, and pass-quality fields.
- Similarity gate note:
  - `sig_player_goalkeeping_defense_brick_wall`: overlap on goalkeeper-shot-stopping intent, but this signal is quality-thresholded (`xGOT`) with mandatory clean sheet instead of raw save-volume trigger.
  - `sig_player_goalkeeping_defense_penalty_stopper`: overlap on goalkeeper-defense family, but that signal is penalty-event specific, while this signal is full-match high-xGOT clean-sheet resilience.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_goalkeeping_defense_clean_sheet_locked.sql`
- Runner: `scripts/gold/signal/runners/sig_player_goalkeeping_defense_clean_sheet_locked.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_clean_sheet_locked`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_goalkeeping_defense_clean_sheet_locked.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for player, team, and match feature sets |
| `match_date` | Match date | Football developer: temporal slicing and backfill validation |
| `home_team_id` | Home team ID | Football developer: fixture orientation context |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixture orientation context |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Full-time home goals | Football developer: final outcome context for clean-sheet validation |
| `away_score` | Full-time away goals | Football developer: final outcome context for clean-sheet validation |
| `triggered_side` | Side of triggered goalkeeper (`home` or `away`) | Football developer: canonical side orientation for downstream aggregation |
| `triggered_player_id` | Triggered goalkeeper player ID | Football developer: durable player identity key |
| `triggered_player_name` | Triggered goalkeeper player name | Football developer: readable trigger attribution |
| `triggered_team_id` | Team ID of triggered goalkeeper | Football developer: linkage to team-level tactical context |
| `triggered_team_name` | Team name of triggered goalkeeper | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup context |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_expected_goals_on_target_faced` | Trigger threshold for xGOT faced (`1.5`) | Football developer: explicit threshold provenance for QA and audits |
| `triggered_team_clean_sheet_flag` | Clean-sheet indicator for triggered side (`1` when opponent goals = 0) | Football developer: direct trigger integrity check |
| `triggered_player_expected_goals_on_target_faced` | xGOT faced by triggered goalkeeper from on-target events | Football developer: primary quality-weighted pressure trigger metric |
| `triggered_player_shots_on_target_faced` | On-target shots faced by triggered goalkeeper | Football developer: event-volume denominator for interpreting xGOT faced |
| `triggered_player_saves` | Saves by triggered goalkeeper | Football developer: shot-stopping output context alongside quality faced |
| `triggered_player_goals_conceded` | Goals conceded by triggered goalkeeper in on-target events | Football developer: confirms clean-sheet resilience at player event grain |
| `triggered_player_save_rate_pct` | Save rate of triggered goalkeeper (%) | Football developer: efficiency context under high-quality pressure |
| `triggered_player_minutes_played` | Minutes played by triggered goalkeeper | Football developer: exposure reliability context |
| `triggered_player_touches` | Touches by triggered goalkeeper | Football developer: overall involvement context under pressure |
| `triggered_player_total_passes` | Pass attempts by triggered goalkeeper | Football developer: distribution workload context in defensive siege matches |
| `triggered_player_accurate_passes` | Accurate passes by triggered goalkeeper | Football developer: execution context for build-up stability |
| `triggered_player_pass_accuracy_pct` | Pass accuracy of triggered goalkeeper (%) | Football developer: composure context under sustained pressure |
| `triggered_team_keeper_saves` | Keeper saves by triggered side | Football developer: team-level save baseline for consistency checks |
| `opponent_keeper_saves` | Keeper saves by opponent side | Football developer: bilateral goalkeeper workload comparator |
| `triggered_team_expected_goals_on_target_faced` | Team-level xGOT faced by triggered side | Football developer: bilateral quality-pressure anchor for trigger interpretation |
| `opponent_expected_goals_on_target_faced` | Team-level xGOT faced by opponent side | Football developer: bilateral quality-pressure comparator |
| `triggered_team_shots_on_target_faced` | Team-level shots on target faced by triggered side | Football developer: volume context paired with xGOT faced |
| `opponent_shots_on_target_faced` | Team-level shots on target faced by opponent side | Football developer: bilateral volume comparator |
| `triggered_team_total_shots_faced` | Team-level total shots faced by triggered side | Football developer: broader pressure volume context beyond on-target subset |
| `opponent_total_shots_faced` | Team-level total shots faced by opponent side | Football developer: bilateral pressure-volume comparator |
| `triggered_team_expected_goals_faced` | Team-level xG faced by triggered side | Football developer: all-shot chance-quality context alongside xGOT |
| `opponent_expected_goals_faced` | Team-level xG faced by opponent side | Football developer: bilateral all-shot quality comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control-state context for resilience interpretation |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered side (%) | Football developer: team execution context under pressure |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent side (%) | Football developer: bilateral execution comparator |
| `expected_goals_on_target_faced_delta` | Triggered-side xGOT faced minus opponent-side xGOT faced | Football developer: net quality-pressure differential around the clean sheet |
| `player_share_of_team_expected_goals_on_target_faced_pct` | Triggered goalkeeper xGOT faced as % of triggered-side xGOT faced | Football developer: data-consistency and keeper-attribution concentration check |
| `player_share_of_team_keeper_saves_pct` | Triggered goalkeeper saves as % of triggered-side keeper saves | Football developer: confirms keeper-level event share in team save totals |
