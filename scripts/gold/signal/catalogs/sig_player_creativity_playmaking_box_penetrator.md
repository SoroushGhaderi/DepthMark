---
signal_id: sig_player_creativity_playmaking_box_penetrator
status: active
entity: player
family: creativity
subfamily: playmaking
grain: match_player
headline: "Box Penetrator"
trigger: "Player completes >= 5 passes into the penalty area (proxied by passes_final_third) in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_creativity_playmaking_box_penetrator
  sql: clickhouse/gold/dml/signals/player/sig_player_creativity_playmaking_box_penetrator.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_creativity_playmaking_box_penetrator

## Purpose

Detect player-level playmakers who repeatedly penetrate advanced attacking zones via pass progression, with a practical proxy for penalty-area pass completions based on available FotMob stats.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_penalty_area_passes_proxy >= 5`
- Source limitation note:
  - `silver.player_match_stat` does not expose a direct `passes_into_penalty_area` field.
  - This signal therefore uses `passes_final_third` as the explicit proxy (`triggered_player_penalty_area_passes_proxy_source = 'passes_final_third_proxy'`).
- Finished-match scope and valid side mapping are enforced:
  - `silver.match.match_finished = 1`
  - `match_id > 0`
  - player team must map to home/away side.
- Bilateral passing, territorial, and control context is retained from `silver.period_stat` (`period = 'All'`).
- Similarity gate note:
  - `sig_player_possession_passing_box_penetrator`: closest naming overlap, but that signal is possession/passing family and triggers on `touches_opp_box > 10`, not pass progression threshold.
  - `sig_player_creativity_playmaking_line_breaker`: same creativity/playmaking family and includes `passes_final_third` proxy, but it uses directional composite trigger (`>= 10` or team long-ball proxy) rather than this explicit `>= 5` box-penetration proxy target.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_creativity_playmaking_box_penetrator.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_creativity_playmaking_box_penetrator`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_creativity_playmaking_box_penetrator
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for joins and deduplication |
| `match_date` | Match date | Temporal slicing and reproducible backfills |
| `home_team_id` | Home team identifier | Preserves bilateral fixture context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team identifier | Preserves bilateral fixture context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Match outcome context |
| `away_score` | Away full-time goals | Match outcome context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side orientation at match-player grain |
| `triggered_player_id` | Triggered player ID | Primary player identity key |
| `triggered_player_name` | Triggered player name | Readable signal attribution |
| `triggered_team_id` | Triggered player's team ID | Player-team linkage for downstream joins |
| `triggered_team_name` | Triggered player's team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Human-readable opponent context |
| `trigger_threshold_min_penalty_area_passes` | Trigger floor for penalty-area pass proxy (`5`) | Explicit threshold provenance for QA |
| `triggered_player_penalty_area_passes_proxy` | Proxy count for penalty-area passes (from `passes_final_third`) | Core trigger metric under available-data constraint |
| `triggered_player_penalty_area_passes_proxy_source` | Proxy source label | Makes trigger provenance explicit for downstream consumers |
| `triggered_player_penalty_area_passes_proxy_above_threshold` | Proxy margin above threshold (`value - 5`) | Trigger severity beyond binary activation |
| `triggered_player_passes_final_third` | Player passes into final third | Raw supporting metric behind proxy |
| `triggered_player_chances_created` | Chances created by triggered player | Creative-output context around progression profile |
| `triggered_player_expected_assists` | Triggered player expected assists | Chance-quality context |
| `triggered_player_touches_opposition_box` | Triggered player touches in opposition box | Territorial involvement context |
| `triggered_player_accurate_passes` | Triggered player accurate passes | Passing execution numerator context |
| `triggered_player_total_passes` | Triggered player total passes | Passing workload denominator context |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy (%) | Efficiency context for risk/reward profiling |
| `triggered_player_minutes_played` | Triggered player minutes played | Exposure context for interpretation |
| `triggered_player_touches` | Triggered player total touches | Overall involvement context |
| `triggered_team_pass_attempts` | Pass attempts by triggered player's team | Team circulation baseline |
| `opponent_pass_attempts` | Pass attempts by opponent team | Bilateral circulation comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered player's team | Team passing-quality baseline |
| `opponent_accurate_passes` | Accurate passes by opponent team | Bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Triggered team pass accuracy (%) | Team execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `triggered_team_touches_opposition_box` | Triggered team touches in opposition box | Team territorial pressure context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial-pressure comparator |
| `triggered_team_possession_pct` | Triggered team possession share (%) | Match control context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `player_share_of_team_penalty_area_passes_proxy_pct` | Player proxy-pass share against team opposition-half pass volume (%) | Concentration context for advanced-territory progression responsibility |
| `player_share_of_team_passes_pct` | Triggered player share of team pass attempts (%) | Role centrality in overall circulation |
