---
signal_id: sig_player_goalkeeping_defense_keeper_save_efficiency
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Keeper Save Efficiency"
trigger: "Goalkeeper saves 100% of on-target shots faced with at least 4 shots on target faced in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_keeper_save_efficiency
  sql: clickhouse/gold/signal/sig_player_goalkeeping_defense_keeper_save_efficiency.sql
  runner: scripts/gold/signal/runners/sig_player_goalkeeping_defense_keeper_save_efficiency.py
---
# sig_player_goalkeeping_defense_keeper_save_efficiency

## Purpose

Identify goalkeeper matches with perfect shot-stopping efficiency (`100%` saves on on-target shots faced)
while enforcing a minimum pressure floor (`>= 4` shots on target faced).

## Tactical And Statistical Logic

- Trigger condition:
  - goalkeeper-only scope (`is_goalkeeper = 1`, finished matches)
  - `triggered_player_shots_on_target_faced >= 4`
  - `triggered_player_saves = triggered_player_shots_on_target_faced` (save rate `100%`)
- On-target goalkeeper events are derived from `silver.shot` at `(match_id, keeper_id)` grain:
  - on-target faced: `is_on_target = 1` and `is_saved_off_line = 0`
  - save: `is_on_target = 1`, `is_goal = 0`, `is_saved_off_line = 0`
  - goal conceded: `is_on_target = 1`, `is_goal = 1`, `is_saved_off_line = 0`
- Trigger rollup preserves both player identity context and bilateral team context from
  `silver.period_stat` (`period = 'All'`) for workload, chance-quality, control, and passing comparison.
- Similarity gate note: closest active signals are `sig_player_goalkeeping_defense_brick_wall` and
  `sig_player_goalkeeping_defense_clean_sheet_locked`; this signal intentionally coexists because it
  centers on perfect save efficiency (`100%`) with a moderate volume floor (`>=4` SOT faced), rather than
  extreme save count (`>=8`) or high xGOT clean-sheet pressure thresholds.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_goalkeeping_defense_keeper_save_efficiency.sql`
- Runner: `scripts/gold/signal/runners/sig_player_goalkeeping_defense_keeper_save_efficiency.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_keeper_save_efficiency`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_goalkeeping_defense_keeper_save_efficiency.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join key for player- and match-level downstream workflows. |
| `match_date` | Match date | Supports temporal cohorts and deterministic backfills. |
| `home_team_id` | Home team identifier | Preserves fixture-side context. |
| `home_team_name` | Home team name | Readable fixture context for analysts. |
| `away_team_id` | Away team identifier | Preserves fixture-side context. |
| `away_team_name` | Away team name | Readable fixture context for analysts. |
| `home_score` | Full-time home goals | Outcome context around perfect save-efficiency matches. |
| `away_score` | Full-time away goals | Outcome context around perfect save-efficiency matches. |
| `triggered_side` | Triggered goalkeeper side (`home` or `away`) | Canonical side orientation for player-grain outputs. |
| `triggered_player_id` | Triggered goalkeeper identifier | Durable player identity for joins and feature serving. |
| `triggered_player_name` | Triggered goalkeeper name | Human-readable signal attribution. |
| `triggered_team_id` | Triggered goalkeeper team identifier | Team context for tactical interpretation. |
| `triggered_team_name` | Triggered goalkeeper team name | Readable team attribution. |
| `opponent_team_id` | Opponent team identifier | Bilateral matchup context. |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator. |
| `trigger_threshold_min_shots_on_target_faced` | Minimum on-target shots faced threshold (`4`) | Encodes trigger provenance for QA and audits. |
| `trigger_threshold_save_rate_pct` | Save-rate threshold (`100%`) | Explicit rule boundary for reproducibility. |
| `triggered_player_shots_on_target_faced` | On-target shots faced by triggered goalkeeper | Trigger denominator and workload baseline. |
| `triggered_player_saves` | Saves by triggered goalkeeper | Core trigger numerator. |
| `triggered_player_goals_conceded` | Goals conceded from on-target shots faced | Outcome severity context and trigger validation. |
| `triggered_player_save_rate_pct` | Save rate of triggered goalkeeper (%) | Normalized shot-stopping efficiency metric. |
| `triggered_player_expected_goals_on_target_faced` | xGOT faced by triggered goalkeeper | Chance-severity context behind perfect save rate. |
| `triggered_player_minutes_played` | Minutes played by triggered goalkeeper | Exposure context for event reliability. |
| `triggered_player_touches` | Touches by triggered goalkeeper | Involvement context beyond saves. |
| `triggered_player_total_passes` | Pass attempts by triggered goalkeeper | Distribution-load context under pressure. |
| `triggered_player_accurate_passes` | Accurate passes by triggered goalkeeper | Distribution execution context. |
| `triggered_player_pass_accuracy_pct` | Pass accuracy of triggered goalkeeper (%) | Ball-security and composure context. |
| `triggered_team_keeper_saves` | Keeper saves by triggered side | Team-level workload and consistency check. |
| `opponent_keeper_saves` | Keeper saves by opponent side | Bilateral goalkeeper-workload comparator. |
| `triggered_team_shots_on_target_faced` | On-target shots faced by triggered side | Team-level pressure denominator. |
| `opponent_shots_on_target_faced` | On-target shots faced by opponent side | Bilateral pressure comparator. |
| `triggered_team_total_shots_faced` | Total shots faced by triggered side | Broader defensive pressure context. |
| `opponent_total_shots_faced` | Total shots faced by opponent side | Bilateral defensive pressure comparator. |
| `triggered_team_expected_goals_on_target_faced` | xGOT faced by triggered side | Team-level on-target chance severity. |
| `opponent_expected_goals_on_target_faced` | xGOT faced by opponent side | Bilateral on-target severity comparator. |
| `triggered_team_expected_goals_faced` | xG faced by triggered side | Team-level chance-quality-against baseline. |
| `opponent_expected_goals_faced` | xG faced by opponent side | Bilateral chance-quality comparator. |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Control-state context for defensive workload. |
| `opponent_possession_pct` | Possession percentage of opponent side | Bilateral control comparator. |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered side (%) | Team execution context. |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent side (%) | Bilateral execution comparator. |
| `expected_goals_on_target_faced_delta` | Triggered minus opponent xGOT faced | Net on-target chance-severity differential context. |
| `player_share_of_team_shots_on_target_faced_pct` | Triggered goalkeeper share of triggered-side SOT faced (%) | Validates concentration of goalkeeper workload attribution. |
| `player_share_of_team_keeper_saves_pct` | Triggered goalkeeper share of triggered-side keeper saves (%) | QA signal for player/team keeper-save consistency. |
