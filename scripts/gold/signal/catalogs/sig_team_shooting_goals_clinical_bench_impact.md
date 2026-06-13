---
signal_id: sig_team_shooting_goals_clinical_bench_impact
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Clinical Bench Impact"
trigger: "Substitutes score 100% of the team's goals in one finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_clinical_bench_impact
  sql: clickhouse/gold/signal/sig_team_shooting_goals_clinical_bench_impact.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_shooting_goals_clinical_bench_impact

## Purpose

Detect matches where every triggered-team goal is scored by substitutes, isolating extreme bench-dependent finishing outcomes at team grain.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_substitute_non_own_goals >= 1`
  - `triggered_team_substitute_non_own_goals = triggered_team_goals`
  - `triggered_team_substitute_goal_share_pct = 100`
- Substitute scorers are derived from `silver.match_personnel` (`role = 'substitute'`, `substitution_time > 0`) joined to non-own goals in `silver.shot` (`is_goal = 1`, `is_own_goal = 0`).
- Goal events are counted only when goal effective minute (`goal_time + goal_overload_time`) is at or after the recorded substitution time.
- Trigger is evaluated separately for home and away teams in finished matches (`silver.match.match_finished = 1`).
- Substitute-goal share is computed against official team goals (`home_score` / `away_score`) so the trigger matches the business rule "100% of team goals".
- Similarity gate note: closest active signal is `sig_team_shooting_goals_bench_goals_impact`. By your explicit decision, both coexist: this signal is stricter share-based logic (`100%`), while the existing signal is volume-based logic (`>= 2` substitute non-own goals).

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_shooting_goals_clinical_bench_impact.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_shooting_goals_clinical_bench_impact`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_shooting_goals_clinical_bench_impact
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join key and deterministic deduplication anchor |
| `match_date` | Match date | Temporal slicing and backfill traceability |
| `home_team_id` | Home team identifier | Fixture-side orientation |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team identifier | Fixture-side orientation |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Official score denominator context |
| `away_score` | Away full-time goals | Official score denominator context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered team identifier | Entity identity for downstream joins |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Readable opponent attribution |
| `trigger_threshold_min_substitute_non_own_goals` | Minimum substitute non-own goals threshold (`1`) | Explicit trigger governance and QA provenance |
| `trigger_threshold_min_substitute_goal_share_pct` | Minimum substitute goal-share threshold (`100`) | Explicit share-based trigger governance |
| `triggered_team_substitute_non_own_goals` | Non-own goals scored by triggered-team substitutes | Core trigger numerator |
| `opponent_substitute_non_own_goals` | Non-own goals scored by opponent substitutes | Bilateral bench-impact benchmark |
| `substitute_non_own_goals_delta` | Triggered minus opponent substitute non-own goals | Side-relative bench-output differential |
| `triggered_team_distinct_substitute_goal_scorers` | Distinct substitute scorers for triggered team | Bench scorer breadth diagnostic |
| `opponent_distinct_substitute_goal_scorers` | Distinct substitute scorers for opponent | Bilateral breadth comparator |
| `distinct_substitute_goal_scorers_delta` | Triggered minus opponent distinct substitute scorers | Substitute-scorer spread edge |
| `triggered_team_top_substitute_scorer_goals` | Max goals by a single triggered-team substitute scorer | Bench scoring concentration indicator |
| `opponent_top_substitute_scorer_goals` | Max goals by a single opponent substitute scorer | Bilateral concentration comparator |
| `top_substitute_scorer_goals_delta` | Triggered minus opponent top substitute-scorer goals | Side-level concentration differential |
| `triggered_team_first_substitute_goal_effective_minute` | Earliest effective minute of triggered-team substitute goal | Timing profile of bench-impact onset |
| `opponent_first_substitute_goal_effective_minute` | Earliest effective minute of opponent substitute goal | Bilateral timing comparator |
| `triggered_team_last_substitute_goal_effective_minute` | Latest effective minute of triggered-team substitute goal | Persistence of bench scoring contribution |
| `opponent_last_substitute_goal_effective_minute` | Latest effective minute of opponent substitute goal | Bilateral persistence comparator |
| `triggered_team_substitute_goal_share_pct` | Share of triggered-team official goals scored by substitutes (%) | Direct validation of the 100% trigger rule |
| `opponent_substitute_goal_share_pct` | Share of opponent official goals scored by substitutes (%) | Bilateral normalized comparator |
| `substitute_goal_share_delta_pct` | Triggered minus opponent substitute-goal share (percentage points) | Compact bench-dependence differential |
| `triggered_team_non_own_goals` | Triggered-team non-own goals | Scorer-attributable goal baseline |
| `opponent_non_own_goals` | Opponent non-own goals | Bilateral attributable-goal baseline |
| `non_own_goals_delta` | Triggered minus opponent non-own goals | Side-relative attributable scoring differential |
| `triggered_team_goals` | Triggered-team official full-time goals | Official trigger denominator and match output context |
| `opponent_goals` | Opponent official full-time goals | Bilateral outcome comparator |
| `goal_delta` | Triggered-team goals minus opponent goals | Outcome edge around bench scoring impact |
| `triggered_team_total_shots` | Triggered-team total shots | Shooting-volume context |
| `opponent_total_shots` | Opponent total shots | Bilateral shooting-volume comparator |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Shot-execution context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral execution comparator |
| `triggered_team_xg` | Triggered-team expected goals | Chance-quality baseline |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-quality edge |
| `triggered_team_big_chances` | Triggered-team big chances | High-value chance creation context |
| `opponent_big_chances` | Opponent big chances | Bilateral high-value chance comparator |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Control-profile context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Compact control differential |
