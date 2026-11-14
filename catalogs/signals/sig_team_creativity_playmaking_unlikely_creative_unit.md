---
signal_id: sig_team_creativity_playmaking_unlikely_creative_unit
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Unlikely Creative Unit"
trigger: "Team wins 3-0 and every one of its goals is assisted by a defender."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_creativity_playmaking_unlikely_creative_unit
  sql: clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_unlikely_creative_unit.sql
---
# sig_team_creativity_playmaking_unlikely_creative_unit

## Purpose

Flags a win whose assists all come from the back line, a set-piece-and-fullback-creativity marker.

## Tactical And Statistical Logic

- Trigger: Team wins 3-0 and every one of its goals is assisted by a defender.
- The team wins 3-0, has exactly 3 non-own goal rows in `fotmob_silver.shot`, each with an `assist_player_id`, and each assister has `usual_playing_position_id = 1` (defender group) in `fotmob_silver.match_personnel`.
- Similarity note: Closest: `sig_team_creativity_playmaking_unlikely_creative_source` (centre backs provide >= 2 assists) and `sig_team_shooting_goals_defensive_scoring_unit`. Different logic: a 3-0 win with every assist from a defender. Related team signals: `sig_team_shooting_goals_rout_win`, `sig_team_shooting_goals_late_surge_goals` and `sig_team_discipline_cards_early_warning`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_unlikely_creative_unit.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_creativity_playmaking_unlikely_creative_unit`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_creativity_playmaking_unlikely_creative_unit
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
| `trigger_threshold_exact_defender_assists` | Configured trigger floor (a 3-0 win with `3` goals, all assisted by defenders) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_defender_assists` | Goals assisted by defenders | Core signal intensity variable. |
| `triggered_team_defender_assists_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
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
