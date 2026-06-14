---
signal_id: sig_match_shooting_goals_boring_stalemate
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Boring Stalemate"
trigger: "Combined match xG < 0.50 and full-time scoreline is 0-0 (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_shooting_goals_boring_stalemate
  sql: clickhouse/gold/dml/signals/match/sig_match_shooting_goals_boring_stalemate.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_shooting_goals_boring_stalemate

## Purpose

Detect goalless matches with extremely low combined chance quality and provide bilateral team context for shot creation, territorial access, and circulation quality in stale game states.

## Tactical And Statistical Logic

- Trigger condition: `coalesce(home_score, 0) = 0`, `coalesce(away_score, 0) = 0`, and `coalesce(expected_goals_home, 0) + coalesce(expected_goals_away, 0) < 0.50` at `period = 'All'`.
- Emits two side-oriented rows per triggered match (`triggered_side = 'home'` and `'away'`) to preserve canonical `match_team` grain.
- Enrichment keeps the low-event profile explainable via bilateral shot volume, shot precision, big-chance activity, penalty-box touches, possession split, and pass accuracy.
- Similarity gate note: nearest active signals are `sig_match_shooting_goals_goal_fest` and `sig_match_possession_passing_dead_zone_game`; this signal remains distinct because it is explicitly anchored on *both* goalless outcome and strict low combined xG (`< 0.50`) rather than high-goal explosions or zero-box-touch proxies.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_shooting_goals_boring_stalemate.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_shooting_goals_boring_stalemate`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_shooting_goals_boring_stalemate
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for joins and deduplication. |
| `match_date` | Match date | Supports temporal slicing and batch auditing. |
| `home_team_id` | Home team identifier | Preserves fixture context. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves fixture context. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Required to verify goalless trigger condition. |
| `away_score` | Full-time away goals | Required to verify goalless trigger condition. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity for `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Team-level join key for downstream features. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-team context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral context. |
| `trigger_threshold_match_total_xg` | Configured xG threshold (`0.50`) | Makes trigger provenance explicit for QA. |
| `match_total_xg` | Combined expected goals | Core trigger magnitude for chance scarcity. |
| `match_total_goals` | Combined goals in the match | Confirms goalless outcome at match level. |
| `match_total_shots` | Combined total shots | Shot-volume context around low xG trigger. |
| `match_total_shots_on_target` | Combined shots on target | Match-level shot precision context. |
| `match_total_big_chances` | Combined big chances | High-quality chance scarcity context. |
| `triggered_team_xg` | Triggered-side expected goals | Side-level chance-quality contribution. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator. |
| `xg_gap` | Triggered xG minus opponent xG | Directional chance-creation edge. |
| `triggered_team_total_shots` | Triggered-side total shots | Side-level attacking volume. |
| `opponent_total_shots` | Opponent total shots | Bilateral attacking-volume comparator. |
| `shot_volume_delta` | Triggered minus opponent total shots | Net shot-volume differential. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Side-level shot precision contribution. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral shot precision comparator. |
| `shot_on_target_delta` | Triggered minus opponent shots on target | Net on-target differential. |
| `triggered_team_shot_accuracy_pct` | Triggered-side on-target rate (%) | Normalized shot precision metric. |
| `opponent_shot_accuracy_pct` | Opponent on-target rate (%) | Bilateral normalized precision comparator. |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Compact precision differential for diagnostics. |
| `triggered_team_big_chances` | Triggered-side big chances | High-quality chance count by side. |
| `opponent_big_chances` | Opponent big chances | Bilateral high-quality chance comparator. |
| `big_chance_delta` | Triggered minus opponent big chances | Net big-chance generation edge. |
| `triggered_team_touches_opposition_box` | Triggered-side opposition-box touches | Final-third penetration context. |
| `opponent_touches_opposition_box` | Opponent opposition-box touches | Bilateral penetration comparator. |
| `opposition_box_touch_delta` | Triggered minus opponent opposition-box touches | Net box-access differential in stale games. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Control-share context for the stalemate. |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Circulation quality context. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation-quality comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Net execution-quality differential. |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Side-level circulation volume. |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation-volume comparator. |
| `pass_attempt_delta` | Triggered minus opponent pass attempts | Net circulation-load differential. |
