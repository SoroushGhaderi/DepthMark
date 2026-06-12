---
signal_id: sig_player_creativity_playmaking_the_quarterback
status: active
entity: player
family: creativity
subfamily: playmaking
grain: match_player
headline: "The Quarterback"
trigger: "Center back completes >= 8 successful long balls in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_creativity_playmaking_the_quarterback
  sql: clickhouse/gold/signal/sig_player_creativity_playmaking_the_quarterback.sql
  runner: scripts/gold/signal/runners/sig_player_creativity_playmaking_the_quarterback.py
---
# sig_player_creativity_playmaking_the_quarterback

## Purpose

Detect center-back playmakers who drive long-range distribution by completing at least eight accurate long balls in a single finished match.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_accurate_long_balls >= 8`
  - `triggered_player_usual_playing_position_id = 1` (defender role)
  - `triggered_player_position_id IN (3, 4)` (center-back proxy)
  - `is_goalkeeper = 0`
  - `match_finished = 1`
- Position scope is resolved from `silver.match_personnel` with starter-priority role resolution per `(match_id, person_id)`.
- Successful long balls are mapped to `silver.player_match_stat.accurate_long_balls`.
- Bilateral passing and long-ball context is preserved through symmetric `triggered_team_*` and `opponent_*` fields from `silver.period_stat` (`period = 'All'`).
- Similarity gate note:
  - `sig_player_possession_passing_long_ball_specialist`: strongest metric overlap (accurate long balls), but that signal is position-agnostic and also requires long-ball success rate `> 80%`.
  - `sig_player_goalkeeping_defense_cb_playmaker_defense`: same center-back role framing, but trigger is interceptions plus high accurate passes, not long-ball completion volume.
  - `sig_player_creativity_playmaking_line_breaker`: same creativity/playmaking family, but it uses directional progression proxies rather than direct player long-ball completion threshold.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_creativity_playmaking_the_quarterback.sql`
- Runner: `scripts/gold/signal/runners/sig_player_creativity_playmaking_the_quarterback.py`
- Target table: `gold_signals.sig_player_creativity_playmaking_the_quarterback`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_creativity_playmaking_the_quarterback.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable deduplication and join key |
| `match_date` | Match date | Temporal slicing and backfill traceability |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home goals at full time | Outcome context for interpretation |
| `away_score` | Away goals at full time | Outcome context for interpretation |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side identity at `match_player` grain |
| `triggered_player_id` | Triggered player ID | Primary player identity key |
| `triggered_player_name` | Triggered player name | Readable signal attribution |
| `triggered_team_id` | Triggered player team ID | Links player output to team context |
| `triggered_team_name` | Triggered player team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup orientation |
| `opponent_team_name` | Opponent team name | Readable opponent attribution |
| `triggered_player_role_group` | Role label (`center_back`) | Explicit role-scope provenance |
| `triggered_player_position_id` | Match-specific position ID | Tactical deployment QA for center-back gate |
| `triggered_player_usual_playing_position_id` | Usual playing position ID | Stable role gate provenance |
| `trigger_threshold_min_accurate_long_balls` | Trigger threshold (`8`) | Explicit trigger boundary provenance |
| `triggered_player_accurate_long_balls` | Accurate long balls by triggered player | Core trigger metric |
| `triggered_player_accurate_long_balls_above_threshold` | Accurate long balls above threshold | Trigger severity beyond activation |
| `triggered_player_long_ball_attempts` | Long-ball attempts by triggered player | Denominator context for completion volume |
| `triggered_player_long_ball_success_rate_pct` | Long-ball success rate of triggered player (%) | Execution efficiency context |
| `triggered_player_total_passes` | Total passes by triggered player | Passing workload context |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Passing execution context |
| `triggered_player_pass_accuracy_pct` | Pass accuracy of triggered player (%) | Normalized passing quality context |
| `triggered_player_passes_final_third` | Final-third passes by triggered player | Progression context |
| `triggered_player_chances_created` | Chances created by triggered player | Playmaking volume context |
| `triggered_player_expected_assists` | Expected assists by triggered player | Chance-quality context |
| `triggered_player_touches_opposition_box` | Touches in opposition box by triggered player | Advanced-territory involvement context |
| `triggered_player_minutes_played` | Minutes played by triggered player | Exposure context |
| `triggered_player_touches` | Total touches by triggered player | On-ball involvement context |
| `triggered_team_long_ball_attempts` | Long-ball attempts by triggered team | Team directness baseline |
| `opponent_long_ball_attempts` | Long-ball attempts by opponent team | Bilateral directness comparator |
| `triggered_team_accurate_long_balls` | Accurate long balls by triggered team | Team long-ball output baseline |
| `opponent_accurate_long_balls` | Accurate long balls by opponent team | Bilateral long-ball output comparator |
| `triggered_team_long_ball_accuracy_pct` | Long-ball accuracy of triggered team (%) | Team direct-play quality context |
| `opponent_long_ball_accuracy_pct` | Long-ball accuracy of opponent team (%) | Bilateral direct-play quality comparator |
| `long_ball_accuracy_delta_pct` | Triggered minus opponent long-ball accuracy (pp) | Net direct-play quality differential |
| `triggered_team_pass_attempts` | Pass attempts by triggered team | Team circulation baseline |
| `opponent_pass_attempts` | Pass attempts by opponent team | Bilateral circulation comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered team | Team passing-quality baseline |
| `opponent_accurate_passes` | Accurate passes by opponent team | Bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered team (%) | Team execution context |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent team (%) | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Net circulation-quality differential |
| `triggered_team_possession_pct` | Possession share of triggered team (%) | Match control context |
| `opponent_possession_pct` | Possession share of opponent team (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (pp) | Net control differential |
| `player_share_of_team_accurate_long_balls_pct` | Triggered player share of team accurate long balls (%) | Concentration of long-ball creation burden |
| `player_share_of_team_long_ball_attempts_pct` | Triggered player share of team long-ball attempts (%) | Concentration of direct-distribution workload |
