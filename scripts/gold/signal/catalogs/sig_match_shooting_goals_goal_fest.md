---
signal_id: sig_match_shooting_goals_goal_fest
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Goal Fest"
trigger: "Combined match goals >= 6 in period `All`."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_match_shooting_goals_goal_fest
  sql: clickhouse/gold/signal/sig_match_shooting_goals_goal_fest.sql
  runner: scripts/gold/signal/runners/sig_match_shooting_goals_goal_fest.py
---
# sig_match_shooting_goals_goal_fest

## Purpose

Flag extreme high-scoring matches (6+ total goals) and expose side-oriented shooting and control context to explain how each team participated in the goal-heavy game state.

## Tactical And Statistical Logic

- Trigger condition: `coalesce(home_score, 0) + coalesce(away_score, 0) >= 6` with `period = 'All'`.
- Match-level trigger emits two rows (`triggered_side = 'home'` and `'away'`) so downstream team-level consumers keep canonical `match_team` grain.
- Enrichment emphasizes finishing profile (`shot_conversion_pct`, `goals_minus_xg`), shot quality/volume (`shots_on_target`, `big_chances`, `xg`), and control context (`possession_pct`, `pass_accuracy_pct`, `touches_opposition_box`).
- Similarity gate note: closest active signals are `sig_match_possession_passing_clinical_match` and `sig_team_shooting_goals_shooting_gallery`; this signal is distinct because it is match-level and trigger-first on raw combined goals (`>= 6`) without requiring an xG ceiling or team-specific shot-volume threshold.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_shooting_goals_goal_fest.sql`
- Runner: `scripts/gold/signal/runners/sig_match_shooting_goals_goal_fest.py`
- Target table: `gold.sig_match_shooting_goals_goal_fest`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_shooting_goals_goal_fest.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for joins and deduplication. |
| `match_date` | Match date | Supports batch slicing and temporal analysis. |
| `home_team_id` | Home team identifier | Preserves full fixture context. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves full fixture context. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Scoreline context behind the trigger. |
| `away_score` | Full-time away goals | Scoreline context behind the trigger. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity for `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Team-oriented join key. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-team context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral context. |
| `trigger_threshold_match_total_goals` | Configured goals threshold (`6`) | Explicit trigger provenance for QA. |
| `match_total_goals` | Combined goals in the match | Core trigger magnitude. |
| `match_total_xg` | Combined expected goals | Chance-quality baseline for total scoring. |
| `match_goal_minus_xg` | Combined goals minus combined xG | Match-level finishing over/under-performance measure. |
| `triggered_team_goals` | Goals scored by triggered side | Side-level score contribution. |
| `opponent_goals` | Goals scored by opponent | Bilateral score comparator. |
| `goal_gap` | Triggered goals minus opponent goals | Outcome edge context. |
| `triggered_team_goal_share_pct` | Triggered-side share of match goals (%) | Normalized contribution to goal fest profile. |
| `opponent_goal_share_pct` | Opponent share of match goals (%) | Symmetric normalized comparator. |
| `goal_share_delta_pct` | Triggered minus opponent goal share (percentage points) | Compact scoring-balance diagnostic. |
| `triggered_team_xg` | Triggered-side expected goals | Side-level chance-quality baseline. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator. |
| `xg_gap` | Triggered xG minus opponent xG | Net chance-generation balance. |
| `triggered_team_goals_minus_xg` | Triggered-side goals minus xG | Side finishing over/under-performance metric. |
| `opponent_goals_minus_xg` | Opponent goals minus xG | Bilateral finishing comparator. |
| `goals_minus_xg_gap` | Triggered minus opponent goals-minus-xG | Identifies which side exceeded chance quality more. |
| `triggered_team_total_shots` | Triggered-side total shots | Shot-volume context. |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator. |
| `shot_volume_delta` | Triggered minus opponent total shots | Net attacking-volume differential. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Shot precision context. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral precision comparator. |
| `triggered_team_shot_accuracy_pct` | Triggered-side on-target rate (%) | Normalized shot precision metric. |
| `opponent_shot_accuracy_pct` | Opponent on-target rate (%) | Bilateral normalized precision comparator. |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Net precision differential. |
| `triggered_team_shot_conversion_pct` | Triggered-side goals per shot (%) | Finishing efficiency context. |
| `opponent_shot_conversion_pct` | Opponent goals per shot (%) | Bilateral finishing efficiency comparator. |
| `shot_conversion_delta_pct` | Triggered minus opponent shot conversion (percentage points) | Net conversion edge diagnostic. |
| `triggered_team_big_chances` | Triggered-side big chances | High-quality chance volume context. |
| `opponent_big_chances` | Opponent big chances | Bilateral high-quality chance comparator. |
| `triggered_team_big_chances_missed` | Triggered-side big chances missed | Wastefulness context under high scoring. |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness comparator. |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Territorial penetration context. |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-circulation quality context. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation-quality comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Net technical-execution differential. |
