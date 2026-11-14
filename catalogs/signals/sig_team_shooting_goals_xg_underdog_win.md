---
signal_id: sig_team_shooting_goals_xg_underdog_win
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "xG Underdog Win"
trigger: "Team wins a finished match with at most half of the opponent's xG."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: fotmob_gold_signals.sig_team_shooting_goals_xg_underdog_win
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_xg_underdog_win.sql
---
# sig_team_shooting_goals_xg_underdog_win

## Purpose

Flags a win where the opponent created at least twice as much xG, an efficiency-or-luck and market-surprise marker.

## Tactical And Statistical Logic

- Trigger: Team wins a finished match with at most half of the opponent's xG.
- The team wins (`goals_for > goals_against`) and `expected_goals <= 0.5 * opponent expected_goals`, with the opponent xG above 0, from `fotmob_silver.period_stat` (`period = 'All'`). The measure is the team's xG as a percentage of the opponent's.
- Similarity note: Closest: `sig_team_shooting_goals_xg_overperformance_team` (>= 4 goals from low xG) and `sig_team_shooting_goals_expected_goal_dominance`. Different logic: a win with half the opponent's xG. No overlap.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_xg_underdog_win.sql`
- Runner: `scripts/fotmob/run_fotmob_gold_jobs.py`
- Target table: `fotmob_gold_signals.sig_team_shooting_goals_xg_underdog_win`

## Example Execution

```bash
python3 scripts/fotmob/run_fotmob_gold_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_xg_underdog_win
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
| `trigger_threshold_max_xg_share_pct` | Configured trigger ceiling (team xG as a percentage of opponent xG) | Explicit trigger provenance for explainability and QA. |
| `triggered_team_xg_share_of_opponent_pct` | Team xG as a percentage of the opponent's xG | Core signal intensity variable: how far the win went against the chances. |
| `xg_share_below_threshold_pct` | Percentage points below the trigger ceiling | Trigger severity beyond binary activation. |
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
