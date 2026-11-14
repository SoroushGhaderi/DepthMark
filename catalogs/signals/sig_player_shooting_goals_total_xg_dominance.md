---
signal_id: sig_player_shooting_goals_total_xg_dominance
status: active
entity: player
family: shooting
subfamily: goals
grain: match_player
headline: "Total xG Dominance"
trigger: "Player accounts for more than 80% of his team's total shot xG (the team needs at least 1.0 xG) in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: fotmob_gold_signals.sig_player_shooting_goals_total_xg_dominance
  sql: clickhouse/gold/dml/signals/player/sig_player_shooting_goals_total_xg_dominance.sql
---
# sig_player_shooting_goals_total_xg_dominance

## Purpose

Flags a one-man attack by chance quality, a key-player-dependence marker.

## Tactical And Statistical Logic

- Trigger: Player accounts for more than 80% of his team's total shot xG (the team needs at least 1.0 xG) in a finished match.
- The player's summed shot `expected_goals` divided by the team's summed shot `expected_goals` (own goals excluded) is above 0.80, and the team total is at least 1.0, so tiny totals cannot qualify.
- Similarity note: Closest: `sig_player_shooting_goals_shot_magnet` (more than 60% of the team's shots) and `sig_player_creativity_playmaking_isolated_creativity`. Related shooting signals: `sig_player_shooting_goals_impossible_angle`, `sig_player_shooting_goals_shot_conversion_peak` and `sig_player_shooting_goals_shot_magnet`. Different logic: a share of the team's xG instead of its shot count. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_shooting_goals_total_xg_dominance.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_player_shooting_goals_total_xg_dominance`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_player_shooting_goals_total_xg_dominance
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
| `triggered_side` | Side of the player's team (`home` or `away`) | Canonical side identity. |
| `triggered_player_id` | Triggered player identifier | Player attribution key (row identity). |
| `triggered_player_name` | Triggered player name | Readable player context. |
| `triggered_team_id` | Player's team identifier | Team context key (row identity). |
| `triggered_team_name` | Player's team name | Readable team context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral context. |
| `trigger_threshold_min_team_xg_share_pct` | Configured trigger floor (more than `80` % of the team's shot xG) | Explicit trigger provenance for explainability and QA. |
| `triggered_player_team_xg_share_pct` | Share of the team's shot xG (%) | Core signal intensity variable. |
| `triggered_player_team_xg_share_pct_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_player_total_xg` | Expected goals of the player's shots | Player xG behind the share. |
| `triggered_team_total_shot_xg` | Expected goals of the team's shots | Team total behind the share. |
| `triggered_player_shots` | Shots by the player in this match (own goals excluded) | Shot-volume context. |
| `triggered_player_goals` | Goals by the player in this match | Outcome context for the trigger. |
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
