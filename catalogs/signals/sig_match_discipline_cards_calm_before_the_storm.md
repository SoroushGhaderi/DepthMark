---
signal_id: sig_match_discipline_cards_calm_before_the_storm
status: active
entity: match
family: discipline
subfamily: cards
grain: match_team
headline: "Calm Before The Storm"
trigger: "A finished match has no cards in the first half and >= 6 cards in the second half."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_discipline_cards_calm_before_the_storm
  sql: clickhouse/gold/dml/signals/match/sig_match_discipline_cards_calm_before_the_storm.sql
---
# sig_match_discipline_cards_calm_before_the_storm

## Purpose

Flags a sudden second-half card wave, a temperament-shift and live-card-market marker.

## Tactical And Statistical Logic

- Trigger: A finished match has no cards in the first half and >= 6 cards in the second half.
- Cards come from `fotmob_silver.card`: first half is `card_minute <= 45`, second half is `card_minute > 45`. Yellow and red cards both count. The measure is the second-half card count. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_match_discipline_cards_boiling_over` (>= 4 cards after minute 80) and `sig_match_discipline_cards_card_frenzy` (>= 10 cards in total). Related discipline signals: `sig_match_discipline_cards_card_frenzy`, `sig_match_discipline_cards_clean_fair_play` and `sig_team_discipline_cards_clean_discipline`. Different logic: a card-free first half followed by a card-heavy second half. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_discipline_cards_calm_before_the_storm.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_discipline_cards_calm_before_the_storm`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_discipline_cards_calm_before_the_storm
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
| `trigger_threshold_min_second_half_cards` | Configured trigger floor (`6` second-half cards after a card-free first half) | Explicit trigger provenance for explainability and QA. |
| `match_second_half_cards` | Cards shown in the second half | Core signal intensity variable. |
| `match_second_half_cards_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `match_first_half_cards` | Cards shown in the first half | Confirms the quiet first half. |
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
