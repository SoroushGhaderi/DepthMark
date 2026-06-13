---
signal_id: sig_player_goalkeeping_defense_interception_marathon
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Interception Marathon"
trigger: "Defender records >= 5 interceptions in the first half alone."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_interception_marathon
  sql: clickhouse/gold/signal/sig_player_goalkeeping_defense_interception_marathon.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_goalkeeping_defense_interception_marathon

## Purpose

Flags defender profiles with marathon-level first-half interception output and preserves bilateral
defensive context, while making source-grain proxy assumptions explicit for reproducibility.

## Tactical And Statistical Logic

- Requested trigger target: defender records `>= 5` interceptions in first half.
- Current warehouse limitation: player-level interceptions are available only at full-match grain in
  `silver.player_match_stat`; no player-period interception split exists.
- Implemented trigger proxy (explicit):
  - `triggered_player_first_half_interceptions_proxy = least(triggered_player_interceptions_full_match, triggered_team_interceptions_first_half)`
  - Signal fires when `triggered_player_first_half_interceptions_proxy >= 5`.
  - `has_first_half_period_row_flag = 1` is required for data-completeness on half-split team context.
- Defender scope and role-gate:
  - `triggered_player_usual_playing_position_id = 1` from `silver.match_personnel`
  - `is_goalkeeper = 0`
  - `match_finished = 1`
- Team first-half and full-match context is sourced from `silver.period_stat` using `period IN ('FirstHalf', 'All')`.
- Similarity gate note:
  - `sig_player_goalkeeping_defense_interception_king`: closest overlap (interception-heavy defender), but it triggers on full-match interceptions (`>= 7`) without first-half framing.
  - `sig_player_goalkeeping_defense_defensive_double_double`: related defensive-volume profile, but requires tackles + interceptions together.
  - `sig_player_goalkeeping_defense_high_line_trapper`: closest proxy-pattern overlap, but trigger axis is offsides-caught proxy, not interceptions.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_goalkeeping_defense_interception_marathon.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_interception_marathon`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_goalkeeping_defense_interception_marathon
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable player-grain join and deduplication key |
| `match_date` | Match date | Temporal slicing and backfill reproducibility |
| `home_team_id` | Home team ID | Fixture context anchor |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team ID | Fixture context anchor |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Outcome context |
| `away_score` | Away full-time goals | Outcome context |
| `triggered_side` | Triggered player side (`home` or `away`) | Canonical orientation for bilateral interpretation |
| `triggered_player_id` | Triggered player ID | Player identity key |
| `triggered_player_name` | Triggered player name | Readable trigger attribution |
| `triggered_team_id` | Triggered player team ID | Player-to-team linkage |
| `triggered_team_name` | Triggered player team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup key |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `triggered_player_role_group` | Role-group label (`defender`) | Explicit role-gate provenance |
| `triggered_player_position_id` | Match position ID | Deployment diagnostics |
| `triggered_player_usual_playing_position_id` | Usual position bucket | Deterministic defender-scope traceability |
| `has_first_half_period_row_flag` | 1 when `FirstHalf` row exists in team-period stats | Trigger-data completeness guard |
| `trigger_threshold_min_first_half_interceptions_proxy` | Proxy threshold value (`5`) | Explicit threshold provenance |
| `trigger_threshold_interception_period` | Requested trigger period label (`FirstHalf`) | Keeps timing contract explicit in-row |
| `triggered_player_interceptions_full_match` | Full-match interceptions by triggered player | Raw source metric used in proxy construction |
| `triggered_team_interceptions_first_half` | Triggered team first-half interceptions | Team half-split cap input for proxy |
| `opponent_interceptions_first_half` | Opponent first-half interceptions | Bilateral half-split comparator |
| `first_half_interceptions_delta` | Triggered-team minus opponent first-half interceptions | First-half anticipation edge context |
| `triggered_player_first_half_interceptions_proxy` | Available-data proxy for player first-half interceptions | Core trigger metric under source-grain constraints |
| `triggered_player_first_half_interceptions_above_threshold_proxy` | Proxy margin above threshold (`proxy - 5`) | Trigger severity ranking |
| `triggered_player_first_half_interception_share_of_team_proxy_pct` | Proxy share of triggered-team first-half interceptions (%) | Concentration context for attribution strength |
| `triggered_player_tackles_won` | Player tackles won | Defensive-duel context beside interception signal |
| `triggered_player_tackle_attempts` | Player tackle attempts | Tackle-volume denominator |
| `triggered_player_tackle_success_pct` | Player tackle success (%) | Tackle efficiency context |
| `triggered_player_clearances` | Player clearances | Pressure-release context |
| `triggered_player_defensive_actions` | Player defensive actions | Total defensive workload context |
| `triggered_player_recoveries` | Player recoveries | Transition-defense contribution context |
| `triggered_player_duels_won` | Player duels won | Physical-control context |
| `triggered_player_duels_lost` | Player duels lost | Counterbalance for duel profile |
| `triggered_player_fouls_committed` | Player fouls committed | Discipline trade-off context |
| `triggered_player_minutes_played` | Player minutes played | Exposure reliability context |
| `triggered_player_touches` | Player touches | Involvement baseline context |
| `triggered_player_total_passes` | Player pass attempts | Ball-use context |
| `triggered_player_accurate_passes` | Player accurate passes | Execution context |
| `triggered_player_pass_accuracy_pct` | Player pass accuracy (%) | Retention quality context |
| `triggered_team_interceptions` | Triggered-team full-match interceptions | Team anticipation baseline |
| `opponent_interceptions` | Opponent full-match interceptions | Bilateral anticipation comparator |
| `interception_delta_vs_opponent_team` | Triggered-team minus opponent full-match interceptions | Net anticipation edge context |
| `triggered_team_tackles_won` | Triggered-team tackles won | Team defensive-intensity baseline |
| `opponent_tackles_won` | Opponent tackles won | Bilateral defensive-intensity comparator |
| `triggered_team_clearances` | Triggered-team clearances | Team pressure-release baseline |
| `opponent_clearances` | Opponent clearances | Bilateral pressure-release comparator |
| `triggered_team_shot_blocks` | Triggered-team shot blocks | Team box-protection baseline |
| `opponent_shot_blocks` | Opponent shot blocks | Bilateral box-protection comparator |
| `triggered_team_duels_won` | Triggered-team duels won | Team physical-control baseline |
| `opponent_duels_won` | Opponent duels won | Bilateral physical-control comparator |
| `triggered_team_fouls` | Triggered-team fouls | Team discipline context |
| `opponent_fouls` | Opponent fouls | Bilateral discipline comparator |
| `triggered_team_possession_pct` | Triggered-team possession share (%) | Control-state context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Team execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
