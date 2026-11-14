---
signal_id: sig_team_physical_workrate_ground_duel_dominance
status: active
entity: team
family: physical
subfamily: workrate
grain: match_team
headline: "Ground Duel Dominance"
trigger: "Team wins more than 60% of its ground duels, with at least 20 contested, in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_physical_workrate_ground_duel_dominance
  sql: clickhouse/gold/dml/signals/team/sig_team_physical_workrate_ground_duel_dominance.sql
---
# sig_team_physical_workrate_ground_duel_dominance

## Purpose

Flags a high ground-duel success rate, a physical-control marker.

## Tactical And Statistical Logic

- Trigger: Team wins more than 60% of its ground duels, with at least 20 contested, in a finished match.
- Success is `ground_duels_won / ground_duel_attempts` (at least 20 attempts) in `fotmob_silver.period_stat`. Stats come from `fotmob_silver.period_stat` (`period = 'All'`). This is the first signal family built only from duel, aerial and recovery counts, because the loaded data has no distance or sprint tracking.
- Similarity note: Closest: `sig_team_physical_workrate_duel_dominance_team` (all duels, 55%). Different logic: ground duels only, above 60%. Related physical signals in this family are built from the same duel statistics; the closest existing signals are `sig_player_discipline_cards_physical_dominance`, `sig_player_goalkeeping_defense_interception_king` and `sig_team_discipline_cards_physical_superiority`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_physical_workrate_ground_duel_dominance.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_physical_workrate_ground_duel_dominance`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_physical_workrate_ground_duel_dominance
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
| `trigger_threshold_min_ground_duel_win_pct` | Configured trigger floor (more than `60` % of ground duels won on 20+ attempts) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_ground_duel_win_pct` | Ground duels won (%) | Core signal intensity variable. |
| `triggered_team_ground_duel_win_pct_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_team_ground_duel_attempts` | Ground duels contested | Volume behind the rate. |
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
