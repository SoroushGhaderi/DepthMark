---
signal_id: sig_match_shooting_goals_penalty_decided_match
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Penalty-Decided Match"
trigger: "Finished scoreline is 1-0, 0-1, or 1-1, and every recorded goal is a penalty goal."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_shooting_goals_penalty_decided_match
  sql: clickhouse/gold/dml/signals/match/sig_match_shooting_goals_penalty_decided_match.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_shooting_goals_penalty_decided_match

## Purpose

Detect tight finished matches that are decided entirely by penalties (1-0, 0-1, or 1-1 with no non-penalty goals), then emit bilateral team rows for shooting, xG, and control diagnostics.

## Tactical And Statistical Logic

- Trigger condition: `match_finished = 1`, scoreline in `{1-0, 0-1, 1-1}`, and `match_total_penalty_goals = match_total_goals` with `match_total_non_penalty_goals = 0`.
- Penalty goals are identified from `silver.shot` goal events where `situation` or `shot_type` contains `"penalty"` (case-insensitive).
- Emits two rows per triggered match (`triggered_side = 'home'` and `'away'`) to preserve canonical `match_team` grain.
- Enrichment includes penalty/non-penalty goal decomposition plus bilateral shot quality, conversion, non-penalty xG context, and possession/passing balance.
- Similarity gate note: closest active signals are `sig_match_shooting_goals_high_xg_low_score` and `sig_team_discipline_cards_penalty_prone`; this signal remains distinct because it is explicitly match-scoreline-bound and requires *all* goals to be penalties, rather than general low-scoring inefficiency or team-level penalty-concession volume.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_shooting_goals_penalty_decided_match.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_shooting_goals_penalty_decided_match`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_shooting_goals_penalty_decided_match
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join and dedup key for downstream consumers. |
| `match_date` | Match date | Supports reproducible backfills and time-based analysis. |
| `home_team_id` | Home team identifier | Preserves full fixture context. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves full fixture context. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Part of strict scoreline trigger validation. |
| `away_score` | Full-time away goals | Part of strict scoreline trigger validation. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity at `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Side-oriented team join key. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator context. |
| `trigger_threshold_home_goals_max` | Configured home-goal cap (`1`) | Makes scoreline boundary explicit for QA. |
| `trigger_threshold_away_goals_max` | Configured away-goal cap (`1`) | Makes scoreline boundary explicit for QA. |
| `trigger_threshold_match_total_goals_max` | Configured total-goal cap (`2`) | Exposes low-score trigger envelope directly. |
| `trigger_threshold_all_goals_penalty_flag` | Required all-penalty-goals trigger flag (`1`) | Documents core rule as an explicit output contract field. |
| `is_one_nil_final_flag` | Indicates scoreline is 1-0 or 0-1 | Distinguishes one-goal-decider cases from draws. |
| `is_one_one_final_flag` | Indicates scoreline is 1-1 | Distinguishes shared-penalty draw cases. |
| `match_total_goals` | Combined full-time goals | Baseline scoring total for trigger and diagnostics. |
| `match_total_penalty_goals` | Combined penalty goals from shot events | Verifies that all goals came from penalties. |
| `match_total_non_penalty_goals` | Combined non-penalty goals from shot events | Must remain zero under signal trigger logic. |
| `match_goal_count_consistent_with_shots_flag` | Whether shot-level goal count equals scoreboard goal count | QA safeguard for event-score consistency. |
| `home_penalty_goals` | Home penalty-goal count | Transparent home-side penalty contribution. |
| `away_penalty_goals` | Away penalty-goal count | Transparent away-side penalty contribution. |
| `home_non_penalty_goals` | Home non-penalty-goal count | Verifies no open-play/set-play goals by home side. |
| `away_non_penalty_goals` | Away non-penalty-goal count | Verifies no open-play/set-play goals by away side. |
| `triggered_team_penalty_goals` | Triggered-side penalty-goal count | Side-oriented penalty output at row grain. |
| `opponent_penalty_goals` | Opponent penalty-goal count | Bilateral penalty-goal comparator. |
| `penalty_goals_delta` | Triggered minus opponent penalty goals | Net penalty-goal edge for side-level interpretation. |
| `triggered_team_non_penalty_goals` | Triggered-side non-penalty-goal count | Explicitly confirms absence of non-penalty scoring for triggered side. |
| `opponent_non_penalty_goals` | Opponent non-penalty-goal count | Explicitly confirms absence of non-penalty scoring for opponent. |
| `non_penalty_goals_delta` | Triggered minus opponent non-penalty goals | Differential sanity field for non-penalty scoring. |
| `triggered_team_total_shots` | Triggered-side total shots | Shooting volume context behind penalty-only scorelines. |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator. |
| `shot_volume_delta` | Triggered minus opponent total shots | Net attacking-volume differential. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Shooting precision context. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral precision comparator. |
| `shot_on_target_delta` | Triggered minus opponent shots on target | Net precision-volume differential. |
| `triggered_team_shot_accuracy_pct` | Triggered-side shot accuracy (%) | Normalized precision metric. |
| `opponent_shot_accuracy_pct` | Opponent shot accuracy (%) | Bilateral normalized precision comparator. |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Net precision differential. |
| `triggered_team_goals` | Goals scored by triggered side | Side-oriented score contribution. |
| `opponent_goals` | Goals scored by opponent | Bilateral scoreline comparator. |
| `goal_gap` | Triggered goals minus opponent goals | Outcome edge from triggered perspective. |
| `triggered_team_shot_conversion_pct` | Triggered-side goals per shot (%) | Finishing efficiency normalization. |
| `opponent_shot_conversion_pct` | Opponent goals per shot (%) | Bilateral finishing-efficiency comparator. |
| `shot_conversion_delta_pct` | Triggered minus opponent shot conversion (percentage points) | Net finishing-efficiency differential. |
| `match_total_xg` | Combined expected goals | Match-level chance-quality baseline. |
| `match_total_xg_non_penalty` | Combined non-penalty expected goals | Separates open-play/set-play chance quality from penalty value. |
| `match_total_penalty_xg_proxy` | Combined xG minus combined non-penalty xG | Proxy for penalty-linked xG share in the match. |
| `triggered_team_xg` | Triggered-side expected goals | Side-level chance-quality context. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator. |
| `xg_gap` | Triggered minus opponent expected goals | Net chance-generation balance. |
| `triggered_team_xg_non_penalty` | Triggered-side non-penalty expected goals | Open-play/set-play chance context for triggered side. |
| `opponent_xg_non_penalty` | Opponent non-penalty expected goals | Open-play/set-play chance context for opponent. |
| `xg_non_penalty_gap` | Triggered minus opponent non-penalty xG | Net non-penalty chance differential. |
| `triggered_team_big_chances` | Triggered-side big chances | High-quality chance-volume context. |
| `opponent_big_chances` | Opponent big chances | Bilateral high-quality chance comparator. |
| `triggered_team_big_chances_missed` | Triggered-side big chances missed | Wastefulness context beyond penalties. |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness comparator. |
| `big_chances_missed_delta` | Triggered minus opponent big chances missed | Net chance-waste differential. |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Territorial penetration context. |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator. |
| `opposition_box_touch_delta` | Triggered minus opponent opposition-box touches | Net territorial-pressure differential. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context for penalty-decided games. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-circulation quality context. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation-quality comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Technical execution differential for interpretation. |
