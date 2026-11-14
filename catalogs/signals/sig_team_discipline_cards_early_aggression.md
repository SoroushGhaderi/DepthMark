---
signal_id: sig_team_discipline_cards_early_aggression
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Early Aggression"
trigger: "Team receives >= 2 yellow cards in the first 20 minutes of a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_discipline_cards_early_aggression
  sql: clickhouse/gold/dml/signals/team/sig_team_discipline_cards_early_aggression.sql
---
# sig_team_discipline_cards_early_aggression

## Purpose

Flags a fast booking run, an early-aggression and referee-strictness marker.

## Tactical And Statistical Logic

- Trigger: Team receives >= 2 yellow cards in the first 20 minutes of a finished match.
- Yellow cards are rows in `fotmob_silver.card` whose `card_type` contains `yellow` with `card_minute <= 20`, for the team's side (`team_side`).
- Similarity note: Closest: `sig_team_discipline_cards_early_warning` (>= 3 different booked players before minute 30) and `sig_player_discipline_cards_walking_tightrope` (one player booked before 20). Different logic: two team yellows within 20 minutes. Related team signals: `sig_team_shooting_goals_rout_win`, `sig_team_shooting_goals_late_surge_goals` and `sig_team_discipline_cards_early_warning`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_discipline_cards_early_aggression.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_discipline_cards_early_aggression`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_discipline_cards_early_aggression
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
| `trigger_threshold_min_early_yellow_cards` | Configured trigger floor (`2` yellow cards in the first 20 minutes) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_early_yellow_cards` | Yellow cards in the first 20 minutes | Core signal intensity variable. |
| `triggered_team_early_yellow_cards_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
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
