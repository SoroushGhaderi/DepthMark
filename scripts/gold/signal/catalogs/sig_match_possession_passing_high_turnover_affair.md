---
signal_id: sig_match_possession_passing_high_turnover_affair
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Match Possession Passing High Turnover Affair"
trigger: "Estimated total match dispossessions/turnovers >= 60 at full time (`period = 'All'`), where turnovers are `failed_passes + failed_dribbles`."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_possession_passing_high_turnover_affair
  sql: clickhouse/gold/signal/sig_match_possession_passing_high_turnover_affair.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_possession_passing_high_turnover_affair

## Purpose

Triggers for matches with very high combined dispossession/turnover volume, surfacing chaotic possession games where both sides repeatedly lose the ball.

## Tactical And Statistical Logic

- Trigger condition: `match_total_turnovers >= 60` from full-match (`period = 'All'`) team stats.
- Turnover proxy definition: `failed_passes + failed_dribbles`, where `failed_passes = max(pass_attempts - accurate_passes, 0)` and `failed_dribbles = max(dribble_attempts - successful_dribbles, 0)`.
- Emits one row per side (`triggered_side` = `home` and `away`) so team-centric consumers can interpret the same high-turnover profile from each tactical orientation.
- Enriches the trigger with bilateral turnover decomposition, passing quality, dribble security, possession share, shot context, and xG context.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_possession_passing_high_turnover_affair.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_possession_passing_high_turnover_affair`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_possession_passing_high_turnover_affair
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable identity for joins and traceability. |
| `match_date` | Match calendar date | Football developer: timeline slicing and backtest partitions. |
| `home_team_id` | Home team numeric ID | Football developer: fixture identity and orientation recovery. |
| `home_team_name` | Home team display name | Football developer: analyst-readable fixture context. |
| `away_team_id` | Away team numeric ID | Football developer: fixture identity and orientation recovery. |
| `away_team_name` | Away team display name | Football developer: analyst-readable fixture context. |
| `home_score` | Full-time home goals | Football developer: outcome context for high-ball-loss matches. |
| `away_score` | Full-time away goals | Football developer: outcome context for high-ball-loss matches. |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: team-centric interpretation of the same match trigger. |
| `triggered_team_id` | Triggered-side team ID | Football developer: side identity for downstream team features. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered-side identity. |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral context and matchup orientation. |
| `opponent_team_name` | Opponent team name | Football developer: bilateral context and matchup orientation. |
| `trigger_threshold_turnovers` | Trigger threshold value (`60`) | Football developer: explicit threshold traceability for QA and explainability. |
| `match_total_turnovers` | Combined estimated turnovers across both teams | Football developer: core trigger metric for high-turnover classification. |
| `match_total_pass_attempts` | Combined pass attempts across both teams | Football developer: denominator context for interpreting turnover volume. |
| `match_turnovers_per_100_pass_attempts` | Match turnovers normalized per 100 pass attempts | Football developer: turnover-intensity normalization across match tempos. |
| `triggered_team_turnovers` | Estimated turnovers by triggered side | Football developer: decomposition of match trigger into side contribution. |
| `opponent_turnovers` | Estimated turnovers by opponent side | Football developer: bilateral comparator for turnover contribution. |
| `triggered_team_turnover_share_pct` | Triggered side share of match turnovers (%) | Football developer: indicates how much of the chaotic turnover profile came from the triggered side. |
| `triggered_team_failed_passes` | Triggered side failed passes | Football developer: turnover decomposition component for passing security. |
| `opponent_failed_passes` | Opponent failed passes | Football developer: bilateral passing-security comparator. |
| `triggered_team_failed_dribbles` | Triggered side failed dribbles | Football developer: turnover decomposition component for carrying security. |
| `opponent_failed_dribbles` | Opponent failed dribbles | Football developer: bilateral carrying-security comparator. |
| `triggered_team_pass_accuracy_pct` | Triggered side pass accuracy (%) | Football developer: passing-quality context beneath high turnover totals. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral quality comparator. |
| `triggered_team_dribble_success_pct` | Triggered side dribble success rate (%) | Football developer: carrying-security context beneath high turnover totals. |
| `opponent_dribble_success_pct` | Opponent dribble success rate (%) | Football developer: bilateral carrying-quality comparator. |
| `triggered_team_possession_pct` | Triggered side possession share (%) | Football developer: control-share context for ball-loss interpretation. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control-share comparator. |
| `triggered_team_total_shots` | Triggered side total shots | Football developer: attacking-volume context around turnover chaos. |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral attacking-volume comparator. |
| `triggered_team_touches_opposition_box` | Triggered side touches in opponent box | Football developer: penetration context in high-turnover games. |
| `opponent_touches_opposition_box` | Opponent touches in triggered-side box | Football developer: bilateral penetration comparator. |
| `triggered_team_xg` | Triggered side expected goals | Football developer: chance-quality context beyond shot volume. |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator. |
| `xg_gap` | Triggered side xG minus opponent xG | Football developer: net chance-quality edge despite shared turnover volatility. |
