---
signal_id: sig_team_creativity_playmaking_assist_connection_duo
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Assist Connection Duo"
trigger: "One player assists the same teammate for >= 2 goals in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_creativity_playmaking_assist_connection_duo
  sql: clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_assist_connection_duo.sql
---
# sig_team_creativity_playmaking_assist_connection_duo

## Purpose

Flags a repeat provider-and-scorer pair, a combination-play marker.

## Tactical And Statistical Logic

- Trigger: One player assists the same teammate for >= 2 goals in a finished match.
- Goal rows in `fotmob_silver.shot` are grouped by the pair (`assist_player_id`, `player_id`) per team; the best pair needs at least 2 goals. Own goals are excluded.
- Similarity note: Closest: `sig_match_creativity_playmaking_playmaker_to_striker_connection` (a player with 5+ key passes and an assist link) and `sig_player_creativity_playmaking_assist_brace` (any player with 2 assists). Different logic: both assists go to the same teammate. Related team signals: `sig_team_shooting_goals_rout_win`, `sig_team_shooting_goals_late_surge_goals` and `sig_team_discipline_cards_early_warning`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_assist_connection_duo.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_creativity_playmaking_assist_connection_duo`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_creativity_playmaking_assist_connection_duo
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
| `trigger_threshold_min_link_goals` | Configured trigger floor (`2` goals from the same assister-and-scorer pair) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_best_link_goals` | Goals from the best assister-and-scorer pair | Core signal intensity variable. |
| `triggered_team_best_link_goals_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
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
