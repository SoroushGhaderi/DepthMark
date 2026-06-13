---
signal_id: sig_team_possession_passing_dribble_heavy_attack
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Team Dribble-Heavy Attack"
trigger: "Team dribble attempts in `period = 'All'` are greater than or equal to 25."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_dribble_heavy_attack
  sql: clickhouse/gold/signal/sig_team_possession_passing_dribble_heavy_attack.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_possession_passing_dribble_heavy_attack

## Purpose

Triggers when a team attempts at least 25 dribbles in a match, identifying aggressive carry-led attacking behavior and high 1v1 intent.

## Tactical And Statistical Logic

- Trigger condition: `triggered_team_dribble_attempts >= 25` at full match (`period = 'All'`).
- Emits one row per qualifying side (`triggered_side in {'home','away'}`); if both teams qualify, both rows are emitted.
- Adds bilateral dribble efficiency, passing quality, possession, penalty-box touch volume, shooting, and xG context to separate productive carrying attacks from low-yield dribble volume.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_possession_passing_dribble_heavy_attack.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_possession_passing_dribble_heavy_attack`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_possession_passing_dribble_heavy_attack
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins across match and signal outputs |
| `match_date` | Match calendar date | Football developer: enables temporal slicing and QA checks |
| `home_team_id` | Home team numeric ID | Football developer: bilateral orientation anchor |
| `home_team_name` | Home team display name | Football developer: readable match context |
| `away_team_id` | Away team numeric ID | Football developer: bilateral orientation anchor |
| `away_team_name` | Away team display name | Football developer: readable match context |
| `home_score` | Full-time home goals | Football developer: outcome context for dribble-heavy attacks |
| `away_score` | Full-time away goals | Football developer: outcome context for dribble-heavy attacks |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: canonical side identity for `match_team` grain |
| `triggered_team_id` | Triggered-side team ID | Football developer: side-level join key for downstream modeling |
| `triggered_team_name` | Triggered-side team name | Football developer: readable triggered-side context |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral interpretation and opponent-aware analysis |
| `opponent_team_name` | Opponent team name | Football developer: readable opponent context |
| `trigger_threshold_dribble_attempts` | Trigger threshold constant (`25`) | Football developer: explicit audit field for explainability and QA |
| `both_sides_triggered` | Flag set to `1` when both teams attempted `>= 25` dribbles | Football developer: marks bilateral trigger matches for deduping and interpretation |
| `triggered_team_dribble_attempts` | Dribble attempts by triggered side | Football developer: core trigger metric volume guard (`>= 25`) |
| `opponent_dribble_attempts` | Dribble attempts by opponent side | Football developer: bilateral carrying-intent comparator |
| `dribble_attempts_delta` | Triggered minus opponent dribble attempts | Football developer: net carrying-load edge for style profiling |
| `triggered_team_successful_dribbles` | Successful dribbles by triggered side | Football developer: carrying output context behind trigger volume |
| `opponent_successful_dribbles` | Successful dribbles by opponent side | Football developer: bilateral carrying output comparator |
| `triggered_team_dribble_success_pct` | Triggered-side dribble success percentage | Football developer: carrying efficiency context for trigger quality |
| `opponent_dribble_success_pct` | Opponent dribble success percentage | Football developer: bilateral carrying efficiency comparator |
| `dribble_success_delta_pct` | Triggered minus opponent dribble success percentage points | Football developer: net efficiency edge around dribble-heavy behavior |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Football developer: circulation baseline around dribble-heavy attack patterns |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass completion percentage | Football developer: passing quality context while carrying frequently |
| `opponent_pass_accuracy_pct` | Opponent pass completion percentage | Football developer: bilateral passing quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy percentage points | Football developer: net ball-retention edge while carrying |
| `triggered_team_possession_pct` | Triggered-side possession percentage | Football developer: control context for interpreting dribble volume |
| `opponent_possession_pct` | Opponent possession percentage | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession percentage points | Football developer: net control edge around carrying-heavy plans |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opponent penalty area | Football developer: penetration context linked to dribble attempts |
| `opponent_touches_opposition_box` | Opponent touches in triggered-side penalty area | Football developer: bilateral penetration comparator |
| `triggered_team_total_shots` | Triggered-side total shots | Football developer: chance-volume context for dribble-heavy behavior |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral chance-volume comparator |
| `triggered_team_xg` | Triggered-side expected goals | Football developer: chance-quality context for carrying-heavy attack |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: net chance-quality edge while dribbling heavily |
