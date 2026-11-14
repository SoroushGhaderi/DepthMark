---
signal_id: sig_team_creativity_playmaking_creative_patience_index
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Creative Patience Index"
trigger: "Team averages >= 20 passes per shot in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_creativity_playmaking_creative_patience_index
  sql: clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_creative_patience_index.sql
---
# sig_team_creativity_playmaking_creative_patience_index

## Purpose

Flags a patient build-up with few shots, a slow-tempo and possession-heavy marker.

## Tactical And Statistical Logic

- Trigger: Team averages >= 20 passes per shot in a finished match.
- Passes per shot is `passes / total_shots` in `fotmob_silver.period_stat` (at least one shot). Stats come from `fotmob_silver.period_stat` (`period = 'All'`).
- Similarity note: Closest: `sig_team_possession_passing_possession_without_purpose` (possession above 65% with fewer than 2 shots on target) and `sig_team_possession_passing_sterile_dominance`. Related creativity signals: `sig_team_creativity_playmaking_chance_barrage`, `sig_team_creativity_playmaking_midfield_engine_vision` and `sig_match_creativity_playmaking_the_creativity_clash`. Different logic: 20 or more passes for each shot. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_creative_patience_index.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_creativity_playmaking_creative_patience_index`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_creativity_playmaking_creative_patience_index
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
| `trigger_threshold_min_passes_per_shot` | Configured trigger floor (at least `20` passes per shot) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_passes_per_shot` | Passes per shot | Core signal intensity variable. |
| `triggered_team_passes_per_shot_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_team_passes` | Passes by the team | Pass volume behind the index. |
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
