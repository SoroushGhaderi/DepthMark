---
signal_id: sig_player_shooting_goals_first_minute_goal
status: active
entity: player
family: shooting
subfamily: goals
grain: match_player
headline: "First-Minute Goal"
trigger: "Player scores a non-own goal within the first 60 seconds (minute-level proxy: goal_minute <= 1 and added_time = 0) in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_shooting_goals_first_minute_goal
  sql: clickhouse/gold/dml/signals/player/sig_player_shooting_goals_first_minute_goal.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_player_shooting_goals_first_minute_goal

## Purpose

Flags players who score immediately after kickoff, surfacing matches where a player delivers
instant attacking impact and changes game state in the opening minute.

## Tactical And Statistical Logic

- Trigger condition:
  - Non-own goal events from `silver.shot` where `is_goal = 1`, `is_own_goal = 0`, `period = 'FirstHalf'`.
  - First-minute proxy uses minute-granularity timing: `goal_minute <= 1` and `goal_added_time = 0`.
  - Player has `triggered_player_first_minute_goals >= 1` in the same finished match.
- Timing logic:
  - Effective minute uses `goal_time + goal_overload_time` (fallback `minute + minute_added`) for deterministic ordering.
  - First and last qualifying first-minute goal timings are retained for chronology and QA.
- Match-context enrichment:
  - Player shooting context comes from `silver.player_match_stat`.
  - Bilateral team/opponent context comes from `silver.period_stat` (`period = 'All'`) and final score from `silver.match`.
  - Symmetric first-minute team-goal context is added via triggered-side/opponent first-minute non-own goal aggregates.
- Similarity note:
  - Closest active signals are `sig_player_shooting_goals_first_half_dominator` and `sig_player_shooting_goals_rapid_brace`.
  - This signal is distinct because it activates on immediate single-goal timing (`<= 1` minute proxy), not multi-goal half dominance or short-window brace pacing.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_shooting_goals_first_minute_goal.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_player_shooting_goals_first_minute_goal`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_player_shooting_goals_first_minute_goal
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable row identity and join key |
| `match_date` | Match date | Football developer: trend slicing and event chronology |
| `home_team_id` | Home team ID | Football developer: bilateral fixture anchor |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: bilateral fixture anchor |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Full-time home goals | Football developer: outcome context around immediate-goal events |
| `away_score` | Full-time away goals | Football developer: outcome context around immediate-goal events |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation at player grain |
| `triggered_player_id` | Triggered player ID | Football developer: durable player identity key |
| `triggered_player_name` | Triggered player name | Football developer: readable player attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: binds player trigger to team context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup anchor |
| `opponent_team_name` | Opponent team name | Football developer: readable opponent context |
| `trigger_threshold_min_first_minute_goals` | Minimum qualifying goals required by trigger (`1`) | Football developer: explicit trigger provenance |
| `trigger_threshold_max_goal_minute` | Maximum base minute accepted by trigger (`1`) | Football developer: first-minute proxy boundary auditability |
| `trigger_threshold_max_goal_added_time` | Maximum added-time component accepted by trigger (`0`) | Football developer: excludes stoppage-time contamination in first-minute proxy |
| `triggered_player_first_minute_goals` | Count of player's qualifying first-minute non-own goals | Football developer: core trigger metric |
| `triggered_player_first_minute_goal_share_of_match_goals_pct` | Share of player's match goals scored in first minute (%) | Football developer: concentration diagnostic for immediate-impact finishing |
| `triggered_player_first_minute_first_goal_minute` | Base minute of earliest qualifying first-minute goal | Football developer: sequence start anchor |
| `triggered_player_first_minute_first_goal_added_time` | Added-time component of earliest qualifying first-minute goal | Football developer: timing QA precision |
| `triggered_player_first_minute_first_goal_effective_minute` | Effective minute of earliest qualifying first-minute goal | Football developer: normalized chronological key |
| `triggered_player_first_minute_last_goal_minute` | Base minute of latest qualifying first-minute goal | Football developer: sequence closure anchor in rare multi-goal first-minute cases |
| `triggered_player_first_minute_last_goal_added_time` | Added-time component of latest qualifying first-minute goal | Football developer: timing QA precision |
| `triggered_player_first_minute_last_goal_effective_minute` | Effective minute of latest qualifying first-minute goal | Football developer: deterministic chronology and replay alignment |
| `goals_above_threshold` | Margin above trigger (`first_minute_goals - 1`) | Football developer: severity ranking beyond binary activation |
| `triggered_player_goals` | Total goals scored by triggered player | Football developer: full-match scoring context around early strike |
| `triggered_player_expected_goals` | Player expected goals in match | Football developer: chance-quality context for the trigger |
| `triggered_player_total_shots` | Player total shots in match | Football developer: shooting-volume baseline |
| `triggered_player_shots_on_target` | Player shots on target in match | Football developer: shot execution context |
| `triggered_player_shot_accuracy_pct` | Player shot accuracy (%) | Football developer: precision diagnostic |
| `triggered_player_expected_goals_per_shot` | Player expected goals per shot | Football developer: average chance profile per attempt |
| `triggered_player_goal_minus_expected_goals` | Goals minus expected goals for triggered player | Football developer: finishing over/under-performance signal |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure context |
| `triggered_team_first_minute_non_own_goals` | Triggered-side non-own goals in first minute | Football developer: team-level immediate scoring backdrop |
| `opponent_first_minute_non_own_goals` | Opponent non-own goals in first minute | Football developer: bilateral immediate-scoring comparator |
| `first_minute_non_own_goal_delta` | Triggered-side minus opponent first-minute non-own goals | Football developer: net immediate-pressure differential |
| `triggered_team_goals` | Full-time goals by triggered player's team | Football developer: side-relative final scoring context |
| `opponent_goals` | Full-time goals by opponent team | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: side-relative final outcome edge |
| `triggered_team_expected_goals` | Triggered-side expected goals | Football developer: team chance-quality baseline |
| `opponent_expected_goals` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `expected_goals_delta` | Triggered-team expected goals minus opponent expected goals | Football developer: net chance-quality control context |
| `triggered_team_total_shots` | Triggered-side total shots | Football developer: team shot-volume context |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral shot-volume comparator |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Football developer: team execution context |
| `opponent_shots_on_target` | Opponent shots on target | Football developer: bilateral execution comparator |
| `triggered_team_big_chances` | Triggered-side big chances | Football developer: high-value chance context |
| `opponent_big_chances` | Opponent big chances | Football developer: bilateral high-value chance comparator |
| `triggered_team_possession_pct` | Triggered-side possession percentage | Football developer: control profile around immediate-goal trigger |
| `opponent_possession_pct` | Opponent possession percentage | Football developer: bilateral control comparator |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Football developer: bilateral territorial comparator |
| `player_share_of_team_goals_pct` | Triggered player's share of team goals (%) | Football developer: concentration of scoring responsibility |
| `player_share_of_team_expected_goals_pct` | Triggered player's share of team expected goals (%) | Football developer: concentration of chance-quality responsibility |
| `player_share_of_team_total_shots_pct` | Triggered player's share of team total shots (%) | Football developer: concentration of shooting workload |
