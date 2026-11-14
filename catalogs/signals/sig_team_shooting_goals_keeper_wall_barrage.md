---
signal_id: sig_team_shooting_goals_keeper_wall_barrage
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Keeper Wall Barrage"
trigger: "Team has >= 15 shots on target but the opposing goalkeeper makes >= 10 saves in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_shooting_goals_keeper_wall_barrage
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_keeper_wall_barrage.sql
---
# sig_team_shooting_goals_keeper_wall_barrage

## Purpose

Flags a barrage met by a wall, a keeper-heroics and unlucky-attack marker.

## Tactical And Statistical Logic

- Trigger: Team has >= 15 shots on target but the opposing goalkeeper makes >= 10 saves in a finished match.
- The team's `shots_on_target` is at least 15 and the opponent's `keeper_saves` is at least 10. Stats come from `fotmob_silver.period_stat` (`period = 'All'`).
- Similarity note: Closest: `sig_team_shooting_goals_conversion_collapse` (>= 10 shots on target, exactly 1 goal) and `sig_player_goalkeeping_defense_save_paralyzer`. Related shooting signals: `sig_player_shooting_goals_impossible_angle`, `sig_player_shooting_goals_shot_conversion_peak` and `sig_player_shooting_goals_shot_magnet`. Different logic: 15 shots on target against a keeper with 10 saves. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_keeper_wall_barrage.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_shooting_goals_keeper_wall_barrage`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_keeper_wall_barrage
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
| `trigger_threshold_min_shots_on_target` | Configured trigger floor (`15` shots on target against 10+ saves) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_shots_on_target` | Shots on target by the team | Core signal intensity variable. |
| `triggered_team_shots_on_target_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `opponent_goalkeeper_saves` | Saves made by the opposing goalkeeper | The wall that stopped the barrage. |
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
