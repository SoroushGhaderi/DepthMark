---
signal_id: sig_team_creativity_playmaking_no_dribble_logic
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "No Dribble Logic"
trigger: "Team creates >= 10 key passes with fewer than 3 completed dribbles in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_creativity_playmaking_no_dribble_logic
  sql: clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_no_dribble_logic.sql
---
# sig_team_creativity_playmaking_no_dribble_logic

## Purpose

Flags a pass-only attack, a combination-play marker.

## Tactical And Statistical Logic

- Trigger: Team creates >= 10 key passes with fewer than 3 completed dribbles in a finished match.
- Key passes are the sum of `chances_created` of the team's players; completed dribbles are `dribbles_succeeded` in `fotmob_silver.period_stat`. Stats come from `fotmob_silver.period_stat` (`period = 'All'`). Player facts come from `fotmob_silver.player_match_stat` summed per team.
- Similarity note: Closest: `sig_team_creativity_playmaking_dribbling_exhibition` (>= 20 dribbles; the opposite) and `sig_team_creativity_playmaking_chance_barrage` (>= 15 key passes). Related creativity signals: `sig_team_creativity_playmaking_chance_barrage`, `sig_team_creativity_playmaking_midfield_engine_vision` and `sig_match_creativity_playmaking_the_creativity_clash`. Different logic: many key passes with almost no dribbling. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_no_dribble_logic.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_creativity_playmaking_no_dribble_logic`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_creativity_playmaking_no_dribble_logic
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
| `trigger_threshold_min_key_passes` | Configured trigger floor (`10` key passes with fewer than 3 completed dribbles) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_key_passes` | Key passes by the team | Core signal intensity variable. |
| `triggered_team_key_passes_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_team_completed_dribbles` | Completed dribbles by the team | Confirms the pass-only attack. |
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
