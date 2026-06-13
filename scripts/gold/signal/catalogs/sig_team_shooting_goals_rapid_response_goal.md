---
signal_id: sig_team_shooting_goals_rapid_response_goal
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Rapid Response Goal"
trigger: "Team scores a non-own goal within 2 effective minutes of conceding a non-own goal in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_rapid_response_goal
  sql: clickhouse/gold/signal/sig_team_shooting_goals_rapid_response_goal.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_shooting_goals_rapid_response_goal

## Purpose

Detect team-level bounce-back scoring where a side responds immediately after conceding, scoring within two effective minutes.

## Tactical And Statistical Logic

- Trigger condition:
  - Non-own goal events from `silver.shot` (`is_goal = 1`, `is_own_goal = 0`).
  - A team scores on the next match goal event after conceding, with effective-minute gap `<= 2`.
- Effective-minute uses `goal_time + goal_overload_time` (fallback `minute + minute_added`) to keep timing deterministic across stoppage-time records.
- Trigger is evaluated bilaterally at `match_team` grain (`triggered_side`), allowing both sides to trigger in one match.
- Response diagnostics preserve first concede and first response timing, response-gap intensity, and symmetric opponent comparators.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_early_blitz` and `sig_player_shooting_goals_rapid_brace`; this signal is distinct because it models opponent-goal reaction speed, not pure early-window burst scoring or player-level brace bursts.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_shooting_goals_rapid_response_goal.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_shooting_goals_rapid_response_goal`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_shooting_goals_rapid_response_goal
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins and deterministic deduplication |
| `match_date` | Match date | Football developer: temporal slicing and backfill traceability |
| `home_team_id` | Home team identifier | Football developer: preserves bilateral fixture orientation |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: preserves bilateral fixture orientation |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: final-score outcome context around response behavior |
| `away_score` | Away full-time goals | Football developer: final-score outcome context around response behavior |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical row identity at match-team grain |
| `triggered_team_id` | Triggered team identifier | Football developer: identity anchor for side-oriented downstream joins |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Football developer: readable opponent attribution |
| `trigger_threshold_max_response_minutes` | Maximum allowed concede-to-response gap (`2`) | Football developer: explicit trigger provenance for reproducibility |
| `trigger_threshold_min_rapid_response_goals` | Minimum rapid-response count required (`1`) | Football developer: explicit activation threshold for QA governance |
| `triggered_team_rapid_response_goals` | Number of triggered-team goals scored within two minutes of conceding | Football developer: core trigger intensity metric |
| `opponent_rapid_response_goals` | Opponent count of rapid-response goals under the same rule | Football developer: bilateral reaction-speed comparator |
| `rapid_response_goals_delta` | Triggered minus opponent rapid-response goal count | Football developer: net reaction-speed edge diagnostic |
| `triggered_team_first_conceded_goal_minute_before_response` | Base minute of the conceded goal preceding first qualifying response | Football developer: timing anchor for first response sequence reconstruction |
| `triggered_team_first_conceded_goal_added_time_before_response` | Added-time component of first conceded goal preceding response | Football developer: stoppage-time precision for first response sequence |
| `triggered_team_first_conceded_goal_effective_minute_before_response` | Effective minute of first conceded goal preceding response | Football developer: normalized concede timing for reproducible sequencing |
| `triggered_team_first_response_goal_minute` | Base minute of triggered-team first qualifying response goal | Football developer: first response timing anchor |
| `triggered_team_first_response_goal_added_time` | Added-time component of first qualifying response goal | Football developer: stoppage-time precision for first response goal |
| `triggered_team_first_response_goal_effective_minute` | Effective minute of first qualifying response goal | Football developer: normalized response timestamp for sequence analytics |
| `minutes_to_first_response_goal` | Effective-minute gap from conceded goal to first qualifying response goal | Football developer: primary reaction-speed metric |
| `triggered_team_average_response_time_minutes` | Average effective-minute response gap across qualifying events | Football developer: stable team-level reaction-speed baseline |
| `opponent_average_response_time_minutes` | Opponent average effective-minute response gap across qualifying events | Football developer: bilateral reaction-speed benchmark |
| `average_response_time_delta_minutes` | Triggered minus opponent average response gap (minutes) | Football developer: compact net reaction-speed differential |
| `rapid_response_window_margin_minutes` | Remaining margin to threshold (`2 - minutes_to_first_response_goal`) | Football developer: closeness/severity diagnostic versus trigger boundary |
| `triggered_team_rapid_response_goals_above_threshold` | Rapid-response goals above minimum required count (`count - 1`) | Football developer: trigger intensity grading beyond binary activation |
| `triggered_team_goals_final` | Triggered-team full-time goals | Football developer: links response behavior to final output |
| `opponent_goals_final` | Opponent full-time goals | Football developer: bilateral final score comparator |
| `goal_delta_final` | Triggered minus opponent full-time goals | Football developer: outcome context for reaction-speed profile |
| `triggered_team_total_shots` | Triggered-team total shots (`period = 'All'`) | Football developer: shot-volume context behind response output |
| `opponent_total_shots` | Opponent total shots (`period = 'All'`) | Football developer: bilateral shot-volume comparator |
| `total_shots_delta` | Triggered minus opponent total shots | Football developer: net pressure indicator |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Football developer: shooting execution context |
| `opponent_shots_on_target` | Opponent shots on target | Football developer: bilateral execution comparator |
| `triggered_team_on_target_ratio_pct` | Triggered-team shots-on-target ratio (%) | Football developer: finishing precision proxy |
| `opponent_on_target_ratio_pct` | Opponent shots-on-target ratio (%) | Football developer: bilateral finishing precision comparator |
| `on_target_ratio_delta_pct` | Triggered minus opponent on-target ratio (percentage points) | Football developer: compact precision differential |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: chance-quality production context |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: net chance-generation edge |
| `triggered_team_big_chances` | Triggered-team big chances | Football developer: high-value chance volume context |
| `opponent_big_chances` | Opponent big chances | Football developer: bilateral high-value chance comparator |
| `triggered_team_big_chances_missed` | Triggered-team big chances missed | Football developer: wastefulness context around rapid responses |
| `opponent_big_chances_missed` | Opponent big chances missed | Football developer: bilateral finishing-variance comparator |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Football developer: match-control context |
| `opponent_possession_pct` | Opponent possession (%) | Football developer: bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Football developer: circulation-volume baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: ball-retention execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral retention comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: compact retention differential |
| `triggered_team_corners` | Triggered-team corners | Football developer: sustained pressure proxy |
| `opponent_corners` | Opponent corners | Football developer: bilateral pressure comparator |
