---
signal_id: sig_player_creativity_playmaking_box_to_box_playmaker
status: active
entity: player
family: creativity
subfamily: playmaking
grain: match_player
headline: "Box-to-Box Playmaker"
trigger: "Midfielder records directional progression proxy >= 5 (passes_final_third OR team long_ball_attempts) and >= 5 recoveries in a single finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_creativity_playmaking_box_to_box_playmaker
  sql: clickhouse/gold/signal/sig_player_creativity_playmaking_box_to_box_playmaker.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_creativity_playmaking_box_to_box_playmaker

## Purpose

Detects two-way midfield creators who combine directional progression influence with active
ball-winning in the same finished match.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_usual_playing_position_id = 2` (midfielder scope)
  - `triggered_player_recoveries >= 5`
  - `triggered_player_passes_final_third_directional_proxy >= 5`
    OR `triggered_team_long_ball_attempts_directional_proxy >= 5`
- Directional progression proxy replacement (for unavailable explicit progressive-pass counts):
  - Player proxy: `silver.player_match_stat.passes_final_third`
  - Team proxy: `silver.period_stat.long_ball_attempts_{home|away}` (`period = 'All'`)
- Trigger provenance is explicit per row via:
  - `triggered_player_directional_proxy_source`
  - `triggered_player_directional_proxy_value`
  - `triggered_player_directional_proxy_above_threshold`
  - `triggered_player_recoveries_above_threshold`
- Midfielder role scope comes from `silver.match_personnel` and is preserved through
  `triggered_player_position_id` and `triggered_player_usual_playing_position_id`.
- Team recovery denominator is built from `silver.player_match_stat` aggregation at match/team
  grain to support `player_share_of_team_recoveries_pct`.
- Similarity gate note:
  - `sig_player_creativity_playmaking_line_breaker`: same creativity/playmaking directional proxy,
    but no recovery requirement and no midfielder-only scope.
  - `sig_player_possession_passing_midfield_workhorse`: same midfielder + recoveries framing, but
    touch-volume trigger (`>= 90`) rather than directional progression proxy.
  - `sig_player_goalkeeping_defense_recovery_engine`: overlaps on recovery metric, but belongs to
    goalkeeping/defense taxonomy and targets defender/midfielder defensive engines.
  - Coexistence rationale: this signal specifically captures two-way midfield creators by combining
    progression proxy and recovery volume under creativity/playmaking taxonomy.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_creativity_playmaking_box_to_box_playmaker.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_creativity_playmaking_box_to_box_playmaker`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_creativity_playmaking_box_to_box_playmaker
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
| `triggered_player_role_group` | Role group label (`midfielder`) | Explicit role-scope provenance |
| `triggered_player_position_id` | Match-specific position ID | Role diagnostics and QA traceability |
| `triggered_player_usual_playing_position_id` | Usual role bucket from personnel | Reproducible midfielder filter field |
| `trigger_threshold_min_directional_proxy` | Trigger floor for directional proxy (`5`) | Explicit threshold provenance for progression proxy |
| `trigger_threshold_min_recoveries` | Trigger floor for recoveries (`5`) | Explicit threshold provenance for ball-winning requirement |
| `triggered_player_passes_final_third_directional_proxy` | Player directional proxy from final-third passes | Primary player-level progression proxy |
| `triggered_team_long_ball_attempts_directional_proxy` | Team directional proxy from long-ball attempts | Fallback progression proxy when direct progressive-pass counts are unavailable |
| `triggered_player_directional_proxy_source` | Trigger source label (`passes_final_third_proxy`, `team_long_ball_attempts_proxy`, `both_proxies`) | Row-level auditable trigger branch |
| `triggered_player_directional_proxy_value` | Max directional proxy value used for ranking | Preserves trigger intensity across proxy branches |
| `triggered_player_directional_proxy_above_threshold` | Directional proxy margin above threshold | Captures progression-trigger severity beyond activation |
| `triggered_player_recoveries` | Recoveries by triggered midfielder | Core two-way contribution metric and trigger component |
| `triggered_player_recoveries_above_threshold` | Recoveries above threshold (`value - 5`) | Captures recovery-trigger severity beyond activation |
| `triggered_team_recoveries` | Total recoveries by triggered side | Team ball-winning baseline around player output |
| `opponent_recoveries` | Total recoveries by opponent side | Bilateral ball-winning comparator |
| `recoveries_delta` | Triggered-team minus opponent recoveries | Net ball-winning context for interpreting player signal quality |
| `triggered_player_chances_created` | Chances created by triggered player | Creativity volume context beyond trigger itself |
| `triggered_player_expected_assists` | Triggered player expected assists | Chance-quality context for playmaking interpretation |
| `triggered_player_touches_opposition_box` | Triggered player touches in opposition box | High-leverage territorial involvement context |
| `triggered_player_accurate_passes` | Triggered player accurate passes | Passing execution baseline |
| `triggered_player_total_passes` | Triggered player total passes | Passing workload context |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy (%) | Efficiency context for risk-reward profile |
| `triggered_player_minutes_played` | Triggered player minutes played | Exposure context for threshold interpretation |
| `triggered_player_touches` | Triggered player total touches | Overall involvement context |
| `triggered_team_pass_attempts` | Pass attempts by triggered side | Team circulation baseline around player output |
| `opponent_pass_attempts` | Pass attempts by opponent side | Bilateral circulation comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered side | Team passing-quality baseline |
| `opponent_accurate_passes` | Accurate passes by opponent side | Bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Triggered team pass accuracy (%) | Team execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `triggered_team_long_ball_attempts` | Long-ball attempts by triggered side | Team directness baseline linked to proxy branch |
| `opponent_long_ball_attempts` | Long-ball attempts by opponent side | Bilateral directness comparator |
| `triggered_team_accurate_long_balls` | Accurate long balls by triggered side | Team directness execution context |
| `opponent_accurate_long_balls` | Accurate long balls by opponent side | Bilateral directness execution comparator |
| `triggered_team_long_ball_accuracy_pct` | Triggered team long-ball accuracy (%) | Quality context for team directness |
| `opponent_long_ball_accuracy_pct` | Opponent long-ball accuracy (%) | Bilateral quality comparator for direct progression profile |
| `triggered_team_opposition_half_passes` | Triggered team passes in opposition half | Territorial progression baseline for player proxy interpretation |
| `opponent_opposition_half_passes` | Opponent passes in opposition half | Bilateral territorial comparator |
| `triggered_team_possession_pct` | Triggered team possession share (%) | Match-control context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `player_share_of_team_recoveries_pct` | Triggered player share of team recoveries (%) | Quantifies player contribution to team ball-winning volume |
| `player_share_of_team_passes_pct` | Triggered player share of team pass attempts (%) | Quantifies player centrality in circulation |
| `player_share_of_team_opposition_half_passes_pct` | Triggered player final-third passes as % of team opposition-half passes | Quantifies player directional progression contribution to team territory gains |
