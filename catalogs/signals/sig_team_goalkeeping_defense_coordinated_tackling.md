---
signal_id: sig_team_goalkeeping_defense_coordinated_tackling
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Coordinated Tackling"
trigger: "At least 10 outfield players of the team record a successful tackle in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_goalkeeping_defense_coordinated_tackling
  sql: clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_coordinated_tackling.sql
---
# sig_team_goalkeeping_defense_coordinated_tackling

## Purpose

Flags collective defensive involvement, a whole-team pressing marker.

## Tactical And Statistical Logic

- Trigger: At least 10 outfield players of the team record a successful tackle in a finished match.
- Count of the team's non-goalkeepers with `tackles_won >= 1` in `fotmob_silver.player_match_stat` (players with minutes). The workbook says all 10 outfield players; substitutes can fill the count, so the test is any 10.
- Similarity note: Closest: `sig_match_goalkeeping_defense_tackle_and_interception_fest` (combined volume) and `sig_player_goalkeeping_defense_tackle_master` (one player). Related defence signals: `sig_team_goalkeeping_defense_aerial_fortress`, `sig_match_goalkeeping_defense_tackle_and_interception_fest` and `sig_player_goalkeeping_defense_save_paralyzer`. Different logic: ten different outfield tacklers in one team. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_coordinated_tackling.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_goalkeeping_defense_coordinated_tackling`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_goalkeeping_defense_coordinated_tackling
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
| `trigger_threshold_min_outfield_tacklers` | Configured trigger floor (`10` outfield players with a tackle) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_outfield_tacklers` | Outfield players with a successful tackle | Core signal intensity variable. |
| `triggered_team_outfield_tacklers_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
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
