---
signal_id: sig_match_streak_consistency_goalless_first_half_rivalry
status: active
entity: match
family: streak
subfamily: consistency
grain: match_team
headline: "Goalless First Half Rivalry"
trigger: "The last >= 4 meetings of the same two teams were all goalless at half-time (this match included)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_streak_consistency_goalless_first_half_rivalry
  sql: clickhouse/gold/dml/signals/match/sig_match_streak_consistency_goalless_first_half_rivalry.sql
---
# sig_match_streak_consistency_goalless_first_half_rivalry

## Purpose

Flags rivalries where the first half stays goalless meeting after meeting, a slow-start and first-half-under marker.

## Tactical And Statistical Logic

- Trigger: The last >= 4 meetings of the same two teams were all goalless at half-time (this match included).
- A goalless-half meeting has no goal rows with `goal_time <= 45` in `fotmob_silver.shot`, and the number of goal rows equals `home_score + away_score`, so a match with incomplete goal data cannot count. A first-half goal resets the run. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match. Meetings are every finished match between the same two teams in `fotmob_silver.match`, in any competition and at either venue, ordered by `match_date` then `match_id`. Stats come from `fotmob_silver.period_stat` (`period = 'All'`) and goal or penalty facts from `fotmob_silver.shot`; a meeting without the needed data breaks the run. A pair needs the full number of loaded meetings, so the signal can stay empty on a short history.
- Similarity note: Closest: `sig_match_possession_passing_early_tactical_lock` (no shots on target in the first 30 minutes of one match) and `sig_match_shooting_goals_game_of_two_halves`. Different grain: half-time scores across the meetings of one pair. Related head-to-head signals: `sig_match_streak_consistency_goal_fest_history`, `sig_match_streak_consistency_nil_nil_curse` and `sig_match_streak_consistency_stalemate_cycle`. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_streak_consistency_goalless_first_half_rivalry.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_streak_consistency_goalless_first_half_rivalry`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_streak_consistency_goalless_first_half_rivalry
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
| `trigger_threshold_min_consecutive_goalless_half_meetings` | Configured minimum streak length (`4` meetings) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_goalless_half_meetings_streak` | Length of the current streak, including this match (meetings) | Core signal intensity variable: how long the goalless-first-half history is. |
| `streak_matches_above_threshold` | Streak length minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match of the streak | Anchors the streak in time for recency and freshness filters. |
| `streak_total_goals` | Total goals (both teams) across the meetings in the run | Shows the goal volume behind the head-to-head run. |
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
