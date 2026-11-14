---
signal_id: sig_player_creativity_playmaking_clutch_set_piece_delivery
status: active
entity: player
family: creativity
subfamily: playmaking
grain: match_player
headline: "Clutch Set Piece Delivery"
trigger: "Player provides the assist for a goal at minute 90 or later that came from a dead ball in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_creativity_playmaking_clutch_set_piece_delivery
  sql: clickhouse/gold/dml/signals/player/sig_player_creativity_playmaking_clutch_set_piece_delivery.sql
---
# sig_player_creativity_playmaking_clutch_set_piece_delivery

## Purpose

Flags a stoppage-time dead-ball assist, a clutch-delivery marker.

## Tactical And Statistical Logic

- Trigger: Player provides the assist for a goal at minute 90 or later that came from a dead ball in a finished match.
- An assist is a non-own goal row in `fotmob_silver.shot` whose `assist_player_id` is the player, with an effective minute (`goal_time` plus `goal_overload_time`) of 90 or more and a `situation` of `FromCorner`, `FreeKick`, `SetPiece` or `ThrowInSetPiece`.
- Similarity note: Closest: `sig_player_creativity_playmaking_deadball_wizard` (>= 2 corner assists) and `sig_player_creativity_playmaking_clutch_vision` (an assist for a decisive goal after 85). Related creativity signals: `sig_player_creativity_playmaking_maestro_output`, `sig_player_creativity_playmaking_isolated_creativity` and `sig_player_creativity_playmaking_clutch_vision`. Different logic: a dead-ball assist in minute 90 or later, whatever the score. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_creativity_playmaking_clutch_set_piece_delivery.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_creativity_playmaking_clutch_set_piece_delivery`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_creativity_playmaking_clutch_set_piece_delivery
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable match key for joins and QA. |
| `match_date` | Match date | Temporal slicing and partition compatibility. |
| `home_team_id` | Home team identifier | Fixture orientation anchor. |
| `home_team_name` | Home team name | Readable fixture context. |
| `away_team_id` | Away team identifier | Fixture orientation anchor. |
| `away_team_name` | Away team name | Readable fixture context. |
| `home_score` | Full-time home goals | Outcome context for the streak match. |
| `away_score` | Full-time away goals | Outcome context for the streak match. |
| `triggered_side` | Side of the player's team (`home` or `away`) | Canonical side identity. |
| `triggered_player_id` | Triggered player identifier | Player attribution key (row identity). |
| `triggered_player_name` | Triggered player name | Readable player context. |
| `triggered_team_id` | Player's team identifier | Team context key (row identity). |
| `triggered_team_name` | Player's team name | Readable team context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral context. |
| `trigger_threshold_min_goal_minute` | Configured trigger floor (assisted goal at minute `90` or later from a dead ball) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_set_piece_assists_in_stoppage_time` | Dead-ball assists at minute 90 or later | Core signal intensity variable. |
| `triggered_player_set_piece_assists_in_stoppage_time_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_player_first_assist_minute` | Effective minute of the earliest qualifying goal | Timing of the assist. |
| `triggered_player_minutes_played` | Minutes played in this match | Playing-time context for the trigger. |
| `triggered_team_goals` | Triggered-side goals in the match | Result context for the streak match. |
| `opponent_goals` | Opponent goals in the match | Bilateral result comparator. |
| `triggered_team_xg` | Triggered-side expected goals (xG) | Chance-quality and control context behind the streak result. |
| `opponent_xg` | Opponent expected goals (xG) | Bilateral comparator for the same match. |
| `triggered_team_total_shots` | Triggered-side total shots | Chance-quality and control context behind the streak result. |
| `opponent_total_shots` | Opponent total shots | Bilateral comparator for the same match. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Chance-quality and control context behind the streak result. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral comparator for the same match. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Chance-quality and control context behind the streak result. |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral comparator for the same match. |
