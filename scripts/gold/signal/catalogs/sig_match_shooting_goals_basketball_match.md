---
signal_id: sig_match_shooting_goals_basketball_match
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Basketball Match"
trigger: "Both teams record >= 20 total shots in full match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_shooting_goals_basketball_match
  sql: clickhouse/gold/dml/signals/match/sig_match_shooting_goals_basketball_match.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_match_shooting_goals_basketball_match

## Purpose

Flag end-to-end matches where both sides sustain very high shot volume (20+ each), then expose side-oriented context to explain whether the shot-trading pattern came from balanced attacking pressure or asymmetric finishing quality.

## Tactical And Statistical Logic

- Trigger condition: `coalesce(total_shots_home, 0) >= 20` and `coalesce(total_shots_away, 0) >= 20` at `period = 'All'`.
- Emits one row per side (`triggered_side in {'home', 'away'}`) to preserve canonical `match_team` grain and keep downstream features team-oriented.
- Enrichment emphasizes bilateral shot volume, on-target execution, xG and big-chance quality, plus possession and passing context.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_shooting_gallery` and `sig_match_shooting_goals_goal_fest`; this signal is distinct because it is match-level and requires both teams to clear a symmetric shot threshold (`>= 20` each), rather than one-side-only volume or a goals-first trigger.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_shooting_goals_basketball_match.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_match_shooting_goals_basketball_match`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_match_shooting_goals_basketball_match
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for joins, deduplication, and QA checks. |
| `match_date` | Match date | Supports temporal slicing and reproducible backfills. |
| `home_team_id` | Home team identifier | Preserves full fixture context for bilateral analysis. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves full fixture context for bilateral analysis. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Scoreline context around high-volume shot trading. |
| `away_score` | Full-time away goals | Scoreline context around high-volume shot trading. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical row identity for `match_team` grain. |
| `triggered_team_id` | Triggered-side team identifier | Team-oriented join key for side-specific modeling. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key. |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator context. |
| `trigger_threshold_total_shots_each_team` | Configured per-team shot threshold (`20`) | Explicit trigger provenance for validation and explainability. |
| `home_total_shots` | Home side full-match total shots | Raw trigger input transparency for home-side condition. |
| `away_total_shots` | Away side full-match total shots | Raw trigger input transparency for away-side condition. |
| `match_total_shots` | Combined full-match shots | Captures total pace and attacking intensity in the fixture. |
| `shot_balance_gap` | Absolute home-away shot gap | Diagnoses balance versus one-sided shot accumulation within the trigger. |
| `triggered_team_total_shots` | Triggered-side total shots | Side-oriented shot-volume context. |
| `opponent_total_shots` | Opponent total shots | Side-oriented bilateral shot-volume comparator. |
| `total_shots_delta` | Triggered minus opponent total shots | Net shot-volume dominance indicator. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Precision context behind shot volume. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral precision comparator. |
| `triggered_team_shot_accuracy_pct` | Triggered-side on-target rate (%) | Normalized finishing precision metric. |
| `opponent_shot_accuracy_pct` | Opponent on-target rate (%) | Bilateral normalized precision comparator. |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Net precision differential for tactical interpretation. |
| `triggered_team_big_chances` | Triggered-side big chances | High-quality chance volume context. |
| `opponent_big_chances` | Opponent big chances | Bilateral high-quality chance comparator. |
| `triggered_team_big_chances_missed` | Triggered-side big chances missed | Wastefulness diagnostic under high shooting volume. |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness comparator. |
| `triggered_team_xg` | Triggered-side expected goals | Chance-quality baseline for side-oriented interpretation. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator. |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-generation balance. |
| `triggered_team_xg_per_shot` | Triggered-side xG per shot | Average chance quality per attempt for triggered side. |
| `opponent_xg_per_shot` | Opponent xG per shot | Bilateral average chance-quality comparator. |
| `xg_per_shot_delta` | Triggered minus opponent xG per shot | Net shot-quality efficiency differential. |
| `triggered_team_goals` | Goals scored by triggered side | Outcome contribution from triggered orientation. |
| `opponent_goals` | Goals scored by opponent | Bilateral scoreline comparator. |
| `goal_gap` | Triggered goals minus opponent goals | Outcome-edge context for interpreting shot-trade results. |
| `triggered_team_shot_conversion_pct` | Triggered-side goals per shot (%) | Finishing efficiency context. |
| `opponent_shot_conversion_pct` | Opponent goals per shot (%) | Bilateral finishing efficiency comparator. |
| `shot_conversion_delta_pct` | Triggered minus opponent shot conversion (percentage points) | Net finishing execution differential. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context behind shot volume. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Ball-circulation quality context for high-event matches. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation-quality comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Technical execution differential. |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Territorial penetration context behind shot volume. |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator. |
