---
signal_id: sig_player_shooting_goals_clutch_equalizer
status: active
entity: player
family: shooting
subfamily: goals
grain: match_player
headline: "Clutch Equalizer"
trigger: "Player scores a tying non-own goal after the 85th minute in a single finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_shooting_goals_clutch_equalizer
  sql: clickhouse/gold/dml/signals/player/sig_player_shooting_goals_clutch_equalizer.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_shooting_goals_clutch_equalizer

## Purpose

Detects player-level clutch scoring moments where a player restores parity late (`> 85`) with a non-own goal, preserving timing evidence plus bilateral team context.

## Tactical And Statistical Logic

- Trigger condition:
  - Non-own goal (`is_goal = 1`, `is_own_goal = 0`) from `silver.shot`.
  - Goal occurs after the 85th minute (`goal_time > 85`).
  - Goal is an equalizer (`home_score_after = away_score_after`).
- Match/player grain:
  - Equalizer events are grouped to `match_id + team_id + player_id` to emit one row per triggered player per match.
  - First and last late-equalizer timing features are retained for sequence analysis in rare multi-event matches.
- Match-context enrichment:
  - Player finishing context comes from `silver.player_match_stat` (goals, xG, shot volume, shot accuracy proxy, minutes).
  - Bilateral team/opponent context comes from `silver.period_stat` (`period = 'All'`) and `silver.match`.
- Similarity note:
  - Closest active signals are `sig_player_shooting_goals_hat_trick_hero` and `sig_player_shooting_goals_long_range_specialist`; this signal is distinct because it is specifically state-change and late-timing driven (equalizing after minute 85), not pure volume/location scoring output.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_shooting_goals_clutch_equalizer.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_shooting_goals_clutch_equalizer`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_shooting_goals_clutch_equalizer
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins, deduplication, and lineage |
| `match_date` | Match date | Football developer: temporal slicing and clutch-event trend tracking |
| `home_team_id` | Home team ID | Football developer: fixed bilateral fixture orientation |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team ID | Football developer: fixed bilateral fixture orientation |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Full-time home goals | Football developer: final outcome context around late equalizer events |
| `away_score` | Full-time away goals | Football developer: final outcome context around late equalizer events |
| `triggered_side` | Side of triggered player (`home` or `away`) | Football developer: canonical side orientation at match-player grain |
| `triggered_player_id` | Triggered player ID | Football developer: durable player identity key |
| `triggered_player_name` | Triggered player name | Football developer: readable player attribution |
| `triggered_team_id` | Team ID of triggered player | Football developer: links player trigger to team context |
| `triggered_team_name` | Team name of triggered player | Football developer: readable team attribution |
| `opponent_team_id` | Opponent team ID | Football developer: bilateral matchup anchor |
| `opponent_team_name` | Opponent team name | Football developer: readable bilateral context |
| `trigger_threshold_min_goal_minute` | Minimum goal minute threshold implied by trigger (`86`) | Football developer: explicit trigger provenance for QA and reproducibility |
| `triggered_player_late_equalizer_goals` | Count of qualifying late equalizer goals by triggered player | Football developer: core trigger metric |
| `triggered_player_first_late_equalizer_minute` | Base minute of first qualifying late equalizer by triggered player | Football developer: timing anchor for event reconstruction |
| `triggered_player_first_late_equalizer_added_time` | Added-time component of first qualifying late equalizer | Football developer: stoppage-time precision for clutch timing |
| `triggered_player_first_late_equalizer_effective_minute` | Effective minute (`minute + added_time`) of first qualifying late equalizer | Football developer: normalized temporal ordering across regulation and stoppage time |
| `triggered_player_last_late_equalizer_minute` | Base minute of last qualifying late equalizer by triggered player | Football developer: sequence extent when multiple qualifying events exist |
| `triggered_player_last_late_equalizer_effective_minute` | Effective minute (`minute + added_time`) of last qualifying late equalizer | Football developer: final clutch-event timing reference |
| `triggered_team_score_before_first_late_equalizer` | Triggered-team score immediately before first qualifying late equalizer | Football developer: confirms pre-goal deficit state before parity restoration |
| `opponent_score_before_first_late_equalizer` | Opponent score immediately before first qualifying late equalizer | Football developer: bilateral pre-goal score-state comparator |
| `triggered_team_score_after_first_late_equalizer` | Triggered-team score immediately after first qualifying late equalizer | Football developer: explicit state-change auditability |
| `opponent_score_after_first_late_equalizer` | Opponent score immediately after first qualifying late equalizer | Football developer: explicit equalized-state auditability |
| `late_equalizer_goals_above_threshold` | Margin above minimum required equalizer count (`late_equalizer_goals - 1`) | Football developer: trigger-intensity grading beyond binary activation |
| `triggered_player_goals` | Total goals scored by triggered player in the match | Football developer: broader finishing output context beyond qualifying events |
| `triggered_player_expected_goals` | Total expected goals by triggered player in the match | Football developer: chance-quality context behind raw scoring output |
| `triggered_player_total_shots` | Total shots attempted by triggered player | Football developer: player shooting-volume baseline |
| `triggered_player_shots_on_target` | Shots on target by triggered player | Football developer: player shot-execution context |
| `triggered_player_shot_accuracy_pct` | Shot accuracy percentage of triggered player | Football developer: finishing precision diagnostic |
| `triggered_player_expected_goals_per_shot` | Expected goals per shot for triggered player | Football developer: average chance-quality per attempt |
| `triggered_player_goal_minus_expected_goals` | Goals minus expected goals for triggered player | Football developer: over/under-performance finishing signal |
| `triggered_player_minutes_played` | Minutes played by triggered player | Football developer: exposure context for interpreting event intensity |
| `triggered_team_goals` | Full-time goals of triggered player's team | Football developer: side-relative scoreline context |
| `opponent_goals` | Full-time goals of opponent team | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: side-relative final outcome edge |
| `triggered_team_expected_goals` | Expected goals of triggered side | Football developer: team chance-quality baseline around clutch event |
| `opponent_expected_goals` | Expected goals of opponent side | Football developer: bilateral chance-quality comparator |
| `expected_goals_delta` | Triggered-team expected goals minus opponent expected goals | Football developer: net chance-quality control context |
| `triggered_team_total_shots` | Total shots by triggered side | Football developer: team shooting-volume baseline |
| `opponent_total_shots` | Total shots by opponent side | Football developer: bilateral shooting-volume comparator |
| `triggered_team_shots_on_target` | Shots on target by triggered side | Football developer: team shot-execution context |
| `opponent_shots_on_target` | Shots on target by opponent side | Football developer: bilateral execution comparator |
| `triggered_team_big_chances` | Big chances created by triggered side | Football developer: high-value chance context around equalizer event |
| `opponent_big_chances` | Big chances created by opponent side | Football developer: bilateral high-value chance comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Football developer: control-profile context for clutch equalizer environment |
| `opponent_possession_pct` | Possession percentage of opponent side | Football developer: bilateral control comparator |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box relative to triggered side | Football developer: bilateral territorial comparator |
| `player_share_of_team_goals_pct` | Triggered player share of team goals (%) | Football developer: concentration of scoring responsibility |
| `player_share_of_team_expected_goals_pct` | Triggered player share of team expected goals (%) | Football developer: concentration of chance-quality responsibility |
| `player_share_of_team_total_shots_pct` | Triggered player share of team total shots (%) | Football developer: concentration of shooting workload |
