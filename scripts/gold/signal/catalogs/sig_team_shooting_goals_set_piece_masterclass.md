---
signal_id: sig_team_shooting_goals_set_piece_masterclass
status: active
entity: team
family: shooting
subfamily: goals
grain: match_team
headline: "Set-Piece Masterclass"
trigger: "Team scores at least one corner goal, one free-kick goal, and one penalty goal in a finished match."
row_identity:
  - match_id
  - triggered_side
asset_paths:
  table: gold.sig_team_shooting_goals_set_piece_masterclass
  sql: clickhouse/gold/signal/sig_team_shooting_goals_set_piece_masterclass.sql
  runner: scripts/gold/signal/runners/sig_team_shooting_goals_set_piece_masterclass.py
---
# sig_team_shooting_goals_set_piece_masterclass

## Purpose

Detect teams that complete a three-channel set-piece scoring profile in one match by scoring from a corner, a free kick, and a penalty.

## Tactical And Statistical Logic

- Trigger condition:
  - Finished match (`match_finished = 1`).
  - Side-level scoring taxonomy requires all three components:
    - `triggered_team_corner_goals >= 1`
    - `triggered_team_free_kick_goals >= 1`
    - `triggered_team_penalty_goals >= 1`
- Event taxonomy:
  - Corner goals: `silver.shot.situation = 'FromCorner'`.
  - Free-kick goals: `situation = 'FreeKick'` or free-kick markers in `shot_type`.
  - Penalty goals: case-insensitive penalty markers in `situation` or `shot_type`.
  - Own goals are excluded from set-piece category metrics.
- Bilateral match-team output:
  - Trigger is evaluated independently for home and away sides, preserving `triggered_team_*` and `opponent_*` symmetry.
