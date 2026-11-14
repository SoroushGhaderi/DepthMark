---
signal_id: sig_team_discipline_cards_zero_card_clean_sheet
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Zero Card Clean Sheet"
trigger: "Team keeps a clean sheet and receives no cards in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_discipline_cards_zero_card_clean_sheet
  sql: clickhouse/gold/dml/signals/team/sig_team_discipline_cards_zero_card_clean_sheet.sql
---
# sig_team_discipline_cards_zero_card_clean_sheet

## Purpose

Flags a shutout without a single card, a defensive-discipline marker.

## Tactical And Statistical Logic

- Trigger: Team keeps a clean sheet and receives no cards in a finished match.
- A clean sheet is `goals_against = 0` and the team has no yellow or red cards in `fotmob_silver.period_stat`. The measure is the number of shots on target the opponent had. Stats come from `fotmob_silver.period_stat` (`period = 'All'`).
- Similarity note: Closest: `sig_team_discipline_cards_clean_sheet_aggression` (a clean sheet with >= 5 yellows; the opposite) and `sig_team_discipline_cards_clean_discipline` (0 cards and <= 7 fouls).

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_discipline_cards_zero_card_clean_sheet.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_discipline_cards_zero_card_clean_sheet`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_discipline_cards_zero_card_clean_sheet
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
| `trigger_threshold_max_cards` | Configured trigger ceiling (`0` cards, clean sheet) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_opponent_shots_on_target_faced` | Shots on target the team faced | Shows how much pressure the clean sheet survived. |
| `triggered_team_fouls` | Fouls committed by the team | Foul volume. |
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
