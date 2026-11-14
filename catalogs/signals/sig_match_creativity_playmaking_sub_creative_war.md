---
signal_id: sig_match_creativity_playmaking_sub_creative_war
status: active
entity: match
family: creativity
subfamily: playmaking
grain: match_team
headline: "Sub Creative War"
trigger: "A substitute records an assist for each team in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_creativity_playmaking_sub_creative_war
  sql: clickhouse/gold/dml/signals/match/sig_match_creativity_playmaking_sub_creative_war.sql
---
# sig_match_creativity_playmaking_sub_creative_war

## Purpose

Flags a two-sided bench creativity battle, a substitution-impact marker.

## Tactical And Statistical Logic

- Trigger: A substitute records an assist for each team in a finished match.
- A substitute assist is a non-own goal row in `fotmob_silver.shot` whose `assist_player_id` is a player listed as a `substitute` for that match in `fotmob_silver.match_personnel`; each team needs at least one. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_team_creativity_playmaking_bench_creative_impact` (one team's bench: >= 2 key passes and >= 1 assist) and `sig_match_shooting_goals_sub_striker_duel` (substitutes score for both teams). Different logic: substitute assists for both teams. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_creativity_playmaking_sub_creative_war.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_creativity_playmaking_sub_creative_war`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_creativity_playmaking_sub_creative_war
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
| `trigger_threshold_min_substitute_assists_per_side` | Configured trigger floor (each side gets at least `1` substitute assist) | Explicit trigger provenance for explainability and QA. |
| `match_substitute_assists` | Substitute assists by both teams | Core signal intensity variable. |
| `match_substitute_assists_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `home_substitute_assists` | Substitute assists by the home side | Per-side split. |
| `away_substitute_assists` | Substitute assists by the away side | Per-side split. |
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
