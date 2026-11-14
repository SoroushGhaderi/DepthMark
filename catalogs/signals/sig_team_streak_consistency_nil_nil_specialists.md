---
signal_id: sig_team_streak_consistency_nil_nil_specialists
status: active
entity: team
family: streak
subfamily: consistency
grain: match_team
headline: "Nil-Nil Specialists"
trigger: "Team plays >= 2 consecutive 0-0 draws (this match included)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_streak_consistency_nil_nil_specialists
  sql: clickhouse/gold/dml/signals/team/sig_team_streak_consistency_nil_nil_specialists.sql
---
# sig_team_streak_consistency_nil_nil_specialists

## Purpose

Flags back-to-back 0-0 results, a marker of a sterile attack and a tight defence.

## Tactical And Statistical Logic

- Trigger: Team plays >= 2 consecutive 0-0 draws (this match included).
- A goalless draw is `goals_for = 0` and `goals_against = 0`. The sequence is every finished match of the team in `fotmob_silver.match` (all loaded competitions), ordered by `match_date` then `match_id`. One row is emitted for each match where the running streak length is >= 2. Only loaded matches count, so a short history can shorten a real streak.
- Similarity note: Closest: `sig_team_streak_consistency_draw_specialist` (any draws, 4 matches) and `sig_team_streak_consistency_scoring_drought` (no goals scored, 3 matches). Different measure: exact 0-0. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_streak_consistency_nil_nil_specialists.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_streak_consistency_nil_nil_specialists`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_streak_consistency_nil_nil_specialists
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
| `trigger_threshold_min_consecutive_nil_nil_draws` | Configured minimum streak length (`2` matches) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_nil_nil_streak_matches` | Length of the current streak, including this match (matches) | Core signal intensity variable: how long the 0-0 run is. |
| `streak_matches_above_threshold` | Streak length minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match of the streak | Anchors the streak in time for recency and freshness filters. |
| `triggered_team_streak_wins` | Wins inside the streak | Shows whether the streak is made of wins or draws. |
| `triggered_team_streak_draws` | Draws inside the streak | Shows how much of the streak is stalemates. |
| `triggered_team_streak_goals_scored` | Goals scored across the streak | Attacking output behind the streak. |
| `triggered_team_streak_goals_conceded` | Goals conceded across the streak | Defensive record behind the streak. |
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
