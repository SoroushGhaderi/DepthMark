---
signal_id: sig_match_shooting_goals_high_xg_low_score
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "High xG, Low Score Shock"
trigger: "Combined match xG > 4.0 and full-time combined goals <= 1 (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_shooting_goals_high_xg_low_score
  sql: clickhouse/gold/dml/signals/match/sig_match_shooting_goals_high_xg_low_score.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_shooting_goals_high_xg_low_score

## Purpose

Detect matches with extreme combined chance creation but very low scoring output, then expose bilateral team context to diagnose collective finishing collapse and shot-conversion underperformance.

## Tactical And Statistical Logic

- Trigger condition: `(coalesce(expected_goals_home, 0) + coalesce(expected_goals_away, 0)) > 4.0` and `(coalesce(home_score, 0) + coalesce(away_score, 0)) <= 1` at `period = 'All'`.
- Match-level trigger emits two rows (`triggered_side = 'home'` and `'away'`) to preserve canonical `match_team` grain for downstream modeling and feature joins.
- Enrichment emphasizes xG-versus-goals inefficiency, bilateral shot and on-target volume, conversion rate, big-chance waste, plus possession and pass-accuracy context.
- Similarity gate note: nearest active signals are `sig_match_shooting_goals_goal_fest` and `sig_match_shooting_goals_boring_stalemate`; this signal remains distinct because it requires an extreme high combined xG floor (`> 4.0`) with a strict low-score cap (`<= 1`), focusing on missed-finishing outcomes rather than high scoring or low-event stalemates.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_shooting_goals_high_xg_low_score.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_shooting_goals_high_xg_low_score`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_shooting_goals_high_xg_low_score
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
| `home_score` | Full-time home goals | Required to validate low-score trigger outcome. |
| `away_score` | Full-time away goals | Required to validate low-score trigger outcome. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity at `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Side-level team join key. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-team context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator context. |
| `trigger_threshold_match_total_xg` | Configured combined xG floor (`4.0`) | Makes trigger provenance explicit for auditability. |
| `trigger_threshold_match_total_goals_max` | Configured combined-goals cap (`1`) | Makes low-score trigger bound explicit for QA checks. |
| `match_total_xg` | Combined expected goals | Core trigger magnitude for chance-creation intensity. |
| `match_total_goals` | Combined full-time goals | Core trigger outcome for score suppression. |
| `match_goal_minus_xg` | Combined goals minus combined xG | Match-level finishing under/over-performance summary. |
| `match_xg_minus_goals` | Combined xG minus combined goals | Positive shortfall diagnostic for missed finishing. |
| `triggered_team_goals` | Goals scored by triggered side | Side-level score contribution in low-score context. |
| `opponent_goals` | Goals scored by opponent | Bilateral score comparator. |
| `goal_gap` | Triggered goals minus opponent goals | Outcome-edge context despite low total scoring. |
| `triggered_team_xg` | Triggered-side expected goals | Side-level chance-quality contribution to trigger. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator. |
| `xg_gap` | Triggered xG minus opponent xG | Net chance-generation balance by side. |
| `triggered_team_goals_minus_xg` | Triggered-side goals minus xG | Side-specific finishing under/over-performance metric. |
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
| `triggered_team_shot_conversion_pct` | Triggered-side goals per shot (%) | Side-level finishing efficiency context. |
| `opponent_shot_conversion_pct` | Opponent goals per shot (%) | Bilateral finishing-efficiency comparator. |
| `shot_conversion_delta_pct` | Triggered minus opponent shot conversion (percentage points) | Net finishing-execution differential. |
| `triggered_team_big_chances` | Triggered-side big chances | High-quality chance volume by side. |
| `opponent_big_chances` | Opponent big chances | Bilateral high-quality chance comparator. |
| `triggered_team_big_chances_missed` | Triggered-side big chances missed | Wastefulness signal under high-xG conditions. |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness comparator. |
| `big_chances_missed_delta` | Triggered minus opponent big chances missed | Net chance-waste differential. |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Territorial penetration context behind high xG. |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context in high-event low-score matches. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-circulation quality context. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation-quality comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Technical execution differential for diagnostics. |
