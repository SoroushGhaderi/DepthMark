---
signal_id: sig_team_shooting_goals_shared_scoring
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Shared Scoring"
trigger: "Team has >= 4 different players score non-own goals in one finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_shared_scoring
  sql: clickhouse/gold/signal/sig_team_shooting_goals_shared_scoring.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_shooting_goals_shared_scoring

## Purpose

Detect team scoring performances where goals are distributed across at least four different scorers, highlighting low-concentration finishing profiles instead of one- or two-player dependency.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_distinct_goal_scorers >= 4`
- Scorer diversity is computed from non-own goals in `silver.shot` at match-team grain.
- Trigger is evaluated separately for home and away sides in finished matches (`period = 'All'`).
- Bilateral output keeps scorer-diversity and shooting-control context as `triggered_team_*` vs `opponent_*` metrics.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_early_blitz` and `sig_player_shooting_goals_one_man_army`; this signal is distinct because it is team-level scorer-diversity driven (`>= 4` distinct scorers) rather than timing bursts or single-player goal concentration.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_shooting_goals_shared_scoring.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_shooting_goals_shared_scoring`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_shooting_goals_shared_scoring
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable key for joins and deterministic deduplication |
| `match_date` | Match date | Football developer: supports time slicing and backfill traceability |
| `home_team_id` | Home team identifier | Football developer: preserves fixture orientation |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: preserves fixture orientation |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: outcome context for scorer-distribution interpretation |
| `away_score` | Away full-time goals | Football developer: outcome context for scorer-distribution interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered team identifier | Football developer: identity anchor for the triggered entity |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Football developer: readable opponent attribution |
| `trigger_threshold_min_distinct_goal_scorers` | Trigger threshold for minimum distinct scorers (`4`) | Football developer: explicit rule provenance for governance and QA |
| `triggered_team_distinct_goal_scorers` | Number of distinct triggered-team non-own-goal scorers | Football developer: core trigger metric |
| `opponent_distinct_goal_scorers` | Number of distinct opponent non-own-goal scorers | Football developer: bilateral scorer-diversity comparator |
| `distinct_goal_scorers_delta` | Triggered minus opponent distinct scorers | Football developer: compact scorer-diversity edge diagnostic |
| `triggered_team_non_own_goals` | Triggered-team non-own goals from shot events | Football developer: denominator for scorer-distribution context |
| `opponent_non_own_goals` | Opponent non-own goals from shot events | Football developer: bilateral goal-output comparator |
| `non_own_goals_delta` | Triggered minus opponent non-own goals | Football developer: side-relative finishing output gap |
| `triggered_team_single_goal_scorers` | Triggered-team scorers with exactly one goal | Football developer: breadth-of-contribution measure |
| `opponent_single_goal_scorers` | Opponent scorers with exactly one goal | Football developer: bilateral breadth comparator |
| `single_goal_scorers_delta` | Triggered minus opponent single-goal scorers | Football developer: low-concentration vs distributed-finishing differential |
| `triggered_team_multi_goal_scorers` | Triggered-team scorers with at least two goals | Football developer: concentration counterbalance to spread |
| `opponent_multi_goal_scorers` | Opponent scorers with at least two goals | Football developer: bilateral concentration comparator |
| `multi_goal_scorers_delta` | Triggered minus opponent multi-goal scorers | Football developer: concentrated-finishing imbalance metric |
| `triggered_team_top_scorer_goals` | Highest non-own-goal count by a single triggered-team scorer | Football developer: identifies max individual scorer load |
| `opponent_top_scorer_goals` | Highest non-own-goal count by a single opponent scorer | Football developer: bilateral max-load comparator |
| `top_scorer_goals_delta` | Triggered minus opponent top-scorer goals | Football developer: side-relative peak scorer burden |
| `triggered_team_top_scorer_goal_share_pct` | Share of triggered-team non-own goals by top scorer (%) | Football developer: direct concentration intensity metric |
| `opponent_top_scorer_goal_share_pct` | Share of opponent non-own goals by top scorer (%) | Football developer: bilateral concentration comparator |
| `top_scorer_goal_share_delta_pct` | Triggered minus opponent top-scorer share (percentage points) | Football developer: compact concentration differential |
| `triggered_team_scorer_spread_pct` | Triggered-team distinct scorers as share of non-own goals (%) | Football developer: normalized scorer-diversity intensity |
| `opponent_scorer_spread_pct` | Opponent distinct scorers as share of non-own goals (%) | Football developer: bilateral spread comparator |
| `scorer_spread_delta_pct` | Triggered minus opponent scorer spread (percentage points) | Football developer: side-level distribution-vs-concentration edge |
| `triggered_team_goals` | Triggered-team official full-time goals | Football developer: scoreline baseline for trigger interpretation |
| `opponent_goals` | Opponent official full-time goals | Football developer: bilateral outcome comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Football developer: winning-margin context around shared scoring |
| `triggered_team_total_shots` | Triggered-team total shots | Football developer: shot-volume context for distributed scoring |
| `opponent_total_shots` | Opponent total shots | Football developer: bilateral shot-volume comparator |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Football developer: execution-quality baseline |
| `opponent_shots_on_target` | Opponent shots on target | Football developer: bilateral execution comparator |
| `triggered_team_xg` | Triggered-team expected goals | Football developer: chance-quality baseline behind spread scoring |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: net chance-generation edge |
| `triggered_team_big_chances` | Triggered-team big chances | Football developer: high-value chance context for scorer diversity |
| `opponent_big_chances` | Opponent big chances | Football developer: bilateral big-chance comparator |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Football developer: control-profile context |
| `opponent_possession_pct` | Opponent possession (%) | Football developer: bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: compact control differential |
