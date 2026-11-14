---
signal_id: sig_team_discipline_cards_tactical_fouling_unit
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Tactical Fouling Unit"
trigger: "At least 8 different players of the team commit a foul in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_discipline_cards_tactical_fouling_unit
  sql: clickhouse/gold/dml/signals/team/sig_team_discipline_cards_tactical_fouling_unit.sql
---
# sig_team_discipline_cards_tactical_fouling_unit

## Purpose

Flags a collective, spread-out fouling pattern, a tactical-foul marker.

## Tactical And Statistical Logic

- Trigger: At least 8 different players of the team commit a foul in a finished match.
- Count of the team's players with `fouls_committed >= 1` in `fotmob_silver.player_match_stat` (players with minutes).
- Similarity note: Closest: `sig_team_discipline_cards_collective_aggression` (>= 20 fouls in total) and `sig_team_discipline_cards_systematic_fouling` (every midfielder booked). Related discipline signals: `sig_team_discipline_cards_collective_aggression`, `sig_player_discipline_cards_late_red_drama` and `sig_player_discipline_cards_captain_reprimand`. Different logic: eight different players committing at least one foul. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_discipline_cards_tactical_fouling_unit.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_discipline_cards_tactical_fouling_unit`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_discipline_cards_tactical_fouling_unit
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
| `trigger_threshold_min_fouling_players` | Configured trigger floor (`8` different players who fouled) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_fouling_players` | Different players who committed a foul | Core signal intensity variable. |
| `triggered_team_fouling_players_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
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
