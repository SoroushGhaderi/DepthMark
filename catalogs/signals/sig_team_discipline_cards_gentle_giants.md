---
signal_id: sig_team_discipline_cards_gentle_giants
status: active
entity: team
family: discipline
subfamily: cards
grain: match_team
headline: "Gentle Giants"
trigger: "Team wins more than 70% of its aerial duels while committing fewer than 5 fouls in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_discipline_cards_gentle_giants
  sql: clickhouse/gold/dml/signals/team/sig_team_discipline_cards_gentle_giants.sql
---
# sig_team_discipline_cards_gentle_giants

## Purpose

Flags clean aerial dominance, a physical-but-fair marker.

## Tactical And Statistical Logic

- Trigger: Team wins more than 70% of its aerial duels while committing fewer than 5 fouls in a finished match.
- Aerial win rate is `aerials_won / aerial_attempts` (at least one duel) and fouls are the team's `fouls` in `fotmob_silver.period_stat`. Stats come from `fotmob_silver.period_stat` (`period = 'All'`).
- Similarity note: Closest: `sig_team_goalkeeping_defense_aerial_fortress` (> 75% aerial wins) and `sig_team_discipline_cards_physical_superiority` (>= 65% duels and >= 15 fouls). Related discipline signals: `sig_match_discipline_cards_card_frenzy`, `sig_match_discipline_cards_clean_fair_play` and `sig_team_discipline_cards_clean_discipline`. Different logic: aerial dominance with very few fouls. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_discipline_cards_gentle_giants.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_discipline_cards_gentle_giants`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_discipline_cards_gentle_giants
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
| `trigger_threshold_min_aerial_win_pct` | Configured trigger floor (more than `70` % of aerial duels won) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_aerial_win_pct` | Aerial duels won (%) | Core signal intensity variable. |
| `triggered_team_aerial_win_pct_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_team_fouls` | Fouls committed by the team | Confirms the low foul count. |
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
