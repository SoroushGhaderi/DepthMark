---
signal_id: sig_player_goalkeeping_defense_reflex_save_streak
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Reflex Save Streak"
trigger: "Goalkeeper records >= 3 saves in a rolling 5-minute window in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_reflex_save_streak
  sql: clickhouse/gold/signal/sig_player_goalkeeping_defense_reflex_save_streak.sql
  runner: scripts/gold/signal/runners/sig_player_goalkeeping_defense_reflex_save_streak.py
---
# sig_player_goalkeeping_defense_reflex_save_streak

## Purpose

Flags goalkeeper shot-stopping bursts where a keeper strings together at least three saves inside a
five-minute rolling window, surfacing reflex-heavy defensive moments rather than only full-match totals.

## Tactical And Statistical Logic

- Trigger condition:
  - Save event is counted from `silver.shot` with:
    - `keeper_id = triggered_player_id`
    - `is_on_target = 1`
    - `is_goal = 0`
  - Trigger fires when a keeper has `COUNT(shot_id) >= 3` in any rolling 5-minute effective-minute window.
- Window timing uses event effective minute (`minute + minute_added`, fallback `goal_time + goal_overload_time`) to keep deterministic chronology through stoppage time.
- If multiple windows qualify for a keeper in one match, SQL keeps the strongest window (`max saves`), then earliest start minute as deterministic tie-break.
- Match-level keeper totals and player-match context (`minutes`, `touches`, `passing`) are retained for severity interpretation and downstream modeling.
- Bilateral pressure/control context is included via `silver.period_stat` plus same-window opponent keeper pressure counts.
- Similarity gate note: closest active signal is `sig_player_goalkeeping_defense_brick_wall`; this signal intentionally coexists because `brick_wall` is full-match volume (`>=8` saves) while this signal is short-window reflex density (`>=3` saves in 5 minutes).

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_goalkeeping_defense_reflex_save_streak.sql`
- Runner: `scripts/gold/signal/runners/sig_player_goalkeeping_defense_reflex_save_streak.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_reflex_save_streak`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_goalkeeping_defense_reflex_save_streak.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable join key for downstream assets |
| `match_date` | Match date | Time slicing and reproducible backfills |
| `home_team_id` | Home team ID | Fixture context anchor |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team ID | Fixture context anchor |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Full-time home goals | Scoreline context for save streak interpretation |
| `away_score` | Full-time away goals | Scoreline context for save streak interpretation |
| `triggered_side` | Triggered keeper side (`home`/`away`) | Canonical side orientation at player grain |
| `triggered_player_id` | Triggered goalkeeper ID | Durable player identity |
| `triggered_player_name` | Triggered goalkeeper name | Readable attribution |
| `triggered_team_id` | Triggered goalkeeper team ID | Player-to-team linkage |
| `triggered_team_name` | Triggered goalkeeper team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `trigger_threshold_saves_in_window` | Save threshold (`3`) | Explicit trigger provenance |
| `trigger_threshold_rolling_window_minutes` | Rolling window size (`5`) | Explicit rule boundary for QA |
| `triggered_player_saves_in_trigger_window` | Saves inside selected trigger window | Core trigger intensity metric |
| `trigger_window_start_effective_minute` | Trigger-window start effective minute | Deterministic temporal anchor |
| `trigger_window_end_effective_minute` | Trigger-window end effective minute | Explicit window boundary |
| `triggered_player_first_save_in_trigger_window_effective_minute` | Earliest save minute inside selected window | Validates onset of reflex streak |
| `triggered_player_last_save_in_trigger_window_effective_minute` | Latest save minute inside selected window | Captures streak closure timing |
| `triggered_player_qualifying_save_windows_count` | Number of qualifying (`>=3`) windows for player in match | Persistence/intensity grading beyond one window |
| `triggered_player_window_margin_saves` | Saves above threshold in selected window | Trigger severity margin |
| `triggered_player_saves_match` | Full-match saves by triggered goalkeeper | Full-match workload context |
| `triggered_player_shots_on_target_faced_match` | Full-match on-target shots faced by triggered goalkeeper | Save-rate denominator context |
| `triggered_player_goals_conceded_match` | Full-match goals conceded from on-target shots | Outcome severity context |
| `triggered_player_save_rate_match_pct` | Full-match save rate (%) | Efficiency context for volume |
| `triggered_player_minutes_played` | Minutes played by triggered goalkeeper | Exposure reliability context |
| `triggered_player_touches` | Triggered goalkeeper touches | Involvement context |
| `triggered_player_total_passes` | Triggered goalkeeper pass attempts | Distribution-load context |
| `triggered_player_accurate_passes` | Triggered goalkeeper accurate passes | Distribution execution context |
| `triggered_player_pass_accuracy_pct` | Triggered goalkeeper pass accuracy (%) | Composure under pressure context |
| `triggered_team_saves_in_trigger_window` | Triggered-side saves in the same selected window | Window-level defensive workload for triggered side |
| `opponent_saves_in_trigger_window` | Opponent-side saves in the same selected window | Bilateral window workload comparator |
| `triggered_team_shots_on_target_faced_in_trigger_window` | Triggered-side on-target shots faced in selected window | Window-level pressure denominator |
| `opponent_shots_on_target_faced_in_trigger_window` | Opponent-side on-target shots faced in selected window | Bilateral pressure denominator comparator |
| `triggered_team_goals_conceded_in_trigger_window` | Triggered-side goals conceded in selected window | Window outcome severity |
| `opponent_goals_conceded_in_trigger_window` | Opponent-side goals conceded in selected window | Bilateral window outcome comparator |
| `triggered_team_keeper_saves` | Full-match keeper saves for triggered side | Team-level validation of keeper workload |
| `opponent_keeper_saves` | Full-match keeper saves for opponent side | Bilateral goalkeeper workload comparator |
| `triggered_team_total_shots_faced` | Full-match total shots faced by triggered side | Broader pressure volume context |
| `opponent_total_shots_faced` | Full-match total shots faced by opponent side | Bilateral pressure volume comparator |
| `triggered_team_shots_on_target_faced` | Full-match on-target shots faced by triggered side | Team-level on-target pressure baseline |
| `opponent_shots_on_target_faced` | Full-match on-target shots faced by opponent side | Bilateral on-target pressure comparator |
| `triggered_team_expected_goals_faced` | Full-match xG against triggered side | Chance-quality-against context |
| `opponent_expected_goals_faced` | Full-match xG against opponent side | Bilateral chance-quality-against comparator |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-state context |
| `opponent_possession_pct` | Opponent-side possession (%) | Bilateral control comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Team execution context |
| `opponent_pass_accuracy_pct` | Opponent-side pass accuracy (%) | Bilateral execution comparator |
