---
signal_id: sig_team_creativity_playmaking_one_sided_playmaking
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "One Sided Playmaking"
trigger: "Team records at least 10 times the xA of the opponent (and at least 1.0 xA) in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_creativity_playmaking_one_sided_playmaking
  sql: clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_one_sided_playmaking.sql
---
# sig_team_creativity_playmaking_one_sided_playmaking

## Purpose

Flags a lopsided creative gap, a dominance marker.

## Tactical And Statistical Logic

- Trigger: Team records at least 10 times the xA of the opponent (and at least 1.0 xA) in a finished match.
- Team xA is at least 10x the opponent's xA and at least 1.0 (opponent xA of 0 qualifies). xA is the sum of `expected_assists` per team. Stats come from `fotmob_silver.period_stat` (`period = 'All'`). Player facts come from `fotmob_silver.player_match_stat` summed per team.
- Similarity note: Closest: `sig_team_creativity_playmaking_one_sided_vision` (>= 10 key passes against 0) and `sig_match_creativity_playmaking_the_creativity_clash` (both teams >= 1.5 xA). Related creativity signals: `sig_team_creativity_playmaking_chance_barrage`, `sig_team_creativity_playmaking_midfield_engine_vision` and `sig_match_creativity_playmaking_the_creativity_clash`. Different logic: a 10x xA ratio instead of a key-pass count. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_creativity_playmaking_one_sided_playmaking.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_creativity_playmaking_one_sided_playmaking`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_creativity_playmaking_one_sided_playmaking
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
| `trigger_threshold_min_xa_ratio` | Configured trigger floor (team xA at least `10` times the opponent's, minimum 1.0) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_xa` | Team expected assists | Core signal intensity variable. |
| `opponent_xa` | Opponent expected assists | Bilateral comparator. |
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
