---
signal_id: sig_match_possession_passing_early_tactical_lock
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Match Possession Passing Early Tactical Lock"
trigger: "No shots on target for either team in the first 30 minutes of play."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_possession_passing_early_tactical_lock
  sql: clickhouse/gold/signal/sig_match_possession_passing_early_tactical_lock.sql
  runner: scripts/gold/signal/runners/sig_match_possession_passing_early_tactical_lock.py
---
# sig_match_possession_passing_early_tactical_lock

## Purpose

Triggers matches where both teams fail to register a shot on target in the opening 30 minutes, surfacing early tactical lock phases with suppressed direct threat.

## Tactical And Statistical Logic

- Trigger condition: `home_first_30_shots_on_target = 0` and `away_first_30_shots_on_target = 0`.
- Operational first-30 window: `silver.shot.minute <= 30`.
- Emits one row per side (`triggered_side` = `home` and `away`) so team-centric consumers can evaluate the same locked opening phase from each tactical orientation.
- Enriches the trigger with early shot activity, full-match shooting output, passing quality, possession share, territorial progression, and xG context.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_possession_passing_early_tactical_lock.sql`
- Runner: `scripts/gold/signal/runners/sig_match_possession_passing_early_tactical_lock.py`
- Target table: `gold_signals.sig_match_possession_passing_early_tactical_lock`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_possession_passing_early_tactical_lock.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable identity for joins and traceability. |
| `match_date` | Match calendar date | Football developer: timeline slicing and backtest partitions. |
| `home_team_id` | Home team numeric ID | Football developer: fixture identity and orientation recovery. |
| `home_team_name` | Home team display name | Football developer: analyst-readable fixture context. |
| `away_team_id` | Away team numeric ID | Football developer: fixture identity and orientation recovery. |
| `away_team_name` | Away team display name | Football developer: analyst-readable fixture context. |
| `home_score` | Full-time home goals | Football developer: outcome context for opening-phase tactical locks. |
| `away_score` | Full-time away goals | Football developer: outcome context for opening-phase tactical locks. |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: team-centric interpretation of the same match trigger. |
| `triggered_team_id` | Triggered-side team ID | Football developer: side identity for downstream team features. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered-side identity. |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral context and matchup orientation. |
| `opponent_team_name` | Opponent team name | Football developer: bilateral context and matchup orientation. |
| `trigger_window_minutes` | Trigger evaluation window in minutes (`30`) | Football developer: explicit trigger window traceability for QA and explainability. |
| `match_first_30_total_shots_on_target` | Combined shots on target in first 30 minutes | Football developer: core trigger metric expected to be zero in triggered matches. |
| `triggered_team_first_30_shots_on_target` | Triggered-side shots on target in first 30 minutes | Football developer: side-level decomposition of the no-on-target opening condition. |
| `opponent_first_30_shots_on_target` | Opponent shots on target in first 30 minutes | Football developer: bilateral comparator for opening-phase threat suppression. |
| `match_first_30_total_shots` | Combined total shots in first 30 minutes | Football developer: distinguishes complete chance drought from off-target-only openings. |
| `triggered_team_first_30_total_shots` | Triggered-side total shots in first 30 minutes | Football developer: side-level early attacking intent beneath on-target drought. |
| `opponent_first_30_total_shots` | Opponent total shots in first 30 minutes | Football developer: bilateral comparator for early attacking intent. |
| `match_first_30_first_shot_minute` | Earliest first-30 shot minute by either side (nullable) | Football developer: timing context for when the tactical lock first loosened. |
| `triggered_team_first_30_first_shot_minute` | Earliest first-30 shot minute by triggered side (nullable) | Football developer: side-level shot-timing context within the opening lock. |
| `opponent_first_30_first_shot_minute` | Earliest first-30 shot minute by opponent side (nullable) | Football developer: bilateral shot-timing comparator within the opening lock. |
| `triggered_team_total_shots` | Triggered-side full-match total shots | Football developer: shows whether early lock persisted or broke later. |
| `opponent_total_shots` | Opponent full-match total shots | Football developer: bilateral full-match shooting comparator. |
| `triggered_team_shots_on_target` | Triggered-side full-match shots on target | Football developer: reveals post-lock progression in shot quality. |
| `opponent_shots_on_target` | Opponent full-match shots on target | Football developer: bilateral full-match shot-quality comparator. |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Football developer: circulation volume context around tactical locking behavior. |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation-volume comparator. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Football developer: execution-quality context during and after locked openings. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral execution-quality comparator. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control-share context for interpreting low early shot quality. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control-share comparator. |
| `triggered_team_opposition_half_passes` | Triggered-side opposition-half passes | Football developer: territorial progression context beneath early on-target suppression. |
| `opponent_opposition_half_passes` | Opponent opposition-half passes | Football developer: bilateral territorial-progression comparator. |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opponent box | Football developer: penetration context for whether lock came from box access denial. |
| `opponent_touches_opposition_box` | Opponent touches in triggered-side box | Football developer: bilateral penetration comparator. |
| `triggered_team_xg` | Triggered-side expected goals | Football developer: chance-quality output after the opening tactical lock. |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator. |
| `xg_gap` | Triggered-side xG minus opponent xG | Football developer: net chance-quality edge after a shared early lock phase. |
