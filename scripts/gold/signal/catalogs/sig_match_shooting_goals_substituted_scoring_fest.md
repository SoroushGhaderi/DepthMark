---
signal_id: sig_match_shooting_goals_substituted_scoring_fest
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Substituted Scoring Fest"
trigger: "3 different substitutes score non-own goals in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_shooting_goals_substituted_scoring_fest
  sql: clickhouse/gold/dml/signals/match/sig_match_shooting_goals_substituted_scoring_fest.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_match_shooting_goals_substituted_scoring_fest

## Purpose

Detect matches where at least three different substitutes score non-own goals, then emit bilateral team context to analyze how distributed bench finishing shaped the match profile.

## Tactical And Statistical Logic

- Trigger condition: `match_distinct_substitute_goal_scorers >= 3` in finished matches.
- Substitute scorers are derived from `silver.match_personnel` where `role = 'substitute'` and `substitution_time > 0`.
- A substitute goal event is counted only when a non-own goal in `silver.shot` occurs at or after that player's substitution minute.
- Match-level trigger is represented at canonical `match_team` grain by emitting two rows (`triggered_side = 'home'` and `'away'`).
- Output blends match-level substitute-scorer spread with side-oriented shooting, chance-quality, possession, and passing context.
- Similarity gate note: nearest active signals are `sig_match_shooting_goals_clinical_sub_impact`, `sig_team_shooting_goals_bench_goals_impact`, and `sig_player_shooting_goals_super_sub_goal`; this signal intentionally coexists because it requires scorer diversity (three different substitutes), not just aggregate substitute goal volume.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_shooting_goals_substituted_scoring_fest.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_match_shooting_goals_substituted_scoring_fest`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_match_shooting_goals_substituted_scoring_fest
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join key for deduplication and downstream modeling. |
| `match_date` | Match date | Supports reproducible backfills and time-sliced analysis. |
| `home_team_id` | Home team identifier | Preserves fixture context. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves fixture context. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Scoreline context for substitute-goal impact interpretation. |
| `away_score` | Full-time away goals | Bilateral scoreline context. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity for `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Side-level team join key. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side attribution. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison join key. |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator context. |
| `trigger_threshold_match_distinct_substitute_goal_scorers_min` | Configured minimum combined distinct substitute goal scorers (`3`) | Explicit trigger governance and QA traceability. |
| `match_distinct_substitute_goal_scorers` | Combined distinct substitute goal scorers in the match | Core trigger metric aligned with scorer-diversity condition. |
| `match_substitute_non_own_goals` | Combined substitute non-own goals in the match | Volume context around the scorer-diversity trigger. |
| `match_total_non_own_goals` | Combined non-own goals in the match | Denominator context for match-level substitute-goal share. |
| `match_substitute_goal_share_pct` | Share of match non-own goals scored by substitutes (%) | Normalized match-level dependence on bench scoring. |
| `home_substitute_non_own_goals` | Home substitute non-own goals | Side-specific decomposition of match trigger. |
| `away_substitute_non_own_goals` | Away substitute non-own goals | Side-specific decomposition of match trigger. |
| `home_distinct_substitute_goal_scorers` | Distinct home substitute goal scorers | Home bench scorer spread context. |
| `away_distinct_substitute_goal_scorers` | Distinct away substitute goal scorers | Away bench scorer spread context. |
| `triggered_team_substitute_non_own_goals` | Triggered-side substitute non-own goals | Triggered-side bench finishing contribution. |
| `opponent_substitute_non_own_goals` | Opponent substitute non-own goals | Bilateral bench finishing comparator. |
| `substitute_non_own_goals_delta` | Triggered minus opponent substitute non-own goals | Compact bench-output differential. |
| `triggered_team_distinct_substitute_goal_scorers` | Distinct triggered-side substitute scorers | Triggered-side bench scorer diversity diagnostic. |
| `opponent_distinct_substitute_goal_scorers` | Distinct opponent substitute scorers | Bilateral scorer-diversity comparator. |
| `distinct_substitute_goal_scorers_delta` | Triggered minus opponent distinct substitute scorers | Relative breadth of bench scoring sources. |
| `triggered_team_top_substitute_scorer_goals` | Max goals by one triggered-side substitute scorer | Bench scoring concentration metric for triggered side. |
| `opponent_top_substitute_scorer_goals` | Max goals by one opponent substitute scorer | Bilateral concentration comparator. |
| `top_substitute_scorer_goals_delta` | Triggered minus opponent top substitute-scorer goals | Directional bench concentration differential. |
| `triggered_team_first_substitute_goal_effective_minute` | Earliest effective minute of triggered-side substitute goal | Timing onset of bench impact. |
| `opponent_first_substitute_goal_effective_minute` | Earliest effective minute of opponent substitute goal | Bilateral timing comparator. |
| `triggered_team_last_substitute_goal_effective_minute` | Latest effective minute of triggered-side substitute goal | Persistence of bench scoring impact. |
| `opponent_last_substitute_goal_effective_minute` | Latest effective minute of opponent substitute goal | Bilateral persistence comparator. |
| `triggered_team_substitute_goal_share_pct` | Share of triggered-side non-own goals scored by substitutes (%) | Side-level normalized bench dependence. |
| `opponent_substitute_goal_share_pct` | Share of opponent non-own goals scored by substitutes (%) | Bilateral normalized comparator. |
| `substitute_goal_share_delta_pct` | Triggered minus opponent substitute-goal share (percentage points) | Compact side-relative bench dependence differential. |
| `triggered_team_non_own_goals` | Triggered-side non-own goals | Triggered-side scoring baseline for share metrics. |
| `opponent_non_own_goals` | Opponent non-own goals | Bilateral scoring baseline comparator. |
| `non_own_goals_delta` | Triggered minus opponent non-own goals | Side-level non-own scoring edge. |
| `triggered_team_goals` | Triggered-side full-time goals | Official score contribution for outcome context. |
| `opponent_goals` | Opponent full-time goals | Bilateral outcome comparator. |
| `goal_delta` | Triggered minus opponent full-time goals | Result-oriented goal differential. |
| `triggered_team_total_shots` | Triggered-side total shots | Side-level shot-volume context. |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Side-level shot-execution context. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral shot-execution comparator. |
| `triggered_team_xg` | Triggered-side expected goals | Chance-quality context for triggered side. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator. |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-quality differential. |
| `triggered_team_big_chances` | Triggered-side big chances | High-value chance volume for triggered side. |
| `opponent_big_chances` | Opponent big chances | Bilateral high-value chance comparator. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context around substitute-goal surge. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-circulation execution context. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Net technical execution differential. |
