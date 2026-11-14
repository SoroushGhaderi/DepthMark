---
signal_id: sig_match_streak_consistency_bogey_team
status: active
entity: match
family: streak
subfamily: consistency
grain: match_team
headline: "Bogey Team"
trigger: "Triggered team has not beaten the opponent in >= 8 consecutive meetings (this match included)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_streak_consistency_bogey_team
  sql: clickhouse/gold/dml/signals/match/sig_match_streak_consistency_bogey_team.sql
---
# sig_match_streak_consistency_bogey_team

## Purpose

Flags fixtures where one team still cannot beat a specific opponent after at least eight meetings, a classic psychological and betting narrative.

## Tactical And Statistical Logic

- Trigger: Triggered team has not beaten the opponent in >= 8 consecutive meetings (this match included).
- Meetings are every finished match between the two teams in `fotmob_silver.match`, in any competition and either venue, ordered by date. From the triggered team's side a meeting is winless when `goals_for <= goals_against`. The streak resets when the team wins. One row per side is emitted for each match where that side's winless run against the opponent is >= 8, so both rows appear only in a long run of draws. A pair needs at least eight meetings in the loaded history, so this signal can stay empty on a short history.
- Similarity note: No existing head-to-head history signal. Closest: `sig_match_discipline_cards_heated_derby_stats` (single match). No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_streak_consistency_bogey_team.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_streak_consistency_bogey_team`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_streak_consistency_bogey_team
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
| `trigger_threshold_min_winless_meetings` | Configured minimum streak length (`8` meetings) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_winless_meetings_streak` | Length of the current streak, including this match (meetings) | Core signal intensity variable: how long the head-to-head drought is. |
| `streak_matches_above_threshold` | Streak length minus the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match of the streak | Anchors the streak in time for recency and freshness filters. |
| `triggered_team_streak_draws` | Draws inside the winless run | Separates draw-heavy droughts from heavy defeats. |
| `triggered_team_streak_defeats` | Defeats inside the winless run | Shows how badly the opponent dominates the fixture. |
| `triggered_team_streak_goals_scored` | Goals scored against this opponent in the run | Attacking output in the fixture. |
| `triggered_team_streak_goals_conceded` | Goals conceded to this opponent in the run | Defensive record in the fixture. |
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
