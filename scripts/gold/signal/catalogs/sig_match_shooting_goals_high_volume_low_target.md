---
signal_id: sig_match_shooting_goals_high_volume_low_target
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "High Volume, Low Target"
trigger: "Combined shots >= 40 while combined shots on target < 5 in full match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_shooting_goals_high_volume_low_target
  sql: clickhouse/gold/signal/sig_match_shooting_goals_high_volume_low_target.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_shooting_goals_high_volume_low_target

## Purpose

Identify chaotic, low-precision matches where total shooting volume is very high but collective on-target execution is extremely poor, then expose side-oriented context for shot quality, finishing waste, and control diagnostics.

## Tactical And Statistical Logic

- Trigger condition: `(coalesce(total_shots_home, 0) + coalesce(total_shots_away, 0)) >= 40` and `(coalesce(shots_on_target_home, 0) + coalesce(shots_on_target_away, 0)) < 5` at `period = 'All'` in finished matches.
- Match-level trigger emits two rows (`triggered_side = 'home'` and `'away'`) to preserve canonical `match_team` grain for downstream feature joins.
- Enrichment keeps bilateral explainability with shot share, shot-accuracy, xG-per-shot, conversion, big-chance waste, box touches, possession, and pass quality.
- Similarity gate note: closest active signals are `sig_match_shooting_goals_basketball_match` and `sig_match_shooting_goals_goalless_siege`; this signal is distinct because it is explicitly a *joint inefficiency* trigger (very high combined shot volume with very low combined shots on target), rather than bilateral high-volume tempo or goalless-only siege conditions.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_shooting_goals_high_volume_low_target.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_shooting_goals_high_volume_low_target`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_shooting_goals_high_volume_low_target
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for deduplication, QA, and downstream joins. |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills. |
| `home_team_id` | Home team identifier | Preserves fixture context for bilateral match analysis. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves fixture context for bilateral match analysis. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Scoreline context around low-target shot chaos. |
| `away_score` | Full-time away goals | Scoreline context around low-target shot chaos. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity for `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Side-level join key for downstream models and QA. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator context. |
| `trigger_threshold_match_total_shots_min` | Configured minimum combined shots (`40`) | Makes the high-volume boundary explicit for audits. |
| `trigger_threshold_match_total_shots_on_target_max` | Configured maximum combined shots on target (`4`) | Encodes the strict low-target ceiling for transparent validation. |
| `match_total_shots` | Combined shots by both teams | Core volume input of the trigger. |
| `match_total_shots_on_target` | Combined shots on target by both teams | Core precision input of the trigger. |
| `match_total_shot_accuracy_pct` | Combined match on-target rate (%) | Normalized measure of overall shooting precision collapse. |
| `match_total_xg` | Combined expected goals | Chance-quality baseline for interpreting whether poor targeting also reduced chance value. |
| `match_total_goals` | Combined full-time goals | Outcome context to compare process inefficiency versus final scoreline. |
| `triggered_team_total_shots` | Triggered-side total shots | Side-oriented shot-volume context. |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator. |
| `shot_volume_delta` | Triggered minus opponent total shots | Net attacking-volume differential. |
| `triggered_team_shot_share_pct` | Triggered-side share of combined shots (%) | Normalized side contribution to match volume. |
| `opponent_shot_share_pct` | Opponent share of combined shots (%) | Bilateral normalized shot-share comparator. |
| `shot_share_delta_pct` | Triggered minus opponent shot share (percentage points) | Compact pressure-balance diagnostic. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Side-level precision context. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral precision comparator. |
| `shot_on_target_delta` | Triggered minus opponent shots on target | Net on-target differential. |
| `triggered_team_shot_accuracy_pct` | Triggered-side on-target rate (%) | Normalized side-level shot precision metric. |
| `opponent_shot_accuracy_pct` | Opponent on-target rate (%) | Bilateral normalized precision comparator. |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Directional precision gap for tactical interpretation. |
| `triggered_team_xg` | Triggered-side expected goals | Side-level chance-quality contribution. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator. |
| `xg_gap` | Triggered minus opponent expected goals | Net chance-generation differential. |
| `triggered_team_xg_per_shot` | Triggered-side xG per shot | Average chance quality per attempt on triggered side. |
| `opponent_xg_per_shot` | Opponent xG per shot | Bilateral average chance-quality comparator. |
| `xg_per_shot_delta` | Triggered minus opponent xG per shot | Net shot-quality efficiency differential. |
| `triggered_team_goals` | Goals scored by triggered side | Side-level outcome contribution. |
| `opponent_goals` | Goals scored by opponent | Bilateral outcome comparator. |
| `goal_gap` | Triggered minus opponent goals | Outcome differential from triggered-side perspective. |
| `triggered_team_shot_conversion_pct` | Triggered-side goals per shot (%) | Finishing-efficiency normalization for triggered side. |
| `opponent_shot_conversion_pct` | Opponent goals per shot (%) | Bilateral finishing-efficiency comparator. |
| `shot_conversion_delta_pct` | Triggered minus opponent shot conversion (percentage points) | Net finishing execution differential. |
| `triggered_team_big_chances` | Triggered-side big chances | High-value chance count for triggered side. |
| `opponent_big_chances` | Opponent big chances | Bilateral high-value chance comparator. |
| `big_chance_delta` | Triggered minus opponent big chances | Net big-chance generation edge. |
| `triggered_team_big_chances_missed` | Triggered-side big chances missed | Wastefulness context for triggered side. |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness comparator. |
| `big_chances_missed_delta` | Triggered minus opponent big chances missed | Net wastefulness differential. |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Territorial penetration context behind shot volume. |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator. |
| `opposition_box_touch_delta` | Triggered minus opponent opposition-box touches | Net box-access differential. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context around high-volume low-target patterns. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Circulation-quality context for shot build-up phases. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation-quality comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Technical execution differential. |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Side-level circulation workload context. |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation-volume comparator. |
| `pass_attempt_delta` | Triggered minus opponent pass attempts | Net circulation-load differential. |
