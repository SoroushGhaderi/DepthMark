---
signal_id: sig_player_streak_consistency_penalty_specialist
status: active
entity: player
family: streak
subfamily: consistency
grain: match_player
headline: "Penalty Specialist"
trigger: "Player has scored his last >= 5 penalties in a row (this match included)."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_streak_consistency_penalty_specialist
  sql: clickhouse/gold/dml/signals/player/sig_player_streak_consistency_penalty_specialist.sql
---
# sig_player_streak_consistency_penalty_specialist

## Purpose

Flags a perfect run from the spot, a reliable-taker marker for penalty and goalscorer markets.

## Tactical And Statistical Logic

- Trigger: Player has scored his last >= 5 penalties in a row (this match included).
- Penalties are shot rows in `fotmob_silver.shot` whose `situation` contains `penalty` (shoot-outs excluded), ordered per player by date, match, minute and `shot_id`. A scored penalty has `is_goal = 1`; a miss or a save resets the run. The run counts the player's own penalties, so matches without a penalty do not break it. One row is emitted for each match where the run reaches >= 5 at the player's last penalty. Five penalties need a long history, so this can stay empty on a short history.
- Similarity note: Closest: `sig_player_discipline_cards_penalty_conceder` (penalties conceded) and `sig_team_streak_consistency_penalty_luck` (team penalties awarded). No existing penalty-taker conversion signal. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_streak_consistency_penalty_specialist.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_streak_consistency_penalty_specialist`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_streak_consistency_penalty_specialist
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
| `trigger_threshold_min_consecutive_penalties_scored` | Configured minimum run length (`5` penalties) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_penalties_scored_streak` | Length of the current run at the player's last event in this match (penalties) | Core signal intensity variable: how many penalties in a row were scored. |
| `streak_matches_above_threshold` | Run length minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first event of the run | Anchors the run in time for recency and freshness filters. |
| `triggered_player_events_in_match` | Penalties the player took in this match | Context for how many qualifying events the player had in this match. |
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
