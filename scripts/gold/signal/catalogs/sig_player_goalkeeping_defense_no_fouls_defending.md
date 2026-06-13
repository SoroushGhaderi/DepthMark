---
signal_id: sig_player_goalkeeping_defense_no_fouls_defending
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "No-Fouls Defending"
trigger: "Defender wins at least 5 combined tackles and duels with 0 fouls committed in a finished match."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_no_fouls_defending
  sql: clickhouse/gold/signal/sig_player_goalkeeping_defense_no_fouls_defending.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_goalkeeping_defense_no_fouls_defending

## Purpose

Flags disciplined defender performances where contest output stays high (`tackles_won + duels_won >= 5`)
while foul count remains zero, capturing clean defensive aggression.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_usual_playing_position_id = 1` (defender scope)
  - `triggered_player_tackles_duels_won_total >= 5`
  - `triggered_player_fouls_committed = 0`
  - `is_goalkeeper = 0`
  - `match_finished = 1`
- Player-level defensive metrics are sourced from `silver.player_match_stat`.
- Defender scope is resolved from `silver.match_personnel` with starter-priority role resolution at
  `(match_id, person_id)` grain.
- Bilateral team context is sourced from `silver.period_stat` (`period = 'All'`) with symmetric
  `triggered_team_*` and `opponent_*` fields plus selected deltas for comparison.
- Similarity gate note:
  - `sig_player_goalkeeping_defense_tackle_master`: close defender/tackle family overlap, but this signal does
    not require perfect tackle success and explicitly requires `0` fouls plus combined tackle+duel output.
  - `sig_player_goalkeeping_defense_defensive_double_double`: both are high-defensive-output profiles, but this
    signal emphasizes clean discipline and combined contest volume instead of tackle+interception dual thresholds.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_goalkeeping_defense_no_fouls_defending.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_no_fouls_defending`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_goalkeeping_defense_no_fouls_defending
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for joins and deduplication |
| `match_date` | Match date | Temporal slicing for trend analysis |
| `home_team_id` | Home team ID | Fixture context anchor |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team ID | Fixture context anchor |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Outcome context for defensive discipline profiles |
| `away_score` | Away full-time goals | Outcome context for defensive discipline profiles |
| `triggered_side` | Side of triggered defender (`home` or `away`) | Canonical bilateral orientation |
| `triggered_player_id` | Triggered defender ID | Player identity key |
| `triggered_player_name` | Triggered defender name | Readable player attribution |
| `triggered_team_id` | Triggered defender team ID | Links player trigger to team context |
| `triggered_team_name` | Triggered defender team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup key |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `triggered_player_role_group` | Role group label (`defender`) | Explicit role scope provenance |
| `triggered_player_position_id` | Match-specific position ID | Role deployment diagnostics |
| `triggered_player_usual_playing_position_id` | Usual playing position ID | Deterministic defender gate traceability |
| `trigger_threshold_min_tackles_duels_won_total` | Combined contest threshold (`5`) | Explicit trigger boundary for reproducibility |
| `trigger_threshold_max_fouls_committed` | Maximum fouls threshold (`0`) | Explicit discipline boundary for trigger integrity |
| `triggered_player_tackles_won` | Tackles won by triggered defender | Core contest-volume component |
| `triggered_player_duels_won` | Duels won by triggered defender | Core contest-volume component |
| `triggered_player_tackles_duels_won_total` | Combined tackles won + duels won | Primary trigger metric |
| `triggered_player_tackles_duels_won_above_threshold` | Combined contest output above threshold | Trigger severity context beyond minimum boundary |
| `triggered_player_fouls_committed` | Fouls committed by triggered defender | Core discipline metric required at zero |
| `triggered_player_tackle_attempts` | Tackle attempts by triggered defender | Tackle denominator context |
| `triggered_player_tackle_success_pct` | Tackle success percentage by triggered defender | Tackling efficiency diagnostic |
| `triggered_player_duels_lost` | Duels lost by triggered defender | Contest-balance context |
| `triggered_player_interceptions` | Interceptions by triggered defender | Anticipation context beyond trigger metrics |
| `triggered_player_clearances` | Clearances by triggered defender | Pressure-release context |
| `triggered_player_recoveries` | Recoveries by triggered defender | Regain-and-transition context |
| `triggered_player_defensive_actions` | Total defensive actions by triggered defender | Composite defensive workload context |
| `triggered_player_ground_duels_won` | Ground duels won by triggered defender | Ground-contest profile context |
| `triggered_player_ground_duel_attempts` | Ground duel attempts by triggered defender | Ground-duel denominator context |
| `triggered_player_ground_duel_success_pct` | Ground duel success percentage | Ground-duel efficiency diagnostic |
| `triggered_player_aerial_duels_won` | Aerial duels won by triggered defender | Aerial profile context |
| `triggered_player_aerial_duel_attempts` | Aerial duel attempts by triggered defender | Aerial denominator context |
| `triggered_player_aerial_duel_success_pct` | Aerial duel success percentage | Aerial efficiency context |
| `triggered_player_dribbled_past` | Times dribbled past for triggered defender | Vulnerability counter-signal context |
| `triggered_player_minutes_played` | Minutes played by triggered defender | Exposure reliability context |
| `triggered_player_touches` | Touches by triggered defender | Involvement baseline |
| `triggered_player_total_passes` | Pass attempts by triggered defender | Distribution-load context |
| `triggered_player_accurate_passes` | Accurate passes by triggered defender | Distribution execution context |
| `triggered_player_pass_accuracy_pct` | Pass accuracy percentage by triggered defender | Retention quality context |
| `triggered_team_tackles_won` | Team tackles won by triggered side | Team tackling baseline |
| `opponent_tackles_won` | Team tackles won by opponent side | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered minus opponent tackles won | Net tackling differential context |
| `triggered_team_duels_won` | Team duels won by triggered side | Team contest-control baseline |
| `opponent_duels_won` | Team duels won by opponent side | Bilateral contest-control comparator |
| `duels_won_delta` | Triggered minus opponent duels won | Net contest differential context |
| `triggered_team_fouls` | Team fouls by triggered side | Team discipline baseline |
| `opponent_fouls` | Team fouls by opponent side | Bilateral discipline comparator |
| `fouls_delta` | Triggered minus opponent fouls | Net discipline differential context |
| `triggered_team_interceptions` | Team interceptions by triggered side | Team anticipation baseline |
| `opponent_interceptions` | Team interceptions by opponent side | Bilateral anticipation comparator |
| `triggered_team_clearances` | Team clearances by triggered side | Team pressure-release baseline |
| `opponent_clearances` | Team clearances by opponent side | Bilateral pressure-release comparator |
| `triggered_team_shot_blocks` | Team shot blocks by triggered side | Team box-protection context |
| `opponent_shot_blocks` | Team shot blocks by opponent side | Bilateral box-protection comparator |
| `triggered_team_possession_pct` | Possession percentage of triggered side | Control-state context |
| `opponent_possession_pct` | Possession percentage of opponent side | Bilateral control comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy percentage | Team execution context |
| `opponent_pass_accuracy_pct` | Opponent-side pass accuracy percentage | Bilateral execution comparator |
| `player_share_of_team_tackles_duels_won_pct` | Triggered player share of side combined tackles+duels won | Concentration of clean defensive contest output in one player |
