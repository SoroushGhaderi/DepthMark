---
signal_id: sig_team_creativity_playmaking_big_chance_monopoly
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Big Chance Monopoly"
trigger: "Team creates >= 5 big chances while opponent creates 0 in a finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_creativity_playmaking_big_chance_monopoly
  sql: clickhouse/gold/signal/sig_team_creativity_playmaking_big_chance_monopoly.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_creativity_playmaking_big_chance_monopoly

## Purpose

Detect team-level matches where one side monopolizes elite chance creation by generating at least
five big chances while allowing the opponent none.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_big_chances >= 5`
  - `opponent_big_chances = 0`
- Trigger uses full-match aggregates from `silver.period_stat` with `period = 'All'` and
  finished-match filtering from `silver.match`.
- Output is side-oriented and bilateral (`triggered_team_*` vs `opponent_*`) to preserve tactical
  comparability and downstream modeling consistency.
- Big-chance conversion context is retained from big-chances and big-chances-missed aggregates.
- Similarity gate note:
  - `sig_team_shooting_goals_shot_on_target_monopoly` is the closest structure overlap (monopoly +
    opponent zero condition), but it operates on shots on target (`>= 10` vs `0`) rather than
    big-chance creation.
  - `sig_team_shooting_goals_big_chance_efficiency` overlaps on big-chance domain, but it focuses
    on conversion efficiency (`100%`) with minimum one big chance, not creative monopoly against a
    zero-opponent baseline.
  - Coexistence rationale: this signal is a creativity/playmaking taxonomy variant anchored to
    bilateral big-chance creation monopoly intensity.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_creativity_playmaking_big_chance_monopoly.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_creativity_playmaking_big_chance_monopoly`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_creativity_playmaking_big_chance_monopoly
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable join and deduplication key |
| `match_date` | Match date | Temporal slicing and reproducible backfills |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Match outcome context |
| `away_score` | Away full-time goals | Match outcome context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical row identity at match-team grain |
| `triggered_team_id` | Triggered team ID | Triggered entity key for downstream joins |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team ID | Bilateral opponent orientation |
| `opponent_team_name` | Opponent team name | Readable bilateral opponent context |
| `trigger_threshold_min_big_chances` | Minimum triggered-side big-chance threshold (`5`) | Explicit trigger provenance for QA |
| `trigger_threshold_max_opponent_big_chances` | Maximum opponent big-chance threshold (`0`) | Explicit suppression boundary provenance |
| `triggered_team_big_chances` | Triggered-side big chances | Core trigger metric for chance creation monopoly |
| `opponent_big_chances` | Opponent big chances | Core suppression metric for monopoly trigger |
| `big_chances_delta` | Triggered minus opponent big chances | Net big-chance creation differential |
| `triggered_team_big_chances_missed` | Triggered-side big chances missed | Wastefulness context for created volume |
| `opponent_big_chances_missed` | Opponent big chances missed | Bilateral wastefulness comparator |
| `big_chances_missed_delta` | Triggered minus opponent big chances missed | Net wastefulness differential |
| `triggered_team_big_chances_converted` | Triggered-side big chances converted | Output conversion context for created monopoly |
| `opponent_big_chances_converted` | Opponent big chances converted | Bilateral conversion comparator |
| `big_chances_converted_delta` | Triggered minus opponent converted big chances | Net conversion-volume differential |
| `triggered_team_big_chance_conversion_pct` | Triggered-side big-chance conversion (%) | Efficiency context around monopoly creation |
| `opponent_big_chance_conversion_pct` | Opponent big-chance conversion (%) | Bilateral efficiency baseline |
| `big_chance_conversion_delta_pct` | Triggered minus opponent big-chance conversion (%) | Net chance-conversion efficiency gap |
| `triggered_team_goals` | Triggered-side goals | Scoreline output context |
| `opponent_goals` | Opponent goals | Bilateral scoreline comparator |
| `goal_delta` | Triggered minus opponent goals | Compact outcome differential |
| `triggered_team_xg` | Triggered-side expected goals | Chance-quality total behind big-chance monopoly |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-generation differential |
| `triggered_team_xg_per_shot` | Triggered-side expected goals per shot | Average shot-quality context |
| `opponent_xg_per_shot` | Opponent expected goals per shot | Bilateral average shot-quality comparator |
| `triggered_team_total_shots` | Triggered-side total shots | Volume context beyond big-chance counts |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume baseline |
| `total_shots_delta` | Triggered minus opponent total shots | Net shot-pressure differential |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Execution-volume context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Net on-target differential |
| `triggered_team_on_target_ratio_pct` | Triggered-side on-target ratio (%) | Shot precision context |
| `opponent_on_target_ratio_pct` | Opponent on-target ratio (%) | Bilateral precision baseline |
| `on_target_ratio_delta_pct` | Triggered minus opponent on-target ratio (%) | Net shooting precision gap |
| `triggered_team_touches_opposition_box` | Triggered-side opposition-box touches | Territorial penetration context |
| `opponent_touches_opposition_box` | Opponent opposition-box touches | Bilateral territorial comparator |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Match control context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (%) | Net control differential |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Circulation workload context |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Build-up execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net circulation-quality differential |
| `triggered_team_corners` | Triggered-side corners | Sustained pressure context |
| `opponent_corners` | Opponent corners | Bilateral pressure comparator |
| `triggered_team_clean_sheet_flag` | 1 when opponent goals = 0, else 0 | Separates creative monopoly from clean-sheet outcome context |
