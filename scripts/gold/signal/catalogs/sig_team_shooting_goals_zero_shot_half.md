---
signal_id: sig_team_shooting_goals_zero_shot_half
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Zero-Shot Half"
trigger: "Team records 0 total shots (including off-target) in at least one full 45-minute half in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_zero_shot_half
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_zero_shot_half.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_shooting_goals_zero_shot_half

## Purpose

Detect team-level attacking blackouts where a side produces no shots at all in a full half.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_shots_first_half = 0` OR `triggered_team_shots_second_half = 0`.
  - Shots use `total_shots_*` from `silver.period_stat` and therefore include off-target attempts.
- Full-half coverage constraint:
  - Signal only evaluates matches with both half period rows present:
    - `has_first_half_period_row_flag = 1`
    - `has_second_half_period_row_flag = 1`
  - This avoids treating missing half-partition rows as true zero-shot halves.
- Grain and output:
  - One row per `match_id` + `triggered_side`.
  - `triggered_half_without_shot` identifies `FirstHalf`, `SecondHalf`, or `BothHalves`.
- Enrichment:
  - Bilateral full-match context (`period = 'All'`) includes scoreline, xG, shot quality, possession,
    passing, and territorial pressure diagnostics.
- Similarity gate note:
  - Closest active signals are `sig_team_shooting_goals_shot_shy` and
    `sig_team_shooting_goals_no_shots_allowed`.
  - This signal is distinct by enforcing explicit full-half period-row coverage before evaluating
    zero-shot halves.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_zero_shot_half.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_shooting_goals_zero_shot_half`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_zero_shot_half
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key and deduplication anchor |
| `match_date` | Match date | Football developer: trend slicing and backfill traceability |
| `home_team_id` | Home team identifier | Football developer: bilateral fixture orientation |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: bilateral fixture orientation |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: scoreline interpretation around half-level drought |
| `away_score` | Away full-time goals | Football developer: scoreline interpretation around half-level drought |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical row identity at team-match grain |
| `triggered_team_id` | Triggered team identifier | Football developer: triggered-side identity key |
| `triggered_team_name` | Triggered team name | Football developer: analyst-readable entity attribution |
| `opponent_team_id` | Opponent team identifier | Football developer: matchup orientation |
| `opponent_team_name` | Opponent team name | Football developer: analyst-readable opponent context |
| `trigger_threshold_max_shots_per_half` | Trigger threshold for half-level shots (`0`) | Football developer: explicit trigger boundary for governance and QA |
| `trigger_threshold_required_half_minutes` | Required half length in minutes (`45`) | Football developer: explicit definition of full-half trigger scope |
| `triggered_half_without_shot` | Half label where zero-shot trigger fires (`FirstHalf`, `SecondHalf`, `BothHalves`) | Football developer: direct tactical timing interpretation |
| `has_first_half_period_row_flag` | 1 when `FirstHalf` period row exists in source | Football developer: data-completeness auditability for full-half rule |
| `has_second_half_period_row_flag` | 1 when `SecondHalf` period row exists in source | Football developer: data-completeness auditability for full-half rule |
| `triggered_team_shots_first_half` | Triggered-side first-half total shots | Football developer: first-half trigger component |
| `triggered_team_shots_second_half` | Triggered-side second-half total shots | Football developer: second-half trigger component |
| `opponent_shots_first_half` | Opponent first-half total shots | Football developer: bilateral first-half comparator |
| `opponent_shots_second_half` | Opponent second-half total shots | Football developer: bilateral second-half comparator |
| `triggered_team_zero_shot_first_half_flag` | 1 if triggered side has zero first-half shots | Football developer: explicit trigger decomposition |
| `triggered_team_zero_shot_second_half_flag` | 1 if triggered side has zero second-half shots | Football developer: explicit trigger decomposition |
| `opponent_zero_shot_first_half_flag` | 1 if opponent has zero first-half shots | Football developer: bilateral suppression context |
| `opponent_zero_shot_second_half_flag` | 1 if opponent has zero second-half shots | Football developer: bilateral suppression context |
| `half_shot_gap_first_half` | Triggered minus opponent first-half shots | Football developer: first-half pressure differential |
| `half_shot_gap_second_half` | Triggered minus opponent second-half shots | Football developer: second-half pressure differential |
| `triggered_team_goals` | Triggered-side goals | Football developer: outcome context around half drought |
| `opponent_goals` | Opponent goals | Football developer: bilateral scoreline comparator |
| `goal_delta` | Triggered minus opponent goals | Football developer: net outcome differential |
| `triggered_team_total_shots` | Triggered-side total shots (`period = 'All'`) | Football developer: full-match shot-volume context |
| `opponent_total_shots` | Opponent total shots (`period = 'All'`) | Football developer: bilateral full-match volume comparator |
| `total_shots_delta` | Triggered minus opponent total shots | Football developer: compact pressure differential |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Football developer: execution-quality context |
| `opponent_shots_on_target` | Opponent shots on target | Football developer: bilateral execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Football developer: net on-target pressure differential |
| `triggered_team_on_target_ratio_pct` | Triggered-side shots-on-target ratio (%) | Football developer: triggered-side shooting precision indicator |
| `opponent_on_target_ratio_pct` | Opponent shots-on-target ratio (%) | Football developer: bilateral precision comparator |
| `on_target_ratio_delta_pct` | Triggered minus opponent on-target ratio (percentage points) | Football developer: compact execution-quality gap |
| `triggered_team_xg` | Triggered-side expected goals | Football developer: chance-quality production context |
| `opponent_xg` | Opponent expected goals | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Football developer: net chance-generation differential |
| `triggered_team_big_chances` | Triggered-side big chances | Football developer: high-value chance context |
| `opponent_big_chances` | Opponent big chances | Football developer: bilateral high-value chance comparator |
| `triggered_team_big_chances_missed` | Triggered-side big chances missed | Football developer: finishing wastefulness context |
| `opponent_big_chances_missed` | Opponent big chances missed | Football developer: bilateral wastefulness comparator |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Football developer: bilateral territorial comparator |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Football developer: control profile around shot drought |
| `opponent_possession_pct` | Opponent possession (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: net control differential |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Football developer: circulation-volume context |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Football developer: retention quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral retention comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: compact circulation-quality differential |
| `triggered_team_corners` | Triggered-side corners | Football developer: sustained attacking-pressure proxy |
| `opponent_corners` | Opponent corners | Football developer: bilateral pressure comparator |
