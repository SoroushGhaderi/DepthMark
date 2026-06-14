---
signal_id: sig_match_shooting_goals_the_brace_battle
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "The Brace Battle"
trigger: "Two different players (one from each team) score a brace (>= 2 non-own goals each) in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_shooting_goals_the_brace_battle
  sql: clickhouse/gold/dml/signals/match/sig_match_shooting_goals_the_brace_battle.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_shooting_goals_the_brace_battle

## Purpose

Detect finished matches where each team has a different brace scorer, then emit bilateral side-oriented context to explain how dual individual finishing spikes shaped match dynamics.

## Tactical And Statistical Logic

- Trigger condition:
  - home side has at least one player with `>= 2` non-own goals
  - away side has at least one player with `>= 2` non-own goals
  - top brace-scorer player IDs differ across teams (different players)
- Brace scorers are derived from `silver.shot` goal events (`is_goal = 1`, `is_own_goal = 0`) grouped by `match_id`, `team_id`, and `player_id`.
- Match-level trigger emits two rows (`triggered_side = 'home'` and `'away'`) to preserve canonical `match_team` grain.
- Enrichment combines brace-scorer decomposition (counts, goals, top scorer identities) with bilateral shooting, xG, chance, possession, and passing context.
- Similarity gate note: nearest active signals are `sig_match_shooting_goals_substituted_scoring_fest`, `sig_match_shooting_goals_clinical_sub_impact`, and `sig_player_shooting_goals_clinical_brace`; this signal intentionally coexists because it is match-scoped and requires bilateral brace symmetry (one brace scorer per team), not substitute-specific scoring or single-player overperformance.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_shooting_goals_the_brace_battle.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_shooting_goals_the_brace_battle`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_shooting_goals_the_brace_battle
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for deduplication and downstream joins. |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills. |
| `home_team_id` | Home team identifier | Preserves fixture context. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves fixture context. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Outcome context for brace-battle interpretation. |
| `away_score` | Full-time away goals | Outcome context for brace-battle interpretation. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity at `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Side-oriented join key for downstream models. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side attribution. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator context. |
| `trigger_threshold_min_goals_per_brace_scorer` | Minimum goals required for brace scorer (`2`) | Explicit trigger provenance for QA and auditability. |
| `trigger_threshold_min_brace_scorers_per_team` | Minimum brace scorers required per side (`1`) | Documents bilateral trigger symmetry requirement. |
| `match_total_brace_scorers` | Combined count of brace scorers across both teams | Core trigger magnitude for scorer-distribution intensity. |
| `match_total_goals_by_brace_scorers` | Combined non-own goals scored by brace scorers | Measures aggregate output contributed by qualifying players. |
| `home_brace_scorers_count` | Number of home players with braces | Trigger decomposition for home side. |
| `away_brace_scorers_count` | Number of away players with braces | Trigger decomposition for away side. |
| `triggered_team_brace_scorers_count` | Triggered-side brace-scorer count | Side-oriented brace density context. |
| `opponent_brace_scorers_count` | Opponent brace-scorer count | Bilateral brace-density comparator. |
| `brace_scorers_count_delta` | Triggered minus opponent brace-scorer count | Net scorer-depth differential between teams. |
| `triggered_team_goals_by_brace_scorers` | Triggered-side goals from brace scorers | Side contribution from high-output individual finishers. |
| `opponent_goals_by_brace_scorers` | Opponent goals from brace scorers | Bilateral high-output contribution comparator. |
| `goals_by_brace_scorers_delta` | Triggered minus opponent goals by brace scorers | Net brace-finishing contribution differential. |
| `triggered_team_top_brace_scorer_player_id` | Player ID of triggered side's top brace scorer | Stable identity anchor for top individual contributor. |
| `triggered_team_top_brace_scorer_player_name` | Player name of triggered side's top brace scorer | Human-readable top-scorer attribution. |
| `triggered_team_top_brace_scorer_goals` | Goal count of triggered side's top brace scorer | Peak individual finishing intensity on triggered side. |
| `opponent_top_brace_scorer_player_id` | Player ID of opponent top brace scorer | Stable bilateral identity comparator. |
| `opponent_top_brace_scorer_player_name` | Player name of opponent top brace scorer | Human-readable bilateral top-scorer comparator. |
| `opponent_top_brace_scorer_goals` | Goal count of opponent top brace scorer | Bilateral peak finishing comparator. |
| `triggered_team_goals` | Full-time goals scored by triggered side | Team outcome context from triggered perspective. |
| `opponent_goals` | Full-time goals scored by opponent | Bilateral outcome comparator. |
| `goal_delta` | Triggered minus opponent goals | Scoreline edge from triggered perspective. |
| `triggered_team_total_shots` | Triggered-side total shots | Attacking-volume context behind brace output. |
| `opponent_total_shots` | Opponent total shots | Bilateral volume comparator. |
| `shot_volume_delta` | Triggered minus opponent shots | Net shot-pressure differential. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Side precision volume context. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral precision-volume comparator. |
| `shot_on_target_delta` | Triggered minus opponent shots on target | Net on-target execution differential. |
| `triggered_team_shot_accuracy_pct` | Triggered-side on-target rate (%) | Normalized side-level precision metric. |
| `opponent_shot_accuracy_pct` | Opponent on-target rate (%) | Bilateral normalized precision comparator. |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Compact shooting-execution differential. |
| `triggered_team_shot_conversion_pct` | Triggered-side goals per shot (%) | Side finishing-efficiency context. |
| `opponent_shot_conversion_pct` | Opponent goals per shot (%) | Bilateral finishing-efficiency comparator. |
| `shot_conversion_delta_pct` | Triggered minus opponent shot conversion (percentage points) | Net finishing differential. |
| `triggered_team_xg` | Triggered-side expected goals | Side-level chance-quality baseline. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator. |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-generation balance. |
| `triggered_team_big_chances` | Triggered-side big chances | High-value chance context for triggered side. |
| `opponent_big_chances` | Opponent big chances | Bilateral high-value chance comparator. |
| `big_chance_delta` | Triggered minus opponent big chances | Net clear-chance differential. |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Territorial penetration context. |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial comparator. |
| `opposition_box_touch_delta` | Triggered minus opponent opposition-box touches | Net box-access differential. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context around brace battle dynamics. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Technical execution quality context. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral technical execution comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Net ball-retention execution differential. |
