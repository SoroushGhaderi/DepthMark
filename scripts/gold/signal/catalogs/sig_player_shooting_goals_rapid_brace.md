---
signal_id: sig_player_shooting_goals_rapid_brace
status: active
entity: player
family: shooting
subfamily: goals
grain: match_player
headline: "Rapid Brace"
trigger: "Player scores 2 non-own goals within a 10-minute effective-minute window in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_shooting_goals_rapid_brace
  sql: clickhouse/gold/dml/signals/player/sig_player_shooting_goals_rapid_brace.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_shooting_goals_rapid_brace

## Purpose

Flags players who produce a rapid brace by scoring two non-own goals within ten effective minutes, isolating short-burst finishing explosions.

## Tactical And Statistical Logic

- Trigger condition:
  - Non-own goal events from `silver.shot` (`is_goal = 1`, `is_own_goal = 0`).
  - Same player, same team, same match has an ordered goal pair where effective-minute gap is `<= 10`.
- Effective-minute definition is `goal_time + goal_overload_time` (fallback `minute + minute_added`), matching existing timing-based shooting signals.
- Deterministic pair selection chooses the earliest qualifying second goal (then earliest first-goal tie-break), producing stable first/second rapid-goal diagnostics.
- Bilateral team/opponent context is sourced from `silver.period_stat` (`period = 'All'`) using symmetric `triggered_team_*` and `opponent_*` fields.
- Similarity gate note: closest active signal is `sig_player_shooting_goals_clinical_brace`; this signal is intentionally complementary because trigger logic is time-window burst finishing rather than low-xG overperformance filtering.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_shooting_goals_rapid_brace.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_shooting_goals_rapid_brace`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_shooting_goals_rapid_brace
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins, deduplication, and lineage |
| `match_date` | Match date | Football developer: temporal slicing for trend analysis |
| `home_team_id` | Home team ID | Football developer: bilateral fixture anchor |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: bilateral fixture anchor |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Full-time home goals | Football developer: scoreline context for interpreting rapid scoring bursts |
| `away_score` | Full-time away goals | Football developer: scoreline context for interpreting rapid scoring bursts |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for match-player grain |
| `triggered_player_id` | Triggered player ID | Football developer: durable player identity key |
| `triggered_player_name` | Triggered player name | Football developer: readable player attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player trigger to team context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup anchor |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_min_goals` | Minimum goals required by trigger (`2`) | Football developer: explicit trigger provenance for QA and reproducibility |
| `trigger_threshold_max_goal_window_minutes` | Maximum allowed gap between the two goals (`10`) | Football developer: explicit trigger provenance for QA and reproducibility |
| `triggered_player_first_rapid_goal_minute` | Base minute of first goal in earliest qualifying rapid pair | Football developer: event timing anchor for tactical replay |
| `triggered_player_first_rapid_goal_added_time` | Added-time component of first rapid goal | Football developer: stoppage-time precision for timing audits |
| `triggered_player_first_rapid_goal_effective_minute` | Effective minute (`minute + added_time`) of first rapid goal | Football developer: normalized timing across regulation and stoppage phases |
| `triggered_player_second_rapid_goal_minute` | Base minute of second goal that completes rapid brace | Football developer: trigger completion timing anchor |
| `triggered_player_second_rapid_goal_added_time` | Added-time component of second rapid goal | Football developer: stoppage-time precision for trigger completion |
| `triggered_player_second_rapid_goal_effective_minute` | Effective minute (`minute + added_time`) of second rapid goal | Football developer: normalized trigger completion timestamp |
| `minutes_between_rapid_brace_goals` | Effective-minute gap between the two rapid-brace goals | Football developer: core burst-intensity metric |
| `triggered_player_rapid_brace_pair_count` | Number of qualifying ordered goal pairs within ten minutes | Football developer: intensity grading for repeated burst windows |
| `goals_above_threshold` | Goals above minimum required count (`goals - 2`) | Football developer: severity ranking beyond binary trigger |
| `rapid_brace_window_margin_minutes` | Remaining margin to threshold (`10 - minutes_between_rapid_brace_goals`) | Football developer: closeness/severity diagnostic relative to rule boundary |
| `triggered_player_goals` | Total goals by triggered player in match | Football developer: full-match finishing volume context |
| `triggered_player_expected_goals` | Total expected goals by triggered player | Football developer: chance-quality context for conversion output |
| `triggered_player_total_shots` | Total shots by triggered player | Football developer: shooting volume baseline |
| `triggered_player_shots_on_target` | Shots on target by triggered player | Football developer: shooting execution context |
| `triggered_player_shot_accuracy_pct` | Shots-on-target share of player shots (%) | Football developer: finishing precision diagnostic |
| `triggered_player_expected_goals_per_shot` | Expected goals per shot by triggered player | Football developer: average chance-quality per attempt |
| `triggered_player_goal_minus_expected_goals` | Goals minus expected goals for triggered player | Football developer: over/under-performance finishing signal |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure context for interpretation |
| `triggered_team_goals` | Full-time goals by triggered player's team | Football developer: side-relative output context |
| `opponent_goals` | Full-time goals by opponent team | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: side-relative final outcome context |
| `triggered_team_expected_goals` | Expected goals by triggered side | Football developer: team chance-quality baseline |
| `opponent_expected_goals` | Expected goals by opponent side | Football developer: bilateral chance-quality comparator |
| `expected_goals_delta` | Triggered-team expected goals minus opponent expected goals | Football developer: net chance-quality context |
| `triggered_team_total_shots` | Total shots by triggered side | Football developer: team shot-volume baseline |
| `opponent_total_shots` | Total shots by opponent side | Football developer: bilateral shot-volume comparator |
| `triggered_team_shots_on_target` | Shots on target by triggered side | Football developer: team shot-execution context |
| `opponent_shots_on_target` | Shots on target by opponent side | Football developer: bilateral execution comparator |
| `triggered_team_big_chances` | Big chances by triggered side | Football developer: high-value chance context around rapid brace |
| `opponent_big_chances` | Big chances by opponent side | Football developer: bilateral high-value chance comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control-profile context for burst finishing events |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Football developer: bilateral territorial comparator |
| `player_share_of_team_goals_pct` | Triggered player share of team goals (%) | Football developer: scoring concentration context |
| `player_share_of_team_expected_goals_pct` | Triggered player share of team expected goals (%) | Football developer: concentration of chance-quality responsibility |
| `player_share_of_team_total_shots_pct` | Triggered player share of team total shots (%) | Football developer: concentration of shooting workload |
