---
signal_id: sig_match_creativity_playmaking_set_piece_creative_war
status: active
entity: match
family: creativity
subfamily: playmaking
grain: match_team
headline: "Set Piece Creative War"
trigger: "A finished match has >= 3 goals that were assisted from set pieces."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_creativity_playmaking_set_piece_creative_war
  sql: clickhouse/gold/dml/signals/match/sig_match_creativity_playmaking_set_piece_creative_war.sql
---
# sig_match_creativity_playmaking_set_piece_creative_war

## Purpose

Flags a dead-ball-assist-heavy match, a delivery-quality marker.

## Tactical And Statistical Logic

- Trigger: A finished match has >= 3 goals that were assisted from set pieces.
- A set-piece assist is a non-own goal row in `fotmob_silver.shot` with an `assist_player_id` and a `situation` of `FromCorner`, `FreeKick`, `SetPiece` or `ThrowInSetPiece`. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_match_creativity_playmaking_set_piece_creative_duel` (each team has at least one set-piece assist) and `sig_player_creativity_playmaking_deadball_wizard`. Related signals: `sig_player_shooting_goals_freekick_master`, `sig_player_shooting_goals_penalty_composure` and `sig_match_shooting_goals_set_piece_duel`. Different logic: three or more set-piece assists in one match, from either team. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_creativity_playmaking_set_piece_creative_war.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_creativity_playmaking_set_piece_creative_war`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_creativity_playmaking_set_piece_creative_war
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
| `triggered_side` | Row orientation (`home` or `away`) | Canonical side identity for match-team grain. |
| `triggered_team_id` | Triggered-side team identifier | Team attribution key for downstream features. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral context. |
| `trigger_threshold_min_set_piece_assisted_goals` | Configured trigger floor (`3` goals assisted from set pieces) | Explicit trigger provenance for explainability and QA. |
| `match_set_piece_assisted_goals` | Goals assisted from set pieces | Core signal intensity variable. |
| `match_set_piece_assisted_goals_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
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
