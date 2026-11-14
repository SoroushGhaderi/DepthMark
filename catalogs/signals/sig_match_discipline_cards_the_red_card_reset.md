---
signal_id: sig_match_discipline_cards_the_red_card_reset
status: active
entity: match
family: discipline
subfamily: cards
grain: match_team
headline: "The Red Card Reset"
trigger: "A match is 0-0 when the first red card is shown and then produces >= 3 goals afterwards."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_discipline_cards_the_red_card_reset
  sql: clickhouse/gold/dml/signals/match/sig_match_discipline_cards_the_red_card_reset.sql
---
# sig_match_discipline_cards_the_red_card_reset

## Purpose

Flags a goalless match opened up by a red card, a red-card-impact marker.

## Tactical And Statistical Logic

- Trigger: A match is 0-0 when the first red card is shown and then produces >= 3 goals afterwards.
- The first red card is the earliest `card_minute` of a red card in `fotmob_silver.card`. No goal may have `goal_time` at or before that minute and at least 3 goals must come after it. The goal rows must add up to the final score. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_team_discipline_cards_red_card_neutralizer` (a goal within 5 minutes of going down to 10 men) and `sig_team_discipline_cards_man_advantage_collapse`. Different logic: a goalless match that produces three or more goals after the first red card.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_discipline_cards_the_red_card_reset.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_discipline_cards_the_red_card_reset`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_discipline_cards_the_red_card_reset
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
| `trigger_threshold_min_goals_after_red_card` | Configured trigger floor (0-0 at the first red card, then `3` goals) | Explicit trigger provenance for explainability and QA. |
| `match_goals_after_first_red_card` | Goals after the first red card | Core signal intensity variable. |
| `match_goals_after_first_red_card_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `match_first_red_card_minute` | Minute of the first red card | Timing of the turning point. |
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
