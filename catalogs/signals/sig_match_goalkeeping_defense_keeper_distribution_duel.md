---
signal_id: sig_match_goalkeeping_defense_keeper_distribution_duel
status: active
entity: match
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Keeper Distribution Duel"
trigger: "Both goalkeepers finish a match with more than 80% pass accuracy on at least 15 passes each."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_goalkeeping_defense_keeper_distribution_duel
  sql: clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_keeper_distribution_duel.sql
---
# sig_match_goalkeeping_defense_keeper_distribution_duel

## Purpose

Flags two accurate sweeper-style keepers, a build-from-the-back marker.

## Tactical And Statistical Logic

- Trigger: Both goalkeepers finish a match with more than 80% pass accuracy on at least 15 passes each.
- Goalkeeper pass accuracy is `accurate_passes / total_passes` summed over each team's goalkeepers with minutes in `fotmob_silver.player_match_stat`; each side needs at least 15 passes. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_match_possession_passing_keeper_playmaking_battle` (keeper involvement in build-up) and `sig_team_possession_passing_accurate_unit`. Related defence signals: `sig_team_goalkeeping_defense_aerial_fortress`, `sig_match_goalkeeping_defense_tackle_and_interception_fest` and `sig_player_goalkeeping_defense_save_paralyzer`. Different logic: both keepers above 80% pass accuracy. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_keeper_distribution_duel.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_goalkeeping_defense_keeper_distribution_duel`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_goalkeeping_defense_keeper_distribution_duel
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
| `trigger_threshold_min_keeper_pass_accuracy_pct` | Configured trigger floor (both keepers above `80` % pass accuracy) | Explicit trigger provenance for explainability and QA. |
| `match_lower_keeper_pass_accuracy_pct` | The lower of the two keepers' pass accuracy (%) | Core signal intensity variable. |
| `match_lower_keeper_pass_accuracy_pct_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
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
