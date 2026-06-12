---
signal_id: sig_team_creativity_playmaking_unassisted_goals
status: active
entity: team
family: creativity
subfamily: playmaking
grain: match_team
headline: "Unassisted Goals"
trigger: "Team scores >= 2 unassisted solo-effort goals (dribble-attributed or long-range) in one finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold_signals.sig_team_creativity_playmaking_unassisted_goals
  sql: clickhouse/gold/signal/sig_team_creativity_playmaking_unassisted_goals.sql
  runner: scripts/gold/signal/runners/sig_team_creativity_playmaking_unassisted_goals.py
---
# sig_team_creativity_playmaking_unassisted_goals

## Purpose

Detect team-level matches where finishing comes from self-created solo actions rather than assisted combinations, specifically unassisted dribble-attributed or long-range goals.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_team_unassisted_solo_goals >= 2`
- Solo-effort definition:
  - Goal event from `silver.shot` with `is_goal = 1`, `is_own_goal = 0`, `assist_player_id = 0/NULL`.
  - Event is treated as solo effort when:
    - dribble-attributed text proxy is present (`shot_type` / `situation` / `goal_description` contains dribble/solo/individual), or
    - long-range proxy is present (`is_from_inside_box = 0` or long-distance text proxy).
- Match scope:
  - `silver.match.match_finished = 1`
  - `match_id > 0`
- Side orientation:
  - Emits one row per triggered side (`home` / `away`) with bilateral `triggered_team_*` and `opponent_*` context.
- Similarity gate note:
  - Closest active `team | creativity | playmaking` candidates are `sig_team_creativity_playmaking_chance_barrage` (high key-pass volume) and `sig_team_creativity_playmaking_final_third_siege` (extreme final-third circulation), but both are buildup/chance-creation volume signals rather than assistless solo-finishing signals.
  - `sig_team_creativity_playmaking_total_fluidity` overlaps in team-grain creativity taxonomy but measures distributed creators (`>= 6` distinct key-pass players), not solo goal execution.
  - Cross-family neighbor `sig_team_shooting_goals_no_striker_needed` is role-composition based and does not require unassisted dribble/long-shot goals.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_creativity_playmaking_unassisted_goals.sql`
- Runner: `scripts/gold/signal/runners/sig_team_creativity_playmaking_unassisted_goals.py`
- Target table: `gold_signals.sig_team_creativity_playmaking_unassisted_goals`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_creativity_playmaking_unassisted_goals.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable join and deduplication anchor |
| `match_date` | Match date | Time slicing and replay traceability |
| `home_team_id` | Home team identifier | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team identifier | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Outcome context |
| `away_score` | Away full-time goals | Outcome context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical row identity at match-team grain |
| `triggered_team_id` | Triggered team identifier | Triggered entity key for downstream joins |
| `triggered_team_name` | Triggered team name | Readable triggered-side attribution |
| `opponent_team_id` | Opponent team identifier | Bilateral opponent orientation |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator |
| `trigger_threshold_min_unassisted_solo_goals` | Minimum solo unassisted goals threshold (`2`) | Explicit trigger provenance for QA and governance |
| `trigger_threshold_max_assists_on_solo_goals` | Maximum assists allowed on counted solo goals (`0`) | Encodes no-assist requirement directly in output contract |
| `triggered_team_unassisted_solo_goals` | Triggered-team unassisted solo-effort goals | Core trigger metric |
| `opponent_unassisted_solo_goals` | Opponent unassisted solo-effort goals | Bilateral core-metric comparator |
| `unassisted_solo_goals_delta` | Triggered minus opponent unassisted solo-effort goals | Net solo-finishing edge |
| `triggered_team_unassisted_dribble_goals` | Triggered-team unassisted dribble-attributed goals | Isolates individual carry/dribble finishing route |
| `opponent_unassisted_dribble_goals` | Opponent unassisted dribble-attributed goals | Bilateral dribble-route comparator |
| `unassisted_dribble_goals_delta` | Triggered minus opponent unassisted dribble goals | Net dribble-finishing differential |
| `triggered_team_unassisted_long_shot_goals` | Triggered-team unassisted long-range goals | Isolates distance-finishing route without assists |
| `opponent_unassisted_long_shot_goals` | Opponent unassisted long-range goals | Bilateral long-range comparator |
| `unassisted_long_shot_goals_delta` | Triggered minus opponent unassisted long-range goals | Net long-range-finishing differential |
| `triggered_team_unassisted_non_own_goals` | Triggered-team total unassisted non-own goals | Broader assistless-finishing baseline beyond solo subset |
| `opponent_unassisted_non_own_goals` | Opponent total unassisted non-own goals | Bilateral assistless baseline comparator |
| `unassisted_non_own_goals_delta` | Triggered minus opponent unassisted non-own goals | Net assistless-finishing volume differential |
| `triggered_team_non_own_goals` | Triggered-team non-own goals | Denominator context for normalization |
| `opponent_non_own_goals` | Opponent non-own goals | Bilateral denominator comparator |
| `non_own_goals_delta` | Triggered minus opponent non-own goals | Net non-own-goal output differential |
| `triggered_team_unassisted_solo_goal_share_of_non_own_goals_pct` | Share of triggered-team non-own goals that are unassisted solo efforts (%) | Normalized trigger intensity beyond raw counts |
| `opponent_unassisted_solo_goal_share_of_non_own_goals_pct` | Share of opponent non-own goals that are unassisted solo efforts (%) | Bilateral normalized comparator |
| `unassisted_solo_goal_share_of_non_own_goals_delta_pct` | Triggered minus opponent solo-goal share (%) | Net normalized solo-finishing differential |
| `triggered_team_goals` | Triggered-team official full-time goals | Official scoreline context |
| `opponent_goals` | Opponent official full-time goals | Bilateral scoreline comparator |
| `goal_delta` | Triggered minus opponent goals | Compact outcome differential |
| `triggered_team_total_shots` | Triggered-team total shots | Shooting-volume context |
| `opponent_total_shots` | Opponent total shots | Bilateral shooting-volume comparator |
| `triggered_team_shots_on_target` | Triggered-team shots on target | Shot-execution context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral shot-execution comparator |
| `triggered_team_shot_accuracy_pct` | Triggered-team shot accuracy (%) | Finishing precision context around solo goals |
| `opponent_shot_accuracy_pct` | Opponent shot accuracy (%) | Bilateral precision comparator |
| `shot_accuracy_delta_pct` | Triggered minus opponent shot accuracy (%) | Net finishing-precision differential |
| `triggered_team_xg` | Triggered-team expected goals | Chance-quality baseline |
| `opponent_xg` | Opponent expected goals | Bilateral chance-quality comparator |
| `xg_delta` | Triggered minus opponent expected goals | Net chance-quality differential |
| `triggered_team_touches_opposition_box` | Triggered-team opposition-box touches | Territorial penetration context |
| `opponent_touches_opposition_box` | Opponent opposition-box touches | Bilateral penetration comparator |
| `triggered_team_pass_attempts` | Triggered-team pass attempts | Circulation-volume baseline |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Build-up execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral build-up comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (%) | Net circulation-quality differential |
| `triggered_team_possession_pct` | Triggered-team possession share (%) | Match control context |
| `opponent_possession_pct` | Opponent possession share (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (%) | Net control differential |
