---
signal_id: sig_match_possession_passing_wing_play_extravaganza
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Possession Passing Wing Play Extravaganza"
trigger: "Combined total of >60 crosses in a single match (period = 'All')."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_possession_passing_wing_play_extravaganza
  sql: clickhouse/gold/signal/sig_match_possession_passing_wing_play_extravaganza.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_possession_passing_wing_play_extravaganza

## Purpose

Triggers when both teams combine for extreme crossing volume, surfacing wing-dominant match states where chance creation funnels through wide delivery.

## Tactical And Statistical Logic

- Trigger condition: `match_total_cross_attempts > 60` from full-match period stats.
- Emits one row per side (`triggered_side` = `home` and `away`) so the same match-level trigger can be read from both team orientations.
- Uses bilateral crossing volume and crossing efficiency to reveal who drove the wing-heavy profile.
- Adds pass volume, possession, shot output, and xG context to separate productive wing play from sterile crossing accumulation.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_possession_passing_wing_play_extravaganza.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_possession_passing_wing_play_extravaganza`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_possession_passing_wing_play_extravaganza
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for downstream signal/scenario feature sets. |
| `match_date` | Match calendar date | Football developer: enables trend analysis and date-partitioned QA. |
| `home_team_id` | Home team numeric ID | Football developer: fixture identity and side reconstruction. |
| `home_team_name` | Home team display name | Football developer: readable fixture context for analysts. |
| `away_team_id` | Away team numeric ID | Football developer: fixture identity and side reconstruction. |
| `away_team_name` | Away team display name | Football developer: readable fixture context for analysts. |
| `home_score` | Full-time home goals | Football developer: outcome context for wing-heavy games. |
| `away_score` | Full-time away goals | Football developer: outcome context for wing-heavy games. |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: side-centric interpretation of one match-level trigger. |
| `triggered_team_id` | Triggered-side team ID | Football developer: side identity for team-level feature generation. |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered-side identity. |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup context. |
| `opponent_team_name` | Opponent team name | Football developer: bilateral matchup context. |
| `match_total_cross_attempts` | Combined cross attempts by both teams | Football developer: direct trigger metric for wing-play extravaganza detection. |
| `match_total_accurate_crosses` | Combined accurate crosses by both teams | Football developer: quality-adjusted context for total crossing activity. |
| `match_cross_accuracy_pct` | Combined cross accuracy percentage in the match | Football developer: match-level delivery quality behind the high-volume trigger. |
| `triggered_team_cross_attempts` | Cross attempts by triggered side | Football developer: side contribution to the match crossing total. |
| `opponent_cross_attempts` | Cross attempts by opponent side | Football developer: bilateral comparator for wing-usage ownership. |
| `triggered_team_accurate_crosses` | Accurate crosses by triggered side | Football developer: side-specific crossing execution quality. |
| `opponent_accurate_crosses` | Accurate crosses by opponent side | Football developer: bilateral crossing execution comparator. |
| `triggered_team_cross_share_pct` | Triggered side share of all match crosses (%) | Football developer: reveals which side drove the trigger most. |
| `opponent_cross_share_pct` | Opponent share of all match crosses (%) | Football developer: balances interpretation with opponent contribution. |
| `triggered_team_cross_accuracy_pct` | Triggered side cross accuracy (%) | Football developer: tactical efficiency context for triggered side wing play. |
| `opponent_cross_accuracy_pct` | Opponent cross accuracy (%) | Football developer: bilateral efficiency comparator. |
| `triggered_team_crosses_per_shot` | Triggered side crosses divided by triggered side shots | Football developer: indicates whether crossing volume converted into attempts efficiently. |
| `opponent_crosses_per_shot` | Opponent crosses divided by opponent shots | Football developer: bilateral conversion-efficiency comparator. |
| `triggered_team_pass_attempts` | Pass attempts by triggered side | Football developer: possession circulation baseline around crossing volume. |
| `opponent_pass_attempts` | Pass attempts by opponent side | Football developer: bilateral circulation comparator. |
| `triggered_team_possession_pct` | Triggered side possession share (%) | Football developer: control context for wing-dominant patterns. |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator. |
| `triggered_team_total_shots` | Total shots by triggered side | Football developer: shot-output context for interpreting crossing strategy returns. |
| `opponent_total_shots` | Total shots by opponent side | Football developer: bilateral shot-output comparator. |
| `triggered_team_xg` | Triggered side expected goals | Football developer: chance-quality context beyond raw shot counts. |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator. |
| `xg_gap` | Triggered side xG minus opponent xG | Football developer: net chance-quality edge under extreme wing-play conditions. |
