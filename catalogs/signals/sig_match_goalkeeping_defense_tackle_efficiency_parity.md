---
signal_id: sig_match_goalkeeping_defense_tackle_efficiency_parity
status: active
entity: match
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Tackle Efficiency Parity"
trigger: "Both teams have a tackle success rate within 2 percentage points of each other, with at least 10 tackle attempts each."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_goalkeeping_defense_tackle_efficiency_parity
  sql: clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_tackle_efficiency_parity.sql
---
# sig_match_goalkeeping_defense_tackle_efficiency_parity

## Purpose

Flags a balanced defensive duel, a mirrored-defence marker.

## Tactical And Statistical Logic

- Trigger: Both teams have a tackle success rate within 2 percentage points of each other, with at least 10 tackle attempts each.
- Tackle success is `tackles_succeeded / tackle_attempts` per team in `fotmob_silver.period_stat`; each team needs at least 10 attempts. The gap is the absolute difference in percentage points. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_match_goalkeeping_defense_tackle_and_interception_fest` and `sig_match_discipline_cards_blood_and_thunder`. Related defence signals: `sig_team_goalkeeping_defense_aerial_fortress`, `sig_match_goalkeeping_defense_tackle_and_interception_fest` and `sig_player_goalkeeping_defense_save_paralyzer`. Different logic: equal tackle success rates. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_tackle_efficiency_parity.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_goalkeeping_defense_tackle_efficiency_parity`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_goalkeeping_defense_tackle_efficiency_parity
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
| `trigger_threshold_max_tackle_rate_gap_pct` | Configured trigger ceiling (tackle success rates within `2` points) | Explicit trigger provenance for explainability and QA. |
| `match_tackle_success_rate_gap_pct` | Gap between the two teams' tackle success rates (points) | Core signal intensity variable. |
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
