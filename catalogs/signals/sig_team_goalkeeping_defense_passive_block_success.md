---
signal_id: sig_team_goalkeeping_defense_passive_block_success
status: active
entity: team
family: goalkeeping
subfamily: defense
grain: match_team
headline: "Passive Block Success"
trigger: "Team wins with less than 30% possession and fewer than 10 fouls in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_goalkeeping_defense_passive_block_success
  sql: clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_passive_block_success.sql
---
# sig_team_goalkeeping_defense_passive_block_success

## Purpose

Flags a win without the ball and without fouling, a disciplined-defence and counter-play marker.

## Tactical And Statistical Logic

- Trigger: Team wins with less than 30% possession and fewer than 10 fouls in a finished match.
- The team wins (`goals_for > goals_against`), has `ball_possession < 30` and `fouls < 10` in `fotmob_silver.period_stat`. Stats come from `fotmob_silver.period_stat` (`period = 'All'`).
- Similarity note: Closest: `sig_team_goalkeeping_defense_parking_the_bus` (a win under 30% possession with 30+ clearances) and `sig_match_possession_passing_counter_vs_bus`. Related defence signals: `sig_match_goalkeeping_defense_offside_frenzy`, `sig_team_goalkeeping_defense_offside_trap_mastery` and `sig_match_goalkeeping_defense_tackle_and_interception_fest`. Different logic: the same win, but defined by few fouls instead of many clearances. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_goalkeeping_defense_passive_block_success.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_goalkeeping_defense_passive_block_success`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_goalkeeping_defense_passive_block_success
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
| `trigger_threshold_max_possession_pct` | Configured trigger ceiling (possession below `30` % in a win with fewer than 10 fouls) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_winning_possession_pct` | Possession of the winning team (%) | Core signal intensity variable. |
| `triggered_team_fouls` | Fouls committed by the team | Confirms the clean low block. |
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
