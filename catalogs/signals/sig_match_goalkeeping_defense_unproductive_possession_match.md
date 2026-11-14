---
signal_id: sig_match_goalkeeping_defense_unproductive_possession_match
status: active
entity: match
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Unproductive Possession Match"
trigger: "A team with more than 65% possession makes fewer interceptions than its opponent in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_goalkeeping_defense_unproductive_possession_match
  sql: clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_unproductive_possession_match.sql
---
# sig_match_goalkeeping_defense_unproductive_possession_match

## Purpose

Flags a possession-heavy side that is passive without it, a control-without-pressing marker.

## Tactical And Statistical Logic

- Trigger: A team with more than 65% possession makes fewer interceptions than its opponent in a finished match.
- One team has `ball_possession > 65` and fewer `interceptions` than the other, in `fotmob_silver.period_stat` (`period = 'All'`). The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_team_possession_passing_possession_without_purpose` (possession above 65% with few shots on target) and `sig_match_possession_passing_counter_vs_bus`. Related match signals: `sig_match_shooting_goals_goal_fest`, `sig_match_shooting_goals_set_piece_duel` and `sig_match_goalkeeping_defense_zero_threat_match`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_unproductive_possession_match.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_goalkeeping_defense_unproductive_possession_match`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_goalkeeping_defense_unproductive_possession_match
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
| `trigger_threshold_min_possession_pct` | Configured trigger floor (a team above `65` % possession with fewer interceptions) | Explicit trigger provenance for explainability and QA. |
| `match_top_possession_pct` | Highest possession share (%) | Core signal intensity variable. |
| `match_top_possession_pct_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `match_interception_gap` | Interception difference between the teams | Size of the defensive-work gap. |
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
