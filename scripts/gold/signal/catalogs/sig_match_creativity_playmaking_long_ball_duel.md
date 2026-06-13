---
signal_id: sig_match_creativity_playmaking_long_ball_duel
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Long Ball Duel"
trigger: "Both teams complete >= 15 long balls in one finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_creativity_playmaking_long_ball_duel
  sql: clickhouse/gold/signal/sig_match_creativity_playmaking_long_ball_duel.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_match_creativity_playmaking_long_ball_duel

## Purpose

Detect bilateral direct-play creativity matches where both teams complete at least 15 long balls,
then preserve side-by-side execution and chance-creation context.

## Tactical And Statistical Logic

- Trigger conditions:
  - `accurate_long_balls_home >= 15`
  - `accurate_long_balls_away >= 15`
  - with `match_finished = 1`, `period = 'All'`, and `match_id > 0`.
- Long-ball completion metrics are sourced from `silver.period_stat`:
  - `accurate_long_balls_{home|away}` (completed long balls)
  - `long_ball_attempts_{home|away}` (attempt volume)
- Creative context is enriched with team key passes and expected assists aggregated from
  `silver.player_match_stat`.
- Output emits two rows per qualified match (`triggered_side = home|away`) for canonical
  `match_team` grain and symmetric bilateral modeling.
- Similarity gate note:
  - `sig_match_creativity_playmaking_progressive_warfare` uses long-ball attempts as one proxy
    branch with a combined threshold (`> 80`), while this signal is strict bilateral completion
    (`accurate_long_balls >= 15` each).
  - `sig_match_creativity_playmaking_box_entry_chaos` is progression-proxy focused
    (`passes_final_third`) and not long-ball completion constrained.
  - `sig_match_possession_passing_keeper_playmaking_battle` tracks possession/keeper dynamics,
    while this signal is creativity/playmaking bilateral directness.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_creativity_playmaking_long_ball_duel.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_match_creativity_playmaking_long_ball_duel`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_match_creativity_playmaking_long_ball_duel
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable deduplication and join anchor |
| `match_date` | Match date | Time slicing and backfill traceability |
| `home_team_id` | Home team identifier | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team identifier | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Outcome context |
| `away_score` | Away full-time goals | Outcome context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical row identity at `match_team` grain |
| `triggered_team_id` | Triggered-side team ID | Side-specific key for downstream joins |
| `triggered_team_name` | Triggered-side team name | Readable side attribution |
| `opponent_team_id` | Opponent team ID | Bilateral comparator identity |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator |
| `trigger_threshold_min_team_accurate_long_balls` | Team completion threshold (`15`) | Explicit trigger provenance and QA guard |
| `match_combined_accurate_long_balls` | Combined completed long balls by both teams | Core bilateral trigger intensity |
| `triggered_team_accurate_long_balls` | Triggered-side completed long balls | Side-level trigger metric |
| `opponent_accurate_long_balls` | Opponent completed long balls | Bilateral trigger comparator |
| `accurate_long_balls_delta` | Triggered minus opponent completed long balls | Net completion-volume differential |
| `triggered_team_accurate_long_ball_share_pct` | Triggered-side share of combined completions (%) | Relative control of long-ball completion load |
| `opponent_accurate_long_ball_share_pct` | Opponent share of combined completions (%) | Bilateral load-share comparator |
| `accurate_long_ball_share_delta_pct` | Triggered minus opponent completion share (%) | Compact long-ball-control differential |
| `triggered_team_long_ball_attempts` | Triggered-side long-ball attempts | Attempt-volume baseline behind completions |
| `opponent_long_ball_attempts` | Opponent long-ball attempts | Bilateral attempt-volume comparator |
| `long_ball_attempts_delta` | Triggered minus opponent long-ball attempts | Net directness-attempt differential |
| `triggered_team_long_ball_completion_pct` | Triggered-side long-ball completion rate (%) | Direct-play execution quality |
| `opponent_long_ball_completion_pct` | Opponent long-ball completion rate (%) | Bilateral execution-quality comparator |
| `long_ball_completion_delta_pct` | Triggered minus opponent long-ball completion rate (%) | Net direct-play execution differential |
| `triggered_team_key_passes` | Triggered-side key passes | Creativity-volume context |
| `opponent_key_passes` | Opponent key passes | Bilateral creativity comparator |
| `key_pass_delta` | Triggered minus opponent key passes | Net chance-creation differential |
| `triggered_team_expected_assists` | Triggered-side expected assists | Creativity-quality context |
| `opponent_expected_assists` | Opponent expected assists | Bilateral creativity-quality comparator |
| `expected_assists_delta` | Triggered minus opponent expected assists | Net creativity-quality differential |
| `triggered_team_goals` | Triggered-side goals | Outcome context |
| `opponent_goals` | Opponent goals | Bilateral outcome comparator |
| `goal_delta` | Triggered minus opponent goals | Net scoreline differential |
| `triggered_team_total_shots` | Triggered-side total shots | Shot-volume context |
| `opponent_total_shots` | Opponent total shots | Bilateral shot-volume comparator |
| `total_shots_delta` | Triggered minus opponent total shots | Net shot-volume differential |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Shot-execution context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral shot-execution comparator |
| `shots_on_target_delta` | Triggered minus opponent shots on target | Net shot-execution differential |
| `triggered_team_expected_goals` | Triggered-side expected goals | Shot-quality context |
| `opponent_expected_goals` | Opponent expected goals | Bilateral shot-quality comparator |
| `expected_goals_delta` | Triggered minus opponent expected goals | Net shot-quality differential |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Circulation baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Team execution quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral passing-quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net passing-quality differential |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Match-control context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-state comparator |
| `possession_delta_pct` | Triggered minus opponent possession (%) | Net control differential |
| `triggered_team_opposition_half_passes` | Triggered-side opposition-half passes | Territorial progression context |
| `opponent_opposition_half_passes` | Opponent opposition-half passes | Bilateral progression comparator |
| `opposition_half_passes_delta` | Triggered minus opponent opposition-half passes | Net territorial progression differential |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Final-third penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Net penalty-area pressure differential |
