---
signal_id: sig_team_shooting_goals_counter_attack_lethality
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Counter Attack Lethality"
trigger: "Team scores >= 2 non-own goals from fast-break situations in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_shooting_goals_counter_attack_lethality
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_counter_attack_lethality.sql
---
# sig_team_shooting_goals_counter_attack_lethality

## Purpose

Flags a match where fast breaks produce at least two goals, a transition-threat marker.

## Tactical And Statistical Logic

- Trigger: Team scores >= 2 non-own goals from fast-break situations in a finished match.
- A fast-break goal is a goal row with `situation = 'FastBreak'` in `fotmob_silver.shot` (own goals excluded). The project uses this situation as its counter-attack proxy.
- Similarity note: Closest: `sig_team_shooting_goals_dead_ball_specialists` (dead-ball goals) and `sig_team_shooting_goals_ruthless_efficiency`. No existing fast-break signal. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_counter_attack_lethality.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_shooting_goals_counter_attack_lethality`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_counter_attack_lethality
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
| `trigger_threshold_min_fast_break_goals` | Configured trigger floor (`2` fast-break goals) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_fast_break_goals` | Goals scored from fast breaks | Core signal intensity variable. |
| `triggered_team_fast_break_goals_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
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
