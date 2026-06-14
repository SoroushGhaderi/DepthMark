---
signal_id: sig_player_goalkeeping_defense_cb_playmaker_defense
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Center Back Playmaker Defense"
trigger: "Center back records >= 5 interceptions and >= 60 accurate passes in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_cb_playmaker_defense
  sql: clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_cb_playmaker_defense.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_goalkeeping_defense_cb_playmaker_defense

## Purpose

Flag center-back performances that combine high anticipation output and high distribution load, capturing defenders who both disrupt attacks and dictate buildup.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_interceptions >= 5`
  - `triggered_player_accurate_passes >= 60`
  - `triggered_player_usual_playing_position_id = 1` (defender scope)
  - `triggered_player_position_id IN (3, 4)` (center-back proxy)
  - `is_goalkeeper = 0`
  - `match_finished = 1`
- Position scope is resolved from `silver.match_personnel` with starter-priority role resolution per `(match_id, person_id)`.
- Player defensive and passing diagnostics are sourced from `silver.player_match_stat`, including interceptions, tackles, clearances, duels, pass quality, and pass-territory proxy metrics.
- Bilateral team context is sourced from `silver.period_stat` (`period = 'All'`) with symmetric `triggered_team_*` and `opponent_*` context plus explicit deltas.
- Similarity gate note:
  - `sig_player_goalkeeping_defense_interception_king`: close defensive anticipation overlap, but that trigger is single-metric interceptions (`>= 7`) and does not require heavy passing output.
  - `sig_player_possession_passing_deep_playmaker`: close center-back passing overlap, but that signal belongs to possession/passing and triggers only on accurate passes (`>= 80`) without defensive interception criteria.
  - `sig_player_goalkeeping_defense_defensive_double_double`: close dual-defensive threshold framing, but that signal uses tackles+interceptions and does not enforce center-back passing volume.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_cb_playmaker_defense.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_cb_playmaker_defense`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_goalkeeping_defense_cb_playmaker_defense
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable join key for downstream analytics and deduplication |
| `match_date` | Match date | Temporal slicing and reproducible backfills |
| `home_team_id` | Home team ID | Fixture orientation context |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team ID | Fixture orientation context |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Match-state context for defensive-distribution interpretation |
| `away_score` | Away full-time goals | Match-state context for defensive-distribution interpretation |
| `triggered_side` | Side of triggered player (`home` or `away`) | Canonical bilateral orientation |
| `triggered_player_id` | Triggered player ID | Stable player-grain identity |
| `triggered_player_name` | Triggered player name | Readable trigger attribution |
| `triggered_team_id` | Triggered player's team ID | Links player output to team context |
| `triggered_team_name` | Triggered player's team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup context |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `triggered_player_role_group` | Role label (`center_back`) | Explicit trigger-scope provenance |
| `triggered_player_position_id` | Match-specific position ID | Tactical deployment QA for center-back scope |
| `triggered_player_usual_playing_position_id` | Usual playing position ID | Stable role-gate traceability |
| `trigger_threshold_min_interceptions` | Interception threshold (`5`) | Explicit defensive trigger boundary |
| `trigger_threshold_min_accurate_passes` | Accurate-pass threshold (`60`) | Explicit distribution trigger boundary |
| `triggered_player_interceptions` | Interceptions by triggered player | Core defensive trigger metric |
| `triggered_player_accurate_passes` | Accurate passes by triggered player | Core passing trigger metric |
| `triggered_player_interceptions_above_threshold` | Interceptions above threshold (`value - 5`) | Defensive trigger severity |
| `triggered_player_accurate_passes_above_threshold` | Accurate passes above threshold (`value - 60`) | Distribution trigger severity |
| `triggered_player_total_passes` | Pass attempts by triggered player | Passing volume denominator context |
| `triggered_player_pass_accuracy_pct` | Pass accuracy of triggered player (%) | Passing execution quality context |
| `triggered_player_passes_final_third` | Final-third passes by triggered player | Progression context around buildup volume |
| `triggered_player_non_final_third_passes_proxy` | Estimated non-final-third passes (`total - final_third`) | Deep-circulation profile context |
| `triggered_player_non_final_third_pass_share_pct` | Share of non-final-third passes (%) | Quantifies deep distribution style |
| `triggered_player_touches` | Touches by triggered player | Involvement baseline |
| `triggered_player_minutes_played` | Minutes played by triggered player | Exposure and reliability context |
| `triggered_player_defensive_actions` | Defensive actions by triggered player | Composite defensive workload context |
| `triggered_player_recoveries` | Recoveries by triggered player | Regain-volume context beyond trigger |
| `triggered_player_tackles_won` | Tackles won by triggered player | Ground-defense context |
| `triggered_player_tackle_attempts` | Tackle attempts by triggered player | Tackle-volume denominator |
| `triggered_player_tackle_success_pct` | Tackle success percentage | Tackling efficiency diagnostic |
| `triggered_player_clearances` | Clearances by triggered player | Pressure-release context |
| `triggered_player_shot_blocks` | Shot blocks by triggered player | Box-protection context |
| `triggered_player_duels_won` | Duels won by triggered player | Physical contest-control context |
| `triggered_player_duels_lost` | Duels lost by triggered player | Contest-balance context |
| `triggered_player_fouls_committed` | Fouls committed by triggered player | Discipline trade-off context |
| `triggered_player_dribbled_past` | Times player was dribbled past | Defensive vulnerability counter-signal |
| `triggered_team_interceptions` | Interceptions by triggered side | Team anticipation baseline |
| `opponent_interceptions` | Interceptions by opponent side | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered minus opponent interceptions | Net anticipation differential |
| `triggered_team_clearances` | Clearances by triggered side | Team pressure-release baseline |
| `opponent_clearances` | Clearances by opponent side | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered minus opponent clearances | Net pressure-release differential |
| `triggered_team_tackles_won` | Tackles won by triggered side | Team tackling baseline |
| `opponent_tackles_won` | Tackles won by opponent side | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net tackling differential |
| `triggered_team_duels_won` | Duels won by triggered side | Team physical-control baseline |
| `opponent_duels_won` | Duels won by opponent side | Bilateral physical-control comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net contest-control differential |
| `triggered_team_fouls` | Fouls by triggered side | Team discipline context |
| `opponent_fouls` | Fouls by opponent side | Bilateral discipline comparator |
| `fouls_delta` | Triggered minus opponent fouls | Net discipline differential |
| `triggered_team_possession_pct` | Possession share of triggered side (%) | Control-state context around CB distribution profile |
| `opponent_possession_pct` | Possession share of opponent side (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered minus opponent possession share (pp) | Net control differential |
| `triggered_team_pass_accuracy_pct` | Pass accuracy of triggered side (%) | Team circulation-quality baseline |
| `opponent_pass_accuracy_pct` | Pass accuracy of opponent side (%) | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered minus opponent pass accuracy (pp) | Net circulation-quality differential |
| `player_share_of_team_interceptions_pct` | Triggered player interceptions as share of team interceptions (%) | Concentration of anticipation burden |
| `player_share_of_team_accurate_passes_pct` | Triggered player accurate passes as share of team accurate passes (%) | Concentration of buildup-distribution burden |
