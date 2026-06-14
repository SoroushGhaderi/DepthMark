---
signal_id: sig_player_creativity_playmaking_clutch_vision
status: active
entity: player
family: creativity
subfamily: playmaking
grain: match_player
headline: "Clutch Vision"
trigger: "Player provides the assisted pass for a decisive non-own winning goal after the 85th minute in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_creativity_playmaking_clutch_vision
  sql: clickhouse/gold/dml/signals/player/sig_player_creativity_playmaking_clutch_vision.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_creativity_playmaking_clutch_vision

## Purpose

Detects player-level clutch playmaking where a player supplies the assist for a decisive winning non-own goal scored after the 85th minute.

## Tactical And Statistical Logic

- Trigger conditions:
  - Goal event is a non-own goal (`is_goal = 1`, `is_own_goal = 0`) in a finished match.
  - Goal effective minute (`goal_time + goal_overload_time`) is at least `86` (after the 85th minute).
  - Goal is assisted (`assist_player_id > 0`) by the triggered player.
  - Goal creates a lead for that side, that side wins the match, and no later opponent goal restores parity or lead.
- Match/player grain:
  - Events are grouped at `match_id + team_id + assist_player_id` to emit one row per triggered playmaker per match.
  - First decisive assist timing and before/after score state are retained for auditability.
- Match-context enrichment:
  - Player passing/creation context comes from `silver.player_match_stat`.
  - Bilateral opponent/team context comes from `silver.period_stat` (`period = 'All'`) and `silver.match`.
- Similarity gate note:
  - Closest active signals are `sig_player_shooting_goals_late_winner_clutch`, `sig_player_creativity_playmaking_assist_brace`, and `sig_player_shooting_goals_winning_impact`.
  - Coexistence rationale: this signal is intentionally assist-centric and late-decisive by event timing; it complements scorer-centric clutch signals and non-temporal assist-volume signals.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_creativity_playmaking_clutch_vision.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_creativity_playmaking_clutch_vision`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_creativity_playmaking_clutch_vision
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join and deduplication key |
| `match_date` | Match date | Temporal slicing and reproducible backfills |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Final outcome context |
| `away_score` | Away full-time goals | Final outcome context |
| `triggered_side` | Triggered side (`home`/`away`) | Canonical side orientation |
| `triggered_player_id` | Triggered player ID | Durable player identity |
| `triggered_player_name` | Triggered player name | Readable player attribution |
| `triggered_team_id` | Triggered player's team ID | Player-team linkage |
| `triggered_team_name` | Triggered player's team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup anchor |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `trigger_threshold_min_goal_effective_minute` | Minimum effective-minute trigger (`86`) | Explicit trigger provenance |
| `triggered_player_late_winning_goal_assists` | Count of qualifying decisive late winning assists | Core trigger intensity |
| `triggered_player_first_late_winning_goal_assist_minute` | Base minute of first qualifying assisted winner | Timing anchor for event reconstruction |
| `triggered_player_first_late_winning_goal_assist_added_time` | Added-time component of first qualifying assisted winner | Stoppage-time precision |
| `triggered_player_first_late_winning_goal_assist_effective_minute` | Effective minute of first qualifying assisted winner | Normalized timing for ordering and QA |
| `triggered_team_score_before_first_late_winning_goal_assist` | Triggered-team score before first qualifying assisted winner | Pre-event score-state context |
| `opponent_score_before_first_late_winning_goal_assist` | Opponent score before first qualifying assisted winner | Bilateral pre-event comparator |
| `triggered_team_score_after_first_late_winning_goal_assist` | Triggered-team score after first qualifying assisted winner | State-change auditability |
| `opponent_score_after_first_late_winning_goal_assist` | Opponent score after first qualifying assisted winner | Bilateral post-event comparator |
| `final_goal_margin` | Final goal margin from triggered-team perspective | Outcome-severity context |
| `late_winning_goal_assists_above_threshold` | Margin above minimum trigger count (`count - 1`) | Trigger ranking beyond binary activation |
| `triggered_player_assists` | Triggered player total assists | Playmaking outcome context |
| `triggered_player_chances_created` | Triggered player total chances created | Creation-volume context |
| `triggered_player_expected_assists` | Triggered player xA | Chance-quality context |
| `triggered_player_assist_minus_expected_assists` | Assists minus xA | Outcome-versus-expected interpretation |
| `triggered_player_passes_final_third` | Triggered player final-third passes | Territorial progression context |
| `triggered_player_touches_opposition_box` | Triggered player touches in opposition box | Advanced-zone involvement context |
| `triggered_player_accurate_passes` | Triggered player accurate passes | Passing execution context |
| `triggered_player_total_passes` | Triggered player pass attempts | Passing workload context |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy (%) | Passing reliability diagnostic |
| `triggered_player_minutes_played` | Triggered player minutes played | Exposure context |
| `triggered_player_touches` | Triggered player total touches | Overall involvement context |
| `triggered_team_goals` | Triggered-team full-time goals | Team output context |
| `opponent_goals` | Opponent full-time goals | Bilateral output comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Net outcome edge |
| `triggered_team_expected_goals` | Triggered-side xG | Team chance-quality baseline |
| `opponent_expected_goals` | Opponent-side xG | Bilateral chance-quality comparator |
| `expected_goals_delta` | Triggered-side xG minus opponent-side xG | Net chance-quality balance |
| `triggered_team_big_chances` | Triggered-side big chances | Team high-value chance context |
| `opponent_big_chances` | Opponent-side big chances | Bilateral high-value chance comparator |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Team circulation baseline |
| `opponent_pass_attempts` | Opponent-side pass attempts | Bilateral circulation comparator |
| `triggered_team_accurate_passes` | Triggered-side accurate passes | Team passing-quality baseline |
| `opponent_accurate_passes` | Opponent-side accurate passes | Bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Team execution context |
| `opponent_pass_accuracy_pct` | Opponent-side pass accuracy (%) | Bilateral execution comparator |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Team control-state context |
| `opponent_possession_pct` | Opponent-side possession (%) | Bilateral control-state comparator |
| `triggered_team_touches_opposition_box` | Triggered-side opposition-box touches | Team territorial pressure context |
| `opponent_touches_opposition_box` | Opponent-side opposition-box touches | Bilateral territorial-pressure comparator |
| `player_share_of_team_assists_pct` | Triggered player share of team goals assisted (%) | Concentration of direct scoring creation contribution |
| `player_share_of_team_chances_created_pct` | Triggered player share of team chances created (%) | Concentration of chance-creation workload |
| `player_share_of_team_passes_pct` | Triggered player share of team pass attempts (%) | Concentration of circulation responsibility |
