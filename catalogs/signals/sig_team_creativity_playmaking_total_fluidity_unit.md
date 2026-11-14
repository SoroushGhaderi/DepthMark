---
signal_id: sig_team_creativity_playmaking_total_fluidity_unit
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Total Fluidity Unit"
trigger: "Every starting midfielder and forward of the team (at least 5 of them) records a key pass in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_creativity_playmaking_total_fluidity_unit
  sql: clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_total_fluidity_unit.sql
---
# sig_team_creativity_playmaking_total_fluidity_unit

## Purpose

Flags a team whose midfield and attack all contribute chances, a collective-creativity marker.

## Tactical And Statistical Logic

- Trigger: Every starting midfielder and forward of the team (at least 5 of them) records a key pass in a finished match.
- Midfielders and forwards are starters with `usual_playing_position_id` of 2 or 3 in `fotmob_silver.match_personnel`; each needs `chances_created >= 1` in `fotmob_silver.player_match_stat`. At least 5 such starters are required.
- Similarity note: Closest: `sig_team_creativity_playmaking_total_fluidity` (>= 6 players with a key pass, any position) and `sig_team_creativity_playmaking_fluid_front_three`. Different logic: all starting midfielders and forwards create.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_total_fluidity_unit.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_creativity_playmaking_total_fluidity_unit`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_creativity_playmaking_total_fluidity_unit
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
| `trigger_threshold_min_starting_attackers` | Configured trigger floor (all of at least `5` starting midfielders and forwards create) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_creating_attackers` | Starting midfielders and forwards who all created | Core signal intensity variable. |
| `triggered_team_creating_attackers_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
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
