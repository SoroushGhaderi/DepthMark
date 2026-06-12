---
signal_id: sig_player_goalkeeping_defense_defensive_workrate_monster
status: active
entity: player
family: goalkeeping
subfamily: defense
grain: match_player
headline: "Defensive Workrate Monster"
trigger: "Player records >= 20 total defensive actions (T, I, C, B)."
row_identity:
  - match_id
  - triggered_player_id
  - triggered_team_id
asset_paths:
  table: gold_signals.sig_player_goalkeeping_defense_defensive_workrate_monster
  sql: clickhouse/gold/signal/sig_player_goalkeeping_defense_defensive_workrate_monster.sql
  runner: scripts/gold/signal/runners/sig_player_goalkeeping_defense_defensive_workrate_monster.py
---
# sig_player_goalkeeping_defense_defensive_workrate_monster

## Purpose

Flags outfield players with extreme defensive workload volume using a compact TICB action stack:
tackles won, interceptions, clearances, and shot blocks.

## Tactical And Statistical Logic

- Trigger condition:
  - `triggered_player_total_defensive_actions_ticb >= 20`
  - `triggered_player_total_defensive_actions_ticb = tackles_won + interceptions + clearances + shot_blocks`
  - `is_goalkeeper = 0`
  - `match_finished = 1`
- Player-level metrics are sourced from `silver.player_match_stat`.
- Position metadata is sourced from `silver.match_personnel` (starter-priority role resolution) for interpretable role grouping.
- Bilateral team context is sourced from `silver.period_stat` (`period = 'All'`) with symmetric `triggered_team_*` and `opponent_*` fields plus explicit delta metrics.
- Similarity gate note:
  - `sig_player_goalkeeping_defense_defensive_double_double`: closest overlap on defensive volume, but trigger requires two separate minima (`tackles >= 5` and `interceptions >= 5`) instead of TICB aggregate workload.
  - `sig_player_goalkeeping_defense_shot_blocker_elite`: closest overlap on one TICB component, but trigger axis is shot blocks only.
  - `sig_player_goalkeeping_defense_interception_king`: closest overlap on one TICB component, but trigger axis is interceptions only.

## Technical Assets

- SQL: `clickhouse/gold/signal/sig_player_goalkeeping_defense_defensive_workrate_monster.sql`
- Runner: `scripts/gold/signal/runners/sig_player_goalkeeping_defense_defensive_workrate_monster.py`
- Target table: `gold_signals.sig_player_goalkeeping_defense_defensive_workrate_monster`

## Example Execution

```bash
python scripts/gold/signal/runners/sig_player_goalkeeping_defense_defensive_workrate_monster.py
```

## Output Schema

