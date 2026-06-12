---
signal_id: sig_match_shooting_goals_high_pressure_finish
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "High-Pressure Finish"
trigger: "Combined shots by both teams after the 85th minute (`effective_shot_minute > 85`) are >= 10."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_shooting_goals_high_pressure_finish
  sql: clickhouse/gold/signal/sig_match_shooting_goals_high_pressure_finish.sql
  runner: scripts/gold/signal/runners/sig_match_shooting_goals_high_pressure_finish.py
---
# sig_match_shooting_goals_high_pressure_finish

## Purpose

Detect matches that turn into late two-sided shot pressure (10+ combined attempts after the 85th minute), then expose bilateral team context for end-game intensity, finishing quality, and control diagnostics.

## Tactical And Statistical Logic

- Trigger condition: combined late shots where `effective_shot_minute = coalesce(goal_time, minute, 0) + coalesce(goal_overload_time, minute_added, 0)` and `effective_shot_minute > 85` is at least `10`.
- Late-shot rollups are computed from `silver.shot`, mapped to home/away by `team_id` against `silver.match` team IDs, then filtered to known sides only.
- Match-level trigger emits two rows (`triggered_side = 'home'` and `'away'`) to preserve canonical `match_team` grain for downstream joins.
- Enrichment combines late-shot pressure metrics (volume, on-target load, late accuracy) with full-match shooting, xG, scoreline, chance quality, possession, and pass-execution context from `silver.period_stat` (`period = 'All'`).
- Similarity gate note: closest active signals are `sig_match_shooting_goals_high_volume_low_target` and `sig_match_shooting_goals_end_to_end_drama`; this signal is distinct because it is strictly late-window shot-volume driven (`85'+`), independent of full-match shot totals, target caps, or half-goal split rules.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_shooting_goals_high_pressure_finish.sql`
- Runner: `scripts/gold/signal/runners/sig_match_shooting_goals_high_pressure_finish.py`
- Target table: `gold_signals.sig_match_shooting_goals_high_pressure_finish`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_shooting_goals_high_pressure_finish.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable primary key for joins, QA, and deduplication. |
| `match_date` | Match date | Enables reproducible time-based backfills and slicing. |
| `home_team_id` | Home team identifier | Preserves fixture context and home-side keying. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves fixture context and away-side keying. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Anchors final-score context around late pressure. |
| `away_score` | Full-time away goals | Anchors final-score context around late pressure. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical `match_team` row identity component. |
| `triggered_team_id` | Triggered-side team identifier | Side-oriented team join key. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparator join key. |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator context. |
| `trigger_threshold_late_shot_minute_exclusive` | Configured late-window lower bound (`85`) | Makes minute-bound trigger provenance explicit for audits. |
| `trigger_threshold_match_total_late_shots_min` | Configured combined late-shot floor (`10`) | Exposes threshold contract directly in output rows. |
| `match_late_shots_total` | Combined home+away late shots (`85'+`) | Core trigger magnitude for end-game pressure intensity. |
| `home_late_shots` | Home-side late shots (`85'+`) | Reveals home contribution to late pressure. |
| `away_late_shots` | Away-side late shots (`85'+`) | Reveals away contribution to late pressure. |
| `match_late_shots_on_target_total` | Combined late shots on target | Adds late-window precision context to raw volume. |
| `match_late_shot_accuracy_pct` | Combined late-window on-target rate (%) | Normalizes late precision across different shot totals. |
| `triggered_team_late_shots` | Triggered-side late shots (`85'+`) | Side-oriented late pressure load. |
| `opponent_late_shots` | Opponent late shots (`85'+`) | Bilateral late pressure comparator. |
| `late_shot_volume_delta` | Triggered minus opponent late shots | Net late-window pressure differential. |
| `triggered_team_late_shots_on_target` | Triggered-side late shots on target | Side-level late precision count. |
| `opponent_late_shots_on_target` | Opponent late shots on target | Bilateral late precision comparator. |
| `late_shot_on_target_delta` | Triggered minus opponent late shots on target | Net late-window on-target differential. |
| `triggered_team_late_shot_accuracy_pct` | Triggered-side late-window on-target rate (%) | Side-normalized late precision quality metric. |
| `opponent_late_shot_accuracy_pct` | Opponent late-window on-target rate (%) | Bilateral normalized late precision comparator. |
| `late_shot_accuracy_delta_pct` | Triggered minus opponent late-window accuracy (percentage points) | Compact late precision execution differential. |
| `triggered_team_total_shots` | Triggered-side full-match total shots | Full-match volume baseline against late burst behavior. |
| `opponent_total_shots` | Opponent full-match total shots | Bilateral full-match volume comparator. |
| `shot_volume_delta` | Triggered minus opponent full-match shots | Net full-match shot-volume differential. |
| `triggered_team_shots_on_target` | Triggered-side full-match shots on target | Full-match side precision count. |
| `opponent_shots_on_target` | Opponent full-match shots on target | Bilateral full-match precision comparator. |
| `shot_on_target_delta` | Triggered minus opponent full-match shots on target | Net full-match on-target differential. |
| `triggered_team_xg` | Triggered-side expected goals | Side-level chance-quality baseline. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator. |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-generation balance from triggered perspective. |
| `triggered_team_goals` | Triggered-side full-time goals | Final scoring output for triggered side. |
| `opponent_goals` | Opponent full-time goals | Bilateral scoring comparator. |
| `goal_gap` | Triggered goals minus opponent goals | Match outcome edge from triggered perspective. |
| `triggered_team_shot_conversion_pct` | Triggered-side goals per shot (%) | Side finishing efficiency context. |
| `opponent_shot_conversion_pct` | Opponent goals per shot (%) | Bilateral finishing-efficiency comparator. |
| `shot_conversion_delta_pct` | Triggered minus opponent shot conversion (percentage points) | Net finishing-execution differential. |
| `triggered_team_big_chances` | Triggered-side big chances | High-quality chance count for triggered side. |
| `opponent_big_chances` | Opponent big chances | Bilateral big-chance comparator. |
| `big_chance_delta` | Triggered minus opponent big chances | Net high-quality chance differential. |
| `triggered_team_big_chances_missed` | Triggered-side big chances missed | Side wastefulness context under late pressure. |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness comparator. |
| `big_chances_missed_delta` | Triggered minus opponent big chances missed | Net chance-waste differential. |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Territorial penetration context for pressure interpretation. |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial penetration comparator. |
| `opposition_box_touch_delta` | Triggered minus opponent opposition-box touches | Net final-third/box occupation differential. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context around late pressure phases. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net match control differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Side circulation-quality context under game-state pressure. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation-quality comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Net technical-execution differential for diagnostics. |
