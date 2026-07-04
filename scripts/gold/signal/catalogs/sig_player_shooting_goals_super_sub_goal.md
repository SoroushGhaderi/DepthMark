---
signal_id: sig_player_shooting_goals_super_sub_goal
status: active
entity: player
family: shooting
subfamily: goals
grain: match_player
headline: "Super Sub Goal"
trigger: "Substitute player scores a non-own goal within 5 minutes of entering the pitch."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_shooting_goals_super_sub_goal
  sql: clickhouse/gold/dml/signals/player/sig_player_shooting_goals_super_sub_goal.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_shooting_goals_super_sub_goal

## Purpose

Detects immediate substitute scoring impact by flagging players who score a non-own goal within five minutes of entering.

## Tactical And Statistical Logic

- Trigger condition:
  - Substitute player (`silver.match_personnel.role = 'substitute'`) with `substitution_time > 0`.
  - Non-own goal event from `silver.shot` where `is_goal = 1`, `is_own_goal = 0`.
  - Goal effective minute (`goal_time + goal_overload_time`) is within 5 minutes of substitution time.
- One row is emitted per `match_id + triggered_player_id + triggered_team_id`.
- Trigger timing diagnostics preserve first qualifying goal minute, added time, effective minute, and score state before/after that goal.
- Bilateral team/opponent context is sourced from `silver.period_stat` (`period = 'All'`) with symmetric `triggered_team_*` and `opponent_*` fields.
- Similarity gate note: closest active signal is `sig_player_shooting_goals_clutch_equalizer`; overlap exists on shot-level goal timing, but this signal is substitution-timing driven rather than late equalizer game-state driven, so they coexist.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_shooting_goals_super_sub_goal.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_shooting_goals_super_sub_goal`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_shooting_goals_super_sub_goal
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins, deduplication, and lineage |
| `match_date` | Match date | Football developer: temporal slicing for scouting and trend workflows |
| `home_team_id` | Home team ID | Football developer: fixed bilateral fixture orientation |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixed bilateral fixture orientation |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Full-time home goals | Football developer: outcome context around substitute impact |
| `away_score` | Full-time away goals | Football developer: outcome context around substitute impact |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation at match-player grain |
| `triggered_player_id` | Triggered player ID | Football developer: durable player identity key |
| `triggered_player_name` | Triggered player name | Football developer: readable player attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player trigger to team context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup anchor |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_max_minutes_from_substitution` | Trigger threshold in minutes (`5`) | Football developer: explicit trigger provenance for QA/reproducibility |
| `triggered_player_substitution_time` | Minute the triggered player entered from the bench | Football developer: confirms substitute timing baseline |
| `triggered_player_first_super_sub_goal_minute` | Base minute of first qualifying super-sub goal | Football developer: event-timing anchor for match reconstruction |
| `triggered_player_first_super_sub_goal_added_time` | Added-time component of first qualifying super-sub goal | Football developer: stoppage-time precision for fast-impact scoring |
| `triggered_player_first_super_sub_goal_effective_minute` | Effective minute (`minute + added_time`) of first qualifying super-sub goal | Football developer: normalized timing across regulation/stoppage contexts |
| `minutes_from_substitution_to_first_super_sub_goal` | Delay from substitution to first qualifying goal | Football developer: core immediacy severity metric |
| `triggered_player_super_sub_goals` | Count of qualifying goals scored within the five-minute window | Football developer: core trigger intensity metric |
| `super_sub_goals_above_threshold` | Goals above minimum required count (`super_sub_goals - 1`) | Football developer: trigger-intensity grading beyond binary activation |
| `triggered_team_score_before_first_super_sub_goal` | Triggered-team score immediately before first qualifying goal | Football developer: pre-goal score-state context |
| `opponent_score_before_first_super_sub_goal` | Opponent score immediately before first qualifying goal | Football developer: bilateral pre-goal score-state comparator |
| `triggered_team_score_after_first_super_sub_goal` | Triggered-team score immediately after first qualifying goal | Football developer: state-change auditability at trigger moment |
| `opponent_score_after_first_super_sub_goal` | Opponent score immediately after first qualifying goal | Football developer: bilateral state-change auditability |
| `triggered_player_goals` | Total goals scored by triggered player in match | Football developer: broader finishing output context |
| `triggered_player_expected_goals` | Total expected goals by triggered player in match | Football developer: chance-quality context for scoring output |
| `triggered_player_total_shots` | Total shots by triggered player | Football developer: shooting-volume baseline |
| `triggered_player_shots_on_target` | Shots on target by triggered player | Football developer: shot-execution context |
| `triggered_player_shot_accuracy_pct` | Shots-on-target share of player shots (%) | Football developer: finishing precision diagnostic |
| `triggered_player_expected_goals_per_shot` | Expected goals per shot by triggered player | Football developer: average chance-quality per attempt |
| `triggered_player_goal_minus_expected_goals` | Goals minus expected goals for triggered player | Football developer: over/under-performance finishing context |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure context for interpretation |
| `triggered_team_goals` | Full-time goals by triggered player's team | Football developer: side-relative scoreline context |
| `opponent_goals` | Full-time goals by opponent team | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: side-relative final outcome edge |
| `triggered_team_expected_goals` | Expected goals by triggered side | Football developer: team chance-quality baseline |
| `opponent_expected_goals` | Expected goals by opponent side | Football developer: bilateral chance-quality comparator |
| `expected_goals_delta` | Triggered-team expected goals minus opponent expected goals | Football developer: net chance-quality control context |
| `triggered_team_total_shots` | Total shots by triggered side | Football developer: team shooting-volume baseline |
| `opponent_total_shots` | Total shots by opponent side | Football developer: bilateral shooting-volume comparator |
| `triggered_team_shots_on_target` | Shots on target by triggered side | Football developer: team shot-execution context |
| `opponent_shots_on_target` | Shots on target by opponent side | Football developer: bilateral execution comparator |
| `triggered_team_big_chances` | Big chances by triggered side | Football developer: high-value chance context around trigger |
| `opponent_big_chances` | Big chances by opponent side | Football developer: bilateral high-value chance comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control-profile context for substitute impact |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Football developer: bilateral territorial comparator |
| `player_share_of_team_goals_pct` | Triggered player share of team goals (%) | Football developer: concentration of scoring responsibility |
| `player_share_of_team_expected_goals_pct` | Triggered player share of team expected goals (%) | Football developer: concentration of chance-quality responsibility |
| `player_share_of_team_total_shots_pct` | Triggered player share of team total shots (%) | Football developer: concentration of shooting workload |
