---
signal_id: sig_player_shooting_goals_clutch_brace_winning
status: active
entity: player
family: shooting
subfamily: goals
grain: match_player
headline: "Clutch Brace Winner"
trigger: "Player scores at least one equalizer and the decisive winning goal in the same finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_shooting_goals_clutch_brace_winning
  sql: clickhouse/gold/dml/signals/player/sig_player_shooting_goals_clutch_brace_winning.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_shooting_goals_clutch_brace_winning

## Purpose

Detects high-leverage player brace patterns where the same player first restores parity and later scores the decisive winner in a finished match.

## Tactical And Statistical Logic

- Trigger condition:
  - Match must be finished with a winner.
  - Triggered player has at least one non-own equalizer event (`home_score_after = away_score_after`).
  - Triggered player also has the decisive non-own winning goal event (goal creates a lead that the opponent never cancels to parity/lead afterward).
  - Equalizer event occurs earlier than decisive winner event for the same `match_id + team_id + player_id`.
- Match/player grain:
  - Rows are emitted at `match_id + team_id + player_id` for players satisfying both events in the same match.
  - First equalizer and first decisive-winner timing/score-state snapshots are preserved for sequence reconstruction.
- Match-context enrichment:
  - Player finishing metrics come from `silver.player_match_stat`.
  - Bilateral team/opponent context comes from `silver.match` and `silver.period_stat` (`period = 'All'`).
