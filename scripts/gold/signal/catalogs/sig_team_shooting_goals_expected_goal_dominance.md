---
signal_id: sig_team_shooting_goals_expected_goal_dominance
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Expected Goal Dominance"
trigger: "Team records > 3.0 xG while opponent records < 0.3 xG in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_expected_goal_dominance
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_expected_goal_dominance.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_shooting_goals_expected_goal_dominance

## Purpose

Detect rare team-level matches with extreme bilateral xG imbalance, where one side generates elite chance quality volume (`xG > 3.0`) while suppressing the opponent to near-zero threat (`xG < 0.3`).

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_xg > 3.0`
  - `opponent_xg < 0.3`
- Trigger is evaluated on finished matches only using full-match aggregates from `silver.period_stat` (`period = 'All'`).
- Output is side-oriented (`triggered_side`) with symmetric `triggered_team_*` and `opponent_*` context for shots, xG efficiency, finishing, possession, circulation, and territory.
- Severity beyond the binary trigger is captured with `triggered_team_xg_above_threshold`, `opponent_xg_below_threshold`, and `trigger_clearance_xg`.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_offensive_masterclass`, `sig_team_shooting_goals_no_shots_allowed`, and `sig_team_shooting_goals_shot_on_target_monopoly`; this signal intentionally coexists because it is bilateral xG-extremes-first (high own xG plus very low opponent xG), not only average shot quality or shots-on-target suppression.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_expected_goal_dominance.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_shooting_goals_expected_goal_dominance`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_shooting_goals_expected_goal_dominance
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for downstream features and QA |
| `match_date` | Match date | Football developer: enables temporal slicing and reproducible backfills |
| `home_team_id` | Home team identifier | Football developer: preserves bilateral match context |
| `home_team_name` | Home team name | Football developer: human-readable home-side attribution |
| `away_team_id` | Away team identifier | Football developer: preserves bilateral match context |
| `away_team_name` | Away team name | Football developer: human-readable away-side attribution |
| `home_score` | Home final goals | Football developer: scoreline context around xG dominance |
| `away_score` | Away final goals | Football developer: scoreline context around xG dominance |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical side orientation at match-team grain |
| `triggered_team_id` | Triggered team identifier | Football developer: primary triggered entity key |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Football developer: preserves bilateral opponent orientation |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral opponent context |
| `trigger_threshold_min_triggered_team_xg` | Minimum xG threshold for triggered side (`3.0`) | Football developer: explicit trigger-rule provenance |
| `trigger_threshold_max_opponent_xg` | Maximum xG threshold for opponent (`0.3`) | Football developer: explicit trigger-rule provenance |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: primary attacking-side trigger metric |
| `opponent_xg` | Opponent expected goals | Football developer: primary suppression-side trigger metric |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: compact bilateral chance-quality dominance summary |
| `triggered_team_xg_above_threshold` | Margin by which triggered-team xG exceeds `3.0` | Football developer: trigger intensity beyond binary activation |
| `opponent_xg_below_threshold` | Margin by which opponent xG is below `0.3` | Football developer: suppression intensity beyond binary activation |
| `trigger_clearance_xg` | Smaller of the two trigger margins | Football developer: conservative one-number confidence of joint trigger satisfaction |
| `triggered_team_total_shots` | Triggered-team total shots | Football developer: shot-volume context behind high xG output |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral shot-volume baseline |
| `total_shots_delta` | Triggered minus opponent total shots | Football developer: net shot-pressure diagnostic |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Football developer: execution-quality volume context |
| `opponent_shots_on_target` | Opponent shots on target | Football developer: bilateral execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Football developer: compact on-target threat differential |
| `triggered_team_on_target_ratio_pct` | Triggered-team on-target ratio (%) | Football developer: shot precision context for attacking dominance |
| `opponent_on_target_ratio_pct` | Opponent on-target ratio (%) | Football developer: bilateral precision baseline |
| `on_target_ratio_delta_pct` | Triggered minus opponent on-target ratio (%) | Football developer: net shot-precision differential |
| `triggered_team_xg_per_shot` | Triggered-team xG per shot | Football developer: average chance quality per triggered-side attempt |
| `opponent_xg_per_shot` | Opponent xG per shot | Football developer: bilateral average chance-quality comparator |
| `xg_per_shot_delta` | Triggered minus opponent xG per shot | Football developer: per-shot quality gap independent of raw shot count |
| `triggered_team_big_chances` | Triggered-team big chances created | Football developer: high-quality chance-volume context |
| `opponent_big_chances` | Opponent big chances created | Football developer: bilateral high-value chance baseline |
| `triggered_team_big_chances_missed` | Triggered-team big chances missed | Football developer: wastefulness context despite high xG creation |
| `opponent_big_chances_missed` | Opponent big chances missed | Football developer: bilateral finishing-waste baseline |
| `triggered_team_goals` | Goals scored by triggered team | Football developer: finishing outcome context relative to xG dominance |
| `opponent_goals` | Goals scored by opponent | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: compact result differential |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Football developer: bilateral territorial baseline |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Football developer: control-profile context for chance creation dominance |
| `opponent_possession_pct` | Opponent possession (%) | Football developer: bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession (%) | Football developer: net control differential |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Football developer: circulation-volume baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation baseline |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Football developer: build-up execution quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral build-up execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Football developer: net circulation-quality differential |
| `triggered_team_corners` | Triggered-team corners won | Football developer: sustained attacking-pressure proxy |
| `opponent_corners` | Opponent corners won | Football developer: bilateral pressure baseline |
| `triggered_team_clean_sheet_flag` | 1 when opponent goals = 0, else 0 | Football developer: links suppression profile to scoreboard clean-sheet outcome |
