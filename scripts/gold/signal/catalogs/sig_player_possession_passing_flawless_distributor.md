---
signal_id: sig_player_possession_passing_flawless_distributor
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "Flawless Distributor"
trigger: "Player attempts >= 40 passes with 100% pass accuracy (accurate_passes = total_passes)."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_flawless_distributor
  sql: clickhouse/gold/signal/sig_player_possession_passing_flawless_distributor.sql
  runner: scripts/gold/signal/runners/sig_player_possession_passing_flawless_distributor.py
---
# sig_player_possession_passing_flawless_distributor

## Purpose

Triggers when a player attempts at least 40 passes and completes every pass, identifying flawless high-volume distributors in match context.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_pass_attempts >= 40`
  - `triggered_player_accurate_passes = triggered_player_pass_attempts`
- Uses player full-match passing totals from `silver.player_match_stat`.
- Adds bilateral team/opponent passing and possession context from `silver.period_stat` (`period = 'All'`) to separate truly controlled distribution from low-involvement clean passing.
- Persists both player and team identity fields for contract-compliant player-grain traceability.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_possession_passing_flawless_distributor.sql`
- Runner: `scripts/gold/signal/runners/sig_player_possession_passing_flawless_distributor.py`
- Target table: `gold_signals.sig_player_possession_passing_flawless_distributor`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_possession_passing_flawless_distributor.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: anchors stable joins across player, team, and fixture features. |
| `match_date` | Match calendar date | Football developer: enables temporal splits and backtest windowing. |
| `home_team_id` | Home team ID | Football developer: fixture orientation and bilateral keying. |
| `home_team_name` | Home team name | Football developer: readable fixture context for analysts. |
| `away_team_id` | Away team ID | Football developer: fixture orientation and bilateral keying. |
| `away_team_name` | Away team name | Football developer: readable fixture context for analysts. |
| `home_score` | Full-time home goals | Football developer: outcome context for interpreting distribution behavior. |
| `away_score` | Full-time away goals | Football developer: outcome context for interpreting distribution behavior. |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical orientation for downstream side-aware aggregations. |
| `triggered_player_id` | Triggered player ID | Football developer: primary player identity key for model features. |
| `triggered_player_name` | Triggered player name | Football developer: human-readable signal interpretation. |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player signal to team tactical profiles. |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution for reporting. |
| `opponent_team_id` | Opponent team ID | Football developer: matchup context for bilateral analysis. |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context. |
| `trigger_threshold_pass_attempts` | Trigger threshold for pass attempts (`40`) | Football developer: explicit threshold provenance for QA and reproducibility. |
| `trigger_threshold_pass_accuracy_pct` | Trigger threshold for pass accuracy (`100`) | Football developer: explicit perfect-accuracy threshold provenance. |
| `triggered_player_pass_attempts` | Total pass attempts by triggered player | Football developer: core trigger volume guard and ranking metric. |
| `triggered_player_accurate_passes` | Total accurate passes by triggered player | Football developer: core trigger numerator confirming flawless completion. |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy (%) | Football developer: direct signal value for filtering and ranking. |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: reliability context for workload interpretation. |
| `triggered_player_touches` | Triggered player total touches | Football developer: involvement context beyond passing counts. |
| `triggered_player_passes_final_third` | Triggered player passes in final third | Football developer: progression context to distinguish safe recycling from territorial contribution. |
| `triggered_team_pass_attempts` | Pass attempts by triggered player's team | Football developer: denominator for player-share and team-style context. |
| `opponent_pass_attempts` | Pass attempts by opponent team | Football developer: bilateral tempo and possession-load comparator. |
| `triggered_team_accurate_passes` | Accurate passes by triggered player's team | Football developer: team-level passing quality baseline. |
| `opponent_accurate_passes` | Accurate passes by opponent team | Football developer: bilateral quality comparator. |
| `triggered_team_pass_accuracy_pct` | Triggered-side team pass accuracy (%) | Football developer: contextualizes flawless player output within team execution quality. |
| `opponent_pass_accuracy_pct` | Opponent team pass accuracy (%) | Football developer: bilateral quality reference for matchup balance. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Football developer: control context for interpreting high-volume clean distribution. |
| `opponent_possession_pct` | Opponent possession (%) | Football developer: bilateral control comparator. |
| `player_share_of_team_passes_pct` | Triggered player pass attempts as % of team pass attempts | Football developer: indicates whether flawless distribution is central or peripheral in team buildup. |
| `triggered_player_vs_team_pass_accuracy_delta_pct` | Triggered player pass accuracy minus team pass accuracy (percentage points) | Football developer: quantifies precision edge over team baseline for modeling and diagnostics. |
