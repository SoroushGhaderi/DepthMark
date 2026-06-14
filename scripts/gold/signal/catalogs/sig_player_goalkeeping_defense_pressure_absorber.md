---
signal_id: sig_player_goalkeeping_defense_pressure_absorber
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Pressure Absorber"
trigger: "Defender plays >= 90 minutes, records > 50 touches, and has 0 turnovers (proxy: failed passes + failed dribbles)."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_pressure_absorber
  sql: clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_pressure_absorber.sql
  runner: scripts/gold/run_sql_job.py
---
# sig_player_goalkeeping_defense_pressure_absorber

## Purpose

Flags defender matches where the player completes a full-match workload (`>= 90` minutes), stays highly involved
on the ball (`touches > 50`), and avoids possession losses via a conservative turnover proxy.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_usual_playing_position_id = 1` (defender scope)
  - `triggered_player_minutes_played >= 90`
  - `triggered_player_touches > 50`
  - `triggered_player_turnovers_proxy = 0`
  - `is_goalkeeper = 0`
  - `match_finished = 1`
- Turnover proxy is defined as:
  - `failed_passes = max(total_passes - accurate_passes, 0)`
  - `failed_dribbles = max(dribble_attempts - successful_dribbles, 0)`
  - `turnovers_proxy = failed_passes + failed_dribbles`
- Player data is sourced from `silver.player_match_stat`; defender role gating is sourced from
  `silver.match_personnel` with starter-priority role resolution.
- Bilateral team context is sourced from `silver.period_stat` (`period = 'All'`) with symmetric
  `triggered_team_*` and `opponent_*` turnover proxies, possession, passing, and defensive outputs.
- Similarity gate note:
  - `sig_player_goalkeeping_defense_no_fouls_defending`: both profile clean defending, but this signal is
    possession-security focused (`touches + zero turnovers`) rather than clean challenge output (`0 fouls`).
  - `sig_player_goalkeeping_defense_passive_defender`: both apply defender scope and minutes filters, but this
    signal requires high on-ball involvement while passive-defender flags minimal defensive activity.

## Technical Assets

- SQL: `clickhouse/gold/dml/signals/player/sig_player_goalkeeping_defense_pressure_absorber.sql`
- Runner: `scripts/gold/run_sql_job.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_pressure_absorber`

## Example Execution

```bash
python scripts/gold/run_sql_job.py --kind signal --id sig_player_goalkeeping_defense_pressure_absorber
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable join key |
| `match_date` | Match date | Temporal analysis |
| `home_team_id` | Home team ID | Fixture context |
| `home_team_name` | Home team name | Readable context |
| `away_team_id` | Away team ID | Fixture context |
| `away_team_name` | Away team name | Readable context |
| `home_score` | Home goals | Outcome context |
| `away_score` | Away goals | Outcome context |
| `triggered_side` | Triggered player side | Bilateral orientation |
| `triggered_player_id` | Triggered player ID | Player identity |
| `triggered_player_name` | Triggered player name | Readable attribution |
| `triggered_team_id` | Triggered player team ID | Player-team linkage |
| `triggered_team_name` | Triggered player team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Matchup context |
| `opponent_team_name` | Opponent team name | Readable matchup context |
| `triggered_player_role_group` | Role group label (`defender`) | Role-scope provenance |
| `triggered_player_position_id` | Match-specific position ID | Deployment diagnostics |
| `triggered_player_usual_playing_position_id` | Usual position ID | Deterministic defender gate |
| `trigger_threshold_min_minutes_played` | Minutes threshold (`90`) | Trigger provenance |
| `trigger_threshold_min_touches_exclusive` | Touch threshold (`> 50`) | Trigger provenance |
| `trigger_threshold_max_turnovers_proxy` | Turnover threshold (`0`) | Trigger provenance |
| `triggered_player_minutes_played` | Minutes played | Exposure reliability |
| `triggered_player_touches` | Touches | Core involvement trigger |
| `triggered_player_turnovers_proxy` | Turnovers proxy (`failed_passes + failed_dribbles`) | Core possession-security trigger |
| `triggered_player_failed_passes` | Failed passes proxy | Trigger decomposition |
| `triggered_player_failed_dribbles` | Failed dribbles proxy | Trigger decomposition |
| `triggered_player_total_passes` | Total passes | Passing-volume context |
| `triggered_player_accurate_passes` | Accurate passes | Passing execution context |
| `triggered_player_pass_accuracy_pct` | Pass accuracy percentage | Passing quality context |
| `triggered_player_dribble_attempts` | Dribble attempts | Carrying-volume context |
| `triggered_player_successful_dribbles` | Successful dribbles | Carrying execution context |
| `triggered_player_dribble_success_pct` | Dribble success percentage | Carrying quality context |
| `triggered_player_tackles_won` | Tackles won | Defensive output context |
| `triggered_player_tackle_attempts` | Tackle attempts | Tackle denominator context |
| `triggered_player_tackle_success_pct` | Tackle success percentage | Tackle efficiency context |
| `triggered_player_duels_won` | Duels won | Physical-control context |
| `triggered_player_duels_lost` | Duels lost | Contest-balance context |
| `triggered_player_interceptions` | Interceptions | Anticipation context |
| `triggered_player_clearances` | Clearances | Pressure-release context |
| `triggered_player_recoveries` | Recoveries | Regain context |
| `triggered_player_defensive_actions` | Defensive actions | Composite workload context |
| `triggered_player_ground_duels_won` | Ground duels won | Duel-profile context |
| `triggered_player_ground_duel_attempts` | Ground duel attempts | Ground-duel denominator |
| `triggered_player_ground_duel_success_pct` | Ground duel success percentage | Ground-duel efficiency |
| `triggered_player_aerial_duels_won` | Aerial duels won | Aerial-profile context |
| `triggered_player_aerial_duel_attempts` | Aerial duel attempts | Aerial denominator |
| `triggered_player_aerial_duel_success_pct` | Aerial duel success percentage | Aerial efficiency context |
| `triggered_player_fouls_committed` | Fouls committed | Discipline context |
| `triggered_player_dribbled_past` | Times dribbled past | Vulnerability context |
| `triggered_team_turnovers_proxy` | Team turnover proxy for triggered side | Team-level possession-security baseline |
| `opponent_turnovers_proxy` | Team turnover proxy for opponent side | Bilateral comparator |
| `turnovers_proxy_delta` | Triggered minus opponent turnover proxy | Net possession-security differential |
| `triggered_team_failed_passes` | Triggered-side failed passes | Team turnover decomposition |
| `opponent_failed_passes` | Opponent failed passes | Bilateral decomposition |
| `triggered_team_failed_dribbles` | Triggered-side failed dribbles | Team turnover decomposition |
| `opponent_failed_dribbles` | Opponent failed dribbles | Bilateral decomposition |
| `triggered_team_possession_pct` | Triggered-side possession percentage | Control-state context |
| `opponent_possession_pct` | Opponent possession percentage | Bilateral control comparator |
| `triggered_team_pass_accuracy_pct` | Triggered-side pass accuracy percentage | Team execution baseline |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy percentage | Bilateral execution comparator |
| `triggered_team_duels_won` | Triggered-side duels won | Team physical-control baseline |
| `opponent_duels_won` | Opponent duels won | Bilateral physical comparator |
| `triggered_team_interceptions` | Triggered-side interceptions | Team anticipation baseline |
| `opponent_interceptions` | Opponent interceptions | Bilateral anticipation comparator |
| `triggered_team_clearances` | Triggered-side clearances | Team pressure-release baseline |
| `opponent_clearances` | Opponent clearances | Bilateral pressure-release comparator |
