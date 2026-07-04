---
signal_id: sig_match_creativity_playmaking_the_cross_heavy_match
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "The Cross-Heavy Match"
trigger: "Combined match successful crosses exceed 25 in one finished match (`period = 'All'`)."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_creativity_playmaking_the_cross_heavy_match
  sql: clickhouse/gold/dml/signals/match/sig_match_creativity_playmaking_the_cross_heavy_match.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_match_creativity_playmaking_the_cross_heavy_match

## Purpose

Detect finished matches where both sides collectively sustain very high successful crossing volume,
then preserve bilateral crossing quality and creation context at match-team grain.

## Tactical And Statistical Logic

- Trigger condition:
  - `match_combined_successful_crosses > 25`, where
  - `match_combined_successful_crosses = accurate_crosses_home + accurate_crosses_away`.
- Match scope:
  - `match_finished = 1`, `period = 'All'`, `match_id > 0`.
- Crossing metrics source:
  - `silver.period_stat.accurate_crosses_{home|away}` for successful crosses.
  - `silver.period_stat.cross_attempts_{home|away}` for crossing volume and accuracy denominator.
- Creativity context source:
  - Team key passes (`chances_created`) and expected assists are aggregated from
    `silver.player_match_stat` by `match_id + team_id`.
- Output shape:
  - Emits two rows per triggered match (`triggered_side = home|away`) for canonical
    `match_team` grain with symmetric triggered/opponent fields.
- Similarity gate note:
  - Closest active match-level sibling is `sig_match_creativity_playmaking_long_ball_duel`, which is bilateral directness-driven on long-ball completions (`>= 15` each) rather than crossing completions.
  - `sig_team_creativity_playmaking_crossing_clinic` is the closest crossing signal but is team-triggered (`triggered_team_successful_crosses >= 10`) rather than combined match-level crossing load.
  - `sig_team_possession_passing_cross_spam` is attempt-driven in possession family, while this signal is successful-cross completion driven in creativity/playmaking.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_creativity_playmaking_the_cross_heavy_match.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_match_creativity_playmaking_the_cross_heavy_match`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_match_creativity_playmaking_the_cross_heavy_match
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
| `trigger_threshold_min_match_combined_successful_crosses` | Match-level successful-cross threshold (`25`) | Explicit trigger provenance and QA guard |
| `match_combined_successful_crosses` | Combined successful crosses by both teams | Core match trigger metric |
| `triggered_team_successful_crosses` | Successful crosses by triggered side | Side-level crossing completion baseline |
| `opponent_successful_crosses` | Successful crosses by opponent | Bilateral crossing completion comparator |
| `successful_crosses_delta` | Triggered minus opponent successful crosses | Net crossing completion differential |
| `triggered_team_successful_cross_share_pct` | Triggered-side share of combined successful crosses (%) | Relative control of match crossing output |
| `opponent_successful_cross_share_pct` | Opponent share of combined successful crosses (%) | Bilateral share comparator |
| `successful_cross_share_delta_pct` | Triggered minus opponent successful-cross share (%) | Net crossing output share edge |
| `triggered_team_cross_attempts` | Triggered-side cross attempts | Attempt-volume denominator context |
| `opponent_cross_attempts` | Opponent cross attempts | Bilateral crossing volume comparator |
| `cross_attempts_delta` | Triggered minus opponent cross attempts | Net crossing load differential |
| `triggered_team_cross_accuracy_pct` | Triggered-side cross completion rate (%) | Crossing execution quality context |
| `opponent_cross_accuracy_pct` | Opponent cross completion rate (%) | Bilateral execution-quality comparator |
| `cross_accuracy_delta_pct` | Triggered minus opponent cross accuracy (%) | Net crossing execution differential |
| `triggered_team_cross_share_of_passes_pct` | Triggered-side cross attempts as share of pass attempts (%) | Tactical style context for wide-route dependency |
| `opponent_cross_share_of_passes_pct` | Opponent cross attempts as share of pass attempts (%) | Bilateral style comparator |
| `cross_share_of_passes_delta_pct` | Triggered minus opponent cross share of passes (%) | Net stylistic imbalance toward crossing |
| `triggered_team_key_passes` | Triggered-side key passes | Creativity volume context |
| `opponent_key_passes` | Opponent key passes | Bilateral creativity comparator |
| `key_pass_delta` | Triggered minus opponent key passes | Net chance-creation differential |
| `triggered_team_expected_assists` | Triggered-side expected assists | Creativity quality context |
| `opponent_expected_assists` | Opponent expected assists | Bilateral creativity-quality comparator |
| `expected_assists_delta` | Triggered minus opponent expected assists | Net creativity-quality differential |
| `triggered_team_goals` | Triggered-side goals | Scoreline outcome context |
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
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Circulation baseline context |
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
