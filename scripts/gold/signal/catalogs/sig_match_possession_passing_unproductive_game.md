---
signal_id: sig_match_possession_passing_unproductive_game
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Possession Passing Unproductive Game"
trigger: "Total match pass attempts > 1000 and total match shots < 10 at full time (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_possession_passing_unproductive_game
  sql: clickhouse/gold/signal/sig_match_possession_passing_unproductive_game.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_possession_passing_unproductive_game

## Purpose

Triggers for matches with very high passing volume but very low total shot volume, surfacing stale possession games where circulation did not convert into attempts.

## Tactical And Statistical Logic

- Trigger condition: `match_total_pass_attempts > 1000` and `match_total_shots < 10` from full-match period stats.
- Emits one row for each side (`triggered_side` = `home` and `away`) so team-oriented consumers can read the same low-productivity game from each tactical orientation.
- Enriches the match-level trigger with bilateral pass share, shot share, pass quality, possession share, territorial progression, and xG context.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_possession_passing_unproductive_game.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_possession_passing_unproductive_game`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_possession_passing_unproductive_game
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
| `home_score` | Full-time home goals | Football developer: outcome context for low-productivity matches. |
| `away_score` | Full-time away goals | Football developer: outcome context for low-productivity matches. |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: team-centric interpretation of the same match trigger. |
| `triggered_team_id` | Triggered-side team ID | Football developer: side identity for downstream team features. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered-side identity. |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral context and matchup orientation. |
| `opponent_team_name` | Opponent team name | Football developer: bilateral context and matchup orientation. |
| `match_total_pass_attempts` | Combined pass attempts by both teams | Football developer: direct trigger input for high-circulation detection. |
| `match_total_shots` | Combined total shots by both teams | Football developer: direct trigger input for low-productivity detection. |
| `match_passes_per_shot` | Match-wide pass attempts per shot | Football developer: compact intensity/efficiency signal value. |
| `triggered_team_pass_attempts` | Pass attempts by triggered side | Football developer: decomposes match volume into side contribution. |
| `opponent_pass_attempts` | Pass attempts by opponent side | Football developer: bilateral comparator for pass-volume ownership. |
| `triggered_team_total_shots` | Total shots by triggered side | Football developer: decomposes shot scarcity by side. |
| `opponent_total_shots` | Total shots by opponent side | Football developer: bilateral comparator for shot scarcity. |
| `triggered_team_pass_share_pct` | Triggered side share of match pass attempts (%) | Football developer: shows who controlled circulation load. |
| `triggered_team_shot_share_pct` | Triggered side share of match shots (%) | Football developer: shows who contributed what little shot volume existed. |
| `triggered_team_pass_accuracy_pct` | Triggered side pass accuracy (%) | Football developer: quality context for heavy circulation. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral quality comparator. |
| `triggered_team_possession_pct` | Triggered side possession share (%) | Football developer: confirms whether pass volume aligned with control share. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator. |
| `triggered_team_opposition_half_passes` | Triggered side passes in opposition half | Football developer: territorial progression context inside sterile games. |
| `opponent_opposition_half_passes` | Opponent passes in opposition half | Football developer: bilateral territorial comparator. |
| `triggered_team_touches_opposition_box` | Triggered side touches in opponent box | Football developer: final-zone penetration context beneath shot scarcity. |
| `opponent_touches_opposition_box` | Opponent touches in the triggered side penalty area | Football developer: bilateral penetration comparator. |
| `triggered_team_xg` | Triggered side expected goals | Football developer: chance-quality context beyond raw shots. |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator. |
| `match_total_xg` | Combined expected goals in the match | Football developer: total chance-quality output of high-pass, low-shot games. |
| `xg_gap` | Triggered side xG minus opponent xG | Football developer: reveals whether sterile volume still produced territorial chance asymmetry. |
