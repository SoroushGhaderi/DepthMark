---
signal_id: sig_match_shooting_goals_unproductive_dominance
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Unproductive Shot Dominance"
trigger: "Team records >= 20 total shots and 0 big chances in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_shooting_goals_unproductive_dominance
  sql: clickhouse/gold/dml/signals/match/sig_match_shooting_goals_unproductive_dominance.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_shooting_goals_unproductive_dominance

## Purpose

Detect finished matches where a side generates very high shot volume but fails to create any big chance, then expose bilateral diagnostics to separate sterile pressure from genuinely dangerous attacking process.

## Tactical And Statistical Logic

- Trigger condition for each side: `total_shots >= 20` and `big_chances = 0` at `period = 'All'`.
- Signal emits one row per qualifying side (`triggered_side = 'home'` or `'away'`), preserving canonical `match_team` grain and allowing bilateral triggers in the same match.
- Enrichment captures shooting execution (volume, on-target rate, conversion), chance quality (`xg`, `xg_per_shot`, big-chance context), territorial pressure (opposition-box touches), and control quality (possession plus passing).
- Similarity gate note: closest active signals are `sig_match_shooting_goals_high_volume_low_target`, `sig_match_shooting_goals_goalless_siege`, and `sig_team_shooting_goals_shot_accuracy_collapse`; this signal is distinct because it is side-triggered on the specific combination of *very high shot count* and *zero big chances*, independent of scoreline or combined match precision constraints.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_shooting_goals_unproductive_dominance.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_shooting_goals_unproductive_dominance`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_shooting_goals_unproductive_dominance
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for deduplication and downstream joins. |
| `match_date` | Match date | Supports reproducible backfills and temporal analysis. |
| `home_team_id` | Home team identifier | Preserves fixture context. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves fixture context. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Scoreline context for trigger interpretation. |
| `away_score` | Full-time away goals | Scoreline context for trigger interpretation. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity at `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Side-oriented team join key. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side attribution. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable opponent attribution. |
| `trigger_threshold_min_triggered_team_total_shots` | Configured shot floor (`20`) | Makes trigger boundary explicit for QA. |
| `trigger_threshold_max_triggered_team_big_chances` | Configured big-chance ceiling (`0`) | Encodes strict chance-quality failure boundary. |
| `match_total_shots` | Combined shots by both teams | Match-level attacking intensity context. |
| `match_total_shots_on_target` | Combined shots on target by both teams | Match-level precision baseline. |
| `match_total_xg` | Combined expected goals | Match-level chance-quality baseline. |
| `match_total_goals` | Combined full-time goals | Outcome context against process metrics. |
| `triggered_team_total_shots` | Triggered-side total shots | Core high-volume trigger component. |
| `opponent_total_shots` | Opponent total shots | Bilateral volume comparator. |
| `shot_volume_delta` | Triggered minus opponent total shots | Net shot-pressure differential. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Triggered-side precision volume. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral precision comparator. |
| `shot_on_target_delta` | Triggered minus opponent shots on target | Net on-target differential. |
| `triggered_team_shot_accuracy_pct` | Triggered-side on-target rate (%) | Normalized shot-execution quality. |
| `opponent_shot_accuracy_pct` | Opponent on-target rate (%) | Bilateral execution comparator. |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Directional precision-gap diagnostic. |
| `triggered_team_big_chances` | Triggered-side big chances | Core chance-quality trigger component (expected to be `0`). |
| `opponent_big_chances` | Opponent big chances | Bilateral high-value chance comparator. |
| `big_chance_delta` | Triggered minus opponent big chances | Net clear-chance creation differential. |
| `triggered_team_big_chances_missed` | Triggered-side big chances missed | Finishing-waste context. |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness comparator. |
| `big_chances_missed_delta` | Triggered minus opponent big chances missed | Net wastefulness differential. |
| `triggered_team_xg` | Triggered-side expected goals | Side-level chance-quality total. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator. |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-generation differential. |
| `triggered_team_xg_per_shot` | Triggered-side expected goals per shot | Average chance quality per attempt. |
| `opponent_xg_per_shot` | Opponent expected goals per shot | Bilateral shot-quality comparator. |
| `xg_per_shot_delta` | Triggered minus opponent expected goals per shot | Net shot-quality efficiency differential. |
| `triggered_team_goals` | Goals scored by triggered side | Outcome contribution by triggered side. |
| `opponent_goals` | Goals scored by opponent | Bilateral outcome comparator. |
| `goal_delta` | Triggered minus opponent goals | Scoreline differential from triggered perspective. |
| `triggered_team_shot_conversion_pct` | Triggered-side goals per shot (%) | Finishing-efficiency normalization. |
| `opponent_shot_conversion_pct` | Opponent goals per shot (%) | Bilateral finishing comparator. |
| `shot_conversion_delta_pct` | Triggered minus opponent conversion (percentage points) | Net finishing differential. |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Territorial penetration context. |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator. |
| `opposition_box_touch_delta` | Triggered minus opponent opposition-box touches | Net territorial-pressure differential. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Ball-control context around shooting pattern. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential. |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Circulation-volume context. |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator. |
| `pass_attempt_delta` | Triggered minus opponent pass attempts | Net circulation-load differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Technical execution context. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution-quality comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Net circulation-quality differential. |
| `opponent_also_triggered` | Flag that opponent also satisfies the trigger | Distinguishes unilateral from bilateral trigger cases. |
| `both_teams_triggered` | Flag that both sides satisfy trigger simultaneously | Supports bilateral-case segmentation and QA. |
