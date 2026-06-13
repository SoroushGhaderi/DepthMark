---
signal_id: sig_team_creativity_playmaking_sustained_creative_pressure
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Sustained Creative Pressure"
trigger: "Team records >= 1 key-pass proxy event in every 10-minute segment (00-09 ... 80-90+) in one finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_creativity_playmaking_sustained_creative_pressure
  sql: clickhouse/gold/signal/sig_team_creativity_playmaking_sustained_creative_pressure.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_team_creativity_playmaking_sustained_creative_pressure

## Purpose

Detect team-level sustained creative pressure where chance-generation cadence remains present across all
10-minute match segments rather than appearing as isolated spikes.

## Tactical And Statistical Logic

- Trigger conditions:
  - `triggered_team_key_pass_proxy_segments_hit_count >= 9`
  - `trigger_threshold_min_key_passes_per_segment = 1`
  - `trigger_threshold_segment_window_minutes = 10`
  - `match_finished = 1`
- Segment grid is `00-09`, `10-19`, `20-29`, `30-39`, `40-49`, `50-59`, `60-69`, `70-79`, `80-90+`.
- Operational key-pass proxy:
  - Current silver schema does not expose minute-level `chances_created`.
  - This signal uses non-penalty, non-own-goal `silver.shot` events as a minute-level
    key-pass pressure proxy and measures segment coverage continuity from those events.