- Similarity gate note:
  - Closest active signal is `sig_team_shooting_goals_dead_ball_specialists`.
  - This signal intentionally coexists because it requires a strict three-type conjunction (corner + free kick + penalty), while `dead_ball_specialists` is a broader count-based dead-ball trigger (`>= 2`) without mandatory category diversity.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_team_shooting_goals_set_piece_masterclass.sql`
- Runner: `scripts/gold/signal/runners/sig_team_shooting_goals_set_piece_masterclass.py`
- Target table: `gold.sig_team_shooting_goals_set_piece_masterclass`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_team_shooting_goals_set_piece_masterclass.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join and dedup key |
| `match_date` | Match date | Temporal slicing and reproducible backfills |
| `home_team_id` | Home team identifier | Preserves fixture orientation |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team identifier | Preserves fixture orientation |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Outcome context around trigger |
| `away_score` | Away full-time goals | Outcome context around trigger |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical match-team row identity |
| `triggered_team_id` | Triggered team identifier | Side-oriented entity key |
| `triggered_team_name` | Triggered team name | Readable side attribution |
| `opponent_team_id` | Opponent team identifier | Bilateral comparator key |
| `opponent_team_name` | Opponent team name | Readable opponent context |
| `trigger_threshold_min_corner_goals` | Corner-goal trigger threshold (`1`) | Explicit trigger provenance |
| `trigger_threshold_min_free_kick_goals` | Free-kick-goal trigger threshold (`1`) | Explicit trigger provenance |
| `trigger_threshold_min_penalty_goals` | Penalty-goal trigger threshold (`1`) | Explicit trigger provenance |
| `triggered_team_goals` | Triggered-side total goals | Scoreline baseline |
| `opponent_goals` | Opponent total goals | Bilateral scoreline comparator |
| `goal_delta` | Triggered minus opponent goals | Outcome edge context |
| `triggered_team_corner_goals` | Corner goals by triggered side | First required trigger component |
| `opponent_corner_goals` | Corner goals by opponent side | Bilateral set-piece comparator |
| `corner_goals_delta` | Triggered minus opponent corner goals | Corner-source finishing edge |
| `triggered_team_free_kick_goals` | Free-kick goals by triggered side | Second required trigger component |
| `opponent_free_kick_goals` | Free-kick goals by opponent side | Bilateral set-piece comparator |
| `free_kick_goals_delta` | Triggered minus opponent free-kick goals | Free-kick finishing edge |
| `triggered_team_penalty_goals` | Penalty goals by triggered side | Third required trigger component |
| `opponent_penalty_goals` | Penalty goals by opponent side | Bilateral set-piece comparator |
| `penalty_goals_delta` | Triggered minus opponent penalty goals | Penalty finishing edge |
| `triggered_team_set_piece_components_hit` | Number of required components hit by triggered side (`0-3`) | Trigger intensity and validation |
| `opponent_set_piece_components_hit` | Number of required components hit by opponent side (`0-3`) | Bilateral diversity comparator |
| `set_piece_components_hit_delta` | Triggered minus opponent component count | Set-piece diversity edge |
| `triggered_team_corner_free_kick_penalty_goals` | Triggered-side goals from the three-component set-piece family | Combined trigger-family output |
| `opponent_corner_free_kick_penalty_goals` | Opponent goals from the same set-piece family | Bilateral combined output comparator |
| `corner_free_kick_penalty_goals_delta` | Triggered minus opponent combined set-piece-family goals | Net family-level finishing edge |
| `triggered_team_corner_free_kick_penalty_goal_share_pct` | Share of triggered-side goals from the three-component family (%) | Dependence on set-piece-family scoring |
| `opponent_corner_free_kick_penalty_goal_share_pct` | Opponent share of goals from the same family (%) | Bilateral dependence comparator |
| `corner_free_kick_penalty_goal_share_delta_pct` | Triggered minus opponent family goal share (percentage points) | Compact style differential |
| `triggered_team_corner_free_kick_penalty_shots` | Triggered-side shots in the three-component set-piece family | Volume denominator for conversion context |
| `opponent_corner_free_kick_penalty_shots` | Opponent shots in the same family | Bilateral family shot-volume comparator |
| `triggered_team_corner_free_kick_penalty_expected_goals` | Triggered-side expected goals from the family | Family chance-quality baseline |
| `opponent_corner_free_kick_penalty_expected_goals` | Opponent expected goals from the family | Bilateral family chance-quality comparator |
| `corner_free_kick_penalty_expected_goals_delta` | Triggered minus opponent family xG | Net set-piece-family chance-quality edge |
| `triggered_team_corner_free_kick_penalty_goals_per_shot` | Triggered-side family goals per family shot | Family finishing efficiency |
| `opponent_corner_free_kick_penalty_goals_per_shot` | Opponent family goals per family shot | Bilateral efficiency comparator |
| `corner_free_kick_penalty_goals_per_shot_delta` | Triggered minus opponent family goals-per-shot | Net family finishing-efficiency edge |
| `triggered_team_total_shots` | Triggered-side total shots | Overall shooting-volume context |
| `opponent_total_shots` | Opponent total shots | Bilateral shooting-volume comparator |
| `triggered_team_shots_on_target` | Triggered-side shots on target | Execution context |
| `opponent_shots_on_target` | Opponent shots on target | Bilateral execution comparator |
| `triggered_team_expected_goals` | Triggered-side expected goals | Whole-match chance-quality baseline |
| `opponent_expected_goals` | Opponent expected goals | Bilateral chance-quality comparator |
| `expected_goals_delta` | Triggered minus opponent expected goals | Net chance-generation context |
| `triggered_team_set_play_expected_goals` | Triggered-side set-play expected goals from period stats | Corroborates set-piece quality at aggregate level |
| `opponent_set_play_expected_goals` | Opponent set-play expected goals from period stats | Bilateral set-play-quality comparator |
| `set_play_expected_goals_delta` | Triggered minus opponent set-play expected goals | Net set-play-quality edge |
| `triggered_team_corners` | Triggered-side corners won | Restart-pressure proxy |
| `opponent_corners` | Opponent corners won | Bilateral restart-pressure comparator |
| `triggered_team_touches_opposition_box` | Triggered-side touches in opposition box | Territorial penetration context |
| `opponent_touches_opposition_box` | Opponent touches in opposition box | Bilateral penetration comparator |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Match-control context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control-share comparator |
| `possession_delta_pct` | Triggered minus opponent possession (percentage points) | Compact control differential |
| `triggered_team_pass_attempts` | Triggered-side pass attempts | Circulation-volume context |
| `opponent_pass_attempts` | Opponent pass attempts | Bilateral circulation comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Technical execution context |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral technical execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (percentage points) | Compact possession-quality differential |
