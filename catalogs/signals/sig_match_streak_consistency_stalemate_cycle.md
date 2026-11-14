---
signal_id: sig_match_streak_consistency_stalemate_cycle
status: active
entity: match
family: streak
subfamily: consistency
grain: match_team
headline: "Stalemate Cycle"
trigger: "The last >= 4 meetings of the same two teams at this stadium all ended in draws (this match included)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_streak_consistency_stalemate_cycle
  sql: clickhouse/gold/dml/signals/match/sig_match_streak_consistency_stalemate_cycle.sql
---
# sig_match_streak_consistency_stalemate_cycle

## Purpose

Flags matches that extend a run of at least four head-to-head draws at the same stadium, a strong low-scoring and stalemate fixture marker.

## Tactical And Statistical Logic

- Trigger: The last >= 4 meetings of the same two teams at this stadium all ended in draws (this match included).
- Meetings are finished matches between the same two teams (either home or away role) played at the same non-empty `stadium_name`, ordered by date. A draw is `home_score = away_score`; a decisive result resets the run. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match. It needs four loaded meetings at one venue, so it can stay empty on a short history.
- Similarity note: Closest: `sig_match_shooting_goals_boring_stalemate`, `sig_match_discipline_cards_foul_heavy_stalemate` (single-match 0-0 states) and `sig_match_streak_consistency_bogey_team`. Different logic: venue-level draw history. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_streak_consistency_stalemate_cycle.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_streak_consistency_stalemate_cycle`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_streak_consistency_stalemate_cycle
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
| `trigger_threshold_min_drawn_meetings` | Configured minimum streak length (`4` meetings at the venue) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_drawn_meetings_streak` | Length of the current streak, including this match (meetings at the venue) | Core signal intensity variable: how long the venue draw cycle is. |
| `streak_matches_above_threshold` | Streak length minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match of the streak | Anchors the streak in time for recency and freshness filters. |
| `streak_total_goals` | Total goals (both teams) across the drawn meetings | Shows whether the cycle is goalless or high-scoring draws. |
| `stadium_name` | Stadium of the fixture | Names the venue that defines the cycle. |
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
