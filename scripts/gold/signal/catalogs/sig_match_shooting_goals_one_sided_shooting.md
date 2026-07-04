---
signal_id: sig_match_shooting_goals_one_sided_shooting
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "One-Sided Shots-on-Target Match"
trigger: "One side records all match shots on target: triggered-team shots on target > 0 and opponent shots on target = 0 in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_shooting_goals_one_sided_shooting
  sql: clickhouse/gold/dml/signals/match/sig_match_shooting_goals_one_sided_shooting.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_match_shooting_goals_one_sided_shooting

## Purpose

Detect finished matches where one side owns every on-target attempt (`> 0` vs `0`) and expose bilateral finishing, chance, and control diagnostics for interpretation and downstream modeling.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_shots_on_target > 0`
  - `opponent_shots_on_target = 0`
- Trigger is evaluated on full-match team stats (`period = 'All'`) and finished matches only.
- Signal emits one side-oriented row (`triggered_side`) for the qualifying side in each match.
- Enrichment includes shot volume/accuracy/conversion, xG quality, big chances, box touches, possession, and pass-accuracy gaps.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_shot_on_target_monopoly` and `sig_team_shooting_goals_no_shots_allowed`; this signal intentionally coexists because it is match-scoped and requires exclusive on-target ownership without the high threshold (`>= 10`) used by the monopoly signal.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_shooting_goals_one_sided_shooting.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_match_shooting_goals_one_sided_shooting`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_match_shooting_goals_one_sided_shooting
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for joins, QA, and deduplication at match-team grain |
| `match_date` | Match date | Temporal slicing and reproducible backfills |
| `home_team_id` | Home team identifier | Preserves fixture context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team identifier | Preserves fixture context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Full-time home goals | Scoreline context for trigger interpretation |
| `away_score` | Full-time away goals | Scoreline context for trigger interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side-oriented row identity |
| `triggered_team_id` | Triggered team identifier | Side-oriented identity for downstream joins |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Bilateral comparator identity |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator |
| `trigger_threshold_min_triggered_team_shots_on_target` | Minimum triggered-side shots-on-target threshold (`1`) | Makes trigger boundary explicit for QA and reproducibility |
| `trigger_threshold_max_opponent_shots_on_target` | Maximum opponent shots-on-target threshold (`0`) | Encodes strict suppression boundary used by trigger |
| `match_total_shots_on_target` | Combined shots on target in the match | Match-intensity baseline for on-target ownership |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Core numerator metric of one-sided shooting |
| `opponent_shots_on_target` | Opponent shots on target | Core suppression comparator and trigger guard |
| `shot_on_target_delta` | Triggered minus opponent shots on target | Net on-target dominance intensity |
| `triggered_team_shots_on_target_share_pct` | Triggered-side share of match shots on target (%) | Normalized on-target ownership metric |
| `opponent_shots_on_target_share_pct` | Opponent share of match shots on target (%) | Bilateral normalized comparator |
| `triggered_team_goals` | Goals scored by triggered side | Outcome context of on-target ownership |
| `opponent_goals` | Goals scored by opponent | Bilateral outcome comparator |
| `goal_gap` | Triggered-team goals minus opponent goals | Compact scoreline differential |
| `triggered_team_total_shots` | Triggered-team total shots | Shot-volume context behind on-target control |
| `opponent_total_shots` | Opponent total shots | Bilateral volume baseline |
| `shot_volume_delta` | Triggered minus opponent total shots | Net shooting-pressure differential |
| `triggered_team_shot_accuracy_pct` | Triggered-team on-target rate (%) | Shot-execution quality for triggered side |
| `opponent_shot_accuracy_pct` | Opponent on-target rate (%) | Bilateral shooting-accuracy comparator |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Normalized execution-gap diagnostic |
| `triggered_team_shot_conversion_pct` | Triggered-team goals per shot (%) | Finishing efficiency of triggered side |
| `opponent_shot_conversion_pct` | Opponent goals per shot (%) | Bilateral finishing-efficiency baseline |
| `shot_conversion_delta_pct` | Triggered minus opponent shot conversion (percentage points) | Finishing differential for tactical interpretation |
| `triggered_team_xg` | Triggered-team expected goals | Chance-quality total behind triggered side |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-generation differential |
| `triggered_team_xg_per_shot` | Triggered-team xG per shot | Average shot quality of triggered side |
| `opponent_xg_per_shot` | Opponent xG per shot | Bilateral average shot-quality comparator |
| `triggered_team_big_chances` | Triggered-team big chances | High-value chance creation context |
| `opponent_big_chances` | Opponent big chances | Bilateral high-value chance baseline |
| `big_chance_delta` | Triggered minus opponent big chances | Net clear-chance differential |
| `triggered_team_big_chances_missed` | Triggered-team big chances missed | Finishing wastefulness diagnostic |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness comparator |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial baseline |
| `opposition_box_touch_delta` | Triggered minus opponent opposition-box touches | Net territorial-pressure differential |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Ball-control context for signal profile |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control baseline |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Technical execution context for sustained control |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation-quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Circulation-quality differential for modeling/QA |
| `triggered_team_corners` | Triggered-team corners won | Sustained pressure and territory recurrence proxy |
| `opponent_corners` | Opponent corners won | Bilateral pressure baseline |
| `triggered_team_clean_sheet_flag` | 1 when opponent goals = 0, else 0 | Distinguishes shot-on-target suppression from scoreboard clean-sheet outcome |
