---
signal_id: sig_match_possession_passing_heavy_rotation
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Match Possession Passing Heavy Rotation"
trigger: "Total player touches in the match exceed 1000 while the maximum touches by any single player are <= 80."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_possession_passing_heavy_rotation
  sql: clickhouse/gold/signal/sig_match_possession_passing_heavy_rotation.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_possession_passing_heavy_rotation

## Purpose

Triggers when a match has very high total touch volume but no individual touch monopolist, surfacing distributed circulation and heavy on-ball rotation.

## Tactical And Statistical Logic

- Trigger condition: `match_total_player_touches > 1000` and `match_max_player_touches <= 80`.
- Touch volume is computed from player-level full-match touches aggregated by team and then combined at match level.
- Emits one row per side (`triggered_side` = `home` and `away`) so downstream consumers can compare the same distributed-touch game from each team orientation.
- Enriches the trigger with side-level pass quality, possession share, territorial progression, box access, and xG context.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_possession_passing_heavy_rotation.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_possession_passing_heavy_rotation`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_possession_passing_heavy_rotation
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins and traceability. |
| `match_date` | Match calendar date | Football developer: supports time-based slicing and QA. |
| `home_team_id` | Home team numeric ID | Football developer: fixture context and orientation recovery. |
| `home_team_name` | Home team display name | Football developer: readable fixture context. |
| `away_team_id` | Away team numeric ID | Football developer: fixture context and orientation recovery. |
| `away_team_name` | Away team display name | Football developer: readable fixture context. |
| `home_score` | Full-time home goals | Football developer: outcome context around distributed-touch games. |
| `away_score` | Full-time away goals | Football developer: outcome context around distributed-touch games. |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: canonical identity for match-team grain. |
| `triggered_team_id` | Triggered-side team ID | Football developer: side-scoped key for downstream features. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable side-scoped team identity. |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup interpretation. |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral matchup interpretation. |
| `trigger_threshold_match_total_player_touches` | Match total-touch threshold used by trigger (`1000`) | Football developer: explicit trigger auditability and model explainability. |
| `trigger_threshold_max_player_touches` | Max-player-touch cap used by trigger (`80`) | Football developer: explicit concentration guardrail traceability. |
| `match_total_player_touches` | Combined player touches across both teams | Football developer: primary volume component of heavy-rotation detection. |
| `match_max_player_touches` | Highest touches by any single player in the match | Football developer: primary concentration component of heavy-rotation detection. |
| `match_players_recorded` | Number of players with recorded touch rows in the match | Football developer: denominator context for touch distribution robustness. |
| `match_average_player_touches` | Average touches per recorded player in the match | Football developer: compact spread indicator beyond total volume. |
| `triggered_team_total_player_touches` | Total player touches for triggered side | Football developer: side contribution to overall touch load. |
| `opponent_total_player_touches` | Total player touches for opponent side | Football developer: bilateral touch-volume comparator. |
| `triggered_team_max_player_touches` | Triggered-side max touches by a single player | Football developer: side-level concentration diagnostic. |
| `opponent_max_player_touches` | Opponent max touches by a single player | Football developer: bilateral concentration comparator. |
| `triggered_team_players_recorded` | Count of triggered-side players with touch rows | Football developer: side-level denominator for distribution analysis. |
| `opponent_players_recorded` | Count of opponent players with touch rows | Football developer: bilateral denominator comparator. |
| `triggered_team_top_touch_player_id` | Triggered-side top touch player's ID | Football developer: identity of side focal touch contributor. |
| `triggered_team_top_touch_player_name` | Triggered-side top touch player's name | Football developer: readable focal touch contributor context. |
| `triggered_team_top_touch_player_touches` | Triggered-side top touch player's touch total | Football developer: magnitude of side focal involvement. |
| `opponent_top_touch_player_id` | Opponent top touch player's ID | Football developer: bilateral focal-contributor comparator. |
| `opponent_top_touch_player_name` | Opponent top touch player's name | Football developer: readable bilateral focal-contributor comparator. |
| `opponent_top_touch_player_touches` | Opponent top touch player's touch total | Football developer: bilateral focal involvement comparator. |
| `triggered_team_touch_share_pct` | Triggered-side share of total match touches (%) | Football developer: share-based control of distributed circulation load. |
| `opponent_touch_share_pct` | Opponent share of total match touches (%) | Football developer: bilateral share comparator. |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Football developer: passing-volume context behind touches. |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral passing-volume comparator. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Football developer: passing-quality context under heavy rotation. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral passing-quality comparator. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control context for touch share interpretation. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator. |
| `triggered_team_opposition_half_passes` | Triggered-side opposition-half passes | Football developer: territorial progression context for distributed circulation. |
| `opponent_opposition_half_passes` | Opponent opposition-half passes | Football developer: bilateral territorial progression comparator. |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opponent penalty box | Football developer: penetration context for high-rotation possession. |
| `opponent_touches_opposition_box` | Opponent touches in triggered-side penalty box | Football developer: bilateral penetration comparator. |
| `triggered_team_xg` | Triggered-side expected goals | Football developer: chance-quality outcome context. |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator. |
| `xg_gap` | Triggered-side xG minus opponent xG | Football developer: net attacking quality edge despite shared rotation profile. |
