---
signal_id: sig_match_possession_passing_set_piece_dominance
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Possession Passing Set-Piece Dominance"
trigger: "Proxy-calibrated: dead-ball restart pass share proxy (player_throws + corners) > 15%, approximating intended >20% true restart-pass share."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_possession_passing_set_piece_dominance
  sql: clickhouse/gold/dml/signals/match/sig_match_possession_passing_set_piece_dominance.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_possession_passing_set_piece_dominance

## Purpose

Triggers when restart-led passing volume dominates the match, flagging games where dead-ball circulation is an unusually large share of total passing.

## Tactical And Statistical Logic

- Trigger condition: `match_dead_ball_restart_pass_share_pct > 15` (proxy-calibrated threshold).
- The restart pass metric is modeled as `player_throws + corners` at team level, summed to match level.
- Because explicit free-kick pass counts are not available in `silver.period_stat`, this is a conservative proxy for dead-ball restart passing.
- The original intended tactical trigger is “>20% of match passes from dead-ball restarts”; in current data, this proxy peaks below 20%, so 15% is used as the closest operational threshold.
- Emits one row per side (`triggered_side in {'home','away'}`) so downstream users can analyze match-level trigger with side-oriented context.
- Adds bilateral context for pass quality, set-piece shot volume, set-play xG, possession, and shot output.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_possession_passing_set_piece_dominance.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_possession_passing_set_piece_dominance`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_possession_passing_set_piece_dominance
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins across gold signal and scenario outputs |
| `match_date` | Calendar date of the match | Football developer: enables temporal slicing and trend analysis |
| `home_team_id` | Home team numeric ID | Football developer: stable bilateral orientation key |
| `home_team_name` | Home team display name | Football developer: readable match context for diagnostics |
| `away_team_id` | Away team numeric ID | Football developer: stable bilateral orientation key |
| `away_team_name` | Away team display name | Football developer: readable match context for diagnostics |
| `home_score` | Full-time home goals | Football developer: outcome context for trigger interpretation |
| `away_score` | Full-time away goals | Football developer: outcome context for trigger interpretation |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: canonical side identity for match-team grain |
| `triggered_team_id` | Triggered-side team ID | Football developer: side-scoped team key for downstream feature joins |
| `triggered_team_name` | Triggered-side team name | Football developer: readable side-scoped context |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral context and opponent-aware modeling |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `match_total_pass_attempts` | Combined pass attempts in the match | Football developer: denominator for match-level trigger metric |
| `match_total_dead_ball_restart_passes_proxy` | Combined dead-ball restart pass proxy count (`player_throws + corners`) | Football developer: numerator for match-level trigger metric |
| `match_dead_ball_restart_pass_share_pct` | Match-level share of pass attempts attributed to dead-ball restart proxy | Football developer: core trigger value (`> 15` proxy-calibrated) |
| `triggered_team_pass_attempts` | Pass attempts by triggered side | Football developer: side-specific passing baseline |
| `opponent_pass_attempts` | Pass attempts by opponent side | Football developer: bilateral passing baseline comparator |
| `triggered_team_dead_ball_restart_passes_proxy` | Triggered-side dead-ball restart pass proxy count (`player_throws + corners`) | Football developer: side-level numerator supporting the trigger |
| `opponent_dead_ball_restart_passes_proxy` | Opponent dead-ball restart pass proxy count (`player_throws + corners`) | Football developer: bilateral side-level comparator |
| `triggered_team_dead_ball_restart_pass_share_pct` | Triggered-side dead-ball restart proxy as % of triggered-side pass attempts | Football developer: side-specific style concentration metric |
| `opponent_dead_ball_restart_pass_share_pct` | Opponent dead-ball restart proxy as % of opponent pass attempts | Football developer: bilateral style concentration comparator |
| `triggered_team_dead_ball_share_of_match_passes_pct` | Triggered-side dead-ball restart proxy as % of all match pass attempts | Football developer: quantifies triggered side contribution to match-level trigger |
| `opponent_dead_ball_share_of_match_passes_pct` | Opponent dead-ball restart proxy as % of all match pass attempts | Football developer: bilateral contribution comparator |
| `triggered_team_dead_ball_share_of_match_dead_ball_restart_passes_pct` | Triggered-side share of total match dead-ball restart proxy volume | Football developer: ownership split of restart-led circulation |
| `opponent_dead_ball_share_of_match_dead_ball_restart_passes_pct` | Opponent share of total match dead-ball restart proxy volume | Football developer: bilateral ownership comparator |
| `triggered_team_player_throws` | Triggered-side throw-ins | Football developer: direct component of dead-ball restart proxy |
| `opponent_player_throws` | Opponent throw-ins | Football developer: bilateral component comparator |
| `triggered_team_corners` | Triggered-side corners | Football developer: direct component of dead-ball restart proxy |
| `opponent_corners` | Opponent corners | Football developer: bilateral component comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass completion rate | Football developer: pass-quality context around restart-heavy profile |
| `opponent_pass_accuracy_pct` | Opponent pass completion rate | Football developer: bilateral pass-quality comparator |
| `triggered_team_set_piece_shots` | Triggered-side shots with set-piece situations (corner/free-kick/set-piece/throw-in set-piece) | Football developer: validates whether restart-heavy circulation translated to shots |
| `opponent_set_piece_shots` | Opponent shots with set-piece situations | Football developer: bilateral set-piece shot-pressure comparator |
| `triggered_team_set_play_xg` | Triggered-side expected goals from set play | Football developer: set-piece chance-quality context |
| `opponent_set_play_xg` | Opponent expected goals from set play | Football developer: bilateral set-piece chance-quality comparator |
| `set_play_xg_delta` | Triggered minus opponent set-play xG | Football developer: net set-piece chance-quality edge |
| `triggered_team_total_shots` | Triggered-side total shots | Football developer: overall shot-volume context beyond set pieces |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral shot-volume comparator |
| `triggered_team_possession_pct` | Triggered-side possession percentage | Football developer: control context for restart-heavy matches |
| `opponent_possession_pct` | Opponent possession percentage | Football developer: bilateral control comparator |
