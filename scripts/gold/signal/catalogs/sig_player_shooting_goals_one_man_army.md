---
signal_id: sig_player_shooting_goals_one_man_army
status: active
entity: player
family: shooting
subfamily: goals
grain: match_player
headline: "One-Man Army 1-0 Winner"
trigger: "Player scores the only non-own goal for their team in a finished 1-0 win."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_shooting_goals_one_man_army
  sql: clickhouse/gold/dml/signals/player/sig_player_shooting_goals_one_man_army.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_shooting_goals_one_man_army

## Purpose

Detects player-level 1-0 match winners where one player scores the only non-own goal for their team and directly owns the full scoring outcome.

## Tactical And Statistical Logic

- Trigger condition:
  - Match must be finished (`match_finished = 1`).
  - Triggered player's team must finish with exactly one goal and concede zero.
  - Triggered player must score exactly one non-own goal (`is_goal = 1`, `is_own_goal = 0`), which is by definition the team's only goal.
- Match/player grain:
  - Goal events are grouped at `match_id + team_id + player_id` grain.
  - Signal emits one row per qualifying player and preserves first-goal timing plus score-state transition fields.
- Match-context enrichment:
  - Player finishing context comes from `silver.player_match_stat`.
  - Bilateral team/opponent context comes from `silver.period_stat` (`period = 'All'`) and `silver.match`.
- Similarity note:
  - Closest active signal is `sig_player_shooting_goals_winning_impact`.
  - Coexistence decision: keep both active. `winning_impact` covers one-goal wins broadly, while `one_man_army` is a stricter 1-0 single-scorer subset.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_shooting_goals_one_man_army.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_shooting_goals_one_man_army`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_shooting_goals_one_man_army
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for deduplication, lineage, and model features |
| `match_date` | Match date | Football developer: supports temporal analysis of match-winning scorer patterns |
| `home_team_id` | Home team ID | Football developer: fixed fixture orientation for bilateral context |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixed fixture orientation for bilateral context |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Final home goals | Football developer: validates the 1-0 outcome within fixture context |
| `away_score` | Final away goals | Football developer: validates the 1-0 outcome within fixture context |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for match-player grain |
| `triggered_player_id` | Triggered player ID | Football developer: durable player identity for downstream joins |
| `triggered_player_name` | Triggered player name | Football developer: readable player attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player trigger to team context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup anchor |
| `opponent_team_name` | Opponent team name | Football developer: readable opponent context |
| `trigger_threshold_team_goals` | Team-goal threshold used by trigger (`1`) | Football developer: explicit trigger provenance for QA and reproducibility |
| `trigger_threshold_opponent_goals` | Opponent-goal threshold used by trigger (`0`) | Football developer: explicit clean-sheet trigger provenance |
| `trigger_threshold_player_goals` | Player-goal threshold used by trigger (`1`) | Football developer: explicit player-condition provenance |
| `triggered_player_only_team_goals` | Count of non-own goals scored by triggered player for their team | Football developer: core trigger metric for single-scorer verification |
| `triggered_player_first_goal_minute` | Base minute of first qualifying goal | Football developer: timing anchor for tactical sequence reconstruction |
| `triggered_player_first_goal_added_time` | Added-time component of first qualifying goal | Football developer: stoppage-time precision for event-timing diagnostics |
| `triggered_player_first_goal_effective_minute` | Effective first-goal minute (`minute + added_time`) | Football developer: normalized event ordering across regulation/stoppage time |
| `triggered_team_score_before_only_goal` | Triggered-team score immediately before the qualifying goal | Football developer: pre-event score-state context |
| `opponent_score_before_only_goal` | Opponent score immediately before the qualifying goal | Football developer: bilateral pre-event score-state comparator |
| `triggered_team_score_after_only_goal` | Triggered-team score immediately after the qualifying goal | Football developer: post-event state-change auditability |
| `opponent_score_after_only_goal` | Opponent score immediately after the qualifying goal | Football developer: bilateral post-event state-change auditability |
| `triggered_player_goal_contribution_pct` | Triggered player share of team goals (%) | Football developer: direct concentration signal for one-man scoring ownership |
| `triggered_player_goals_above_threshold` | Margin above required player-goal threshold (`goals - 1`) | Football developer: trigger-intensity field for consistent scoring-signal templates |
| `triggered_player_goals` | Total goals scored by triggered player | Football developer: finishing context beyond trigger qualification |
| `triggered_player_expected_goals` | Triggered player expected goals | Football developer: chance-quality baseline behind the decisive output |
| `triggered_player_total_shots` | Triggered player total shots | Football developer: shooting-volume baseline for trigger interpretation |
| `triggered_player_shots_on_target` | Triggered player shots on target | Football developer: execution-quality context |
| `triggered_player_shot_accuracy_pct` | Triggered player shot accuracy (%) | Football developer: finishing precision diagnostic |
| `triggered_player_expected_goals_per_shot` | Triggered player expected goals per shot | Football developer: per-attempt chance-quality context |
| `triggered_player_goal_minus_expected_goals` | Triggered player goals minus expected goals | Football developer: finishing over/under-performance indicator |
| `triggered_player_minutes_played` | Triggered player minutes played | Football developer: exposure context for interpreting impact |
| `triggered_team_goals` | Goals scored by triggered player's team | Football developer: team scoring anchor for trigger validation |
| `opponent_goals` | Goals scored by opponent | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: side-relative result margin context |
| `triggered_team_expected_goals` | Expected goals of triggered side | Football developer: team chance-quality context in the 1-0 profile |
| `opponent_expected_goals` | Expected goals of opponent side | Football developer: bilateral chance-quality comparator |
| `expected_goals_delta` | Triggered-team xG minus opponent xG | Football developer: net chance-quality balance context |
| `triggered_team_total_shots` | Total shots by triggered side | Football developer: team shot-volume context |
| `opponent_total_shots` | Total shots by opponent side | Football developer: bilateral shot-volume comparator |
| `triggered_team_shots_on_target` | Shots on target by triggered side | Football developer: team execution context |
| `opponent_shots_on_target` | Shots on target by opponent side | Football developer: bilateral execution comparator |
| `triggered_team_big_chances` | Big chances by triggered side | Football developer: high-value chance context around low-scoring wins |
| `opponent_big_chances` | Big chances by opponent side | Football developer: bilateral high-value chance comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control-profile context for the match state |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box relative to triggered side | Football developer: bilateral territorial comparator |
| `player_share_of_team_goals_pct` | Triggered player share of team goals (%) | Football developer: standardized concentration feature shared across player-shooting signals |
| `player_share_of_team_expected_goals_pct` | Triggered player share of team expected goals (%) | Football developer: concentration of chance-quality responsibility |
| `player_share_of_team_total_shots_pct` | Triggered player share of team total shots (%) | Football developer: concentration of shooting workload |
