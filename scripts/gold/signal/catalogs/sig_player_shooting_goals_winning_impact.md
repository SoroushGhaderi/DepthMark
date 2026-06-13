---
signal_id: sig_player_shooting_goals_winning_impact
status: active
entity: player
family: shooting
subfamily: goals
grain: match_player
headline: "Decisive One-Goal Winner"
trigger: "Player scores the decisive non-own winning goal in a finished match that ends with a 1-goal margin."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_shooting_goals_winning_impact
  sql: clickhouse/gold/signal/sig_player_shooting_goals_winning_impact.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_shooting_goals_winning_impact

## Purpose

Detects player-level match-winning finishing events where the triggered player scores the decisive winning goal and the final scoreline margin is exactly one goal.

## Tactical And Statistical Logic

- Trigger condition:
  - Goal event is a non-own goal (`is_goal = 1`, `is_own_goal = 0`) by a valid player/team.
  - Triggered player's team wins the match by exactly one goal (`abs(home_score - away_score) = 1`).
  - Goal is decisive for that one-goal win, meaning removing that goal from the winner would drop the final result from win to draw.
- Match/player grain:
  - Candidate decisive events are grouped at `match_id + team_id + player_id` to emit one row per triggered player per match.
  - First decisive-goal timing and before/after score state are preserved for auditability and downstream sequence modeling.
- Match-context enrichment:
  - Player finishing context is sourced from `silver.player_match_stat` (goals, expected goals, shots, shots on target, shot accuracy proxy, minutes).
  - Bilateral team/opponent context is sourced from `silver.period_stat` (`period = 'All'`) and `silver.match`.
- Similarity note:
  - Closest active signal is `sig_player_shooting_goals_clutch_equalizer`; this signal is distinct because it targets decisive winning contribution in one-goal victories, not late parity restoration.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_shooting_goals_winning_impact.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_shooting_goals_winning_impact`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_shooting_goals_winning_impact
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key for feature assembly, lineage, and deduplication |
| `match_date` | Match date | Football developer: temporal slicing and trend analysis for decisive scorers |
| `home_team_id` | Home team ID | Football developer: fixed fixture orientation for bilateral context |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixed fixture orientation for bilateral context |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Final home goals | Football developer: final score context for one-goal win validation |
| `away_score` | Final away goals | Football developer: final score context for one-goal win validation |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation for match-player grain |
| `triggered_player_id` | Triggered player ID | Football developer: durable player identity for joins and model features |
| `triggered_player_name` | Triggered player name | Football developer: readable player attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: ties player trigger to team-level context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup anchor |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral matchup context |
| `trigger_threshold_goal_margin` | Goal-margin threshold implied by trigger (`1`) | Football developer: explicit trigger provenance for QA and reproducibility |
| `trigger_threshold_min_decisive_winning_goals` | Minimum decisive-winning-goal count required (`1`) | Football developer: explicit trigger auditability |
| `triggered_player_decisive_winning_goals` | Count of decisive winning goals by triggered player in the match | Football developer: core trigger metric and potential multi-event intensity |
| `triggered_player_first_decisive_goal_minute` | Base minute of first decisive winning goal | Football developer: event-timing anchor for tactical reconstruction |
| `triggered_player_first_decisive_goal_added_time` | Added-time component of first decisive winning goal | Football developer: stoppage-time precision for timing diagnostics |
| `triggered_player_first_decisive_goal_effective_minute` | Effective minute (`minute + added_time`) of first decisive winning goal | Football developer: normalized sequencing across regulation and stoppage time |
| `triggered_team_score_before_first_decisive_goal` | Triggered-team score immediately before first decisive winning goal | Football developer: pre-event score-state context for causal interpretation |
| `opponent_score_before_first_decisive_goal` | Opponent score immediately before first decisive winning goal | Football developer: bilateral pre-event score-state comparator |
| `triggered_team_score_after_first_decisive_goal` | Triggered-team score immediately after first decisive winning goal | Football developer: explicit state-change auditability |
| `opponent_score_after_first_decisive_goal` | Opponent score immediately after first decisive winning goal | Football developer: explicit bilateral post-event auditability |
| `final_goal_margin` | Final goal margin from triggered team perspective | Football developer: verifies one-goal-win constraint directly in output |
| `decisive_winning_goals_above_threshold` | Margin above minimum decisive-winning-goal threshold (`count - 1`) | Football developer: trigger-intensity ranking beyond binary activation |
| `triggered_player_goals` | Total goals scored by triggered player | Football developer: finishing context beyond decisive event itself |
| `triggered_player_expected_goals` | Total expected goals by triggered player | Football developer: chance-quality baseline behind decisive contribution |
| `triggered_player_total_shots` | Total shots attempted by triggered player | Football developer: shooting-volume baseline for triggered player |
| `triggered_player_shots_on_target` | Shots on target by triggered player | Football developer: execution-quality context for finishing output |
| `triggered_player_shot_accuracy_pct` | Triggered player shot accuracy percentage | Football developer: finishing precision diagnostic |
| `triggered_player_expected_goals_per_shot` | Triggered player expected goals per shot | Football developer: average chance quality per attempt |
| `triggered_player_goal_minus_expected_goals` | Triggered player goals minus expected goals | Football developer: over/under-performance finishing indicator |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure context for interpreting decisiveness |
| `triggered_team_goals` | Final goals of triggered player's team | Football developer: team scoring context tied to triggered player |
| `opponent_goals` | Final goals of opponent team | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: side-relative outcome edge in the triggered match |
| `triggered_team_expected_goals` | Expected goals of triggered side | Football developer: team chance-quality baseline around winning event |
| `opponent_expected_goals` | Expected goals of opponent side | Football developer: bilateral chance-quality comparator |
| `expected_goals_delta` | Triggered-team expected goals minus opponent expected goals | Football developer: net chance-quality balance context |
| `triggered_team_total_shots` | Total shots by triggered side | Football developer: team shooting-volume context |
| `opponent_total_shots` | Total shots by opponent side | Football developer: bilateral shooting-volume comparator |
| `triggered_team_shots_on_target` | Shots on target by triggered side | Football developer: team shot-execution context |
| `opponent_shots_on_target` | Shots on target by opponent side | Football developer: bilateral execution comparator |
| `triggered_team_big_chances` | Big chances created by triggered side | Football developer: high-value chance context around winning-goal profile |
| `opponent_big_chances` | Big chances created by opponent side | Football developer: bilateral high-value chance comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control-profile context for decisive-finishing environments |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Football developer: territorial penetration context for winner profile |
| `opponent_touches_opposition_box` | Opponent touches in opposition box relative to triggered side | Football developer: bilateral territorial comparator |
| `player_share_of_team_goals_pct` | Triggered player share of team goals (%) | Football developer: concentration of scoring responsibility |
| `player_share_of_team_expected_goals_pct` | Triggered player share of team expected goals (%) | Football developer: concentration of chance-quality responsibility |
| `player_share_of_team_total_shots_pct` | Triggered player share of team total shots (%) | Football developer: concentration of shooting workload |
