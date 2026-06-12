---
signal_id: sig_match_shooting_goals_early_goal_late_goal
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Early Goal, Late Goal"
trigger: ">= 1 non-own goal in effective minutes 1-5 and >= 1 non-own goal in effective minutes >= 86."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_shooting_goals_early_goal_late_goal
  sql: clickhouse/gold/signal/sig_match_shooting_goals_early_goal_late_goal.sql
  runner: scripts/gold/signal/runners/sig_match_shooting_goals_early_goal_late_goal.py
---
# sig_match_shooting_goals_early_goal_late_goal

## Purpose

Flag finished matches that feature both an opening-phase breakthrough and an endgame strike, then expose side-oriented scoring-window splits plus shooting/control context.

## Tactical And Statistical Logic

- Trigger condition:
  - `match_early_goal_count >= 1` in effective-minute window `[1, 5]`.
  - `match_late_goal_count >= 1` in effective-minute window `[86, +inf)`.
- Goal events come from `silver.shot` where `is_goal = 1` and `is_own_goal = 0`; ordering minute is `goal_time + goal_overload_time` with minute fallbacks.
- Triggered matches emit two rows (`triggered_side = 'home'` and `'away'`) to preserve canonical `match_team` grain.
- Window diagnostics capture bilateral early/late split counts plus span from first early goal to last late goal.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_early_blitz`, `sig_team_shooting_goals_late_surge_goals`, and `sig_match_shooting_goals_rapid_fire_exchange`; this signal is distinct because it is a match-level conjunction requiring at least one early-window and one late-window goal in the same match.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_shooting_goals_early_goal_late_goal.sql`
- Runner: `scripts/gold/signal/runners/sig_match_shooting_goals_early_goal_late_goal.py`
- Target table: `gold_signals.sig_match_shooting_goals_early_goal_late_goal`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_shooting_goals_early_goal_late_goal.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for joins, deduplication, and QA checks. |
| `match_date` | Match date | Supports backfills and time-based slicing. |
| `home_team_id` | Home team identifier | Preserves fixture context. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves fixture context. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Final score context around the trigger windows. |
| `away_score` | Full-time away goals | Final score context around the trigger windows. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical `match_team` row identity component. |
| `triggered_team_id` | Triggered-side team identifier | Side-oriented join key. |
| `triggered_team_name` | Triggered-side team name | Readable side context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral context. |
| `trigger_threshold_max_early_effective_minute` | Maximum early-window effective minute (`5`) | Explicit trigger provenance for auditability. |
| `trigger_threshold_min_late_effective_minute` | Minimum late-window effective minute (`86`) | Explicit trigger provenance for auditability. |
| `match_early_goal_count` | Total non-own goals in early window | Match-level early-phase goal intensity. |
| `match_late_goal_count` | Total non-own goals in late window | Match-level endgame goal intensity. |
| `home_early_goal_count` | Home non-own goals in early window | Early split transparency by side. |
| `away_early_goal_count` | Away non-own goals in early window | Early split transparency by side. |
| `home_late_goal_count` | Home non-own goals in late window | Late split transparency by side. |
| `away_late_goal_count` | Away non-own goals in late window | Late split transparency by side. |
| `first_early_goal_effective_minute` | Earliest effective minute in early window | Anchors opening-goal timing. |
| `last_late_goal_effective_minute` | Latest effective minute in late window | Anchors endgame-goal timing. |
| `early_to_late_goal_span_minutes` | `last_late_goal_effective_minute - first_early_goal_effective_minute` | Measures temporal spread between trigger windows. |
| `both_sides_scored_early_flag` | 1 when both teams score in early window | Fast bilateral-pattern sanity indicator. |
| `both_sides_scored_late_flag` | 1 when both teams score in late window | Endgame bilateral-pattern sanity indicator. |
| `triggered_team_early_goal_count` | Triggered-side early-window goals | Side-oriented early scoring contribution. |
| `opponent_early_goal_count` | Opponent early-window goals | Bilateral early-window comparator. |
| `early_goal_count_delta` | Triggered minus opponent early-window goals | Net early-window edge. |
| `triggered_team_late_goal_count` | Triggered-side late-window goals | Side-oriented late scoring contribution. |
| `opponent_late_goal_count` | Opponent late-window goals | Bilateral late-window comparator. |
| `late_goal_count_delta` | Triggered minus opponent late-window goals | Net late-window edge. |
| `triggered_team_total_goals` | Triggered-side full-time goals | Outcome context for triggered side. |
| `opponent_total_goals` | Opponent full-time goals | Outcome comparator context. |
| `goal_gap` | Triggered goals minus opponent goals | Final margin from triggered-side perspective. |
| `triggered_team_total_shots` | Triggered-side total shots (`period = 'All'`) | Shot-volume context for scoring windows. |
| `opponent_total_shots` | Opponent total shots (`period = 'All'`) | Bilateral shot-volume comparator. |
| `shot_volume_delta` | Triggered minus opponent total shots | Net attacking-volume differential. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Precision context for triggered side. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral precision comparator. |
| `triggered_team_shot_accuracy_pct` | Triggered-side on-target rate (%) | Normalized shooting precision metric. |
| `opponent_shot_accuracy_pct` | Opponent on-target rate (%) | Bilateral normalized precision comparator. |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Compact precision differential. |
| `triggered_team_xg` | Triggered-side expected goals | Side-level chance-quality baseline. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator. |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-generation balance. |
| `triggered_team_shot_conversion_pct` | Triggered-side goals per shot (%) | Finishing efficiency context. |
| `opponent_shot_conversion_pct` | Opponent goals per shot (%) | Bilateral finishing-efficiency comparator. |
| `shot_conversion_delta_pct` | Triggered minus opponent shot conversion (percentage points) | Net finishing execution differential. |
| `triggered_team_big_chances` | Triggered-side big chances | High-quality chance volume context. |
| `opponent_big_chances` | Opponent big chances | Bilateral high-quality chance comparator. |
| `triggered_team_big_chances_missed` | Triggered-side big chances missed | Wastefulness context. |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness comparator. |
| `triggered_team_touches_opposition_box` | Triggered-side opposition-box touches | Territorial penetration context. |
| `opponent_touches_opposition_box` | Opponent opposition-box touches | Bilateral territorial comparator. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Technical circulation quality context. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral technical comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Execution-quality differential for modeling and QA. |
