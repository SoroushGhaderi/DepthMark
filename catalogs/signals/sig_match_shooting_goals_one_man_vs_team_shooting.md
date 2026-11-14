---
signal_id: sig_match_shooting_goals_one_man_vs_team_shooting
status: active
entity: match
family: shooting
subfamily: goals
grain: match_team
headline: "One Man Vs Team Shooting"
trigger: "One player has more shots (at least 5) than the entire opposing team in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_shooting_goals_one_man_vs_team_shooting
  sql: clickhouse/gold/dml/signals/match/sig_match_shooting_goals_one_man_vs_team_shooting.sql
---
# sig_match_shooting_goals_one_man_vs_team_shooting

## Purpose

Flags a one-man shooting display, an extreme shot-dominance marker.

## Tactical And Statistical Logic

- Trigger: One player has more shots (at least 5) than the entire opposing team in a finished match.
- Shot counts come from `fotmob_silver.shot` (own goals excluded). A player's shots must be at least 5 and greater than the other team's total shots; the other team needs at least one shot row. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_player_shooting_goals_shot_volume_monster` (a player with >= 8 shots, any opponent) and `sig_player_shooting_goals_shot_magnet` (a share of his own team's shots). Related match signals: `sig_match_shooting_goals_goal_fest`, `sig_match_shooting_goals_set_piece_duel` and `sig_match_goalkeeping_defense_zero_threat_match`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_shooting_goals_one_man_vs_team_shooting.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_shooting_goals_one_man_vs_team_shooting`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_shooting_goals_one_man_vs_team_shooting
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
| `trigger_threshold_min_player_shots` | Configured trigger floor (one player has at least `5` shots and more than the other team) | Explicit trigger provenance for explainability and QA. |
| `match_top_player_shots` | Shots by the top shooter | Core signal intensity variable. |
| `match_top_player_shots_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `home_team_shots` | Shots by the home team | Team total. |
| `away_team_shots` | Shots by the away team | Team total. |
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
