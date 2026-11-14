---
signal_id: sig_match_discipline_cards_high_tension_draw
status: active
entity: match
family: discipline
subfamily: cards
grain: match_team
headline: "High Tension Draw"
trigger: "A finished match ends 1-1 with >= 8 yellow cards and exactly 1 red card."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_discipline_cards_high_tension_draw
  sql: clickhouse/gold/dml/signals/match/sig_match_discipline_cards_high_tension_draw.sql
---
# sig_match_discipline_cards_high_tension_draw

## Purpose

Flags a heated 1-1 draw with a sending-off, a tension and card-market marker.

## Tactical And Statistical Logic

- Trigger: A finished match ends 1-1 with >= 8 yellow cards and exactly 1 red card.
- The final score is 1-1, `yellow_cards_home + yellow_cards_away >= 8` and `red_cards_home + red_cards_away = 1` in `fotmob_silver.period_stat` (`period = 'All'`). The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_match_discipline_cards_card_frenzy` (>= 10 cards in any match) and `sig_match_discipline_cards_heated_derby_stats`. Related discipline signals: `sig_match_discipline_cards_card_frenzy`, `sig_match_discipline_cards_clean_fair_play` and `sig_team_discipline_cards_clean_discipline`. Different logic: a 1-1 draw with 8+ yellows and one red. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_discipline_cards_high_tension_draw.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_discipline_cards_high_tension_draw`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_discipline_cards_high_tension_draw
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
| `trigger_threshold_min_yellow_cards` | Configured trigger floor (`8` yellow cards in a 1-1 draw with one red) | Explicit trigger provenance for explainability and QA. |
| `match_yellow_cards` | Yellow cards in the match | Core signal intensity variable. |
| `match_yellow_cards_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `match_red_cards` | Red cards in the match | Confirms the single sending-off. |
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
