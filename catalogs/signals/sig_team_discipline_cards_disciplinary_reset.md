---
signal_id: sig_team_discipline_cards_disciplinary_reset
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Disciplinary Reset"
trigger: "Team plays a match with no cards right after a match in which it received >= 2 red cards."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_discipline_cards_disciplinary_reset
  sql: clickhouse/gold/dml/signals/team/sig_team_discipline_cards_disciplinary_reset.sql
---
# sig_team_discipline_cards_disciplinary_reset

## Purpose

Flags a disciplinary recovery, a manager-reaction and discipline marker.

## Tactical And Statistical Logic

- Trigger: Team plays a match with no cards right after a match in which it received >= 2 red cards.
- The previous match is the team's immediately preceding finished match, with `red_cards >= 2` in `fotmob_silver.period_stat`; this match has `yellow_cards + red_cards = 0`. Both matches need stats. Stats come from `period = 'All'`.
- Similarity note: Closest: `sig_team_discipline_cards_discipline_meltdown` (>= 2 reds in one match, the match before) and `sig_team_discipline_cards_clean_discipline`. Different logic: a card-free match right after a two-red match. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_discipline_cards_disciplinary_reset.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_discipline_cards_disciplinary_reset`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_discipline_cards_disciplinary_reset
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
| `trigger_threshold_min_previous_red_cards` | Configured trigger floor (`2` red cards in the previous match) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_previous_match_red_cards` | Red cards received in the previous match | Core signal intensity variable. |
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
