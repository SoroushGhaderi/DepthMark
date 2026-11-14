---
signal_id: sig_team_discipline_cards_foul_heavy_defeat
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Foul Heavy Defeat"
trigger: "Team commits at least 3 times the fouls of the opponent but loses the match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_discipline_cards_foul_heavy_defeat
  sql: clickhouse/gold/dml/signals/team/sig_team_discipline_cards_foul_heavy_defeat.sql
---
# sig_team_discipline_cards_foul_heavy_defeat

## Purpose

Flags a defeat built on fouling, a negative-style and frustration marker.

## Tactical And Statistical Logic

- Trigger: Team commits at least 3 times the fouls of the opponent but loses the match.
- The team's `fouls` are at least three times the opponent's (opponent fouls at least 1) and `goals_for < goals_against`. The measure is the foul ratio. Stats come from `fotmob_silver.period_stat` (`period = 'All'`).
- Similarity note: Closest: `sig_match_discipline_cards_asymmetric_aggression` (3x fouls but fewer cards) and `sig_team_discipline_cards_card_heavy_defeat` (a 3-goal defeat with a red). Related discipline signals: `sig_match_discipline_cards_card_frenzy`, `sig_match_discipline_cards_clean_fair_play` and `sig_team_discipline_cards_clean_discipline`. Different logic: a 3x foul ratio and a defeat. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_discipline_cards_foul_heavy_defeat.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_discipline_cards_foul_heavy_defeat`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_discipline_cards_foul_heavy_defeat
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
| `trigger_threshold_min_foul_ratio` | Configured trigger floor (at least `3` times the opponent's fouls) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_foul_ratio` | Team fouls divided by opponent fouls | Core signal intensity variable. |
| `triggered_team_foul_ratio_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_team_fouls` | Fouls committed by the team | Foul volume. |
| `opponent_fouls` | Fouls committed by the opponent | Bilateral comparator. |
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