- Similarity gate note:
  - Closest active signals are `sig_player_shooting_goals_clutch_equalizer`, `sig_player_shooting_goals_late_winner_clutch`, and `sig_player_shooting_goals_rapid_brace`.
  - This signal is distinct because it requires both a score-restoring equalizer and a later decisive winner by the same player in the same match (not just one of those behaviors in isolation, and without a 90+ timing dependency).

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_shooting_goals_clutch_brace_winning.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_shooting_goals_clutch_brace_winning`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_shooting_goals_clutch_brace_winning
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join key for lineage and deduplication |
| `match_date` | Match date | Temporal slicing and trend analysis |
| `home_team_id` | Home team ID | Fixed bilateral fixture orientation |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team ID | Fixed bilateral fixture orientation |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Final home goals | Final outcome context |
| `away_score` | Final away goals | Final outcome context |
| `triggered_side` | Side of triggered player (`home`/`away`) | Canonical side orientation |
| `triggered_player_id` | Triggered player ID | Durable player identity |
| `triggered_player_name` | Triggered player name | Readable player attribution |
| `triggered_team_id` | Triggered player's team ID | Connects player event to team context |
| `triggered_team_name` | Triggered player's team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup anchor |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `trigger_threshold_min_equalizer_goals` | Minimum equalizer-count threshold (`1`) | Explicit trigger provenance for QA |
| `trigger_threshold_min_decisive_winning_goals` | Minimum decisive-winner-count threshold (`1`) | Explicit trigger provenance for QA |
| `triggered_player_equalizer_goals` | Count of qualifying equalizer goals by triggered player | Core trigger component: parity restoration |
| `triggered_player_decisive_winning_goals` | Count of qualifying decisive winning goals by triggered player | Core trigger component: decisive winning action |
| `triggered_player_first_equalizer_minute` | Base minute of first qualifying equalizer | Sequence reconstruction anchor |
| `triggered_player_first_equalizer_added_time` | Added-time component of first qualifying equalizer | Stoppage-time precision |
| `triggered_player_first_equalizer_effective_minute` | Effective minute (`minute + added_time`) of first qualifying equalizer | Normalized event ordering |
| `triggered_player_first_decisive_winning_goal_minute` | Base minute of first qualifying decisive winner | Sequence reconstruction anchor |
| `triggered_player_first_decisive_winning_goal_added_time` | Added-time component of first qualifying decisive winner | Stoppage-time precision |
| `triggered_player_first_decisive_winning_goal_effective_minute` | Effective minute (`minute + added_time`) of first qualifying decisive winner | Normalized event ordering |
| `triggered_team_score_before_first_equalizer` | Triggered-team score before first qualifying equalizer | Confirms pre-equalizer trailing state |
| `opponent_score_before_first_equalizer` | Opponent score before first qualifying equalizer | Bilateral pre-equalizer comparator |
| `triggered_team_score_after_first_equalizer` | Triggered-team score after first qualifying equalizer | Audits parity restoration |
| `opponent_score_after_first_equalizer` | Opponent score after first qualifying equalizer | Audits parity restoration |
| `triggered_team_score_before_first_decisive_winning_goal` | Triggered-team score before first qualifying decisive winner | Pre-decisive-goal score-state context |
| `opponent_score_before_first_decisive_winning_goal` | Opponent score before first qualifying decisive winner | Bilateral pre-decisive-goal comparator |
| `triggered_team_score_after_first_decisive_winning_goal` | Triggered-team score after first qualifying decisive winner | Audits lead-creation state change |
| `opponent_score_after_first_decisive_winning_goal` | Opponent score after first qualifying decisive winner | Audits lead-creation state change |
| `minutes_between_first_equalizer_and_first_decisive_winning_goal` | Effective-minute gap between first equalizer and first decisive winner | Measures sequence compression and clutch turnaround speed |
| `final_goal_margin` | Final goal margin from triggered-team perspective | Outcome-severity context |
| `triggered_player_goals` | Total goals by triggered player in the match | Overall finishing output context |
| `triggered_player_expected_goals` | Total expected goals by triggered player | Chance-quality context |
| `triggered_player_total_shots` | Total shots by triggered player | Shooting-volume baseline |
| `triggered_player_shots_on_target` | Shots on target by triggered player | Shot-execution context |
| `triggered_player_shot_accuracy_pct` | Shot accuracy percentage by triggered player | Finishing precision diagnostic |
| `triggered_player_expected_goals_per_shot` | Expected goals per shot for triggered player | Average chance quality per attempt |
| `triggered_player_goal_minus_expected_goals` | Goals minus expected goals for triggered player | Over/under-performance indicator |
| `triggered_player_minutes_played` | Minutes played by triggered player | Exposure context |
| `triggered_team_goals` | Final goals of triggered player's team | Side-relative scoreline context |
| `opponent_goals` | Final goals of opponent team | Bilateral scoreline comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Side-relative final outcome edge |
| `triggered_team_expected_goals` | Expected goals of triggered side | Team chance-quality baseline |
| `opponent_expected_goals` | Expected goals of opponent side | Bilateral chance-quality comparator |
| `expected_goals_delta` | Triggered-side expected goals minus opponent-side expected goals | Net chance-quality balance context |
| `triggered_team_total_shots` | Total shots by triggered side | Team shooting-volume context |
| `opponent_total_shots` | Total shots by opponent side | Bilateral shooting-volume comparator |
| `triggered_team_shots_on_target` | Shots on target by triggered side | Team shot-execution context |
| `opponent_shots_on_target` | Shots on target by opponent side | Bilateral shot-execution comparator |
| `triggered_team_big_chances` | Big chances by triggered side | High-value chance context |
| `opponent_big_chances` | Big chances by opponent side | Bilateral high-value chance comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Control-profile context |
| `opponent_possession_pct` | Possession percentage of opponent side | Bilateral control comparator |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Territorial penetration context |
| `opponent_touches_opposition_box` | Opponent-side touches in opposition box | Bilateral territorial comparator |
| `player_share_of_team_goals_pct` | Triggered player share of team goals (%) | Concentration of scoring responsibility |
| `player_share_of_team_expected_goals_pct` | Triggered player share of team expected goals (%) | Concentration of chance-quality responsibility |
| `player_share_of_team_total_shots_pct` | Triggered player share of team shots (%) | Concentration of shooting workload |
