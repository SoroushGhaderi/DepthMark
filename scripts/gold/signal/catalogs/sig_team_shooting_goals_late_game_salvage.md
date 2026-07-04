---
signal_id: sig_team_shooting_goals_late_game_salvage
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Late-Game Salvage"
trigger: "Team scores a tying or winning non-own goal after the 90th minute (effective minute > 90) and avoids finishing behind."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_late_game_salvage
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_late_game_salvage.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_shooting_goals_late_game_salvage

## Purpose

Detect team-level late-game salvage moments where a side scores a tying or winning non-own goal after the 90th minute and converts a losing or level late state into a non-losing final outcome.

## Tactical And Statistical Logic

- Trigger condition:
  - Non-own goal event (`is_goal = 1`, `is_own_goal = 0`) with `goal_effective_minute > 90`.
  - Event is score-state salvage: goal either restores parity (`tying`) or creates a lead (`winning`) at the event moment.
  - Final-state validity guard:
    - tying-event salvage requires triggered side to finish draw-or-win.
    - winning-event salvage requires triggered side to finish as match winner.
- Grain and orientation:
  - Emits side-oriented rows (`triggered_side`) at `match_team` grain, allowing bilateral triggering when both teams satisfy the rule in the same match.
  - Preserves first qualifying late-salvage timing and before/after score-state evidence for auditability.
- Match context enrichment:
  - Adds bilateral shooting, xG, big-chance, possession, passing, and corner diagnostics from `silver.period_stat` (`period = 'All'`).
- Similarity gate note:
  - Closest active signals are `sig_team_shooting_goals_late_surge_goals`, `sig_team_shooting_goals_rapid_response_goal`, and `sig_player_shooting_goals_late_winner_clutch`.
  - This signal intentionally coexists because it is team-triggered and score-state specific (tying/winning salvage after 90), not burst-count or immediate-response focused.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_late_game_salvage.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_shooting_goals_late_game_salvage`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_late_game_salvage
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join key for downstream feature tables and QA checks |
| `match_date` | Match date | Temporal slicing and reproducible backfill tracking |
| `home_team_id` | Home team identifier | Preserves fixture orientation for bilateral interpretation |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team identifier | Preserves fixture orientation for bilateral interpretation |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Final home goals | Final outcome anchor around salvage events |
| `away_score` | Final away goals | Final outcome anchor around salvage events |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical row identity component at match-team grain |
| `triggered_team_id` | Triggered team identifier | Side-oriented entity key for joins |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Bilateral comparator identity key |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator attribution |
| `trigger_threshold_min_goal_effective_minute` | Minimum effective-minute boundary (`90`) | Explicit trigger provenance for governance |
| `trigger_threshold_min_late_salvage_goals` | Minimum late salvage event count (`1`) | Explicit activation threshold for QA |
| `triggered_team_late_salvage_goals` | Count of qualifying late tying/winning salvage goals by triggered side | Core trigger intensity metric |
| `triggered_team_late_tying_goals` | Count of qualifying late tying-goal salvage events | Distinguishes parity-restoration salvage subtype |
| `triggered_team_late_winning_goals` | Count of qualifying late winning-goal salvage events | Distinguishes lead-creation salvage subtype |
| `opponent_late_salvage_goals` | Opponent count of qualifying late salvage goals | Bilateral late-salvage comparator |
| `late_salvage_goals_delta` | Triggered minus opponent late salvage goals | Net late-salvage dominance signal |
| `triggered_team_first_late_salvage_goal_minute` | Base minute of first qualifying salvage goal | Timing anchor for event reconstruction |
| `triggered_team_first_late_salvage_goal_added_time` | Added-time component of first qualifying salvage goal | Stoppage-time precision for auditability |
| `triggered_team_first_late_salvage_goal_effective_minute` | Effective minute (`minute + added_time`) of first qualifying salvage goal | Normalized chronology across regulation and stoppage time |
| `triggered_team_first_late_salvage_goal_type` | Type of first qualifying salvage goal (`tying` or `winning`) | Explains first trigger path semantics |
| `triggered_team_score_before_first_late_salvage_goal` | Triggered-team score immediately before first qualifying salvage goal | Pre-event score-state evidence |
| `opponent_score_before_first_late_salvage_goal` | Opponent score immediately before first qualifying salvage goal | Bilateral pre-event score-state comparator |
| `triggered_team_score_after_first_late_salvage_goal` | Triggered-team score immediately after first qualifying salvage goal | Post-event score-state evidence |
| `opponent_score_after_first_late_salvage_goal` | Opponent score immediately after first qualifying salvage goal | Bilateral post-event score-state comparator |
| `triggered_team_late_salvage_goals_above_threshold` | Count above minimum threshold (`late_salvage_goals - 1`) | Severity ranking beyond binary trigger activation |
| `triggered_team_final_result_points` | Triggered-side final points (`3`, `1`, or `0`) | Outcome severity context for salvage impact |
| `triggered_team_goals_final` | Triggered-side final goals | Final scoring output context |
| `opponent_goals_final` | Opponent final goals | Bilateral final scoring comparator |
| `goal_delta_final` | Triggered-side final goal margin (goals) | Side-relative final outcome edge |
| `triggered_team_total_shots` | Triggered-side total shots | Shot-volume context behind late salvage |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator |
| `total_shots_delta` | Triggered minus opponent total shots | Net shot-pressure differential |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Shooting execution context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral shooting execution comparator |
| `triggered_team_on_target_ratio_pct` | Triggered-side shots-on-target ratio (%) | Side finishing-precision proxy |
| `opponent_on_target_ratio_pct` | Opponent shots-on-target ratio (%) | Bilateral finishing-precision comparator |
| `on_target_ratio_delta_pct` | Triggered minus opponent on-target ratio (percentage points) | Net finishing-precision differential |
| `triggered_team_xg` | Triggered-side expected goals | Chance-quality production context |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-generation edge |
| `triggered_team_big_chances` | Triggered-side big chances | High-quality chance volume context |
| `opponent_big_chances` | Opponent big chances | Bilateral high-value chance comparator |
| `triggered_team_big_chances_missed` | Triggered-side big chances missed | Wastefulness context around salvage phase |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness comparator |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Match-control profile context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Circulation-volume context |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-retention execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral retention comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Net retention/execution differential |
| `triggered_team_corners` | Triggered-side corners | Sustained-pressure proxy |
| `opponent_corners` | Opponent corners | Bilateral pressure comparator |
