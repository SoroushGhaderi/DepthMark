---
signal_id: sig_team_shooting_goals_woodwork_frustration_team
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Woodwork Frustration Team"
trigger: "Team hits woodwork >= 3 times in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_woodwork_frustration_team
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_woodwork_frustration_team.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_shooting_goals_woodwork_frustration_team

## Purpose

Detect team matches where one side repeatedly hits the post/crossbar (`>= 3` woodwork hits), surfacing frustrated finishing profiles despite meaningful shot and chance creation.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_shots_woodwork >= 3`
- Trigger is evaluated on finished matches only using full-match aggregates from `silver.period_stat` (`period = 'All'`).
- Signal keeps bilateral context with symmetric `triggered_team_*` and `opponent_*` metrics for woodwork burden, shot quality, conversion, possession, circulation, and pressure context.
- Similarity gate note: closest active signals are `sig_match_shooting_goals_unlucky_game`, `sig_team_shooting_goals_wasteful_box_presence`, and `sig_team_shooting_goals_conversion_collapse`; this signal intentionally coexists because it is team-side trigger-first on own woodwork volume (`>= 3`) rather than combined match woodwork, box-touch-plus-zero-goal criteria, or high on-target/low-goal conversion collapse.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_woodwork_frustration_team.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_shooting_goals_woodwork_frustration_team`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_woodwork_frustration_team
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join key and canonical row identity. |
| `match_date` | Match date | Temporal slicing and reproducible backfills. |
| `home_team_id` | Home team identifier | Preserves fixture orientation. |
| `home_team_name` | Home team name | Human-readable fixture context. |
| `away_team_id` | Away team identifier | Preserves fixture orientation. |
| `away_team_name` | Away team name | Human-readable fixture context. |
| `home_score` | Home full-time goals | Scoreline context around finishing frustration. |
| `away_score` | Away full-time goals | Scoreline context around finishing frustration. |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side orientation at `match_team` grain. |
| `triggered_team_id` | Triggered team identifier | Triggered-side identity key. |
| `triggered_team_name` | Triggered team name | Readable triggered-side context. |
| `opponent_team_id` | Opponent team identifier | Bilateral comparator key. |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator context. |
| `trigger_threshold_min_shots_woodwork` | Minimum woodwork threshold (`3`) | Explicit trigger provenance for QA and governance. |
| `match_total_shots_woodwork` | Combined woodwork hits by both teams | Context for share and distribution of woodwork burden. |
| `triggered_team_shots_woodwork` | Woodwork hits by triggered team | Primary trigger metric. |
| `opponent_shots_woodwork` | Woodwork hits by opponent | Bilateral woodwork comparison baseline. |
| `shots_woodwork_delta` | Triggered minus opponent woodwork hits | Net woodwork burden differential. |
| `triggered_team_shots_woodwork_share_pct` | Triggered-side share of total woodwork hits (%) | Normalized contribution to match woodwork profile. |
| `opponent_shots_woodwork_share_pct` | Opponent share of total woodwork hits (%) | Bilateral normalized comparator. |
| `shots_woodwork_share_delta_pct` | Triggered minus opponent woodwork share (percentage points) | Compact imbalance diagnostic. |
| `triggered_team_shots_woodwork_above_threshold` | Margin above threshold (`shots_woodwork - 3`) | Trigger severity beyond binary activation. |
| `triggered_team_xg_per_shot` | Triggered-team xG per shot | Average chance-quality context for woodwork frequency. |
| `opponent_xg_per_shot` | Opponent xG per shot | Bilateral chance-quality-per-shot comparator. |
| `xg_per_shot_delta` | Triggered minus opponent xG per shot | Net per-shot chance-quality differential. |
| `triggered_team_xg` | Triggered-team expected goals | Chance-quality volume context. |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality baseline. |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-generation differential. |
| `triggered_team_total_shots` | Triggered-team total shots | Shot-volume denominator context. |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume baseline. |
| `total_shots_delta` | Triggered minus opponent total shots | Net shot-pressure differential. |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Execution-quality volume context. |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral execution comparator. |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Net on-target differential. |
| `triggered_team_on_target_ratio_pct` | Triggered-team on-target ratio (%) | Normalized shot-precision indicator. |
| `opponent_on_target_ratio_pct` | Opponent on-target ratio (%) | Bilateral precision baseline. |
| `on_target_ratio_delta_pct` | Triggered minus opponent on-target ratio (percentage points) | Precision-gap diagnostic. |
| `triggered_team_goals` | Triggered-team goals | Outcome context against woodwork frustration. |
| `opponent_goals` | Opponent goals | Bilateral scoreline comparator. |
| `goal_delta` | Triggered-team goals minus opponent goals | Outcome differential context. |
| `triggered_team_big_chances` | Triggered-team big chances | High-value chance-volume context. |
| `opponent_big_chances` | Opponent big chances | Bilateral high-value chance comparator. |
| `triggered_team_big_chances_missed` | Triggered-team big chances missed | Wastefulness diagnostic alongside woodwork hits. |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness comparator. |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Territorial-penetration context. |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral territorial comparator. |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Control-share context for chance creation profile. |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share baseline. |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Compact control differential. |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Circulation-volume context. |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation baseline. |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Build-up execution context. |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral build-up execution comparator. |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Circulation-quality differential. |
| `triggered_team_corners` | Triggered-team corners won | Sustained attacking-pressure proxy. |
| `opponent_corners` | Opponent corners won | Bilateral pressure comparator. |
