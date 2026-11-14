---
signal_id: sig_match_discipline_cards_disciplinary_equality
status: active
entity: match
family: discipline
subfamily: cards
grain: match_team
headline: "Disciplinary Equality"
trigger: "Both teams receive exactly 1 red card and exactly 3 yellow cards in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_discipline_cards_disciplinary_equality
  sql: clickhouse/gold/dml/signals/match/sig_match_discipline_cards_disciplinary_equality.sql
---
# sig_match_discipline_cards_disciplinary_equality

## Purpose

Flags a symmetric card record, a fairness and referee-balance marker.

## Tactical And Statistical Logic

- Trigger: Both teams receive exactly 1 red card and exactly 3 yellow cards in a finished match.
- Each side has `yellow_cards = 3` and `red_cards = 1` in `fotmob_silver.period_stat` (`period = 'All'`). The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_match_discipline_cards_double_red_drama` (both teams get a red) and `sig_match_discipline_cards_foul_parity` (equal fouls). Related discipline signals: `sig_match_discipline_cards_card_frenzy`, `sig_match_discipline_cards_clean_fair_play` and `sig_team_discipline_cards_clean_discipline`. Different logic: exactly 3 yellows and 1 red for each side. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_discipline_cards_disciplinary_equality.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_discipline_cards_disciplinary_equality`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_discipline_cards_disciplinary_equality
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
| `trigger_threshold_exact_total_cards` | Configured trigger floor (exactly `8` cards: 3 yellow and 1 red for each side) | Explicit trigger provenance for explainability and QA. |
| `match_total_cards` | Total cards in the match | Core signal intensity variable. |
| `match_total_cards_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
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
