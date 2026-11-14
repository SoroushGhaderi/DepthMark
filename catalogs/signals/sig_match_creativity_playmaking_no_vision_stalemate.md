---
signal_id: sig_match_creativity_playmaking_no_vision_stalemate
status: active
entity: match
family: creativity
subfamily: playmaking
grain: match_team
headline: "No Vision Stalemate"
trigger: "Combined match xA is below 0.40 in a finished match with full player data."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_creativity_playmaking_no_vision_stalemate
  sql: clickhouse/gold/dml/signals/match/sig_match_creativity_playmaking_no_vision_stalemate.sql
---
# sig_match_creativity_playmaking_no_vision_stalemate

## Purpose

Flags extremely poor creativity from both teams, an under-goals and dull-match marker.

## Tactical And Statistical Logic

- Trigger: Combined match xA is below 0.40 in a finished match with full player data.
- Combined xA is the sum of `expected_assists` of all players with minutes in `fotmob_silver.player_match_stat`. The match needs at least 18 player rows, so missing player data cannot make a match look dull. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_match_creativity_playmaking_zero_flair_stalemate` (a 0-0 with no dribbles) and `sig_match_shooting_goals_boring_stalemate` (combined xG below 0.5). Related creativity signals: `sig_team_creativity_playmaking_chance_barrage`, `sig_team_creativity_playmaking_midfield_engine_vision` and `sig_match_creativity_playmaking_the_creativity_clash`. Different logic: combined xA below 0.40. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_creativity_playmaking_no_vision_stalemate.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_creativity_playmaking_no_vision_stalemate`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_creativity_playmaking_no_vision_stalemate
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
| `trigger_threshold_max_combined_xa` | Configured trigger ceiling (combined xA below `0.4`) | Explicit trigger provenance for explainability and QA. |
| `match_combined_xa` | Combined expected assists in the match | Core signal intensity variable. |
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
