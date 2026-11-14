---
signal_id: sig_match_discipline_cards_first_half_red
status: active
entity: match
family: discipline
subfamily: cards
grain: match_team
headline: "First Half Red"
trigger: "A finished match features a red card within the first 15 minutes."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_discipline_cards_first_half_red
  sql: clickhouse/gold/dml/signals/match/sig_match_discipline_cards_first_half_red.sql
---
# sig_match_discipline_cards_first_half_red

## Purpose

Flags a red card in the opening quarter hour, a tactical-reset and live-market marker.

## Tactical And Statistical Logic

- Trigger: A finished match features a red card within the first 15 minutes.
- A red card is a row in `fotmob_silver.card` whose `card_type` or `description` contains `red`, with `card_minute <= 15`. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_player_discipline_cards_early_bath` (a player's red at minute 20 or earlier) and `sig_match_discipline_cards_double_red_drama`. Related discipline signals: `sig_team_discipline_cards_collective_aggression`, `sig_player_discipline_cards_late_red_drama` and `sig_player_discipline_cards_captain_reprimand`. Different entity and logic: a match-level flag for a red card in the first 15 minutes. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_discipline_cards_first_half_red.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_discipline_cards_first_half_red`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_discipline_cards_first_half_red
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
| `trigger_threshold_max_red_card_minute` | Configured trigger floor (red card at minute `15` or earlier) | Explicit trigger provenance for explainability and QA. |
| `match_early_red_cards` | Red cards in the first 15 minutes | Core signal intensity variable. |
| `match_early_red_cards_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `match_first_red_card_minute` | Minute of the earliest red card | Timing of the dismissal. |
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
