---
signal_id: sig_match_shooting_goals_rapid_fire_exchange
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Rapid-Fire Exchange"
trigger: "Both teams score within the same 3-minute effective-goal window via at least one opposite-side consecutive goal pair."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_match_shooting_goals_rapid_fire_exchange
  sql: clickhouse/gold/signal/sig_match_shooting_goals_rapid_fire_exchange.sql
  runner: scripts/gold/signal/runners/sig_match_shooting_goals_rapid_fire_exchange.py
---
# sig_match_shooting_goals_rapid_fire_exchange

## Purpose

Flag matches with immediate bilateral goal trading (3-minute exchange windows), then emit side-oriented finishing, shot-quality, and control context to explain which team benefited more from rapid scoring momentum.

## Tactical And Statistical Logic

- Trigger condition: at least one opposite-side consecutive non-own-goal pair where `effective_goal_minute_gap <= 3`.
- Goal-event ordering uses `goal_time + goal_overload_time` (with minute fallbacks) to keep stoppage-time exchanges chronologically consistent.
- Match-level trigger emits two rows (`triggered_side = 'home'` and `'away'`) so downstream team consumers retain canonical `match_team` grain.
- Rapid-fire diagnostics include exchange frequency, first/last exchange timing, minimum/average gap, and side-oriented exchange-goal participation counts.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_rapid_response_goal` and `sig_match_shooting_goals_end_to_end_drama`; this signal is distinct because it is match-level, requires bilateral opposite-side scoring in a shared 3-minute window, and models exchange bursts rather than per-team concession-response behavior or half-level scoring balance.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_shooting_goals_rapid_fire_exchange.sql`
- Runner: `scripts/gold/signal/runners/sig_match_shooting_goals_rapid_fire_exchange.py`
- Target table: `gold.sig_match_shooting_goals_rapid_fire_exchange`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_shooting_goals_rapid_fire_exchange.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for joins, deduplication, and QA checks. |
| `match_date` | Match date | Supports reproducible backfills and temporal slicing. |
| `home_team_id` | Home team identifier | Preserves full fixture context. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves full fixture context. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Scoreline context around rapid exchanges. |
| `away_score` | Full-time away goals | Scoreline context around rapid exchanges. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical `match_team` row identity component. |
| `triggered_team_id` | Triggered-side team identifier | Side-oriented join key. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator context. |
| `trigger_threshold_rapid_fire_window_minutes` | Configured rapid-fire window in minutes (`3`) | Explicit trigger provenance for explainability and QA. |
| `trigger_threshold_min_rapid_fire_exchanges` | Minimum required qualifying exchange count (`1`) | Makes threshold logic explicit for downstream audits. |
| `match_rapid_fire_exchange_count` | Count of opposite-side consecutive goal exchanges in-window | Captures burst frequency intensity within the match. |
| `home_goals_in_rapid_fire_exchanges` | Home goals participating in qualifying exchanges | Exposes home-side contribution to exchange bursts. |
| `away_goals_in_rapid_fire_exchanges` | Away goals participating in qualifying exchanges | Exposes away-side contribution to exchange bursts. |
| `first_rapid_fire_exchange_start_effective_minute` | Effective minute of first goal in earliest qualifying exchange | Anchors where rapid-fire momentum begins. |
| `first_rapid_fire_exchange_end_effective_minute` | Effective minute of second goal in earliest qualifying exchange | Anchors completion time of first detected exchange. |
| `first_rapid_fire_exchange_gap_minutes` | Minute gap for the earliest qualifying exchange | Measures initial exchange speed. |
| `smallest_exchange_gap_minutes` | Minimum minute gap among qualifying exchanges | Captures peak scoring immediacy. |
| `average_exchange_gap_minutes` | Average minute gap across qualifying exchanges | Summarizes tempo of bilateral goal trades. |
| `last_rapid_fire_exchange_end_effective_minute` | Effective minute of second goal in latest qualifying exchange | Anchors how late rapid exchanges persist. |
| `match_rapid_fire_exchange_span_minutes` | Last qualifying exchange end minute minus first start minute | Measures temporal spread of exchange bursts. |
| `both_sides_scored_in_rapid_fire_flag` | 1 when both sides have exchange-participating goals | Explicit bilateral sanity flag for trigger interpretation. |
| `triggered_team_rapid_fire_goals` | Triggered-side goals participating in qualifying exchanges | Side-oriented rapid-fire contribution metric. |
| `opponent_rapid_fire_goals` | Opponent goals participating in qualifying exchanges | Bilateral rapid-fire comparator. |
| `rapid_fire_goals_delta` | Triggered minus opponent rapid-fire goals | Net exchange participation differential. |
| `triggered_team_goals` | Triggered-side full-time goals | Outcome context for triggered side. |
| `opponent_goals` | Opponent full-time goals | Outcome comparator context. |
| `goal_gap` | Triggered goals minus opponent goals | Final score differential from triggered-side perspective. |
| `triggered_team_total_shots` | Triggered-side total shots (`period = 'All'`) | Shot-volume context behind goal exchanges. |
| `opponent_total_shots` | Opponent total shots (`period = 'All'`) | Bilateral shot-volume comparator. |
| `shot_volume_delta` | Triggered minus opponent total shots | Net attacking-volume differential. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Precision context for triggered side. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral precision comparator. |
| `triggered_team_shot_accuracy_pct` | Triggered-side on-target rate (%) | Normalized shooting precision metric. |
| `opponent_shot_accuracy_pct` | Opponent on-target rate (%) | Bilateral normalized precision comparator. |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Compact precision differential for diagnostics. |
| `triggered_team_xg` | Triggered-side expected goals | Side-level chance-quality baseline. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator. |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-generation balance. |
| `triggered_team_shot_conversion_pct` | Triggered-side goals per shot (%) | Finishing efficiency context for triggered side. |
| `opponent_shot_conversion_pct` | Opponent goals per shot (%) | Bilateral finishing-efficiency comparator. |
| `shot_conversion_delta_pct` | Triggered minus opponent shot conversion (percentage points) | Net finishing execution differential. |
| `triggered_team_big_chances` | Triggered-side big chances | High-quality chance volume context. |
| `opponent_big_chances` | Opponent big chances | Bilateral high-quality chance comparator. |
| `triggered_team_big_chances_missed` | Triggered-side big chances missed | Wastefulness context behind exchange outcomes. |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness comparator. |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Territorial penetration context. |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context around goal trades. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-circulation quality context in high-tempo phases. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation-quality comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Technical execution differential for modeling and QA. |
