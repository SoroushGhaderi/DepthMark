---
signal_id: sig_match_creativity_playmaking_box_entry_chaos
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Box Entry Chaos"
trigger: "Combined match successful passes into the box exceed 50 (proxied by passes_final_third)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_creativity_playmaking_box_entry_chaos
  sql: clickhouse/gold/dml/signals/match/sig_match_creativity_playmaking_box_entry_chaos.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_match_creativity_playmaking_box_entry_chaos

## Purpose

Detect bilateral creativity matches with extreme combined box-entry progression volume, where teams
repeatedly move possession into advanced threat zones.

## Tactical And Statistical Logic

- Trigger condition:
  - `match_combined_successful_box_passes_proxy > 50`
  - with `period = 'All'`, `match_finished = 1`, and valid `match_id`.
- Source limitation and proxy contract:
  - Direct `successful_passes_into_box` is not available in current Silver tables.
  - Signal uses `silver.player_match_stat.passes_final_third` as explicit proxy:
    - `trigger_successful_box_passes_proxy_source = 'passes_final_third_proxy'`.
- Emits one row per side (`home`, `away`) for canonical `match_team` grain and symmetric
  downstream usage.
- Bilateral context includes creativity quality (`expected_assists`, `key_passes`) plus passing,
  shot, territorial, and directness diagnostics.
- Similarity gate note:
  - Closest active signal is `sig_match_creativity_playmaking_progressive_warfare`, which also tracks progression intensity but uses an OR trigger across `passes_final_third` and `long_ball_attempts` at a higher threshold (`> 80`).
  - `sig_match_creativity_playmaking_the_creativity_clash` is creativity-quality bilateral (`xA`) rather than box-entry progression-volume based.
  - `sig_match_shooting_goals_box_siege_match` overlaps on territorial pressure (`touches_opp_box`) but belongs to shooting outcomes, not playmaking progression.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_creativity_playmaking_box_entry_chaos.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_match_creativity_playmaking_box_entry_chaos`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_match_creativity_playmaking_box_entry_chaos
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join key and deduplication anchor |
| `match_date` | Match date | Backfill reproducibility and time slicing |
| `home_team_id` | Home team identifier | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team identifier | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Outcome context |
| `away_score` | Away full-time goals | Outcome context |
| `triggered_side` | Row orientation (`home` or `away`) | Canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered-side team identifier | Side-specific key for downstream joins |
| `triggered_team_name` | Triggered-side team name | Readable triggered-team attribution |
| `opponent_team_id` | Opponent team identifier | Bilateral comparison key |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator |
| `trigger_threshold_min_match_combined_successful_box_passes_proxy` | Trigger floor for combined successful box-pass proxy (`50`) | Explicit threshold provenance |
| `trigger_successful_box_passes_proxy_source` | Proxy source label (`passes_final_third_proxy`) | Auditable metric provenance under source constraints |
| `match_combined_successful_box_passes_proxy` | Combined match successful box-pass proxy volume | Core match-level trigger metric |
| `triggered_team_successful_box_passes_proxy` | Triggered-side successful box-pass proxy volume | Side-level proxy baseline |
| `opponent_successful_box_passes_proxy` | Opponent successful box-pass proxy volume | Bilateral proxy comparator |
| `successful_box_passes_proxy_delta` | Triggered minus opponent successful box-pass proxy | Net progression-volume differential |
| `triggered_team_successful_box_passes_share_pct` | Triggered-side share of combined successful box-pass proxy (%) | Relative control over box-entry progression load |
| `opponent_successful_box_passes_share_pct` | Opponent share of combined successful box-pass proxy (%) | Bilateral load-share comparator |
| `successful_box_passes_share_delta_pct` | Triggered minus opponent successful box-pass share (%) | Compact progression-control differential |
| `triggered_team_key_passes` | Triggered-side key passes | Creativity volume context around trigger |
| `opponent_key_passes` | Opponent key passes | Bilateral creativity-volume comparator |
| `key_pass_delta` | Triggered minus opponent key passes | Net chance-creation volume differential |
| `triggered_team_expected_assists` | Triggered-side expected assists | Creativity quality context |
| `opponent_expected_assists` | Opponent expected assists | Bilateral creativity-quality comparator |
| `expected_assists_delta` | Triggered minus opponent expected assists | Net creativity-quality differential |
| `triggered_team_goals` | Triggered-side goals | Outcome conversion context |
| `opponent_goals` | Opponent goals | Bilateral outcome comparator |
| `goal_delta` | Triggered minus opponent goals | Compact scoreline differential |
| `triggered_team_total_shots` | Triggered-side total shots | Shot-volume context |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator |
| `total_shots_delta` | Triggered minus opponent total shots | Net shot-volume differential |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Shot-execution context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral shot-execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Net shot-execution differential |
| `triggered_team_expected_goals` | Triggered-side expected goals | Shot-quality context |
| `opponent_expected_goals` | Opponent expected goals | Bilateral shot-quality comparator |
| `expected_goals_delta` | Triggered minus opponent expected goals | Net shot-quality differential |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Possession-circulation baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Team execution quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution-quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net circulation-quality differential |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Match-control context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (%) | Net control-state differential |
| `triggered_team_opposition_half_passes` | Triggered-side opposition-half passes | Territorial progression context |
| `opponent_opposition_half_passes` | Opponent opposition-half passes | Bilateral progression comparator |
| `opposition_half_passes_delta` | Triggered minus opponent opposition-half passes | Net territorial progression differential |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Final-third penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Net final-third pressure differential |
| `triggered_team_long_ball_attempts` | Triggered-side long-ball attempts | Directness diagnostic around progression pathway |
| `opponent_long_ball_attempts` | Opponent long-ball attempts | Bilateral directness diagnostic comparator |
| `long_ball_attempts_delta` | Triggered minus opponent long-ball attempts | Net directness differential in progression style |
