---
signal_id: sig_player_possession_passing_one_touch_specialist
status: active
entity: player
family: possession
subfamily: passing
grain: match_player
headline: "One-Touch Specialist"
trigger: "Player has >= 50 passes with < 1.2 touches per pass."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_possession_passing_one_touch_specialist
  sql: clickhouse/gold/dml/signals/player/sig_player_possession_passing_one_touch_specialist.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_possession_passing_one_touch_specialist

## Purpose

Triggers when a player records high passing volume with very low touches-per-pass ratio, surfacing quick-release circulation specialists.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_total_passes >= 50`
  - `triggered_player_touches_per_pass < 1.2`
- Touches-per-pass is computed as `triggered_player_total_touches / triggered_player_total_passes` and evaluated only where the pass-volume gate is met.
- Uses player-level full-match totals from `silver.player_match_stat` and bilateral team/opponent passing-possession context from `silver.period_stat` (`period = 'All'`).
- Persists both player identity and team identity fields for contract-compliant downstream joins.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_possession_passing_one_touch_specialist.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_possession_passing_one_touch_specialist`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_possession_passing_one_touch_specialist
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key across signal and match feature sets |
| `match_date` | Match calendar date | Football developer: supports temporal splits and model backtesting windows |
| `home_team_id` | Home team ID | Football developer: fixture-side context for bilateral interpretation |
| `home_team_name` | Home team name | Football developer: readable fixture attribution |
| `away_team_id` | Away team ID | Football developer: fixture-side context for bilateral interpretation |
| `away_team_name` | Away team name | Football developer: readable fixture attribution |
| `home_score` | Full-time home goals | Football developer: outcome context for interpreting circulation behavior |
| `away_score` | Full-time away goals | Football developer: outcome context for interpreting circulation behavior |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for downstream aggregation |
| `triggered_player_id` | Triggered player ID | Football developer: player-level identity for feature joins |
| `triggered_player_name` | Triggered player name | Football developer: human-readable narrative and QA support |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player behavior to team tactical context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup context |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral matchup context |
| `trigger_threshold_total_passes` | Trigger minimum pass-attempt threshold (`50`) | Football developer: threshold provenance for reproducibility and QA |
| `trigger_threshold_max_touches_per_pass` | Trigger maximum touches-per-pass threshold (`1.2`) | Football developer: threshold provenance for reproducibility and QA |
| `triggered_player_total_touches` | Total touches by triggered player | Football developer: numerator of touches-per-pass style metric |
| `triggered_player_total_passes` | Total passes attempted by triggered player | Football developer: volume gate and denominator for ratio calculation |
| `triggered_player_touches_per_pass` | Triggered player touches divided by total passes | Football developer: core one-touch-style signal value for ranking/filtering |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Football developer: passing-quality context around fast circulation |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy (%) | Football developer: ensures quick-release profile can be evaluated with completion quality |
| `triggered_player_passes_final_third` | Triggered player passes into final third | Football developer: progression context versus pure retention passing |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: reliability context for per-match volume thresholds |
| `triggered_team_pass_attempts` | Pass attempts by triggered player's team | Football developer: team passing-load baseline for concentration analysis |
| `opponent_pass_attempts` | Pass attempts by opponent team | Football developer: bilateral tempo and possession comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered player's team | Football developer: team completion baseline for share metrics |
| `opponent_accurate_passes` | Accurate passes by opponent team | Football developer: bilateral completion comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered side (%) | Football developer: team-level completion context around the event |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent side (%) | Football developer: bilateral quality reference |
| `triggered_team_possession_pct` | Possession share of triggered side (%) | Football developer: control context for interpreting quick circulation usage |
| `opponent_possession_pct` | Possession share of opponent side (%) | Football developer: bilateral control comparator |
| `triggered_team_touches_opposition_box` | Opponent-box touches by triggered side | Football developer: territorial attacking context around fast-release passing |
| `opponent_touches_opposition_box` | Opponent-box touches by opponent side | Football developer: bilateral territorial comparator |
| `player_share_of_team_passes_pct` | Triggered player pass attempts as % of team pass attempts | Football developer: concentration measure for circulation responsibility |
| `player_share_of_team_accurate_passes_pct` | Triggered player accurate passes as % of team accurate passes | Football developer: share of completed circulation load attributed to the player |
