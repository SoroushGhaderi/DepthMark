---
signal_id: sig_team_shooting_goals_shooting_gallery
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Team Shooting Gallery"
trigger: "Team records >= 25 total shots in a single match (`period = 'All'`)"
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_shooting_gallery
  sql: clickhouse/gold/signal/sig_team_shooting_goals_shooting_gallery.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_shooting_goals_shooting_gallery

## Purpose

Detect extreme shot-volume team matches (25+ attempts) and quantify whether the volume reflected real chance quality and sustained attacking pressure.

## Tactical And Statistical Logic

- Trigger condition: `coalesce(total_shots_home, 0) >= 25` (home trigger) or `coalesce(total_shots_away, 0) >= 25` (away trigger) for full-match rows (`period = 'All'`).
- Signal output is side-oriented (`triggered_side`) and includes bilateral team/opponent context for interpretable diagnostics.
- Enrichment prioritizes conversion context (`on_target_ratio_pct`, `xg_per_shot`), territorial threat (`touches_opposition_box`, corners), and possession/circulation baselines.
- Similarity gate note: closest active team-level shot context signal is `sig_team_possession_passing_shot_per_possession`; this new signal is distinct because it is absolute volume-first (`>= 25` shots) rather than passing-efficiency-first.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_shooting_goals_shooting_gallery.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_shooting_goals_shooting_gallery`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_shooting_goals_shooting_gallery
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Join key for downstream match-level features and QA checks |
| `match_date` | Match date | Temporal slicing and reproducible batch backfills |
| `home_team_id` | Home team identifier | Stable team identity context |
| `home_team_name` | Home team name | Analyst-readable home-side context |
| `away_team_id` | Away team identifier | Stable team identity context |
| `away_team_name` | Away team name | Analyst-readable away-side context |
| `home_score` | Home goals scored | Game-state outcome context for interpretation |
| `away_score` | Away goals scored | Game-state outcome context for interpretation |
| `triggered_side` | Side that triggered (`home` or `away`) | Canonical row identity and bilateral orientation |
| `triggered_team_id` | Triggered team identifier | Triggered entity identity for modeling and joins |
| `triggered_team_name` | Triggered team name | Human-readable triggered entity |
| `opponent_team_id` | Opponent team identifier | Opponent orientation for tactical comparison |
| `opponent_team_name` | Opponent team name | Opponent orientation for tactical comparison |
| `trigger_threshold_total_shots` | Fixed trigger threshold (`25`) | Explicitly stores the governing trigger rule |
| `triggered_team_total_shots` | Total shots by triggered team | Primary trigger metric |
| `opponent_total_shots` | Total shots by opponent | Bilateral shot-volume baseline |
| `total_shots_delta` | Triggered minus opponent total shots | Relative shot dominance diagnostic |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Shot precision context behind volume |
| `opponent_shots_on_target` | Opponent shots on target | Opponent threat baseline |
| `triggered_team_on_target_ratio_pct` | Triggered-team on-target ratio (%) | Efficiency context of shot selection/execution |
| `opponent_on_target_ratio_pct` | Opponent on-target ratio (%) | Bilateral efficiency baseline |
| `on_target_ratio_delta_pct` | Triggered minus opponent on-target ratio (%) | Net finishing precision diagnostic |
| `triggered_team_big_chances` | Triggered-team big chances | Quality of opportunities behind raw volume |
| `opponent_big_chances` | Opponent big chances | Opponent chance-quality baseline |
| `triggered_team_big_chances_missed` | Triggered-team big chances missed | Wastefulness diagnostic under high volume |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness context |
| `triggered_team_xg` | Triggered-team expected goals | Chance-quality total generated |
| `opponent_xg` | Opponent expected goals | Opponent chance-quality baseline |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-quality dominance |
| `triggered_team_xg_per_shot` | Triggered-team xG per shot | Average quality per attempt |
| `opponent_xg_per_shot` | Opponent xG per shot | Bilateral shot-quality baseline |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial baseline |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Match-control baseline for shot output |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral match-control baseline |
| `possession_delta_pct` | Triggered minus opponent possession (%) | Net territorial control indicator |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Circulation volume context |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation baseline |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Ball-retention quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Opponent retention baseline |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Differential control and execution signal |
| `triggered_team_corners` | Triggered-team corners won | Sustained pressure/set-piece volume proxy |
| `opponent_corners` | Opponent corners won | Bilateral pressure baseline |
