---
signal_id: sig_match_shooting_goals_shot_efficiency_parity
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Shot Efficiency Parity"
trigger: "Both teams have identical shots on target and identical full-time goals (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_shooting_goals_shot_efficiency_parity
  sql: clickhouse/gold/dml/signals/match/sig_match_shooting_goals_shot_efficiency_parity.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_shooting_goals_shot_efficiency_parity

## Purpose

Detect finished matches where both teams end with identical shots on target and identical goals, then provide bilateral context to explain whether parity came from mirrored chance quality or offsetting tactical paths.

## Tactical And Statistical Logic

- Trigger condition: `coalesce(shots_on_target_home, 0) = coalesce(shots_on_target_away, 0)` and `coalesce(home_score, 0) = coalesce(away_score, 0)` at `period = 'All'`.
- Emits two rows per triggered match (`triggered_side = 'home'` and `'away'`) to keep canonical `match_team` grain for downstream joins.
- Enrichment focuses on parity diagnostics: goals per shot on target, total-shot and xG asymmetry, goals-minus-xG balance, big-chance usage, box-touch pressure, and control/circulation context.
- Similarity gate note: nearest active signals are `sig_match_shooting_goals_boring_stalemate` and `sig_match_shooting_goals_basketball_match`; this signal is distinct because it requires dual equality on *both* outcome (`goals`) and execution proxy (`shots on target`) regardless of event volume.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_shooting_goals_shot_efficiency_parity.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_shooting_goals_shot_efficiency_parity`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_shooting_goals_shot_efficiency_parity
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable primary join key for analytics and deduplication. |
| `match_date` | Match date | Enables backfill reproducibility and time-slicing. |
| `home_team_id` | Home team identifier | Preserves fixture context for bilateral analysis. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves fixture context for bilateral analysis. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Home full-time goals | Confirms score-parity trigger side of the rule. |
| `away_score` | Away full-time goals | Confirms score-parity trigger side of the rule. |
| `triggered_side` | Row orientation (`home` or `away`) | Canonical identity dimension at `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Side-level team key for downstream feature joins. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-team context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison join key. |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator context. |
| `trigger_threshold_abs_shots_on_target_delta` | Configured shots-on-target parity threshold (`0`) | Makes trigger boundary explicit for QA and contract checks. |
| `trigger_threshold_abs_goal_delta` | Configured goal parity threshold (`0`) | Makes scoreline parity boundary explicit for QA and audits. |
| `match_total_goals` | Combined goals in the match | Separates low-event and high-event parity outcomes. |
| `match_total_shots_on_target` | Combined shots on target | Captures total precision-event volume for parity matches. |
| `match_total_shots` | Combined total shots | Adds volume context behind identical on-target output. |
| `match_total_xg` | Combined expected goals | Quantifies total chance quality under parity conditions. |
| `home_shots_on_target` | Home shots on target | Direct audit field for trigger verification. |
| `away_shots_on_target` | Away shots on target | Direct audit field for trigger verification. |
| `home_goals` | Home goals as integer context field | Supports direct scoreline parity diagnostics. |
| `away_goals` | Away goals as integer context field | Supports direct scoreline parity diagnostics. |
| `triggered_team_goals` | Triggered-side goals | Side-oriented scoring contribution. |
| `opponent_goals` | Opponent goals | Bilateral scoring comparator. |
| `goal_gap` | Triggered minus opponent goals | Directional score differential sanity check. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Side-level precision-event contribution. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral precision-event comparator. |
| `shot_on_target_delta` | Triggered minus opponent shots on target | Trigger-invariant parity gap check (expected zero). |
| `triggered_team_goal_per_shot_on_target_pct` | Triggered-side goals per shot on target (%) | Direct shot-efficiency realization metric. |
| `opponent_goal_per_shot_on_target_pct` | Opponent goals per shot on target (%) | Bilateral efficiency comparator. |
| `goal_per_shot_on_target_delta_pct` | Triggered minus opponent goals-per-shot-on-target (pp) | Compact differential for finishing parity diagnostics. |
| `triggered_team_total_shots` | Triggered-side total shots | Attacking volume context beyond on-target equality. |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator. |
| `shot_volume_delta` | Triggered minus opponent total shots | Reveals volume asymmetry hidden by parity outcome. |
| `triggered_team_shot_accuracy_pct` | Triggered-side on-target rate (%) | Normalized shot precision context. |
| `opponent_shot_accuracy_pct` | Opponent on-target rate (%) | Bilateral precision-rate comparator. |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (pp) | Highlights precision path differences under parity. |
| `triggered_team_shot_conversion_pct` | Triggered-side goals per shot (%) | Standard finishing conversion context. |
| `opponent_shot_conversion_pct` | Opponent goals per shot (%) | Bilateral conversion comparator. |
| `shot_conversion_delta_pct` | Triggered minus opponent shot conversion (pp) | Captures finishing differential from total-shot basis. |
| `triggered_team_xg` | Triggered-side expected goals | Side-level chance-quality contribution. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator. |
| `xg_delta` | Triggered minus opponent xG | Net chance-generation edge despite parity outcomes. |
| `triggered_team_goals_minus_xg` | Triggered-side goals minus xG | Side-level finishing over/under-performance diagnostic. |
| `opponent_goals_minus_xg` | Opponent goals minus xG | Bilateral finishing-performance comparator. |
| `goals_minus_xg_delta` | Triggered minus opponent goals-minus-xG | Directional finishing-efficiency imbalance measure. |
| `triggered_team_big_chances` | Triggered-side big chances | High-quality chance volume by side. |
| `opponent_big_chances` | Opponent big chances | Bilateral high-quality chance comparator. |
| `big_chance_delta` | Triggered minus opponent big chances | Net big-chance generation differential. |
| `triggered_team_big_chances_missed` | Triggered-side big chances missed | Wastefulness context for triggered side. |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness comparator. |
| `big_chances_missed_delta` | Triggered minus opponent big chances missed | Net chance-waste differential. |
| `triggered_team_touches_opposition_box` | Triggered-side opposition-box touches | Penalty-area access context behind parity outcomes. |
| `opponent_touches_opposition_box` | Opponent opposition-box touches | Bilateral box-access comparator. |
| `opposition_box_touch_delta` | Triggered minus opponent opposition-box touches | Territorial-pressure differential. |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Control-share context in parity matches. |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (pp) | Net control differential for tactical interpretation. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Circulation execution quality context. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation-quality comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Technical execution differential under parity. |
