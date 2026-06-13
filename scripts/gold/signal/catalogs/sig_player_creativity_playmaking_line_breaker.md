---
signal_id: sig_player_creativity_playmaking_line_breaker
status: active
entity: player
family: creativity
subfamily: playmaking
grain: match_player
headline: "Line Breaker"
trigger: "Player directional progression proxy >= 10 using passes_final_third (player_match_stat) OR team long_ball_attempts (period_stat)."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_creativity_playmaking_line_breaker
  sql: clickhouse/gold/signal/sig_player_creativity_playmaking_line_breaker.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_creativity_playmaking_line_breaker

## Purpose

Detect player-level line-breaking playmaking performances using directional progression proxies when direct progressive-pass counts are unavailable in current source stats.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_passes_final_third_directional_proxy >= 10`
  - OR `triggered_team_long_ball_attempts_directional_proxy >= 10`
- Directional proxy sources:
  - player proxy: `silver.player_match_stat.passes_final_third`
  - team proxy: `silver.period_stat.long_ball_attempts_{home|away}` with `period = 'All'`
- Trigger provenance is explicit per row through:
  - `triggered_player_directional_proxy_source`
  - `triggered_player_directional_proxy_value`
  - `triggered_player_directional_proxy_above_threshold`
- Finished-match scope and valid side mapping are enforced:
  - `silver.match.match_finished = 1`
  - `match_id > 0`
  - player team must map to home/away side.
- Similarity gate note:
  - `sig_player_possession_passing_final_third_engine`: closest metric overlap on `passes_final_third`, but it uses a much stricter threshold (`>= 20`) and sits in possession taxonomy.
  - `sig_player_creativity_playmaking_maestro_output`: same creativity/playmaking family, but trigger is key-pass volume (`chances_created >= 5`) rather than directional progression proxy.
  - `sig_player_creativity_playmaking_expected_wizard`: same family, but trigger is xA under-assist profile, not directional progression volume.
  - Coexistence rationale: this signal adds a lower-threshold directional proxy specifically for creativity/playmaking classification, including a documented team-directness fallback proxy.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_creativity_playmaking_line_breaker.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_creativity_playmaking_line_breaker`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_creativity_playmaking_line_breaker
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
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side orientation at `match_player` grain |
| `triggered_player_id` | Triggered player ID | Primary player identity key |
| `triggered_player_name` | Triggered player name | Readable signal attribution |
| `triggered_team_id` | Triggered player's team ID | Player-team linkage for downstream joins |
| `triggered_team_name` | Triggered player's team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Human-readable opponent context |
| `trigger_threshold_min_directional_proxy` | Trigger floor for directional proxy (`10`) | Explicit threshold provenance and QA guard |
| `triggered_player_passes_final_third_directional_proxy` | Player directional proxy from final-third passes | Primary player-level proxy for line-breaking progression |
| `triggered_team_long_ball_attempts_directional_proxy` | Team directional proxy from long-ball attempts | Fallback directness proxy when explicit progressive-pass counts are unavailable |
| `triggered_player_directional_proxy_source` | Trigger source label (`passes_final_third_proxy`, `team_long_ball_attempts_proxy`, `both_proxies`) | Makes per-row trigger path auditable for downstream consumers |
| `triggered_player_directional_proxy_value` | Max directional proxy value used for ranking | Preserves trigger severity across both proxy branches |
| `triggered_player_directional_proxy_above_threshold` | Directional proxy margin above threshold | Captures activation severity beyond binary trigger |
| `triggered_player_chances_created` | Chances created by triggered player | Creation-volume context around directional progression |
| `triggered_player_expected_assists` | Triggered player expected assists | Chance-quality context for playmaking interpretation |
| `triggered_player_touches_opposition_box` | Triggered player touches in opposition box | High-leverage territorial involvement context |
| `triggered_player_accurate_passes` | Triggered player accurate passes | Passing execution numerator context |
| `triggered_player_total_passes` | Triggered player total passes | Passing workload denominator context |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy (%) | Efficiency context for creative risk profile |
| `triggered_player_minutes_played` | Triggered player minutes played | Exposure context for output interpretation |
| `triggered_player_touches` | Triggered player total touches | Overall involvement context |
| `triggered_team_pass_attempts` | Pass attempts by triggered player's team | Team circulation baseline around player output |
| `opponent_pass_attempts` | Pass attempts by opponent team | Bilateral circulation comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered player's team | Team passing-quality baseline |
| `opponent_accurate_passes` | Accurate passes by opponent team | Bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Triggered team pass accuracy (%) | Team execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `triggered_team_long_ball_attempts` | Long-ball attempts by triggered player's team | Team directness baseline used by proxy branch |
| `opponent_long_ball_attempts` | Long-ball attempts by opponent team | Bilateral directness comparator |
| `triggered_team_accurate_long_balls` | Accurate long balls by triggered player's team | Team directness execution context |
| `opponent_accurate_long_balls` | Accurate long balls by opponent team | Bilateral directness execution comparator |
| `triggered_team_long_ball_accuracy_pct` | Triggered team long-ball accuracy (%) | Quality context for direct progression profile |
| `opponent_long_ball_accuracy_pct` | Opponent long-ball accuracy (%) | Bilateral quality comparator for direct progression |
| `triggered_team_opposition_half_passes` | Triggered team passes in opposition half | Territorial progression baseline for player proxy interpretation |
| `opponent_opposition_half_passes` | Opponent passes in opposition half | Bilateral territorial comparator |
| `triggered_team_possession_pct` | Triggered team possession share (%) | Match control context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `player_share_of_team_passes_pct` | Triggered player share of team pass attempts (%) | Quantifies player centrality in overall circulation |
| `player_share_of_team_opposition_half_passes_pct` | Triggered player final-third passes as % of team opposition-half passes | Quantifies player contribution to advanced-territory ball progression |
