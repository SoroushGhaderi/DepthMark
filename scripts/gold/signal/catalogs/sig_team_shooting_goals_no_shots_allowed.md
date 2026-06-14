---
signal_id: sig_team_shooting_goals_no_shots_allowed
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "No Shots Allowed"
trigger: "Team allows 0 shots on target to the opposition in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_no_shots_allowed
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_no_shots_allowed.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_shooting_goals_no_shots_allowed

## Purpose

Detect team-level defensive suppression events where the opponent fails to register a single shot on target, and preserve bilateral attacking/control context for interpretation.

## Tactical And Statistical Logic

- Trigger condition: `opponent_shots_on_target = 0` at full-match scope (`period = 'All'`) in finished matches only.
- Rows are emitted at `match_team` grain with `triggered_side` orientation, so both teams can appear when both suppress on-target attempts.
- Enrichment keeps symmetric team/opponent context across outcome, volume, chance quality, and circulation to separate pure defensive control from low-event game states.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_ruthless_efficiency` and `sig_team_shooting_goals_shooting_gallery`; this signal is distinct because it is suppression-first (opponent on-target attempts fixed at zero), not conversion-first or own shot-volume-first.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_no_shots_allowed.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_shooting_goals_no_shots_allowed`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_shooting_goals_no_shots_allowed
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join key for downstream QA, feature engineering, and reporting |
| `match_date` | Match date | Supports temporal slicing, trend analysis, and backfill traceability |
| `home_team_id` | Home team identifier | Preserves bilateral match context |
| `home_team_name` | Home team name | Human-readable home-side context |
| `away_team_id` | Away team identifier | Preserves bilateral match context |
| `away_team_name` | Away team name | Human-readable away-side context |
| `home_score` | Home goals scored | Outcome context for the suppression event |
| `away_score` | Away goals scored | Outcome context for the suppression event |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical row identity for match-team grain |
| `triggered_team_id` | Triggered team identifier | Stable identity key for triggered-side joins |
| `triggered_team_name` | Triggered team name | Analyst-readable triggered entity |
| `opponent_team_id` | Opponent team identifier | Preserves opponent orientation for tactical comparisons |
| `opponent_team_name` | Opponent team name | Analyst-readable opponent context |
| `trigger_threshold_max_opponent_shots_on_target` | Fixed trigger threshold (`0`) | Makes trigger rule explicit and auditable in output |
| `triggered_team_goals` | Goals scored by triggered team | Connects defensive suppression to attacking output |
| `opponent_goals` | Goals scored by opponent | Detects edge cases (for example own-goal outcomes) despite zero on-target shots |
| `goal_delta` | Triggered-team goals minus opponent goals | Compact result differential |
| `triggered_team_total_shots` | Total shots by triggered team | Attacking-volume context for triggered side |
| `opponent_total_shots` | Total shots by opponent | Distinguishes shot suppression from complete event suppression |
| `total_shots_delta` | Triggered minus opponent total shots | Relative shot-pressure diagnostic |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Triggered-side shot execution context |
| `opponent_shots_on_target` | Opponent shots on target | Core trigger metric (`0`) |
| `shots_on_target_delta` | Triggered minus opponent shots on target | On-target threat differential |
| `triggered_team_on_target_ratio_pct` | Triggered-team on-target ratio (%) | Triggered-side shot precision indicator |
| `opponent_on_target_ratio_pct` | Opponent on-target ratio (%) | Opponent shot precision baseline |
| `on_target_ratio_delta_pct` | Triggered minus opponent on-target ratio (percentage points) | Net shot-precision gap diagnostic |
| `triggered_team_big_chances` | Big chances created by triggered team | High-quality chance creation context |
| `opponent_big_chances` | Big chances created by opponent | Opponent chance-quality baseline despite zero on-target attempts |
| `triggered_team_big_chances_missed` | Big chances missed by triggered team | Finishing wastefulness context on triggered side |
| `opponent_big_chances_missed` | Big chances missed by opponent | Opponent wastefulness context |
| `triggered_team_xg` | Triggered-team expected goals | Triggered-side chance-quality total |
| `opponent_xg` | Opponent expected goals | Opponent chance-quality baseline |
| `xg_delta` | Triggered-team xG minus opponent xG | Net chance-quality differential |
| `triggered_team_xg_per_shot` | Triggered-team xG per shot | Average chance quality per triggered-side attempt |
| `opponent_xg_per_shot` | Opponent xG per shot | Opponent average chance quality per attempt |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in triggered-team box | Bilateral territorial baseline |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Control-profile context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share baseline |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Circulation volume context |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation baseline |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Triggered-side retention/execution quality |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Opponent retention baseline |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Net circulation-quality differential |
| `triggered_team_corners` | Corners won by triggered team | Sustained pressure proxy for triggered side |
| `opponent_corners` | Corners won by opponent | Opponent set-piece pressure baseline |
| `triggered_team_clean_sheet_flag` | 1 when opponent goals = 0, else 0 | Separates pure chance suppression from scoreboard clean-sheet outcome |
