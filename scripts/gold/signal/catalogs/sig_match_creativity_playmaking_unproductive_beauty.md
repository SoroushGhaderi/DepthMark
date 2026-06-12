---
signal_id: sig_match_creativity_playmaking_unproductive_beauty
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Unproductive Beauty"
trigger: "Combined successful dribbles >= 40, combined key passes >= 20, and total match goals = 0."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_creativity_playmaking_unproductive_beauty
  sql: clickhouse/gold/signal/sig_match_creativity_playmaking_unproductive_beauty.sql
  runner: scripts/gold/signal/runners/sig_match_creativity_playmaking_unproductive_beauty.py
---
# sig_match_creativity_playmaking_unproductive_beauty

## Purpose

Detect finished matches where creativity volume is high (dribbles and key passes) but output is
nil (0 total goals), surfacing aesthetically rich yet unproductive attacking contests.

## Tactical And Statistical Logic

- Trigger condition:
  - `match_combined_successful_dribbles >= 40`
  - `match_combined_key_passes >= 20`
  - `match_total_goals = 0`
- Aggregate sources:
  - Team key passes and expected assists come from `silver.player_match_stat`.
  - Dribbles, shots, passing, possession, and territorial context come from
    `silver.period_stat` where `period = 'All'`.
- Match scope:
  - `silver.match.match_finished = 1`
  - `match_id > 0`
- Side orientation:
  - Emits one row for `home` and one row for `away` at `match_team` grain.
- Similarity gate note:
  - `sig_match_creativity_playmaking_dribbling_battle` overlaps on high dribble volume, but does
    not require high key-pass volume nor zero-goal outcomes.
  - `sig_match_possession_passing_unproductive_game` overlaps on low-output outcomes, but triggers
    on pass-volume and low-shot constraints instead of creativity dribble/key-pass intensity.
  - `sig_team_creativity_playmaking_unproductive_flair` is unilateral team-level logic; this
    signal is bilateral match-level creativity/output paradox detection.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_match_creativity_playmaking_unproductive_beauty.sql`
- Runner: `scripts/gold/signal/runners/sig_match_creativity_playmaking_unproductive_beauty.py`
- Target table: `gold_signals.sig_match_creativity_playmaking_unproductive_beauty`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_match_creativity_playmaking_unproductive_beauty.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable deduplication and join anchor |
| `match_date` | Match date | Time slicing and backfill reproducibility |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Outcome context |
| `away_score` | Away full-time goals | Outcome context |
| `triggered_side` | Triggered row orientation (`home` or `away`) | Canonical side identity at `match_team` grain |
| `triggered_team_id` | Triggered-side team ID | Side-level identity for downstream joins |
| `triggered_team_name` | Triggered-side team name | Readable triggered-team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral comparator identity |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator |
| `trigger_threshold_min_combined_successful_dribbles` | Dribble trigger floor (`40`) | Explicit trigger provenance and QA traceability |
| `trigger_threshold_min_combined_key_passes` | Key-pass trigger floor (`20`) | Explicit trigger provenance and QA traceability |
| `trigger_threshold_match_total_goals` | Goal-output trigger target (`0`) | Makes the unproductive outcome rule explicit |
| `match_combined_successful_dribbles` | Combined successful dribbles in the match | Core creativity-volume trigger metric |
| `match_combined_key_passes` | Combined key passes in the match | Core chance-construction trigger metric |
| `match_total_goals` | Combined goals in the match | Outcome-failure trigger metric |
| `triggered_team_successful_dribbles` | Successful dribbles by triggered side | Side-level dribbling output context |
| `opponent_successful_dribbles` | Successful dribbles by opponent side | Bilateral dribbling comparator |
| `successful_dribbles_delta` | Triggered minus opponent successful dribbles | Net dribble output differential |
| `triggered_team_dribble_attempts` | Triggered-side dribble attempts | Attempt volume context behind completions |
| `opponent_dribble_attempts` | Opponent dribble attempts | Bilateral attempt-volume comparator |
| `dribble_attempts_delta` | Triggered minus opponent dribble attempts | Net dribble intent differential |
| `triggered_team_dribble_success_pct` | Triggered-side dribble success rate (%) | Dribble efficiency context |
| `opponent_dribble_success_pct` | Opponent dribble success rate (%) | Bilateral efficiency comparator |
| `dribble_success_delta_pct` | Triggered minus opponent dribble success rate (%) | Net dribble efficiency differential |
| `triggered_team_key_passes` | Triggered-side key passes | Side-level chance-creation volume context |
| `opponent_key_passes` | Opponent key passes | Bilateral chance-creation comparator |
| `key_pass_delta` | Triggered minus opponent key passes | Net chance-creation differential |
| `triggered_team_key_pass_share_pct` | Triggered-side share of combined key passes (%) | Normalized side contribution to chance creation |
| `opponent_key_pass_share_pct` | Opponent share of combined key passes (%) | Bilateral normalized comparator |
| `key_pass_share_delta_pct` | Triggered minus opponent key-pass share (%) | Directional chance-creation share differential |
| `triggered_team_expected_assists` | Triggered-side expected assists | Creativity quality context |
| `opponent_expected_assists` | Opponent expected assists | Bilateral creativity-quality comparator |
| `expected_assists_delta` | Triggered minus opponent expected assists | Net creativity-quality differential |
| `triggered_team_goals` | Triggered-side goals | Side-level outcome context |
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
| `triggered_team_big_chances` | Triggered-side big chances | High-value chance context |
| `opponent_big_chances` | Opponent big chances | Bilateral high-value comparator |
| `big_chances_delta` | Triggered minus opponent big chances | Net high-value chance differential |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Circulation-volume baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Build-up execution-quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral build-up comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net circulation-quality differential |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Match control context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (%) | Net control-state differential |
| `triggered_team_opposition_half_passes` | Triggered-side opposition-half passes | Territorial progression context |
| `opponent_opposition_half_passes` | Opponent opposition-half passes | Bilateral progression comparator |
| `opposition_half_passes_delta` | Triggered minus opponent opposition-half passes | Net territorial progression differential |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Final-third penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Net penalty-area pressure differential |
