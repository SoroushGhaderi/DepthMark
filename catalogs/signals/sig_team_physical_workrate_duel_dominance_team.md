---
signal_id: sig_team_physical_workrate_duel_dominance_team
status: active
entity: team
family: physical
subfamily: workrate
grain: match_team
headline: "Duel Dominance Team"
trigger: "Team wins more than 55% of all duels in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_physical_workrate_duel_dominance_team
  sql: clickhouse/gold/dml/signals/team/sig_team_physical_workrate_duel_dominance_team.sql
---
# sig_team_physical_workrate_duel_dominance_team

## Purpose

Flags a team that wins most duels, a physical-superiority marker.

## Tactical And Statistical Logic

- Trigger: Team wins more than 55% of all duels in a finished match.
- The team's share is `duels_won / (duels_won_home + duels_won_away)` in `fotmob_silver.period_stat`. Stats come from `fotmob_silver.period_stat` (`period = 'All'`). This is the first signal family built only from duel, aerial and recovery counts, because the loaded data has no distance or sprint tracking.
- Similarity note: Closest: `sig_team_discipline_cards_physical_superiority` (>= 65% of duels with >= 15 fouls). Different logic: more than 55% of all duels, whatever the fouls. Related physical signals in this family are built from the same duel statistics; the closest existing signals are `sig_player_discipline_cards_physical_dominance`, `sig_player_goalkeeping_defense_interception_king` and `sig_team_discipline_cards_physical_superiority`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_physical_workrate_duel_dominance_team.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_physical_workrate_duel_dominance_team`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_physical_workrate_duel_dominance_team
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
| `trigger_threshold_min_duel_win_pct` | Configured trigger floor (more than `55` % of all duels won) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_duel_win_pct` | Share of all duels won (%) | Core signal intensity variable. |
| `triggered_team_duel_win_pct_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_team_duels_won` | Duels won by the team | Volume behind the share. |
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
