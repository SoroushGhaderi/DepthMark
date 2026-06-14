---
signal_id: sig_match_shooting_goals_complete_dominance
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Complete xG Dominance"
trigger: "Triggered-side xG is at least 10x opponent xG in a finished match (`period = 'All'`); opponent xG = 0 also qualifies when triggered-side xG > 0."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_shooting_goals_complete_dominance
  sql: clickhouse/gold/dml/signals/match/sig_match_shooting_goals_complete_dominance.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_shooting_goals_complete_dominance

## Purpose

Detect extreme one-sided chance-quality control where one team generates at least ten times the opponent xG, then emit side-oriented diagnostics for finishing, shot profile, and control context.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_xg > 0`
  - `triggered_team_xg / opponent_xg >= 10.0`, or `opponent_xg = 0`
- Trigger is evaluated on `silver.period_stat` with `period = 'All'` and finished matches only.
- This signal emits only the qualifying side row (`triggered_side`) per match because the trigger is intrinsically side-specific.
- Enrichment keeps bilateral context with xG share, shot-volume/accuracy, conversion, big chances, box touches, possession, and pass-quality differentials.
- Similarity gate note: closest active signals are `sig_team_shooting_goals_shot_on_target_monopoly` and `sig_match_shooting_goals_high_xg_low_score`; this signal is distinct because it is purely xG-ratio based (>= 10x side imbalance) and does not require a specific scoreline or shots-on-target threshold.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_shooting_goals_complete_dominance.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_shooting_goals_complete_dominance`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_shooting_goals_complete_dominance
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable key for deduplication, QA, and downstream joins. |
| `match_date` | Match date | Enables reproducible backfills and time-based analysis. |
| `home_team_id` | Home team identifier | Preserves fixture context. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves fixture context. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Full-time home goals | Scoreline context around chance dominance. |
| `away_score` | Full-time away goals | Scoreline context around chance dominance. |
| `triggered_side` | Side orientation (`home` or `away`) | Canonical `match_team` row identity component. |
| `triggered_team_id` | Triggered-side team identifier | Side-oriented join key. |
| `triggered_team_name` | Triggered-side team name | Readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparator key. |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator context. |
| `trigger_threshold_min_xg_ratio` | Configured minimum xG ratio (`10.0`) | Explicit trigger provenance for auditability. |
| `match_total_xg` | Combined expected goals | Match-level chance-quality baseline for scale. |
| `match_total_goals` | Combined full-time goals | Outcome context for whether dominance translated to scoreline separation. |
| `triggered_team_goals` | Goals scored by triggered side | Side-level scoring output under dominant chance generation. |
| `opponent_goals` | Goals scored by opponent | Bilateral score comparator. |
| `goal_gap` | Triggered minus opponent goals | Net scoreline differential from triggered-side perspective. |
| `triggered_team_xg` | Triggered-side expected goals | Core numerator of the dominance trigger. |
| `opponent_xg` | Opponent expected goals | Core denominator comparator for dominance trigger. |
| `xg_gap` | Triggered minus opponent expected goals | Absolute chance-quality separation measure. |
| `triggered_to_opponent_xg_ratio` | Triggered-side xG divided by opponent xG (`999.0` when opponent xG = 0) | Primary dominance-intensity ranking metric aligned with trigger logic. |
| `opponent_zero_xg_flag` | 1 when opponent xG = 0, else 0 | Disambiguates ratio rows with zero-denominator opponents. |
| `triggered_team_xg_share_pct` | Triggered-side share of combined xG (%) | Normalized dominance share robust to match pace. |
| `opponent_xg_share_pct` | Opponent share of combined xG (%) | Bilateral share comparator. |
| `xg_share_delta_pct` | Triggered minus opponent xG share (percentage points) | Compact normalized chance-control differential. |
| `triggered_team_total_shots` | Triggered-side total shots | Volume context behind xG dominance. |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator. |
| `shot_volume_delta` | Triggered minus opponent total shots | Net shooting-pressure differential. |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Shot-precision context for dominant side. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral precision comparator. |
| `shot_on_target_delta` | Triggered minus opponent shots on target | Net on-target execution differential. |
| `triggered_team_shot_accuracy_pct` | Triggered-side on-target rate (%) | Normalized shooting precision for triggered side. |
| `opponent_shot_accuracy_pct` | Opponent on-target rate (%) | Bilateral precision baseline. |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (percentage points) | Compact precision gap for diagnostics. |
| `triggered_team_shot_conversion_pct` | Triggered-side goals per shot (%) | Finishing efficiency context for triggered side. |
| `opponent_shot_conversion_pct` | Opponent goals per shot (%) | Bilateral finishing-efficiency comparator. |
| `shot_conversion_delta_pct` | Triggered minus opponent shot conversion (percentage points) | Net finishing-execution differential. |
| `triggered_team_big_chances` | Triggered-side big chances | High-quality chance volume behind dominance. |
| `opponent_big_chances` | Opponent big chances | Bilateral high-value chance comparator. |
| `big_chance_delta` | Triggered minus opponent big chances | Net clear-chance creation differential. |
| `triggered_team_big_chances_missed` | Triggered-side big chances missed | Wastefulness diagnostic on dominant side. |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness comparator. |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Territorial penetration context for dominance profile. |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial comparator. |
| `opposition_box_touch_delta` | Triggered minus opponent opposition-box touches | Net box-territory control differential. |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Control-share context around chance dominance. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Net control differential. |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Circulation-quality context for sustained control. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral circulation-quality comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Technical execution differential for modeling and QA. |
