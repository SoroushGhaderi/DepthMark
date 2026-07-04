---
signal_id: sig_team_shooting_goals_sustained_second_half_siege
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Sustained Second-Half Siege"
trigger: "Team records >= 15 total shots in the second half alone in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_shooting_goals_sustained_second_half_siege
  sql: clickhouse/gold/dml/signals/team/sig_team_shooting_goals_sustained_second_half_siege.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_team_shooting_goals_sustained_second_half_siege

## Purpose

Detect team matches where post-halftime pressure escalates into extreme second-half shot volume.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_shots_second_half >= 15`.
  - Shot volume comes from `silver.period_stat` at `period = 'SecondHalf'`.
- Coverage guard:
  - Require both half rows to exist before evaluation:
    - `has_first_half_period_row_flag = 1`
    - `has_second_half_period_row_flag = 1`
- Grain and output:
  - One row per `match_id` + `triggered_side` for any side crossing the threshold.
- Enrichment:
  - Half-level bilateral diagnostics: first-half vs second-half shots, second-half on-target profile,
    second-half xG, and second-half shot share.
  - Full-match bilateral context from `period = 'All'`: scoreline, shot quality, possession,
    passing, territory, and set-piece pressure proxies.
- Similarity gate note:
  - Closest active signals are `sig_team_shooting_goals_shooting_gallery`,
    `sig_team_shooting_goals_sustained_barrage`, and `sig_team_shooting_goals_zero_shot_half`.
  - This signal intentionally coexists because it is half-segment-specific and volume-first
    (`>= 15` in `SecondHalf`), rather than full-match total-shot (`>= 25`), short-window burst,
    or zero-shot drought logic.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/team/sig_team_shooting_goals_sustained_second_half_siege.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_team_shooting_goals_sustained_second_half_siege`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_team_shooting_goals_sustained_second_half_siege
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Football developer: stable join key and dedup anchor |
| `match_date` | Match date | Football developer: reproducible backfill/time slicing |
| `home_team_id` | Home team identifier | Football developer: bilateral fixture context |
| `home_team_name` | Home team name | Football developer: readable fixture context |
| `away_team_id` | Away team identifier | Football developer: bilateral fixture context |
| `away_team_name` | Away team name | Football developer: readable fixture context |
| `home_score` | Home full-time goals | Football developer: outcome context for pressure translation |
| `away_score` | Away full-time goals | Football developer: outcome context for pressure translation |
| `triggered_side` | Triggered side (`home` or `away`) | Football developer: canonical row orientation |
| `triggered_team_id` | Triggered team identifier | Football developer: triggered entity key |
| `triggered_team_name` | Triggered team name | Football developer: readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Football developer: bilateral opponent orientation |
| `opponent_team_name` | Opponent team name | Football developer: readable opponent attribution |
| `trigger_threshold_min_second_half_shots` | Trigger threshold for second-half shots (`15`) | Football developer: explicit trigger provenance |
| `trigger_threshold_required_half_minutes` | Required half length in minutes (`45`) | Football developer: explicit trigger scope contract |
| `has_first_half_period_row_flag` | 1 when first-half period row exists | Football developer: coverage QA before half comparisons |
| `has_second_half_period_row_flag` | 1 when second-half period row exists | Football developer: trigger-data completeness QA |
| `triggered_team_shots_first_half` | Triggered-side first-half shots | Football developer: baseline before post-halftime siege |
| `triggered_team_shots_second_half` | Triggered-side second-half shots | Football developer: core trigger metric |
| `opponent_shots_first_half` | Opponent first-half shots | Football developer: bilateral pre-break comparator |
| `opponent_shots_second_half` | Opponent second-half shots | Football developer: bilateral post-break comparator |
| `first_half_shots_delta` | Triggered minus opponent first-half shots | Football developer: first-half pressure differential |
| `second_half_shots_delta` | Triggered minus opponent second-half shots | Football developer: second-half siege dominance measure |
| `triggered_team_second_half_shot_share_pct` | Triggered-side share of full-match shots taken in second half (%) | Football developer: concentration of attacking load post-break |
| `opponent_second_half_shot_share_pct` | Opponent share of full-match shots taken in second half (%) | Football developer: bilateral concentration comparator |
| `second_half_shot_share_delta_pct` | Triggered minus opponent second-half shot share (percentage points) | Football developer: net post-break concentration edge |
| `triggered_team_shots_on_target_second_half` | Triggered-side second-half shots on target | Football developer: second-half execution context |
| `opponent_shots_on_target_second_half` | Opponent second-half shots on target | Football developer: bilateral execution comparator |
| `shots_on_target_second_half_delta` | Triggered minus opponent second-half shots on target | Football developer: net second-half shot-quality pressure proxy |
| `triggered_team_on_target_ratio_second_half_pct` | Triggered-side second-half on-target ratio (%) | Football developer: second-half precision indicator |
| `opponent_on_target_ratio_second_half_pct` | Opponent second-half on-target ratio (%) | Football developer: bilateral second-half precision baseline |
| `on_target_ratio_second_half_delta_pct` | Triggered minus opponent second-half on-target ratio (percentage points) | Football developer: net second-half precision differential |
| `triggered_team_xg_second_half` | Triggered-side second-half xG | Football developer: second-half chance-quality output |
| `opponent_xg_second_half` | Opponent second-half xG | Football developer: bilateral second-half chance-quality comparator |
| `xg_second_half_delta` | Triggered minus opponent second-half xG | Football developer: net second-half chance creation edge |
| `triggered_team_xg_per_shot_second_half` | Triggered-side second-half xG per shot | Football developer: average second-half shot quality |
| `opponent_xg_per_shot_second_half` | Opponent second-half xG per shot | Football developer: bilateral shot-quality comparator |
| `xg_per_shot_second_half_delta` | Triggered minus opponent second-half xG per shot | Football developer: net second-half shot-quality differential |
| `triggered_team_goals` | Triggered-side full-time goals | Football developer: outcome translation context |
| `opponent_goals` | Opponent full-time goals | Football developer: bilateral outcome context |
| `goal_delta` | Triggered minus opponent full-time goals | Football developer: compact scoreline differential |
| `triggered_team_total_shots` | Triggered-side full-match shots | Football developer: links half trigger to full-match volume |
| `opponent_total_shots` | Opponent full-match shots | Football developer: bilateral full-match baseline |
| `total_shots_delta` | Triggered minus opponent full-match shots | Football developer: net match-level shot dominance |
| `triggered_team_shots_on_target` | Triggered-side full-match shots on target | Football developer: full-match finishing execution context |
| `opponent_shots_on_target` | Opponent full-match shots on target | Football developer: bilateral full-match execution comparator |
| `triggered_team_on_target_ratio_pct` | Triggered-side full-match on-target ratio (%) | Football developer: match-level precision metric |
| `opponent_on_target_ratio_pct` | Opponent full-match on-target ratio (%) | Football developer: bilateral match-level precision baseline |
| `on_target_ratio_delta_pct` | Triggered minus opponent full-match on-target ratio (percentage points) | Football developer: net full-match precision differential |
| `triggered_team_xg` | Triggered-side full-match xG | Football developer: match-level chance-quality context |
| `opponent_xg` | Opponent full-match xG | Football developer: bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent full-match xG | Football developer: compact match-level quality edge |
| `triggered_team_big_chances` | Triggered-side full-match big chances | Football developer: high-value chance context |
| `opponent_big_chances` | Opponent full-match big chances | Football developer: bilateral high-value chance baseline |
| `triggered_team_big_chances_missed` | Triggered-side full-match big chances missed | Football developer: finishing wastefulness context |
| `opponent_big_chances_missed` | Opponent full-match big chances missed | Football developer: bilateral wastefulness comparator |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Football developer: territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Football developer: bilateral territorial baseline |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Football developer: control profile around siege state |
| `opponent_possession_pct` | Opponent possession share (%) | Football developer: bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Football developer: compact control differential |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Football developer: circulation volume context |
| `opponent_pass_attempts` | Opponent pass attempts | Football developer: bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Football developer: build-up execution quality |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Football developer: bilateral build-up execution baseline |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Football developer: net circulation-quality differential |
| `triggered_team_corners` | Triggered-side corners won | Football developer: sustained pressure proxy |
| `opponent_corners` | Opponent corners won | Football developer: bilateral pressure comparator |
