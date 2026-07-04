---
signal_id: sig_match_shooting_goals_woodwork_record_match
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Woodwork Record Match"
trigger: "Combined match woodwork hits >= 5 (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_shooting_goals_woodwork_record_match
  sql: clickhouse/gold/dml/signals/match/sig_match_shooting_goals_woodwork_record_match.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_match_shooting_goals_woodwork_record_match

## Purpose

Flag extreme woodwork-heavy matches where finishing repeatedly strikes the post or crossbar (combined woodwork hits `>= 5`) and expose bilateral team context so analysts can distinguish severe finishing variance from broader chance-creation or control imbalance.

## Tactical And Statistical Logic

- Trigger condition: `coalesce(shots_woodwork_home, 0) + coalesce(shots_woodwork_away, 0) >= 5` at `period = 'All'` in finished matches.
- Match-level trigger emits two rows (`triggered_side = 'home'` and `'away'`) to preserve canonical `match_team` grain for downstream team-oriented features.
- Enrichment pairs woodwork-specific diagnostics (counts, share, and side delta) with chance-quality and execution context (`xg`, `goals_minus_xg`, shot accuracy, big chances, possession, and pass accuracy).
- Similarity gate note: closest active signals are `sig_match_shooting_goals_unlucky_game`, `sig_match_shooting_goals_high_volume_low_target`, and `sig_match_shooting_goals_shot_efficiency_parity`; this signal intentionally coexists as a stricter record-level woodwork variant (`>= 5`) focused on extreme shot-outcome variance.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_shooting_goals_woodwork_record_match.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_match_shooting_goals_woodwork_record_match`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_match_shooting_goals_woodwork_record_match
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for joins and deduplication. |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills. |
| `home_team_id` | Home team identifier | Preserves full fixture context. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves full fixture context. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Scoreline context for interpreting unlucky finishing patterns. |
| `away_score` | Full-time away goals | Scoreline context for interpreting unlucky finishing patterns. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity for `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Team-oriented join key. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral context. |
| `trigger_threshold_match_total_shots_woodwork` | Configured woodwork trigger threshold (`5`) | Explicit trigger provenance for QA and explainability. |
| `match_total_shots_woodwork` | Combined woodwork hits in the match | Core trigger magnitude for unlucky-finishing intensity. |
| `match_total_shots_woodwork_above_threshold` | Surplus woodwork hits above trigger minimum (`match_total_shots_woodwork - 5`) | Severity ranking beyond binary activation. |
| `match_total_goals` | Combined goals in the match | Outcome context relative to woodwork-heavy finishing. |
| `match_total_xg` | Combined expected goals | Match-level chance-quality baseline. |
| `triggered_team_shots_woodwork` | Woodwork hits by triggered side | Primary side-oriented trigger component. |
| `opponent_shots_woodwork` | Woodwork hits by opponent | Bilateral unlucky-finishing comparator. |
| `shots_woodwork_delta` | Triggered minus opponent woodwork hits | Net woodwork burden differential. |
| `triggered_team_shots_woodwork_share_pct` | Triggered-side share of combined woodwork hits (%) | Normalized side contribution to unlucky-finishing profile. |
| `opponent_shots_woodwork_share_pct` | Opponent share of combined woodwork hits (%) | Bilateral normalized comparator. |
| `shots_woodwork_share_delta_pct` | Triggered minus opponent woodwork share (percentage points) | Compact distribution-imbalance diagnostic. |
| `triggered_team_total_shots` | Total shots by triggered side | Volume context behind woodwork outcomes. |
| `opponent_total_shots` | Total shots by opponent | Bilateral shot-volume comparator. |
| `shot_volume_delta` | Triggered minus opponent total shots | Net attacking-volume differential. |
| `triggered_team_shots_on_target` | Shots on target by triggered side | Precision context around finishing luck. |
| `opponent_shots_on_target` | Shots on target by opponent | Bilateral precision comparator. |
| `shot_on_target_delta` | Triggered minus opponent shots on target | Net precision differential. |
| `triggered_team_shot_accuracy_pct` | Triggered-side on-target rate (%) | Normalized shot-precision metric. |
| `opponent_shot_accuracy_pct` | Opponent on-target rate (%) | Bilateral normalized precision comparator. |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Compact precision-edge diagnostic. |
| `triggered_team_goals` | Goals scored by triggered side | Side-level outcome contribution. |
| `opponent_goals` | Goals scored by opponent | Bilateral outcome comparator. |
| `goal_gap` | Triggered goals minus opponent goals | Outcome-edge context against woodwork variance. |
| `triggered_team_xg` | Triggered-side expected goals | Side-level chance-quality baseline. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator. |
| `xg_gap` | Triggered xG minus opponent xG | Net chance-generation differential. |
| `triggered_team_goals_minus_xg` | Triggered-side goals minus xG | Finishing over/under-performance for triggered side. |
| `opponent_goals_minus_xg` | Opponent goals minus xG | Bilateral finishing comparator. |
| `goals_minus_xg_gap` | Triggered minus opponent goals-minus-xG | Identifies which side under/over-finished more strongly. |
| `triggered_team_big_chances` | Big chances by triggered side | High-quality chance volume context. |
| `opponent_big_chances` | Big chances by opponent | Bilateral high-quality chance comparator. |
| `big_chance_delta` | Triggered minus opponent big chances | Net high-value chance differential. |
| `triggered_team_big_chances_missed` | Big chances missed by triggered side | Wastefulness context linked to unlucky outcomes. |
| `opponent_big_chances_missed` | Big chances missed by opponent | Bilateral wastefulness comparator. |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Territorial penetration context. |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator. |
| `opposition_box_touch_delta` | Triggered minus opponent opposition-box touches | Net final-third access differential. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context in woodwork-heavy matches. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-circulation quality context. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation-quality comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Technical execution differential for match-state interpretation. |
