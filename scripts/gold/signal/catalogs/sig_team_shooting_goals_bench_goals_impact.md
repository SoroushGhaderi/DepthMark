---
signal_id: sig_team_shooting_goals_bench_goals_impact
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Bench Goals Impact"
trigger: "Substitutes account for >= 2 goals for the team in one finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_bench_goals_impact
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_bench_goals_impact.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_shooting_goals_bench_goals_impact

## Purpose

Detect team scoring performances where the bench contributes at least two non-own goals, signaling high substitute finishing impact within the match.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_substitute_non_own_goals >= 2`
- Substitute scorers are derived from `silver.match_personnel` (`role = 'substitute'`, `substitution_time > 0`) joined to non-own goals in `silver.shot` (`is_goal = 1`, `is_own_goal = 0`).
- Goal events are counted only when the goal effective minute (`goal_time + goal_overload_time`) is at or after the recorded substitution time.
- Trigger is evaluated separately for home and away teams in finished matches (`silver.match.match_finished = 1`).
- Bilateral output includes substitute-goal volume, substitute-scorer spread, timing markers, and shooting/possession context as `triggered_team_*` vs `opponent_*` metrics.
- Similarity gate note: closest active signals are `sig_player_shooting_goals_super_sub_goal` and `sig_team_shooting_goals_shared_scoring`; this signal is distinct because it is team-level and bench-contribution driven (`>= 2` substitute non-own goals), rather than player-level fast-impact scoring or broad scorer-diversity triggers.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_bench_goals_impact.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_shooting_goals_bench_goals_impact`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_shooting_goals_bench_goals_impact
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key and deterministic deduplication anchor |
| `match_date` | Match date | Football developer: supports temporal slicing and backfill traceability |
| `home_team_id` | Home team identifier | Football developer: preserves fixture-side orientation |
| `home_team_name` | Home team name | Football developer: human-readable fixture context |
| `away_team_id` | Away team identifier | Football developer: preserves fixture-side orientation |
| `away_team_name` | Away team name | Football developer: human-readable fixture context |
| `home_score` | Home full-time goals | Football developer: final score context around bench contribution |
| `away_score` | Away full-time goals | Football developer: bilateral scoreline context |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered team identifier | Football developer: entity identity for downstream joins |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Football developer: readable opponent attribution |
| `trigger_threshold_min_substitute_non_own_goals` | Trigger threshold for substitute non-own goals (`2`) | Football developer: explicit governance and QA provenance |
| `triggered_team_substitute_non_own_goals` | Non-own goals scored by triggered-team substitutes | Football developer: core trigger metric |
| `opponent_substitute_non_own_goals` | Non-own goals scored by opponent substitutes | Football developer: bilateral benchmark for bench impact |
| `substitute_non_own_goals_delta` | Triggered minus opponent substitute non-own goals | Football developer: compact side-relative bench-output differential |
| `triggered_team_distinct_substitute_goal_scorers` | Distinct substitute scorers for triggered team | Football developer: bench scorer breadth diagnostic |
| `opponent_distinct_substitute_goal_scorers` | Distinct substitute scorers for opponent | Football developer: bilateral breadth comparator |
| `distinct_substitute_goal_scorers_delta` | Triggered minus opponent distinct substitute scorers | Football developer: normalized substitute-scorer spread edge |
| `triggered_team_top_substitute_scorer_goals` | Max goals by a single triggered-team substitute scorer | Football developer: bench scoring concentration indicator |
| `opponent_top_substitute_scorer_goals` | Max goals by a single opponent substitute scorer | Football developer: bilateral concentration comparator |
| `top_substitute_scorer_goals_delta` | Triggered minus opponent top substitute-scorer goals | Football developer: side-level concentration differential |
| `triggered_team_first_substitute_goal_effective_minute` | Earliest effective minute of triggered-team substitute goal | Football developer: timing profile of bench impact onset |
| `opponent_first_substitute_goal_effective_minute` | Earliest effective minute of opponent substitute goal | Football developer: bilateral timing comparator |
| `triggered_team_last_substitute_goal_effective_minute` | Latest effective minute of triggered-team substitute goal | Football developer: persistence of bench scoring contribution |
| `opponent_last_substitute_goal_effective_minute` | Latest effective minute of opponent substitute goal | Football developer: bilateral persistence comparator |
| `triggered_team_substitute_goal_share_pct` | Share of triggered-team non-own goals scored by substitutes (%) | Football developer: normalized bench-dependence intensity |
| `opponent_substitute_goal_share_pct` | Share of opponent non-own goals scored by substitutes (%) | Football developer: bilateral normalized comparator |
| `substitute_goal_share_delta_pct` | Triggered minus opponent substitute-goal share (percentage points) | Football developer: compact bench-dependence differential |
| `triggered_team_non_own_goals` | Triggered-team non-own goals | Football developer: denominator context for bench-share metrics |
| `opponent_non_own_goals` | Opponent non-own goals | Football developer: bilateral goal-output baseline |
| `non_own_goals_delta` | Triggered minus opponent non-own goals | Football developer: side-relative scoring-output differential |
| `triggered_team_goals` | Triggered-team official full-time goals | Football developer: final score context for trigger interpretation |
| `opponent_goals` | Opponent official full-time goals | Football developer: bilateral outcome comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: outcome edge around bench scoring impact |
| `triggered_team_total_shots` | Triggered-team total shots | Football developer: shooting-volume context |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral shooting-volume comparator |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Football developer: shot-execution context |
| `opponent_shots_on_target` | Opponent shots on target | Football developer: bilateral execution comparator |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: chance-quality baseline |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: net chance-quality edge |
| `triggered_team_big_chances` | Triggered-team big chances | Football developer: high-value chance creation context |
| `opponent_big_chances` | Opponent big chances | Football developer: bilateral high-value chance comparator |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Football developer: control-profile context |
| `opponent_possession_pct` | Opponent possession (%) | Football developer: bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: compact control differential |