| Column Name | Description | Reason |
|---|---|---|
| `match_id` | Match identifier | Stable key for joins and deduplication |
| `match_date` | Match date | Temporal analysis and backfills |
| `home_team_id` | Home team ID | Fixture context |
| `home_team_name` | Home team name | Readable fixture context |
| `away_team_id` | Away team ID | Fixture context |
| `away_team_name` | Away team name | Readable fixture context |
| `home_score` | Home full-time goals | Outcome context |
| `away_score` | Away full-time goals | Outcome context |
| `triggered_side` | Triggered player side (`home`/`away`) | Canonical bilateral orientation |
| `triggered_player_id` | Triggered player ID | Player identity key |
| `triggered_player_name` | Triggered player name | Readable trigger attribution |
| `triggered_team_id` | Triggered player team ID | Player-to-team linkage |
| `triggered_team_name` | Triggered player team name | Readable team attribution |
| `opponent_team_id` | Opponent team ID | Bilateral matchup key |
| `opponent_team_name` | Opponent team name | Readable bilateral context |
| `triggered_player_role_group` | Derived role group | Role interpretation and QA |
| `triggered_player_position_id` | Match-specific position ID | Tactical deployment context |
| `triggered_player_usual_playing_position_id` | Usual position bucket | Reproducible role metadata |
| `trigger_threshold_min_total_defensive_actions_ticb` | Trigger threshold (`20`) | Explicit trigger provenance |
| `triggered_player_total_defensive_actions_ticb` | Player TICB total (`T+I+C+B`) | Core trigger metric |
| `triggered_player_total_defensive_actions_ticb_above_threshold` | TICB margin above threshold | Trigger severity ranking |
| `triggered_player_tackles_won` | Player tackles won | TICB component visibility |
| `triggered_player_interceptions` | Player interceptions | TICB component visibility |
| `triggered_player_clearances` | Player clearances | TICB component visibility |
| `triggered_player_shot_blocks` | Player shot blocks | TICB component visibility |
| `triggered_player_defensive_actions` | Source defensive_actions field | Comparison against custom TICB aggregate |
| `triggered_player_recoveries` | Player recoveries | Defensive workload context beyond TICB |
| `triggered_player_duels_won` | Player duels won | Contest-control context |
| `triggered_player_duels_lost` | Player duels lost | Contest-balance context |
| `triggered_player_fouls_committed` | Player fouls committed | Discipline trade-off context |
| `triggered_player_dribbled_past` | Times dribbled past | Vulnerability counter-context |
| `triggered_player_minutes_played` | Player minutes | Exposure reliability context |
| `triggered_player_touches` | Player touches | Involvement baseline |
| `triggered_player_total_passes` | Player pass attempts | Ball-use context |
| `triggered_player_accurate_passes` | Player accurate passes | Execution context |
| `triggered_player_pass_accuracy_pct` | Player pass accuracy (%) | Retention quality context |
| `triggered_team_total_defensive_actions_ticb` | Triggered-team TICB total | Team defensive-workload baseline |
| `opponent_total_defensive_actions_ticb` | Opponent TICB total | Bilateral TICB comparator |
| `total_defensive_actions_ticb_delta` | Triggered-team minus opponent TICB total | Net defensive-workload edge |
| `triggered_team_tackles_won` | Triggered-team tackles won | Team tackling baseline |
| `opponent_tackles_won` | Opponent tackles won | Bilateral tackling comparator |
| `tackles_won_delta` | Triggered-team minus opponent tackles | Net tackling differential |
| `triggered_team_interceptions` | Triggered-team interceptions | Team anticipation baseline |
| `opponent_interceptions` | Opponent interceptions | Bilateral anticipation comparator |
| `interceptions_delta` | Triggered-team minus opponent interceptions | Net anticipation differential |
| `triggered_team_clearances` | Triggered-team clearances | Team pressure-release baseline |
| `opponent_clearances` | Opponent clearances | Bilateral pressure-release comparator |
| `clearances_delta` | Triggered-team minus opponent clearances | Net release differential |
| `triggered_team_shot_blocks` | Triggered-team shot blocks | Team box-protection baseline |
| `opponent_shot_blocks` | Opponent shot blocks | Bilateral box-protection comparator |
| `shot_blocks_delta` | Triggered-team minus opponent shot blocks | Net block differential |
| `triggered_team_duels_won` | Triggered-team duels won | Team physical-control baseline |
| `opponent_duels_won` | Opponent duels won | Bilateral physical-control comparator |
| `duels_won_delta` | Triggered-team minus opponent duels won | Net contest differential |
| `triggered_team_fouls` | Triggered-team fouls | Team discipline context |
| `opponent_fouls` | Opponent fouls | Bilateral discipline comparator |
| `fouls_delta` | Triggered-team minus opponent fouls | Net discipline differential |
| `triggered_team_possession_pct` | Triggered-team possession (%) | Match control context |
| `opponent_possession_pct` | Opponent possession (%) | Bilateral control comparator |
| `possession_delta_pct` | Triggered-team minus opponent possession (pp) | Net control differential |
| `triggered_team_pass_accuracy_pct` | Triggered-team pass accuracy (%) | Team execution baseline |
| `opponent_pass_accuracy_pct` | Opponent pass accuracy (%) | Bilateral execution comparator |
| `pass_accuracy_delta_pct` | Triggered-team minus opponent pass accuracy (pp) | Net circulation-quality differential |
| `player_share_of_team_total_defensive_actions_ticb_pct` | Player TICB share of triggered-team TICB (%) | Concentration of team defensive burden in one player |
