---
signal_id: sig_player_creativity_playmaking_unselfish_forward
status: active
entity: player
family: creativity
subfamily: playmaking
grain: match_player
headline: "Unselfish Forward"
trigger: "Striker records >= 3 key passes with 0 total shots in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_creativity_playmaking_unselfish_forward
  sql: clickhouse/gold/signal/sig_player_creativity_playmaking_unselfish_forward.sql
  runner: scripts/gold/signal/runners/sig_player_creativity_playmaking_unselfish_forward.py
---
# sig_player_creativity_playmaking_unselfish_forward

## Purpose

Detects forward-led playmaking performances where a striker proxy creates at least three key passes but attempts no shots.

## Tactical And Statistical Logic

- Trigger conditions:
  - `triggered_player_usual_playing_position_id = 3` (forward/striker proxy).
  - `triggered_player_key_passes >= 3`.
  - `triggered_player_total_shots = 0`.
  - `match_finished = 1`.
- Key passes are sourced from `silver.player_match_stat.chances_created`; shots are from `silver.player_match_stat.total_shots`.
- Positional classification is sourced from `silver.match_personnel` using starter-priority `argMax` selection per match/player.
- Team context retains bilateral key-pass volume, shot volume, xG, passing, possession, and territorial metrics from `silver.period_stat` (`period = 'All'`) and team key-pass aggregates.
- Similarity gate note:
  - `sig_player_creativity_playmaking_maestro_output`: overlaps on key-pass creation but has no zero-shot or striker gate.
  - `sig_player_creativity_playmaking_high_value_turnover`: overlaps on key-pass framing but uses zero-assist guard, not zero-shot forward behavior.
  - `sig_player_shooting_goals_high_xg_no_shot`: overlaps on zero-shot concept, but trigger is box-touch volume and sits in shooting taxonomy.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_creativity_playmaking_unselfish_forward.sql`
- Runner: `scripts/gold/signal/runners/sig_player_creativity_playmaking_unselfish_forward.py`
- Target table: `gold_signals.sig_player_creativity_playmaking_unselfish_forward`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_creativity_playmaking_unselfish_forward.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Unique match identifier | Stable join and deduplication anchor |
| `match_date` | Match date | Time-series slicing and reproducible backfills |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Human-readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Human-readable fixture context |
| `home_score` | Home full-time goals | Outcome context |
| `away_score` | Away full-time goals | Outcome context |
| `triggered_side` | Triggered side (`home` or `away`) | Canonical side orientation |
| `triggered_player_id` | Triggered player ID | Durable player identity key |
| `triggered_player_name` | Triggered player name | Readable player attribution |
| `triggered_team_id` | Triggered player's team ID | Player-to-team linkage |
| `triggered_team_name` | Triggered player's team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup anchor |
| `opponent_team_name` | Opponent team name | Readable bilateral comparator |
| `triggered_player_role_group` | Role group label (`striker_proxy`) | Explicit trigger-role provenance |
| `triggered_player_position_id` | Match-specific position ID | Role diagnostics for lineup usage |
| `triggered_player_usual_playing_position_id` | Usual position bucket | Documents positional trigger gate |
| `trigger_threshold_min_key_passes` | Key-pass threshold (`3`) | Explicit trigger provenance |
| `trigger_threshold_max_total_shots` | Shot ceiling (`0`) | Explicit no-shot trigger provenance |
| `trigger_threshold_required_usual_playing_position_id` | Required usual position (`3`) | Explicit striker-proxy requirement |
| `triggered_player_key_passes` | Triggered player key passes | Core creative trigger metric |
| `triggered_player_key_passes_above_threshold` | Key passes above floor (`key_passes - 3`) | Trigger severity beyond activation |
| `triggered_player_total_shots` | Triggered player total shots | Core no-shot guard metric |
| `triggered_player_shots_on_target` | Triggered player shots on target | Confirms shot profile under guard |
| `triggered_player_shot_accuracy_pct` | Triggered player shot accuracy (%) | Shot-quality diagnostic under no-shot trigger |
| `triggered_player_assists` | Triggered player assists | Downstream outcome context for created chances |
| `triggered_player_expected_assists` | Triggered player expected assists (xA) | Chance-quality context for key passes |
| `triggered_player_chances_created` | Triggered player chances created | Reinforces key-pass source metric |
| `triggered_player_passes_final_third` | Triggered player final-third passes | Territorial progression context |
| `triggered_player_touches_opposition_box` | Triggered player opposition-box touches | Advanced-zone involvement context |
| `triggered_player_accurate_passes` | Triggered player accurate passes | Passing execution context |
| `triggered_player_total_passes` | Triggered player total passes | Workload and circulation context |
| `triggered_player_pass_accuracy_pct` | Triggered player pass accuracy (%) | Passing reliability context |
| `triggered_player_minutes_played` | Triggered player minutes played | Exposure context for trigger interpretation |
| `triggered_player_touches` | Triggered player total touches | Overall involvement baseline |
| `triggered_team_total_key_passes` | Total key passes by triggered team | Team creative-volume denominator |
| `opponent_total_key_passes` | Total key passes by opponent team | Bilateral creative-volume comparator |
| `key_pass_delta` | Triggered-team minus opponent key passes | Net creative-volume edge |
| `triggered_team_total_shots` | Total shots by triggered team | Team finishing-volume context |
| `opponent_total_shots` | Total shots by opponent team | Bilateral finishing-volume comparator |
| `total_shot_delta` | Triggered-team minus opponent total shots | Net shot-volume edge |
| `triggered_team_expected_goals` | Triggered-side xG | Team chance-quality context |
| `opponent_expected_goals` | Opponent-side xG | Bilateral chance-quality comparator |
| `expected_goals_delta` | Triggered-side minus opponent xG | Net chance-quality balance |
| `triggered_team_pass_attempts` | Pass attempts by triggered side | Team circulation baseline |
| `opponent_pass_attempts` | Pass attempts by opponent side | Bilateral circulation comparator |
| `triggered_team_accurate_passes` | Accurate passes by triggered side | Team passing-quality baseline |
| `opponent_accurate_passes` | Accurate passes by opponent side | Bilateral passing-quality comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy (%) | Team execution context |
| `opponent_pass_accuracy_pct` | Opponent-side pass accuracy (%) | Bilateral execution comparator |
| `triggered_team_possession_pct` | Triggered-side possession (%) | Match-control context |
| `opponent_possession_pct` | Opponent-side possession (%) | Bilateral control comparator |
| `triggered_team_touches_opposition_box` | Triggered-side opposition-box touches | Team territorial-pressure context |
| `opponent_touches_opposition_box` | Opponent-side opposition-box touches | Bilateral territorial-pressure comparator |
| `player_share_of_team_key_passes_pct` | Player share of team key passes (%) | Concentration of creative workload |
| `player_share_of_team_passes_pct` | Player share of team pass attempts (%) | Concentration of circulation responsibility |
| `player_share_of_team_opposition_box_touches_pct` | Player share of team opposition-box touches (%) | Concentration of advanced-territory involvement |
