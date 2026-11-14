---
signal_id: sig_match_streak_consistency_card_fest_rivalry
status: active
entity: match
family: streak
subfamily: consistency
grain: match_team
headline: "Card Fest Rivalry"
trigger: "The last 10 meetings of the same two teams averaged >= 6 yellow cards per meeting (this match included)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_streak_consistency_card_fest_rivalry
  sql: clickhouse/gold/dml/signals/match/sig_match_streak_consistency_card_fest_rivalry.sql
---
# sig_match_streak_consistency_card_fest_rivalry

## Purpose

Flags rivalries with a ten-meeting record of heavy booking, a card-market and temperament marker.

## Tactical And Statistical Logic

- Trigger: The last 10 meetings of the same two teams averaged >= 6 yellow cards per meeting (this match included).
- The window is the pair's last 10 consecutive meetings, each with stats. Yellow cards are `yellow_cards_home + yellow_cards_away` in `fotmob_silver.period_stat`. A row is emitted for each match where the 10-meeting window is complete, every meeting has stats and the total is >= 60 (an average of 6 per meeting). The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted. Meetings are every finished match between the same two teams in `fotmob_silver.match`, in any competition and at either venue, ordered by `match_date` then `match_id`. A pair needs the full number of loaded meetings, so the signal can stay empty on a short history.
- Similarity note: Closest: `sig_match_discipline_cards_card_frenzy` (many cards in one match) and `sig_match_streak_consistency_foul_fest_rivalry` (fouls over 5 meetings). Related head-to-head signals: `sig_match_streak_consistency_penalty_fest_rivalry`, `sig_match_streak_consistency_foul_fest_rivalry` and `sig_match_streak_consistency_goal_fest_history`. Different logic: the average of yellow cards over a ten-meeting window. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_streak_consistency_card_fest_rivalry.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_streak_consistency_card_fest_rivalry`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_streak_consistency_card_fest_rivalry
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
| `trigger_threshold_min_window_yellow_cards` | Configured trigger threshold (`60` yellow cards over the last 10 meetings) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_window_yellow_cards` | Yellow cards over the last 10 meetings, including this match | Core signal intensity variable. |
| `streak_matches_above_threshold` | Yellow cards above the trigger floor | Trigger severity beyond binary activation. |
| `streak_start_date` | Date of the first match inside the window | Anchors the window in time for recency and freshness filters. |
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
