---
signal_id: sig_player_shooting_goals_first_half_dominator
status: active
entity: player
family: shooting
subfamily: goals
grain: match_player
headline: "First-Half Dominator"
trigger: "Player scores 2+ non-own goals before the half-time whistle in a single finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_shooting_goals_first_half_dominator
  sql: clickhouse/gold/signal/sig_player_shooting_goals_first_half_dominator.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_shooting_goals_first_half_dominator

## Purpose

Flags players who score at least two non-own goals in the first half, isolating matches where one player dominates scoring output before the break.

## Tactical And Statistical Logic

- Trigger condition:
  - Non-own goal events from `silver.shot` where `is_goal = 1`, `is_own_goal = 0`, and `period = 'FirstHalf'`.
  - Player has `triggered_player_first_half_goals >= 2` in the same finished match.
- Timing logic:
  - Event timing uses `goal_time + goal_overload_time` (fallback `minute + minute_added`) to retain stoppage-time precision inside first-half boundaries.
  - Earliest and latest first-half goal timings are preserved for tempo and sequence analysis.
- Match-context enrichment:
  - Player finishing context comes from `silver.player_match_stat` (goals, xG, shots, shots on target, minutes).
  - Bilateral team/opponent context comes from `silver.period_stat` (`period = 'All'`) and final score context from `silver.match`.
  - Additional first-half team scoring context comes from first-half non-own `silver.shot` goal aggregates for triggered team and opponent.
- Similarity note:
  - Closest active signals are `sig_player_shooting_goals_hat_trick_hero` and `sig_player_shooting_goals_rapid_brace`.
  - This signal is intentionally distinct because it targets half-time timing dominance (`FirstHalf`, `>= 2` goals) rather than full-match high-volume output (`>= 3`) or short-window burst pacing (`<= 10` minutes).

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_shooting_goals_first_half_dominator.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_shooting_goals_first_half_dominator`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_shooting_goals_first_half_dominator
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key and row lineage anchor |
| `match_date` | Match date | Football developer: temporal slicing and trend analysis |
| `home_team_id` | Home team ID | Football developer: fixed bilateral fixture orientation |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixed bilateral fixture orientation |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Full-time home goals | Football developer: final score context for first-half dominance interpretation |
| `away_score` | Full-time away goals | Football developer: final score context for first-half dominance interpretation |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation at match-player grain |
| `triggered_player_id` | Triggered player ID | Football developer: durable player identity key |
| `triggered_player_name` | Triggered player name | Football developer: readable player attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: binds trigger to team context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup anchor |
| `opponent_team_name` | Opponent team name | Football developer: readable opponent context |
| `trigger_threshold_min_first_half_goals` | Minimum first-half goals required by trigger (`2`) | Football developer: explicit trigger provenance for reproducibility and QA |
| `trigger_threshold_goal_period` | Goal-period constraint used by trigger (`FirstHalf`) | Football developer: explicit temporal boundary for signal activation |
| `triggered_player_first_half_goals` | Count of player's qualifying first-half non-own goals | Football developer: core trigger metric |
| `triggered_player_first_half_goal_share_of_match_goals_pct` | Share of player's total match goals scored in first half (%) | Football developer: concentration diagnostic for front-loaded finishing impact |
| `triggered_player_first_half_first_goal_minute` | Base minute of triggered player's first qualifying first-half goal | Football developer: timing anchor for sequence reconstruction |
| `triggered_player_first_half_first_goal_added_time` | Added-time component of player's first qualifying first-half goal | Football developer: stoppage-time precision for first-half timing audit |
| `triggered_player_first_half_first_goal_effective_minute` | Effective minute (`minute + added_time`) of first qualifying first-half goal | Football developer: normalized timing key across regulation and stoppage phases |
| `triggered_player_first_half_last_goal_minute` | Base minute of triggered player's last qualifying first-half goal | Football developer: captures burst window closure before half-time |
| `triggered_player_first_half_last_goal_added_time` | Added-time component of player's last qualifying first-half goal | Football developer: stoppage-time precision for sequence end |
| `triggered_player_first_half_last_goal_effective_minute` | Effective minute (`minute + added_time`) of last qualifying first-half goal | Football developer: normalized end-of-burst timing reference |
| `goals_above_threshold` | Margin above trigger threshold (`first_half_goals - 2`) | Football developer: severity ranking beyond binary activation |
| `triggered_player_goals` | Total goals scored by triggered player in the match | Football developer: full-match finishing context around first-half dominance |
| `triggered_player_expected_goals` | Expected goals generated by triggered player in match | Football developer: chance-quality denominator for finishing interpretation |
| `triggered_player_total_shots` | Total shots attempted by triggered player | Football developer: player shooting-volume baseline |
| `triggered_player_shots_on_target` | Shots on target by triggered player | Football developer: shot execution context |
| `triggered_player_shot_accuracy_pct` | Shot accuracy percentage of triggered player | Football developer: finishing precision diagnostic |
| `triggered_player_expected_goals_per_shot` | Expected goals per shot by triggered player | Football developer: average chance quality per attempt |
| `triggered_player_goal_minus_expected_goals` | Goals minus expected goals for triggered player | Football developer: over/under-performance finishing indicator |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure context for interpreting output magnitude |
| `triggered_team_first_half_non_own_goals` | Triggered-team non-own goals in first half | Football developer: team-level first-half scoring backdrop around player trigger |
| `opponent_first_half_non_own_goals` | Opponent non-own goals in first half | Football developer: bilateral first-half scoring comparator |
| `first_half_non_own_goal_delta` | Triggered-team first-half non-own goals minus opponent first-half non-own goals | Football developer: side-relative first-half scoreboard pressure context |
| `triggered_team_goals` | Full-time goals by triggered player's team | Football developer: side-relative final scoring context |
| `opponent_goals` | Full-time goals by opponent team | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: side-relative final outcome edge |
| `triggered_team_expected_goals` | Expected goals by triggered side | Football developer: team chance-quality baseline around trigger |
| `opponent_expected_goals` | Expected goals by opponent side | Football developer: bilateral chance-quality comparator |
| `expected_goals_delta` | Triggered-team expected goals minus opponent expected goals | Football developer: net chance-quality control context |
| `triggered_team_total_shots` | Total shots by triggered side | Football developer: team shooting-volume baseline |
| `opponent_total_shots` | Total shots by opponent side | Football developer: bilateral shooting-volume comparator |
| `triggered_team_shots_on_target` | Shots on target by triggered side | Football developer: team shot-execution context |
| `opponent_shots_on_target` | Shots on target by opponent side | Football developer: bilateral shot-execution comparator |
| `triggered_team_big_chances` | Big chances created by triggered side | Football developer: high-value chance context around first-half scoring control |
| `opponent_big_chances` | Big chances created by opponent side | Football developer: bilateral high-value chance comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control-profile context for tactical interpretation |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box relative to triggered side | Football developer: bilateral territorial comparator |
| `player_share_of_team_goals_pct` | Triggered player's share of team goals (%) | Football developer: concentration of finishing responsibility |
| `player_share_of_team_expected_goals_pct` | Triggered player's share of team expected goals (%) | Football developer: concentration of chance-quality responsibility |
| `player_share_of_team_total_shots_pct` | Triggered player's share of team total shots (%) | Football developer: concentration of shooting workload |
