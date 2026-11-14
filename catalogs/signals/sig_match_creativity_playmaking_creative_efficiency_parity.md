---
signal_id: sig_match_creativity_playmaking_creative_efficiency_parity
status: active
entity: match
family: creativity
subfamily: playmaking
grain: match_team
headline: "Creative Efficiency Parity"
trigger: "Both teams finish within 0.1 xA of each other, with at least 1.0 xA combined, in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_creativity_playmaking_creative_efficiency_parity
  sql: clickhouse/gold/dml/signals/match/sig_match_creativity_playmaking_creative_efficiency_parity.sql
---
# sig_match_creativity_playmaking_creative_efficiency_parity

## Purpose

Flags a perfectly balanced creative match, a mirrored-creativity marker.

## Tactical And Statistical Logic

- Trigger: Both teams finish within 0.1 xA of each other, with at least 1.0 xA combined, in a finished match.
- Team xA is the sum of `expected_assists` of the team's players with minutes in `fotmob_silver.player_match_stat`. The absolute difference must be at most 0.1, and combined xA at least 1.0 so two empty sides cannot qualify. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_match_creativity_playmaking_the_creativity_clash` (both teams >= 1.5 xA) and `sig_match_shooting_goals_shot_efficiency_parity`. Related match signals: `sig_match_shooting_goals_goal_fest`, `sig_match_shooting_goals_set_piece_duel` and `sig_match_goalkeeping_defense_zero_threat_match`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_creativity_playmaking_creative_efficiency_parity.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_creativity_playmaking_creative_efficiency_parity`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_creativity_playmaking_creative_efficiency_parity
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
| `trigger_threshold_max_xa_gap` | Configured trigger ceiling (xA gap of at most `0.1`) | Explicit trigger provenance for explainability and QA. |
| `match_xa_gap` | Absolute xA difference between the teams | Core signal intensity variable. |
| `home_xa` | Home team expected assists | Per-side value. |
| `away_xa` | Away team expected assists | Per-side value. |
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