- Team-level creativity context is retained from `silver.player_match_stat` (`chances_created`, `expected_assists`) and bilateral match context from `silver.period_stat` (`period = 'All'`).
- Similarity gate note:
  - `sig_team_creativity_playmaking_chance_barrage` is nearest on metric family (team key-pass volume), but it is aggregate-only (`>= 15`) and not cadence-segmented.
  - `sig_team_shooting_goals_sustained_barrage` is nearest on cadence shape (short-window pressure), but it is shooting-family and window-burst based (`10 shots in 15 minutes`) rather than full-match creativity continuity.
  - Coexistence rationale: this signal focuses on all-phase continuity of creative pressure at team grain.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_creativity_playmaking_sustained_creative_pressure.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_team_creativity_playmaking_sustained_creative_pressure`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_team_creativity_playmaking_sustained_creative_pressure
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
| `home_score` | Home full-time goals | Outcome context |
| `away_score` | Away full-time goals | Outcome context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical row identity at match-team grain |
| `triggered_team_id` | Triggered team ID | Triggered-entity key for downstream joins |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team ID | Bilateral opponent orientation |
| `opponent_team_name` | Opponent team name | Human-readable bilateral context |
| `trigger_threshold_min_key_passes_per_segment` | Minimum segment-level key-pass proxy threshold (`1`) | Explicit per-segment trigger provenance |
| `trigger_threshold_segment_window_minutes` | Segment window size in minutes (`10`) | Explicit segmentation contract for reproducibility |
| `trigger_threshold_required_segment_count` | Required covered segments (`9`) | Explicit full-match cadence completeness threshold |
| `triggered_team_key_pass_proxy_segment_00_09` | Triggered-team key-pass proxy count in minutes `00-09` | Early-phase creative-pressure continuity diagnostic |
| `triggered_team_key_pass_proxy_segment_10_19` | Triggered-team key-pass proxy count in minutes `10-19` | Early-first-half continuity diagnostic |
| `triggered_team_key_pass_proxy_segment_20_29` | Triggered-team key-pass proxy count in minutes `20-29` | Mid-first-half continuity diagnostic |
| `triggered_team_key_pass_proxy_segment_30_39` | Triggered-team key-pass proxy count in minutes `30-39` | Late-first-half buildup continuity diagnostic |
| `triggered_team_key_pass_proxy_segment_40_49` | Triggered-team key-pass proxy count in minutes `40-49` | Half-transition continuity diagnostic |
| `triggered_team_key_pass_proxy_segment_50_59` | Triggered-team key-pass proxy count in minutes `50-59` | Early-second-half continuity diagnostic |
| `triggered_team_key_pass_proxy_segment_60_69` | Triggered-team key-pass proxy count in minutes `60-69` | Mid-second-half continuity diagnostic |
| `triggered_team_key_pass_proxy_segment_70_79` | Triggered-team key-pass proxy count in minutes `70-79` | Late-second-half continuity diagnostic |
| `triggered_team_key_pass_proxy_segment_80_90_plus` | Triggered-team key-pass proxy count in minutes `80-90+` | Closing-phase pressure continuity diagnostic |
| `opponent_key_pass_proxy_segment_00_09` | Opponent key-pass proxy count in minutes `00-09` | Bilateral segment comparator |
| `opponent_key_pass_proxy_segment_10_19` | Opponent key-pass proxy count in minutes `10-19` | Bilateral segment comparator |
| `opponent_key_pass_proxy_segment_20_29` | Opponent key-pass proxy count in minutes `20-29` | Bilateral segment comparator |
| `opponent_key_pass_proxy_segment_30_39` | Opponent key-pass proxy count in minutes `30-39` | Bilateral segment comparator |
| `opponent_key_pass_proxy_segment_40_49` | Opponent key-pass proxy count in minutes `40-49` | Bilateral segment comparator |
| `opponent_key_pass_proxy_segment_50_59` | Opponent key-pass proxy count in minutes `50-59` | Bilateral segment comparator |
| `opponent_key_pass_proxy_segment_60_69` | Opponent key-pass proxy count in minutes `60-69` | Bilateral segment comparator |
| `opponent_key_pass_proxy_segment_70_79` | Opponent key-pass proxy count in minutes `70-79` | Bilateral segment comparator |
| `opponent_key_pass_proxy_segment_80_90_plus` | Opponent key-pass proxy count in minutes `80-90+` | Bilateral segment comparator |
| `triggered_team_key_pass_proxy_segments_hit_count` | Number of 10-minute segments with at least one triggered-team key-pass proxy event | Core cadence trigger metric |
| `opponent_key_pass_proxy_segments_hit_count` | Number of 10-minute segments with at least one opponent key-pass proxy event | Bilateral cadence comparator |
| `key_pass_proxy_segments_hit_count_delta` | Triggered minus opponent covered-segment count | Net continuity dominance metric |
| `triggered_team_key_pass_proxy_segment_coverage_pct` | Triggered-team covered-segment share (%) | Normalized continuity severity metric |
| `opponent_key_pass_proxy_segment_coverage_pct` | Opponent covered-segment share (%) | Bilateral normalized continuity comparator |
| `key_pass_proxy_segment_coverage_delta_pct` | Triggered minus opponent segment-coverage share (%) | Net cadence-coverage gap |
| `triggered_team_key_pass_proxy_total` | Triggered-team total key-pass proxy events across match | Aggregate pressure baseline |
| `opponent_key_pass_proxy_total` | Opponent total key-pass proxy events across match | Bilateral aggregate comparator |
| `key_pass_proxy_total_delta` | Triggered minus opponent key-pass proxy total | Net aggregate pressure differential |
| `triggered_team_total_key_passes` | Triggered-team total key passes (`chances_created`) | Team creativity baseline aligned to official aggregate metric |
| `opponent_total_key_passes` | Opponent total key passes (`chances_created`) | Bilateral creativity baseline comparator |
| `total_key_passes_delta` | Triggered minus opponent total key passes | Net official creativity-volume differential |
| `triggered_team_expected_assists` | Triggered-team total expected assists (xA) | Chance-quality baseline around continuity profile |
| `opponent_expected_assists` | Opponent total expected assists (xA) | Bilateral chance-quality comparator |
| `expected_assists_delta` | Triggered minus opponent total expected assists | Net chance-quality differential |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Circulation workload context |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Build-up execution quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral passing-quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net circulation-quality differential |
| `triggered_team_touches_opposition_box` | Triggered-team touches in opposition box | Territorial-penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Net territorial-pressure differential |
| `triggered_team_total_shots` | Triggered-team total shots | Shot-output context for continuous creative pressure |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-output comparator |
| `total_shots_delta` | Triggered minus opponent total shots | Net shot-volume differential |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Execution output context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Net execution differential |
| `triggered_team_xg` | Triggered-team expected goals | Shot-quality outcome context |
| `opponent_xg` | Opponent expected goals | Bilateral shot-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Net shot-quality differential |
| `triggered_team_goals` | Triggered-side goals | Scoreline conversion context |
| `opponent_goals` | Opponent goals | Bilateral scoreline comparator |
| `goal_delta` | Triggered minus opponent goals | Compact outcome differential |
| `triggered_team_possession_pct` | Triggered-team possession share (%) | Match-control context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (%) | Net control differential |
