---
signal_id: sig_player_creativity_playmaking_cross_perfection
status: active
entity: player
family: creativity
subfamily: playmaking
grain: match_player
headline: "Cross Perfection"
trigger: "Player completes >= 5 crosses with 100% crossing accuracy in a single finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_creativity_playmaking_cross_perfection
  sql: clickhouse/gold/signal/sig_player_creativity_playmaking_cross_perfection.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_creativity_playmaking_cross_perfection

## Purpose

Detects player performances where wide service is both high-confidence and perfectly executed: at
least five accurate crosses with no failed crosses.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_accurate_crosses >= 5`
  - `triggered_player_cross_attempts = triggered_player_accurate_crosses` (100% cross accuracy)
- Trigger uses player full-match crossing totals from `silver.player_match_stat`.
- Signal retains playmaking context (`chances_created`, `expected_assists`, `passes_final_third`,
  `touches_opposition_box`) so crossing perfection can be interpreted as chance-creation behavior
  rather than isolated delivery volume.
- Bilateral team/opponent crossing, passing, possession, and box-touch context is sourced from
  `silver.period_stat` (`period = 'All'`) for tactical comparability.
- Similarity gate note:
  - `sig_player_possession_passing_volume_crosser`: overlap in cross-volume framing, but that
    signal triggers on very high attempt volume (`>= 15`) and does not require perfection.
  - `sig_player_possession_passing_unsuccessful_crosser`: opposite quality profile (`0%` crossing
    accuracy with high attempts).
  - `sig_player_creativity_playmaking_maestro_output`: same creativity/playmaking family but based
    on key-pass volume, not crossing execution.
  - Coexistence rationale: this signal isolates precision crossing playmaking that is not covered by
    existing volume-only or failure-profile crossing signals.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_creativity_playmaking_cross_perfection.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_creativity_playmaking_cross_perfection`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_creativity_playmaking_cross_perfection
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
| `trigger_threshold_min_accurate_crosses` | Minimum accurate-cross trigger threshold (`5`) | Explicit trigger provenance and QA guard |
| `trigger_threshold_min_cross_accuracy_pct` | Minimum cross-accuracy trigger threshold (`100`) | Explicit perfection threshold provenance |
| `triggered_player_cross_attempts` | Triggered player cross attempts | Trigger denominator and crossing volume context |
| `triggered_player_accurate_crosses` | Triggered player accurate crosses | Core trigger metric |
| `triggered_player_cross_accuracy_pct` | Triggered player cross accuracy (%) | Confirms perfection trigger quality |
| `triggered_player_accurate_crosses_above_threshold` | Accurate crosses above trigger floor (`value - 5`) | Trigger severity beyond activation boundary |
| `triggered_player_chances_created` | Triggered player chances created | Playmaking volume context beyond crossing output |
| `triggered_player_expected_assists` | Triggered player expected assists | Chance-quality context for created opportunities |
| `triggered_player_passes_final_third` | Triggered player passes into final third | Territorial progression context for delivery profile |
| `triggered_player_touches_opposition_box` | Triggered player touches in opposition box | High-leverage involvement context near goal |
| `triggered_player_accurate_passes` | Triggered player accurate passes | Passing execution baseline |
| `triggered_player_total_passes` | Triggered player total passes | Passing workload context |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy (%) | General passing-efficiency context around crossing profile |
| `triggered_player_minutes_played` | Triggered player minutes played | Exposure context for interpretation |
| `triggered_player_touches` | Triggered player total touches | Overall involvement context |
| `triggered_team_cross_attempts` | Cross attempts by triggered player's team | Team crossing baseline around player output |
| `opponent_cross_attempts` | Cross attempts by opponent team | Bilateral crossing-volume comparator |
| `triggered_team_accurate_crosses` | Accurate crosses by triggered player's team | Team crossing-quality baseline |
| `opponent_accurate_crosses` | Accurate crosses by opponent team | Bilateral crossing-quality comparator |
| `triggered_team_cross_accuracy_pct` | Triggered team cross accuracy (%) | Team execution context for wide delivery |
| `opponent_cross_accuracy_pct` | Opponent cross accuracy (%) | Bilateral wide-delivery execution comparator |
| `triggered_team_pass_attempts` | Pass attempts by triggered player's team | Team circulation baseline around player output |
| `opponent_pass_attempts` | Pass attempts by opponent team | Bilateral circulation comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered player's team | Team passing-quality baseline |
| `opponent_accurate_passes` | Accurate passes by opponent team | Bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Triggered team pass accuracy (%) | Team execution benchmark around signal event |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `triggered_team_possession_pct` | Triggered team possession share (%) | Match control context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `triggered_team_touches_opposition_box` | Triggered team touches in opposition box | Team territorial pressure context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial-pressure comparator |
| `player_share_of_team_accurate_crosses_pct` | Triggered player share of team accurate crosses (%) | Quantifies concentration of crossing precision responsibility |
| `player_share_of_team_cross_attempts_pct` | Triggered player share of team cross attempts (%) | Quantifies crossing volume centrality |
| `player_share_of_team_passes_pct` | Triggered player share of team pass attempts (%) | Balances crossing specialization against overall passing role |
