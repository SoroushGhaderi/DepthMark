---
signal_id: sig_match_possession_passing_dead_zone_game
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Possession Passing Dead Zone Game"
trigger: "Both sides record zero opposition-box touches at full time (`period = 'All'`), used as a proxy for zero opposition 6-yard-box touches."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_possession_passing_dead_zone_game
  sql: clickhouse/gold/dml/signals/match/sig_match_possession_passing_dead_zone_game.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_match_possession_passing_dead_zone_game

## Purpose

Triggers matches where both teams fail to generate any opposition-box touches, surfacing sterile, low-penetration game states that align with a tactical dead-zone profile.

## Tactical And Statistical Logic

- Trigger condition: `touches_opp_box_home = 0` and `touches_opp_box_away = 0` at full-match period stats.
- Because no dedicated 6-yard touch metric exists in `silver.period_stat`, this signal uses opposition-box touches as the closest available proxy for the requested dead-zone condition.
- Emits one row per side (`home` and `away`) so downstream team pipelines can consume a side-oriented record for the same match-level trigger.
- Enriches the trigger with pass volume, pass accuracy, possession share, territorial pass context, and xG context.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_possession_passing_dead_zone_game.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_match_possession_passing_dead_zone_game`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_match_possession_passing_dead_zone_game
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable identity for joins, QA, and feature lineage. |
| `match_date` | Match calendar date | Football developer: time slicing and model backtest partitioning. |
| `home_team_id` | Home team numeric ID | Football developer: fixture identity and orientation reconstruction. |
| `home_team_name` | Home team display name | Football developer: analyst-readable fixture context. |
| `away_team_id` | Away team numeric ID | Football developer: fixture identity and orientation reconstruction. |
| `away_team_name` | Away team display name | Football developer: analyst-readable fixture context. |
| `home_score` | Full-time home goals | Football developer: outcome context for dead-zone fixtures. |
| `away_score` | Full-time away goals | Football developer: outcome context for dead-zone fixtures. |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: side-oriented interpretation of a match-level trigger. |
| `triggered_team_id` | Triggered-side team ID | Football developer: side identity for downstream team features. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered-side identity. |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup context. |
| `opponent_team_name` | Opponent team name | Football developer: bilateral matchup context. |
| `trigger_threshold_opposition_six_yard_box_touches` | Trigger threshold count (`0`) | Football developer: explicit threshold reference used by signal logic. |
| `match_total_opposition_box_touches_proxy` | Combined opposition-box touches by both teams | Football developer: transparent proxy variable underpinning the dead-zone trigger. |
| `triggered_team_touches_opposition_box` | Triggered-side opposition-box touches | Football developer: side-level contribution to the dead-zone condition. |
| `opponent_touches_opposition_box` | Opponent opposition-box touches | Football developer: bilateral comparator for dead-zone confirmation. |
| `match_total_pass_attempts` | Combined pass attempts by both teams | Football developer: passing tempo context in low-penetration matches. |
| `triggered_team_pass_attempts` | Pass attempts by triggered side | Football developer: side-level passing workload under dead-zone conditions. |
| `opponent_pass_attempts` | Pass attempts by opponent side | Football developer: bilateral passing workload comparator. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Football developer: quality context for circulation in sterile games. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral passing quality comparator. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control context for dead-zone passing profiles. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator. |
| `triggered_team_opposition_half_passes` | Triggered-side opposition-half passes | Football developer: territorial progression context without box penetration. |
| `opponent_opposition_half_passes` | Opponent opposition-half passes | Football developer: bilateral territorial comparator. |
| `triggered_team_total_shots` | Triggered-side total shots | Football developer: shot output context beneath dead-zone territory. |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral shot-output comparator. |
| `triggered_team_xg` | Triggered-side expected goals | Football developer: chance-quality context beyond raw shot count. |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator. |
| `match_total_xg` | Combined expected goals in the match | Football developer: aggregate chance-quality output in dead-zone games. |
| `xg_gap` | Triggered-side xG minus opponent xG | Football developer: directional chance-quality edge for side-oriented consumers. |
