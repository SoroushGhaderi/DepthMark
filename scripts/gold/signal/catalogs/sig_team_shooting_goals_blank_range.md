---
signal_id: sig_team_shooting_goals_blank_range
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Blank Range"
trigger: "Team fails to score despite total match xG > 2.5 in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_blank_range
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_blank_range.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_shooting_goals_blank_range

## Purpose

Detect team-level finishing collapses where chance creation was strong (xG > 2.5) but the team scored zero goals.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_goals = 0`
  - `triggered_team_xg > 2.5`
- Trigger evaluation uses full-match rows only (`period = 'All'`) and finished matches only.
- Signal output stays bilateral (`triggered_team_*` vs `opponent_*`) to explain whether the blank result came from poor shot execution, goalkeeper resistance, or wider tactical imbalance.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_shooting_gallery` and `sig_player_shooting_goals_wasteful_finisher`; this signal is distinct because it is team-triggered and specifically models severe zero-goal underperformance at high team xG rather than generic shot volume or player-level wastefulness.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_blank_range.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_shooting_goals_blank_range`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_blank_range
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for downstream feature and QA pipelines |
| `match_date` | Match date | Football developer: enables temporal backfills and trend slices |
| `home_team_id` | Home team identifier | Football developer: preserves bilateral team context |
| `home_team_name` | Home team name | Football developer: readable home-side context for analysis |
| `away_team_id` | Away team identifier | Football developer: preserves bilateral team context |
| `away_team_name` | Away team name | Football developer: readable away-side context for analysis |
| `home_score` | Home full-time goals | Football developer: scoreline context for trigger interpretation |
| `away_score` | Away full-time goals | Football developer: scoreline context for trigger interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical row identity at match-team grain |
| `triggered_team_id` | Triggered team identifier | Football developer: identity key for side-scoped joins |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-side context |
| `opponent_team_id` | Opponent team identifier | Football developer: preserves matchup orientation |
| `opponent_team_name` | Opponent team name | Football developer: readable matchup orientation |
| `trigger_threshold_min_xg` | Trigger threshold for minimum xG (`2.5`) | Football developer: explicit trigger-rule traceability |
| `trigger_required_goals` | Trigger-required goals (`0`) | Football developer: explicit trigger-rule traceability |
| `triggered_team_goals` | Goals scored by triggered team | Football developer: core trigger metric |
| `opponent_goals` | Goals scored by opponent | Football developer: bilateral scoreline baseline |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: outcome context around underperformance |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: core chance-creation trigger metric |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality baseline |
| `xg_delta` | Triggered-team xG minus opponent xG | Football developer: reveals chance-creation superiority or parity |
| `triggered_team_goals_minus_xg` | Triggered-team goals minus triggered-team xG | Football developer: direct finishing underperformance measure |
| `opponent_goals_minus_xg` | Opponent goals minus opponent xG | Football developer: opponent finishing baseline comparator |
| `goals_minus_xg_delta` | Triggered minus opponent goals-minus-xG | Football developer: net finishing efficiency gap across sides |
| `triggered_team_total_shots` | Total shots by triggered team | Football developer: volume context behind xG and zero goals |
| `opponent_total_shots` | Total shots by opponent | Football developer: bilateral shot-volume comparator |
| `total_shots_delta` | Triggered minus opponent total shots | Football developer: compact shot-pressure differential |
| `triggered_team_shots_on_target` | Shots on target by triggered team | Football developer: shot execution context for the blank result |
| `opponent_shots_on_target` | Shots on target by opponent | Football developer: bilateral execution baseline |
| `triggered_team_on_target_ratio_pct` | Triggered-team on-target share of total shots (%) | Football developer: precision indicator for attempt quality/execution |
| `opponent_on_target_ratio_pct` | Opponent on-target share of total shots (%) | Football developer: bilateral precision comparator |
| `on_target_ratio_delta_pct` | Triggered minus opponent on-target ratio (percentage points) | Football developer: quick execution-quality differential |
| `triggered_team_big_chances` | Big chances created by triggered team | Football developer: high-quality chance context for missed output |
| `opponent_big_chances` | Big chances created by opponent | Football developer: bilateral chance-quality baseline |
| `triggered_team_big_chances_missed` | Big chances missed by triggered team | Football developer: explicit wastefulness diagnostic |
| `opponent_big_chances_missed` | Big chances missed by opponent | Football developer: bilateral wastefulness comparator |
| `triggered_team_xg_per_shot` | Triggered-team xG per shot | Football developer: average chance quality per attempt |
| `opponent_xg_per_shot` | Opponent xG per shot | Football developer: bilateral attempt-quality comparator |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opponent box | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in triggered-team box | Football developer: bilateral territorial comparator |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Football developer: control-profile context |
| `opponent_possession_pct` | Opponent possession (%) | Football developer: bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: compact control differential |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Football developer: circulation volume baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation baseline |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: ball-retention quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral retention comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: control and execution gap diagnostic |
| `triggered_team_corners` | Corners won by triggered team | Football developer: sustained attacking pressure proxy |
| `opponent_corners` | Corners won by opponent | Football developer: bilateral pressure comparator |
