---
signal_id: sig_player_shooting_goals_late_winner_clutch
status: active
entity: player
family: shooting
subfamily: goals
grain: match_player
headline: "Late Winner Clutch"
trigger: "Player scores the decisive non-own winning goal in the 90+ minute in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_shooting_goals_late_winner_clutch
  sql: clickhouse/gold/signal/sig_player_shooting_goals_late_winner_clutch.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_shooting_goals_late_winner_clutch

## Purpose

Detects player-level clutch finishing where a player scores the decisive match-winning non-own goal in 90+ time, with explicit score-state evidence and bilateral match context.

## Tactical And Statistical Logic

- Trigger condition:
  - Goal event is a non-own goal (`is_goal = 1`, `is_own_goal = 0`) by a valid player/team in a finished match.
  - Goal effective minute (`goal_time + goal_overload_time`) is at least `90`.
  - Goal creates a lead for the scorer's side and the side wins the match.
  - No later opponent goal reaches parity or lead, so the late goal remains the decisive winner.
- Match/player grain:
  - Events are grouped at `match_id + team_id + player_id` to emit one row per triggered player per match.
  - First decisive late-winner timing and first before/after score state are preserved.
- Match-context enrichment:
  - Player finishing context comes from `silver.player_match_stat`.
  - Bilateral team/opponent context comes from `silver.period_stat` (`period = 'All'`) and `silver.match`.
- Similarity note:
  - Closest active signals are `sig_player_shooting_goals_clutch_equalizer` and `sig_player_shooting_goals_winning_impact`; this signal is distinct because it requires both 90+ timing and decisive winner persistence after the goal.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_shooting_goals_late_winner_clutch.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_shooting_goals_late_winner_clutch`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_shooting_goals_late_winner_clutch
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join key for lineage and deduplication |
| `match_date` | Match date | Temporal slicing and trend analysis |
| `home_team_id` | Home team ID | Fixed fixture orientation |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team ID | Fixed fixture orientation |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Final home goals | Final outcome context |
| `away_score` | Final away goals | Final outcome context |
| `triggered_side` | Triggered side (`home`/`away`) | Canonical side orientation |
| `triggered_player_id` | Triggered player ID | Durable player identity |
| `triggered_player_name` | Triggered player name | Readable player attribution |
| `triggered_team_id` | Triggered player's team ID | Connects player event to team context |
| `triggered_team_name` | Triggered player's team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup anchor |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `trigger_threshold_min_goal_effective_minute` | Minimum effective minute threshold (`90`) | Explicit trigger provenance |
| `triggered_player_late_winning_goals` | Count of qualifying late decisive winning goals | Core trigger metric |
| `triggered_player_first_late_winning_goal_minute` | Base minute of first qualifying goal | Timing anchor for event reconstruction |
| `triggered_player_first_late_winning_goal_added_time` | Added-time component of first qualifying goal | Stoppage-time precision |
| `triggered_player_first_late_winning_goal_effective_minute` | Effective minute (`minute + added_time`) of first qualifying goal | Normalized sequencing across regulation and stoppage time |
| `triggered_team_score_before_first_late_winning_goal` | Triggered-team score immediately before first qualifying goal | Pre-event score-state context |
| `opponent_score_before_first_late_winning_goal` | Opponent score immediately before first qualifying goal | Bilateral pre-event score comparator |
| `triggered_team_score_after_first_late_winning_goal` | Triggered-team score immediately after first qualifying goal | State-change auditability |
| `opponent_score_after_first_late_winning_goal` | Opponent score immediately after first qualifying goal | Bilateral post-event state context |
| `final_goal_margin` | Final goal margin from triggered-team perspective | Outcome severity context |
| `late_winning_goals_above_threshold` | Margin above minimum trigger count (`count - 1`) | Trigger intensity ranking beyond binary activation |
| `triggered_player_goals` | Triggered player total goals | Finishing output context |
| `triggered_player_expected_goals` | Triggered player total xG | Chance-quality context |
| `triggered_player_total_shots` | Triggered player total shots | Shooting-volume baseline |
| `triggered_player_shots_on_target` | Triggered player shots on target | Shot-execution context |
| `triggered_player_shot_accuracy_pct` | Triggered player shot accuracy percentage | Finishing precision diagnostic |
| `triggered_player_expected_goals_per_shot` | Triggered player xG per shot | Average chance quality per attempt |
| `triggered_player_goal_minus_expected_goals` | Triggered player goals minus xG | Over/under-performance indicator |
| `triggered_player_minutes_played` | Triggered player minutes played | Exposure context |
| `triggered_team_goals` | Triggered-team final goals | Side-relative scoreline context |
| `opponent_goals` | Opponent final goals | Bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Side-relative outcome edge |
| `triggered_team_expected_goals` | Triggered-side xG | Team chance-quality baseline |
| `opponent_expected_goals` | Opponent-side xG | Bilateral chance-quality comparator |
| `expected_goals_delta` | Triggered-side xG minus opponent-side xG | Net chance-quality balance |
| `triggered_team_total_shots` | Triggered-side total shots | Team shooting-volume context |
| `opponent_total_shots` | Opponent-side total shots | Bilateral shooting-volume comparator |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Team execution context |
| `opponent_shots_on_target` | Opponent-side shots on target | Bilateral execution comparator |
| `triggered_team_big_chances` | Triggered-side big chances | High-value chance context |
| `opponent_big_chances` | Opponent-side big chances | Bilateral high-value chance comparator |
| `triggered_team_possession_pct` | Triggered-side possession percentage | Control-profile context |
| `opponent_possession_pct` | Opponent-side possession percentage | Bilateral control comparator |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Territorial penetration context |
| `opponent_touches_opposition_box` | Opponent-side touches in opposition box | Bilateral territorial comparator |
| `player_share_of_team_goals_pct` | Triggered player share of team goals (%) | Concentration of scoring responsibility |
| `player_share_of_team_expected_goals_pct` | Triggered player share of team xG (%) | Concentration of chance-quality responsibility |
| `player_share_of_team_total_shots_pct` | Triggered player share of team shots (%) | Concentration of shooting workload |
