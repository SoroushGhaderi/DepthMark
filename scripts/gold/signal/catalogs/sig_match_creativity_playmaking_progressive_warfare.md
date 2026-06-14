---
signal_id: sig_match_creativity_playmaking_progressive_warfare
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Progressive Warfare"
trigger: "Combined progressive-pass directional proxy exceeds 80 using passes_final_third (player_match_stat) OR long_ball_attempts (period_stat)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_creativity_playmaking_progressive_warfare
  sql: clickhouse/gold/dml/signals/match/sig_match_creativity_playmaking_progressive_warfare.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_creativity_playmaking_progressive_warfare

## Purpose

Detect bilateral creativity battles where match-level progression volume is extreme, using directional
proxy metrics when explicit progressive-pass counts are not available in current source tables.

## Tactical And Statistical Logic

- Trigger condition:
  - `(home_passes_final_third + away_passes_final_third) > 80`
  - OR `(long_ball_attempts_home + long_ball_attempts_away) > 80`
  - with `period = 'All'`, `match_finished = 1`, and valid `match_id`.
- Proxy replacement contract:
  - Player/team progression proxy: `silver.player_match_stat.passes_final_third` aggregated by team.
  - Team directness proxy: `silver.period_stat.long_ball_attempts_{home|away}`.
- Trigger-path audit fields preserve which proxy fired:
  - `match_combined_directional_proxy_source`
  - `match_combined_directional_proxy_value`
- One row per side is emitted (`home`, `away`) for canonical `match_team` grain and symmetric
  downstream modeling.
- Similarity gate note:
  - Closest active match-level sibling is `sig_match_creativity_playmaking_the_creativity_clash`, but that trigger is bilateral xA (`>= 1.5` each) rather than progression-volume proxies.
  - `sig_match_possession_passing_keeper_playmaking_battle` also uses long-ball context, but it is goalkeeper- and possession-focused, not creativity/playmaking progression warfare.
  - Player-level analogs (`sig_player_creativity_playmaking_line_breaker`, `sig_player_creativity_playmaking_box_to_box_playmaker`) share the same proxy strategy but are `match_player` rather than match-team bilateral rows.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_creativity_playmaking_progressive_warfare.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_creativity_playmaking_progressive_warfare`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_creativity_playmaking_progressive_warfare
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
| `trigger_threshold_min_combined_directional_proxy` | Trigger floor for combined directional proxy (`80`) | Explicit threshold provenance and QA guard |
| `match_combined_passes_final_third_directional_proxy` | Combined match directional proxy from final-third passes | Primary progression-volume proxy under source constraints |
| `match_combined_long_ball_attempts_directional_proxy` | Combined match directional proxy from long-ball attempts | Fallback directness proxy for progression volume |
| `match_combined_directional_proxy_source` | Trigger source label (`passes_final_third_proxy`, `long_ball_attempts_proxy`, `both_proxies`) | Auditable trigger branch by match |
| `match_combined_directional_proxy_value` | Dominant combined directional proxy value used for intensity | Preserves trigger severity across proxy branches |
| `triggered_team_passes_final_third_directional_proxy` | Triggered-side directional proxy from final-third passes | Side-level progression proxy baseline |
| `opponent_passes_final_third_directional_proxy` | Opponent directional proxy from final-third passes | Bilateral progression-proxy comparator |
| `passes_final_third_directional_proxy_delta` | Triggered minus opponent final-third directional proxy | Net progression-volume edge from final-third proxy |
| `triggered_team_long_ball_attempts_directional_proxy` | Triggered-side directional proxy from long-ball attempts | Side-level directness proxy baseline |
| `opponent_long_ball_attempts_directional_proxy` | Opponent directional proxy from long-ball attempts | Bilateral directness-proxy comparator |
| `long_ball_attempts_directional_proxy_delta` | Triggered minus opponent long-ball directional proxy | Net directness-volume edge |
| `triggered_team_directional_proxy_value` | Triggered-side composite directional proxy value (`max(final_third, long_balls)`) | Side-level proxy intensity across branches |
| `opponent_directional_proxy_value` | Opponent-side composite directional proxy value | Bilateral composite intensity comparator |
| `directional_proxy_value_delta` | Triggered minus opponent composite directional proxy value | Net directional-proxy intensity edge |
| `triggered_team_directional_proxy_share_pct` | Triggered-side share of combined directional proxy value (%) | Relative control over match progression load |
| `opponent_directional_proxy_share_pct` | Opponent-side share of combined directional proxy value (%) | Bilateral load-share comparator |
| `directional_proxy_share_delta_pct` | Triggered minus opponent directional proxy share (%) | Compact progression-control differential |
| `triggered_team_key_passes` | Triggered-side key passes | Creativity volume context around proxy trigger |
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
