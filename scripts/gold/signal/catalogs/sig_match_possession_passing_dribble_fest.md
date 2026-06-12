---
signal_id: sig_match_possession_passing_dribble_fest
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Match Dribble Fest"
trigger: "Combined successful dribbles in `period = 'All'` exceed 25."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_possession_passing_dribble_fest
  sql: clickhouse/gold/signal/sig_match_possession_passing_dribble_fest.sql
  runner: scripts/gold/signal/runners/sig_match_possession_passing_dribble_fest.py
---
# sig_match_possession_passing_dribble_fest

## Purpose

Triggers matches with very high combined successful dribble volume, identifying open 1v1-heavy games where both sides repeatedly beat defenders off the dribble.

## Tactical And Statistical Logic

- Trigger condition: `match_total_successful_dribbles > 25` at full match (`period = 'All'`).
- Emits one row per side (`triggered_side in {'home','away'}`) so match-level dribble intensity can be consumed in a team-oriented shape.
- Adds bilateral dribble share and success context, plus passing quality, possession, box touches, shot volume, and xG to distinguish productive dribble-fests from chaotic low-yield games.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_possession_passing_dribble_fest.sql`
- Runner: `scripts/gold/signal/runners/sig_match_possession_passing_dribble_fest.py`
- Target table: `gold_signals.sig_match_possession_passing_dribble_fest`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_possession_passing_dribble_fest.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins across match and downstream signal tables |
| `match_date` | Match calendar date | Football developer: supports temporal analysis and QA checks |
| `home_team_id` | Home team numeric ID | Football developer: bilateral orientation anchor |
| `home_team_name` | Home team display name | Football developer: readable match context |
| `away_team_id` | Away team numeric ID | Football developer: bilateral orientation anchor |
| `away_team_name` | Away team display name | Football developer: readable match context |
| `home_score` | Full-time home goals | Football developer: outcome context for high-dribble matches |
| `away_score` | Full-time away goals | Football developer: outcome context for high-dribble matches |
| `triggered_side` | Row orientation (`home` or `away`) | Football developer: canonical side identity for `match_team` grain |
| `triggered_team_id` | Triggered-side team ID | Football developer: side-level join key for downstream features |
| `triggered_team_name` | Triggered-side team name | Football developer: readable side-level context |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral interpretation and opponent-aware modeling |
| `opponent_team_name` | Opponent team name | Football developer: readable opponent context |
| `trigger_threshold_successful_dribbles` | Successful-dribble threshold constant used by trigger (`25`) | Football developer: explicit trigger audit field for QA and explainability |
| `match_total_successful_dribbles` | Combined successful dribbles by both teams | Football developer: core trigger metric (`>25`) |
| `match_total_dribble_attempts` | Combined dribble attempts by both teams | Football developer: denominator context for whether successful volume came from high attempt volume |
| `match_dribble_success_pct` | Combined successful-dribble percentage across the match | Football developer: efficiency context for match-level dribble intensity |
| `triggered_team_successful_dribbles` | Successful dribbles by triggered side | Football developer: side-specific contribution to trigger |
| `opponent_successful_dribbles` | Successful dribbles by opponent side | Football developer: bilateral contribution comparator |
| `triggered_team_dribble_attempts` | Dribble attempts by triggered side | Football developer: side carrying intent context |
| `opponent_dribble_attempts` | Dribble attempts by opponent side | Football developer: bilateral carrying intent comparator |
| `triggered_team_dribble_success_pct` | Triggered-side dribble success percentage | Football developer: side-level carrying efficiency around the trigger |
| `opponent_dribble_success_pct` | Opponent dribble success percentage | Football developer: bilateral carrying efficiency comparator |
| `triggered_team_successful_dribble_share_pct` | Triggered-side share of match successful dribbles | Football developer: allocation of dribble output ownership |
| `opponent_successful_dribble_share_pct` | Opponent share of match successful dribbles | Football developer: bilateral ownership comparator |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Football developer: possession-circulation baseline around dribble-heavy game states |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation baseline comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass completion percentage | Football developer: passing quality context around dribble reliance |
| `opponent_pass_accuracy_pct` | Opponent pass completion percentage | Football developer: bilateral passing quality comparator |
| `triggered_team_possession_pct` | Triggered-side possession percentage | Football developer: control context for dribble volume interpretation |
| `opponent_possession_pct` | Opponent possession percentage | Football developer: bilateral control comparator |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opponent penalty area | Football developer: penetration context linked to dribble outcomes |
| `opponent_touches_opposition_box` | Opponent touches in triggered-side penalty area | Football developer: bilateral penetration comparator |
| `triggered_team_total_shots` | Triggered-side total shots | Football developer: chance-volume context for dribble-heavy play |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral chance-volume comparator |
| `triggered_team_xg` | Triggered-side expected goals | Football developer: chance-quality context for dribble-heavy play |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_gap` | Triggered minus opponent xG | Football developer: net chance-quality edge while both teams dribble successfully |
