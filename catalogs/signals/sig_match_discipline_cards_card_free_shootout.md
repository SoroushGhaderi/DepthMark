---
signal_id: sig_match_discipline_cards_card_free_shootout
status: active
entity: match
family: discipline
subfamily: cards
grain: match_team
headline: "Card Free Shootout"
trigger: "A finished match has >= 30 combined shots and >= 5 goals but no cards."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_discipline_cards_card_free_shootout
  sql: clickhouse/gold/dml/signals/match/sig_match_discipline_cards_card_free_shootout.sql
---
# sig_match_discipline_cards_card_free_shootout

## Purpose

Flags an open and clean match, an entertainment and fair-play marker.

## Tactical And Statistical Logic

- Trigger: A finished match has >= 30 combined shots and >= 5 goals but no cards.
- Combined shots are `total_shots_home + total_shots_away`, goals are the final score and cards are all yellow and red cards in `fotmob_silver.period_stat` (`period = 'All'`). The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_match_discipline_cards_clean_fair_play` (<= 12 fouls and no cards) and `sig_match_shooting_goals_goal_fest` (>= 6 goals). Related discipline signals: `sig_match_discipline_cards_card_frenzy`, `sig_match_discipline_cards_clean_fair_play` and `sig_team_discipline_cards_clean_discipline`. Different logic: lots of shots and goals with zero cards. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_discipline_cards_card_free_shootout.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_discipline_cards_card_free_shootout`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_discipline_cards_card_free_shootout
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
| `trigger_threshold_min_goals` | Configured trigger floor (`5` goals and 30 shots with 0 cards) | Explicit trigger provenance for explainability and QA. |
| `match_goals` | Goals in the match | Core signal intensity variable. |
| `match_goals_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `match_total_shots` | Combined shots in the match | Shot-volume context. |
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
