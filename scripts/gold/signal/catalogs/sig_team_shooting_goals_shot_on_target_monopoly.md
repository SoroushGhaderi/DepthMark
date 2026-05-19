---
signal_id: sig_team_shooting_goals_shot_on_target_monopoly
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Shot-on-Target Monopoly"
trigger: "Team records >= 10 shots on target while opponent records 0 in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_team_shooting_goals_shot_on_target_monopoly
  sql: clickhouse/gold/signal/sig_team_shooting_goals_shot_on_target_monopoly.sql
  runner: scripts/gold/signal/runners/sig_team_shooting_goals_shot_on_target_monopoly.py
---
# sig_team_shooting_goals_shot_on_target_monopoly

## Purpose

Detect team-level matches where one side completely monopolizes on-target shot execution (`>= 10` vs `0`), signaling simultaneous attacking dominance and defensive suppression.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_shots_on_target >= 10`
  - `opponent_shots_on_target = 0`
- Trigger is evaluated on full-match team stats (`period = 'All'`) and finished matches only.
- Signal output remains side-oriented (`triggered_side`) and bilateral (`triggered_team_*` vs `opponent_*`) so analysts can separate pure suppression from broader game-state effects.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_no_shots_allowed` and `sig_team_shooting_goals_conversion_collapse`; this signal intentionally coexists because it requires both strict opponent suppression (`0` opponent shots on target) and high triggered-side on-target dominance (`>= 10`), not just one side of that profile.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_shooting_goals_shot_on_target_monopoly.sql`
- Runner: `scripts/gold/signal/runners/sig_team_shooting_goals_shot_on_target_monopoly.py`
- Target table: `gold.sig_team_shooting_goals_shot_on_target_monopoly`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_shooting_goals_shot_on_target_monopoly.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join key for QA, feature engineering, and downstream analytics |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills |
| `home_team_id` | Home team identifier | Preserves bilateral fixture context |
| `home_team_name` | Home team name | Analyst-readable home-side context |
| `away_team_id` | Away team identifier | Preserves bilateral fixture context |
| `away_team_name` | Away team name | Analyst-readable away-side context |
| `home_score` | Home full-time goals | Scoreline context for trigger interpretation |
| `away_score` | Away full-time goals | Scoreline context for trigger interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical row identity at `match_team` grain |
| `triggered_team_id` | Triggered team identifier | Triggered-side identity key for joins |
| `triggered_team_name` | Triggered team name | Readable triggered entity attribution |
| `opponent_team_id` | Opponent team identifier | Preserves bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Readable opponent context |
| `trigger_threshold_min_shots_on_target` | Minimum triggered-side shots-on-target threshold (`10`) | Explicit trigger boundary for reproducibility and QA |
| `trigger_threshold_max_opponent_shots_on_target` | Maximum opponent shots-on-target threshold (`0`) | Explicit suppression boundary for reproducibility and QA |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Core trigger metric for attacking dominance |
| `opponent_shots_on_target` | Opponent shots on target | Core trigger metric for defensive suppression |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Net on-target dominance intensity |
| `triggered_team_total_shots` | Triggered-team total shots | Volume context behind on-target monopoly |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume baseline |
| `total_shots_delta` | Triggered minus opponent total shots | Net shot-pressure differential |
| `triggered_team_on_target_ratio_pct` | Triggered-team on-target ratio (%) | Triggered-side shot execution quality context |
| `opponent_on_target_ratio_pct` | Opponent on-target ratio (%) | Opponent execution baseline |
| `on_target_ratio_delta_pct` | Triggered minus opponent on-target ratio (percentage points) | Side-level execution-gap diagnostic |
| `triggered_team_goals` | Goals scored by triggered team | End-product context for the trigger event |
| `opponent_goals` | Goals scored by opponent | Bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Compact match-outcome differential |
| `triggered_team_xg` | Triggered-team expected goals | Chance-quality total behind on-target dominance |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality baseline |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-generation differential |
| `triggered_team_xg_per_shot` | Triggered-team xG per shot | Average shot quality for triggered side |
| `opponent_xg_per_shot` | Opponent xG per shot | Bilateral average shot-quality comparator |
| `triggered_team_big_chances` | Triggered-team big chances | High-value chance creation context |
| `opponent_big_chances` | Opponent big chances | Bilateral high-value chance baseline |
| `triggered_team_big_chances_missed` | Triggered-team big chances missed | Finishing wastefulness context despite monopoly |
| `opponent_big_chances_missed` | Opponent big chances missed | Opponent wastefulness baseline |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial baseline |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Control-profile context for sustained pressure |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share baseline |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Circulation-volume context |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation baseline |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Retention/execution quality for the triggered side |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral retention baseline |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Net circulation-quality differential |
| `triggered_team_corners` | Triggered-team corners won | Sustained pressure and repeat-entry proxy |
| `opponent_corners` | Opponent corners won | Bilateral pressure baseline |
| `triggered_team_clean_sheet_flag` | 1 when opponent goals = 0, else 0 | Distinguishes shot suppression from scoreboard clean-sheet outcome |
