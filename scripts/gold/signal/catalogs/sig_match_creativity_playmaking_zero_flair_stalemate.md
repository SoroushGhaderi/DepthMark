---
signal_id: sig_match_creativity_playmaking_zero_flair_stalemate
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Zero Flair Stalemate"
trigger: "0-0 draw with 0 successful dribbles in the match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_match_creativity_playmaking_zero_flair_stalemate
  sql: clickhouse/gold/dml/signals/match/sig_match_creativity_playmaking_zero_flair_stalemate.sql
  runner: scripts/gold/run_gold_sql_jobs.py
---
# sig_match_creativity_playmaking_zero_flair_stalemate

## Purpose

Identify finished scoreless matches where neither side completes a single dribble, signaling an
extreme low-flair, low-separation creative stalemate.

## Tactical And Statistical Logic

- Trigger condition:
  - `match_total_goals = 0`
  - `match_combined_successful_dribbles = 0`
  - with `period = 'All'`, `match_finished = 1`, and valid `match_id`.
- Emits one row per side (`home`, `away`) at `match_team` grain for symmetric downstream usage.
- Keeps bilateral diagnostics for chance creation and territory (key passes, xA, shots, xG,
  possession, opposition-half passes, opposition-box touches).
- Adds directness substitutes (`cross_attempts`, `long_ball_attempts`) to profile whether teams
  replaced dribbling with lower-risk progression channels.
- Similarity gate note:
  - `sig_match_creativity_playmaking_unproductive_beauty` is closest structurally (scoreless and
    dribble-aware), but it requires very high dribble and key-pass volume (`>= 40`, `>= 20`) rather
    than zero successful dribbles.
  - `sig_match_creativity_playmaking_dribbling_battle` is the inverse profile, triggered by very
    high combined successful dribbles (`> 40`).
  - `sig_match_possession_passing_clean_game` overlaps on low-event control archetypes, but it is
    possession-family, not creativity/playmaking dribble-collapse logic.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/match/sig_match_creativity_playmaking_zero_flair_stalemate.sql`
- Runner: `scripts/gold/run_gold_sql_jobs.py`
- Target table: `gold_signals.sig_match_creativity_playmaking_zero_flair_stalemate`

## Example Execution

```bash
python3 scripts/gold/run_gold_sql_jobs.py --date YYYYMMDD --kind signal --id sig_match_creativity_playmaking_zero_flair_stalemate
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join key and dedup anchor |
| `match_date` | Match date | Time slicing and backfill reproducibility |
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
| `trigger_threshold_match_total_goals` | Goal threshold in trigger (`0`) | Explicit trigger provenance |
| `trigger_threshold_match_combined_successful_dribbles` | Combined successful dribble threshold in trigger (`0`) | Explicit trigger provenance |
| `match_total_goals` | Combined home+away goals | Confirms scoreless condition in output |
| `match_combined_successful_dribbles` | Combined successful dribbles in match | Core no-flair trigger metric |
| `triggered_team_successful_dribbles` | Triggered-side successful dribbles | Side-level dribble completion baseline |
| `opponent_successful_dribbles` | Opponent successful dribbles | Bilateral dribble completion comparator |
| `successful_dribbles_delta` | Triggered minus opponent successful dribbles | Net dribble-completion differential |
| `triggered_team_dribble_attempts` | Triggered-side dribble attempts | Distinguishes no-attempt vs failed-attempt states |
| `opponent_dribble_attempts` | Opponent dribble attempts | Bilateral attempt-volume comparator |
| `dribble_attempts_delta` | Triggered minus opponent dribble attempts | Net dribble intent differential |
| `triggered_team_dribble_success_pct` | Triggered-side dribble success (%) | Execution quality context under stall profile |
| `opponent_dribble_success_pct` | Opponent dribble success (%) | Bilateral execution comparator |
| `dribble_success_delta_pct` | Triggered minus opponent dribble success (%) | Net execution-quality differential |
| `triggered_team_key_passes` | Triggered-side key passes | Creativity volume context despite no dribble completions |
| `opponent_key_passes` | Opponent key passes | Bilateral creativity-volume comparator |
| `key_pass_delta` | Triggered minus opponent key passes | Net chance-creation differential |
| `triggered_team_expected_assists` | Triggered-side expected assists | Creativity quality context |
| `opponent_expected_assists` | Opponent expected assists | Bilateral creativity-quality comparator |
| `expected_assists_delta` | Triggered minus opponent expected assists | Net creativity-quality differential |
| `triggered_team_goals` | Triggered-side goals | Side outcome context |
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
| `triggered_team_big_chances` | Triggered-side big chances | High-quality chance volume context |
| `opponent_big_chances` | Opponent big chances | Bilateral high-quality chance comparator |
| `big_chances_delta` | Triggered minus opponent big chances | Net high-quality chance differential |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Circulation baseline in a dribble-null match |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Execution quality context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution-quality comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net circulation-quality differential |
| `triggered_team_possession_pct` | Triggered-side possession share (%) | Match-control context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (%) | Net control-state differential |
| `triggered_team_opposition_half_passes` | Triggered-side opposition-half passes | Territorial progression context |
| `opponent_opposition_half_passes` | Opponent opposition-half passes | Bilateral territorial comparator |
| `opposition_half_passes_delta` | Triggered minus opponent opposition-half passes | Net territorial differential |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Final-third penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator |
| `opposition_box_touches_delta` | Triggered minus opponent opposition-box touches | Net final-third pressure differential |
| `triggered_team_cross_attempts` | Triggered-side cross attempts | Directness pathway context when dribbling fails |
| `opponent_cross_attempts` | Opponent cross attempts | Bilateral directness comparator |
| `cross_attempts_delta` | Triggered minus opponent cross attempts | Net crossing-intent differential |
| `triggered_team_long_ball_attempts` | Triggered-side long-ball attempts | Alternative progression route context |
| `opponent_long_ball_attempts` | Opponent long-ball attempts | Bilateral route-one comparator |
| `long_ball_attempts_delta` | Triggered minus opponent long-ball attempts | Net route-one reliance differential |
