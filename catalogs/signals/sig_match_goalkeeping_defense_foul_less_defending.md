---
signal_id: sig_match_goalkeeping_defense_foul_less_defending
status: active
entity: match
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Foul Less Defending"
trigger: "A finished match has more than 30 successful tackles but fewer than 10 fouls."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_match_goalkeeping_defense_foul_less_defending
  sql: clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_foul_less_defending.sql
---
# sig_match_goalkeeping_defense_foul_less_defending

## Purpose

Flags a high-contact but clean match, a fair-tackling marker.

## Tactical And Statistical Logic

- Trigger: A finished match has more than 30 successful tackles but fewer than 10 fouls.
- Combined successful tackles are `tackles_succeeded_home + tackles_succeeded_away` and combined fouls are `fouls_home + fouls_away` in `fotmob_silver.period_stat`. The signal is a property of the fixture, so both side rows (`home` and `away`) are emitted for each triggered match.
- Similarity note: Closest: `sig_match_discipline_cards_clean_fair_play` (<= 12 fouls and no cards) and `sig_match_goalkeeping_defense_tackle_and_interception_fest`. Related defence signals: `sig_team_goalkeeping_defense_aerial_fortress`, `sig_match_goalkeeping_defense_tackle_and_interception_fest` and `sig_player_goalkeeping_defense_save_paralyzer`. Different logic: many successful tackles with very few fouls. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_goalkeeping_defense_foul_less_defending.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_match_goalkeeping_defense_foul_less_defending`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_match_goalkeeping_defense_foul_less_defending
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
| `trigger_threshold_min_combined_tackles` | Configured trigger floor (more than `30` successful tackles with fewer than 10 fouls) | Explicit trigger provenance for explainability and QA. |
| `match_combined_tackles` | Combined successful tackles | Core signal intensity variable. |
| `match_combined_tackles_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `match_combined_fouls` | Combined fouls | Confirms the clean contact. |
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
