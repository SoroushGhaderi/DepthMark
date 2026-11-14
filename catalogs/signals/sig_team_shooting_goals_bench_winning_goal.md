---
signal_id: sig_team_shooting_goals_bench_winning_goal
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Bench Winning Goal"
trigger: "A substitute scores the winning goal after minute 80 in a one-goal win."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_shooting_goals_bench_winning_goal
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_bench_winning_goal.sql
---
# sig_team_shooting_goals_bench_winning_goal

## Purpose

Flags a late bench winner, a substitution-impact and super-sub marker.

## Tactical And Statistical Logic

- Trigger: A substitute scores the winning goal after minute 80 in a one-goal win.
- The winning goal is the match's last goal row in `fotmob_silver.shot` (highest score total), the final margin is exactly 1 and the goal rows add up to the final score. The scorer is listed as a `substitute` in `fotmob_silver.match_personnel` and `goal_time > 80`. Own goals are excluded from the choice of last goal.
- Similarity note: Closest: `sig_player_shooting_goals_late_winner_clutch` (a decisive 90+ goal by any player) and `sig_player_shooting_goals_super_sub_goal` (a goal within 5 minutes of entering). Different logic: a substitute scores the winner after minute 80. Related team signals: `sig_team_shooting_goals_rout_win`, `sig_team_shooting_goals_late_surge_goals` and `sig_team_discipline_cards_early_warning`.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_bench_winning_goal.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_shooting_goals_bench_winning_goal`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_bench_winning_goal
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
| `trigger_threshold_min_winning_goal_minute` | Configured trigger floor (substitute scores the winner after minute `80`) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_winning_goal_minute` | Minute of the substitute's winning goal | Core signal intensity variable. |
| `triggered_team_winning_goal_minute_above_threshold` | Value minus the trigger floor | Trigger severity beyond binary activation. |
| `triggered_team_winning_scorer_id` | Player id of the substitute who scored the winner | Names the match-winner. |
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
