---
signal_id: sig_team_possession_passing_set_piece_focus
status: active
entity: team
family: possession
subfamily: passing
grain: match_team
headline: "Set-Piece Focus"
trigger: "Team wins >= 15 corners in a single match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_possession_passing_set_piece_focus
  sql: clickhouse/gold/dml/signals/team/sig_team_possession_passing_set_piece_focus.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_possession_passing_set_piece_focus

## Purpose

Detect teams that concentrate match attacking pressure into repeated corner-winning sequences, then profile whether the resulting set-piece focus is supported by passing control and chance quality.

## Tactical And Statistical Logic

- Trigger condition: team-level `corners >= 15` in a single finished match.
- Signal emits one row per triggered side (`home` or `away`) with mirrored opponent context.
- Corner pressure is paired with set-piece end-product (`set_piece_shots`, `set_play_xg`) to distinguish sterile corner volume from dangerous corner volume.
- Passing context (`pass_attempts`, `pass_accuracy`, `opposition_half_passes`) and territory/shot context (`touches_opposition_box`, `total_shots`, `possession`) help explain whether set-piece focus emerged from sustained control.
- Dead-ball restart proxy metrics (`player_throws + corners`) quantify how much of each side's circulation came through restart actions.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_possession_passing_set_piece_focus.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_possession_passing_set_piece_focus`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_possession_passing_set_piece_focus
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable primary key for signal joins and QA |
| `match_date` | Match date | Football developer: supports temporal filtering and monitoring |
| `home_team_id` | Home team ID | Football developer: fixture identity anchor |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixture identity anchor |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Full-time home goals | Football developer: scoreline context for trigger interpretation |
| `away_score` | Full-time away goals | Football developer: scoreline context for trigger interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: preserves canonical side orientation |
| `triggered_team_id` | Triggered team ID | Football developer: side-scoped team identity for downstream features |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered identity |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral comparator identity |
| `opponent_team_name` | Opponent team name | Football developer: bilateral comparator identity |
| `trigger_threshold_corners` | Constant threshold used by the signal (`15`) | Football developer: explicit audit trail for trigger configuration |
| `triggered_team_corners` | Corners won by triggered team | Football developer: direct trigger metric |
| `opponent_corners` | Corners won by opponent | Football developer: bilateral baseline for corner pressure imbalance |
| `corner_delta` | Triggered minus opponent corners | Football developer: quantifies net set-piece pressure from corners |
| `triggered_team_set_piece_shots` | Triggered-team shots from set-piece situations | Football developer: validates whether corner pressure became attempts |
| `opponent_set_piece_shots` | Opponent shots from set-piece situations | Football developer: bilateral set-piece output comparator |
| `triggered_team_set_play_xg` | Triggered-team set-play xG | Football developer: set-piece chance-quality output |
| `opponent_set_play_xg` | Opponent set-play xG | Football developer: bilateral chance-quality comparator |
| `set_play_xg_delta` | Triggered minus opponent set-play xG | Football developer: net set-piece chance-quality edge |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Football developer: possession circulation volume context |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation comparator |
| `triggered_team_accurate_passes` | Triggered-team accurate passes | Football developer: raw passing execution context |
| `opponent_accurate_passes` | Opponent accurate passes | Football developer: bilateral passing execution comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: passing-quality context around set-piece focus |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral passing-quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Football developer: net passing-quality edge |
| `triggered_team_cross_attempts` | Triggered-team cross attempts | Football developer: wide-delivery route context for corner generation |
| `opponent_cross_attempts` | Opponent cross attempts | Football developer: bilateral route-selection comparator |
| `cross_attempts_delta` | Triggered minus opponent cross attempts | Football developer: net wide-attacking load linked to corner pressure |
| `triggered_team_opposition_half_passes` | Triggered-team passes in opposition half | Football developer: territorial progression context |
| `opponent_opposition_half_passes` | Opponent passes in opposition half | Football developer: bilateral territorial progression comparator |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Football developer: box-occupation context around corner pressure |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Football developer: bilateral box-occupation comparator |
| `triggered_team_total_shots` | Triggered-team total shots | Football developer: overall attacking output context |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral attacking output comparator |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Football developer: control context for set-piece-focused profile |
| `opponent_possession_pct` | Opponent possession (%) | Football developer: bilateral control comparator |
| `triggered_team_player_throws` | Triggered-team throw-ins | Football developer: dead-ball restart component context |
| `opponent_player_throws` | Opponent throw-ins | Football developer: bilateral restart component comparator |
| `triggered_team_dead_ball_restart_passes_proxy` | Triggered-team restart-pass proxy (`player_throws + corners`) | Football developer: estimates restart-led circulation volume |
| `opponent_dead_ball_restart_passes_proxy` | Opponent restart-pass proxy (`player_throws + corners`) | Football developer: bilateral restart-led circulation comparator |
| `triggered_team_dead_ball_restart_pass_share_pct` | Triggered-team restart-pass proxy share of its pass attempts (%) | Football developer: tactical concentration of circulation into restarts |
| `opponent_dead_ball_restart_pass_share_pct` | Opponent restart-pass proxy share of its pass attempts (%) | Football developer: bilateral concentration comparator |
