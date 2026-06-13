---
signal_id: sig_match_shooting_goals_clean_sheet_broken_late
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Clean Sheet Broken Late"
trigger: "First non-own goal has effective minute >= 89 and the pre-goal scoreline is 0-0."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_shooting_goals_clean_sheet_broken_late
  sql: clickhouse/gold/signal/sig_match_shooting_goals_clean_sheet_broken_late.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_shooting_goals_clean_sheet_broken_late

## Purpose

Detect finished matches where the first non-own goal arrives only after the 88th minute and breaks a 0-0 state, then expose side-oriented finishing and control context.

## Tactical And Statistical Logic

- Trigger condition: first goal event in the match satisfies `first_goal_effective_minute >= 89`, `home_score_before_first_goal = 0`, and `away_score_before_first_goal = 0`.
- Goal timing uses `goal_effective_minute = coalesce(goal_time, minute, 0) + coalesce(goal_overload_time, minute_added, 0)`.
- Goal events come from `silver.shot` where `is_goal = 1` and `is_own_goal = 0`.
- First-goal selection is deterministic using `row_number()` ordered by `(goal_effective_minute, goal_minute, goal_added_time, shot_id)`.
- Triggered matches emit two rows (`triggered_side = 'home'` and `'away'`) for canonical `match_team` grain.
- Similarity gate note: closest active signals are `sig_match_shooting_goals_early_goal_late_goal`, `sig_match_shooting_goals_high_pressure_finish`, and `sig_player_shooting_goals_late_winner_clutch`; this signal is distinct because it is explicitly first-goal timing + pre-goal score-state driven.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_shooting_goals_clean_sheet_broken_late.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_shooting_goals_clean_sheet_broken_late`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_shooting_goals_clean_sheet_broken_late
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable deduplication and join key. |
| `match_date` | Match date | Supports time-based slicing and backfills. |
| `home_team_id` | Home team identifier | Preserves fixture context. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves fixture context. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Outcome context around trigger behavior. |
| `away_score` | Full-time away goals | Outcome context around trigger behavior. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical `match_team` identity component. |
| `triggered_team_id` | Triggered-side team identifier | Side-oriented join key. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparator key. |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator context. |
| `trigger_threshold_min_first_goal_effective_minute` | Effective-minute threshold (`89`) | Explicit trigger provenance. |
| `trigger_threshold_max_home_score_before_first_goal` | Pre-goal home-score ceiling (`0`) | Encodes 0-0 pre-break condition. |
| `trigger_threshold_max_away_score_before_first_goal` | Pre-goal away-score ceiling (`0`) | Encodes 0-0 pre-break condition. |
| `first_goal_side` | Side that scored first | Identifies breakthrough side. |
| `first_goal_scoring_team_id` | First-goal scoring team identifier | Stable key for breakthrough-side analysis. |
| `first_goal_scoring_team_name` | First-goal scoring team name | Readable breakthrough-side context. |
| `first_goal_conceding_team_id` | First-goal conceding team identifier | Stable key for broken-clean-sheet side analysis. |
| `first_goal_conceding_team_name` | First-goal conceding team name | Readable conceding-side context. |
| `first_goal_minute` | Regulation minute of first goal | Base timing component of breakthrough. |
| `first_goal_added_time` | Added-time component of first goal | Stoppage-time detail for breakthrough timing. |
| `first_goal_effective_minute` | Effective minute of first goal | Core trigger evidence. |
| `home_score_before_first_goal` | Home score before first goal | Validates pre-break score state. |
| `away_score_before_first_goal` | Away score before first goal | Validates pre-break score state. |
| `home_score_after_first_goal` | Home score after first goal | Captures immediate score transition. |
| `away_score_after_first_goal` | Away score after first goal | Captures immediate score transition. |
| `scoreline_zero_zero_before_first_goal_flag` | 1 when pre-goal scoreline is 0-0 | Fast QA indicator for trigger integrity. |
| `match_total_goals` | Total full-time goals | Match scoring magnitude context. |
| `goals_after_first_goal` | Goals scored after breakthrough goal | Measures endgame continuation after deadlock break. |
| `first_goal_scoring_side_won_match_flag` | 1 when first-goal side wins | Outcome linkage to late breakthrough side. |
| `triggered_team_scored_first_goal_flag` | 1 when triggered side scored first | Side-oriented breakthrough indicator. |
| `triggered_team_clean_sheet_broken_flag` | 1 when triggered side conceded first | Side-oriented clean-sheet-break indicator. |
| `triggered_team_goals` | Triggered-side full-time goals | Outcome context from triggered perspective. |
| `opponent_goals` | Opponent full-time goals | Bilateral outcome comparator. |
| `goal_gap` | Triggered goals minus opponent goals | Final margin from triggered perspective. |
| `triggered_team_total_shots` | Triggered-side total shots | Attacking volume context. |
| `opponent_total_shots` | Opponent total shots | Bilateral attacking volume comparator. |
| `shot_volume_delta` | Triggered minus opponent total shots | Net attacking-volume differential. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Triggered-side precision count. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral precision comparator. |
| `triggered_team_shot_accuracy_pct` | Triggered-side on-target rate (%) | Normalized precision metric. |
| `opponent_shot_accuracy_pct` | Opponent on-target rate (%) | Bilateral normalized precision comparator. |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Compact precision differential. |
| `triggered_team_xg` | Triggered-side expected goals | Chance-quality baseline. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator. |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-generation balance. |
| `triggered_team_shot_conversion_pct` | Triggered-side goals per shot (%) | Side finishing efficiency context. |
| `opponent_shot_conversion_pct` | Opponent goals per shot (%) | Bilateral finishing-efficiency comparator. |
| `shot_conversion_delta_pct` | Triggered minus opponent conversion (percentage points) | Net finishing execution differential. |
| `triggered_team_big_chances` | Triggered-side big chances | High-quality chance volume context. |
| `opponent_big_chances` | Opponent big chances | Bilateral high-quality chance comparator. |
| `triggered_team_big_chances_missed` | Triggered-side big chances missed | Side wastefulness context. |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness comparator. |
| `big_chances_missed_delta` | Triggered minus opponent big chances missed | Net wastefulness differential. |
| `triggered_team_touches_opposition_box` | Triggered-side opposition-box touches | Territorial penetration context. |
| `opponent_touches_opposition_box` | Opponent opposition-box touches | Bilateral territorial comparator. |
| `opposition_box_touch_delta` | Triggered minus opponent opposition-box touches | Net box-occupation differential. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Circulation quality context. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation-quality comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Net technical-execution differential. |
