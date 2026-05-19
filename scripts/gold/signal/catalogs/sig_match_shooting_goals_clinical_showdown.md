---
signal_id: sig_match_shooting_goals_clinical_showdown
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Clinical Showdown"
trigger: "Combined match goals >= 4 and full-time combined xG < 1.5 (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_match_shooting_goals_clinical_showdown
  sql: clickhouse/gold/signal/sig_match_shooting_goals_clinical_showdown.sql
  runner: scripts/gold/signal/runners/sig_match_shooting_goals_clinical_showdown.py
---
# sig_match_shooting_goals_clinical_showdown

## Purpose

Detect matches where finishing output is extremely clinical relative to chance quality (4+ combined goals from <1.5 combined xG), then expose bilateral team context for overperformance and execution diagnostics.

## Tactical And Statistical Logic

- Trigger condition: `(coalesce(home_score, 0) + coalesce(away_score, 0)) >= 4` and `(coalesce(expected_goals_home, 0) + coalesce(expected_goals_away, 0)) < 1.5` at `period = 'All'`.
- Match-level trigger emits two rows (`triggered_side = 'home'` and `'away'`) to preserve canonical `match_team` grain for downstream modeling and feature joins.
- Enrichment emphasizes goals-versus-xG overperformance, bilateral shot and on-target volume, conversion efficiency, big-chance usage, and possession/passing control context.
- Similarity gate note: nearest active signals are `sig_match_shooting_goals_goal_fest` and `sig_match_shooting_goals_high_xg_low_score`; this signal remains distinct because it requires a strict *low* combined xG ceiling (`< 1.5`) together with a *high* combined goals floor (`>= 4`), capturing extreme clinical finishing rather than high-event creation or low-score waste.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_shooting_goals_clinical_showdown.sql`
- Runner: `scripts/gold/signal/runners/sig_match_shooting_goals_clinical_showdown.py`
- Target table: `gold.sig_match_shooting_goals_clinical_showdown`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_shooting_goals_clinical_showdown.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for deduplication, QA, and downstream joins. |
| `match_date` | Match date | Enables reproducible backfills and time-based analysis. |
| `home_team_id` | Home team identifier | Preserves fixture-level match context. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves fixture-level match context. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Required to validate the high-goal trigger component. |
| `away_score` | Full-time away goals | Required to validate the high-goal trigger component. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity at `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Side-level team join key. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-team context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator context. |
| `trigger_threshold_match_total_xg_max` | Configured combined xG ceiling (`1.5`) | Makes the low-chance trigger bound explicit for auditability. |
| `trigger_threshold_match_total_goals_min` | Configured combined-goals floor (`4`) | Makes the high-output trigger bound explicit for QA checks. |
| `match_total_xg` | Combined expected goals | Core trigger magnitude for chance-quality scarcity. |
| `match_total_goals` | Combined full-time goals | Core trigger outcome for scoring overproduction. |
| `match_goal_minus_xg` | Combined goals minus combined xG | Primary match-level clinical-finishing overperformance metric. |
| `match_xg_minus_goals` | Combined xG minus combined goals | Inverse over/under-performance diagnostic. |
| `triggered_team_goals` | Goals scored by triggered side | Side-level score contribution in clinical-finishing context. |
| `opponent_goals` | Goals scored by opponent | Bilateral score comparator. |
| `goal_gap` | Triggered goals minus opponent goals | Outcome-edge context in high-scoring matches. |
| `triggered_team_xg` | Triggered-side expected goals | Side-level chance-quality contribution. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator. |
| `xg_gap` | Triggered xG minus opponent xG | Net chance-generation balance by side. |
| `triggered_team_goals_minus_xg` | Triggered-side goals minus xG | Side-specific clinical-finishing over/under-performance metric. |
| `opponent_goals_minus_xg` | Opponent goals minus xG | Bilateral finishing-performance comparator. |
| `goals_minus_xg_gap` | Triggered minus opponent goals-minus-xG | Directional finishing-efficiency differential. |
| `triggered_team_total_shots` | Triggered-side total shots | Side-level attacking volume context. |
| `opponent_total_shots` | Opponent total shots | Bilateral attacking-volume comparator. |
| `shot_volume_delta` | Triggered minus opponent total shots | Net shot-pressure differential. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Side-level shot precision contribution. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral precision comparator. |
| `shot_on_target_delta` | Triggered minus opponent shots on target | Net on-target differential for finishing diagnostics. |
| `triggered_team_shot_accuracy_pct` | Triggered-side on-target rate (%) | Normalized shot precision metric. |
| `opponent_shot_accuracy_pct` | Opponent on-target rate (%) | Bilateral normalized precision comparator. |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Compact precision differential for analysis. |
| `triggered_team_shot_conversion_pct` | Triggered-side goals per shot (%) | Side-level conversion efficiency context. |
| `opponent_shot_conversion_pct` | Opponent goals per shot (%) | Bilateral conversion-efficiency comparator. |
| `shot_conversion_delta_pct` | Triggered minus opponent shot conversion (percentage points) | Net finishing-execution differential. |
| `triggered_team_big_chances` | Triggered-side big chances | High-quality chance volume by side. |
| `opponent_big_chances` | Opponent big chances | Bilateral high-quality chance comparator. |
| `triggered_team_big_chances_missed` | Triggered-side big chances missed | Wastefulness context under clinical scorelines. |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness comparator. |
| `big_chances_missed_delta` | Triggered minus opponent big chances missed | Net chance-waste differential. |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Territorial penetration context behind finishing output. |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context in clinical high-output matches. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-circulation quality context. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation-quality comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Technical execution differential for diagnostics. |
